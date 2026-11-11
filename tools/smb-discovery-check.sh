#!/bin/sh
# 在 OpenWrt 设备上运行（只读，不改配置）：
#   scp tools/smb-discovery-check.sh root@192.168.2.150:/tmp/
#   ssh root@192.168.2.150 sh /tmp/smb-discovery-check.sh
#
# 目标：确认 Windows 10/11“网络”里能不能按名字发现 ksmbd 共享。
# kmod 模式（ksmbd）没有 nmbd，名字发现依赖 wsdd2：
#   - WSD    UDP 3702  -> 在“网络”里出现设备
#   - LLMNR  UDP 5355  -> \\主机名 能被解析
# 本脚本只做检查，不做任何修改。

say() { printf '\n===== %s =====\n' "$*"; }
kv()  { printf '%-28s %s\n' "$1" "$2"; }
have() { command -v "$1" >/dev/null 2>&1; }

say "构建版本"
[ -f /etc/wrt_release ] && cat /etc/wrt_release | grep -E 'RELEASE_ID|BUILD_MODEL|BUILD_DATE' || kv "RELEASE_ID" "(无 /etc/wrt_release)"
kv "运行时长" "$(uptime 2>/dev/null)"

say "主机名（两台设备不能相同）"
kv "hostname" "$(cat /proc/sys/kernel/hostname 2>/dev/null)"
kv "UCI hostname" "$(uci -q get system.@system[0].hostname)"
kv "NetBIOS 名(wsdd2 使用)" "$(sed 's/\..*//' /proc/sys/kernel/hostname 2>/dev/null | tr '[:lower:]' '[:upper:]')"

say "LAN 接口与地址"
. /lib/functions/network.sh 2>/dev/null
network_get_device LANDEV lan 2>/dev/null
kv "UCI lan 设备" "${LANDEV:-<解析失败>}"
ip -4 addr show 2>/dev/null | grep -E 'inet ' | sed 's/^/  /'

say "相关软件包"
if have apk; then
	apk list -I 2>/dev/null | grep -E '^(wsdd2|ksmbd-server|ksmbd-avahi-service|luci-app-ksmbd|umdns|avahi)-' || echo "  (未找到 wsdd2/ksmbd/avahi 相关包)"
elif have opkg; then
	opkg list-installed 2>/dev/null | grep -E '^(wsdd2|ksmbd-server|ksmbd-avahi-service|luci-app-ksmbd|umdns|avahi) ' || echo "  (未找到 wsdd2/ksmbd/avahi 相关包)"
else
	echo "  没有 apk/opkg"
fi

say "服务状态"
for svc in ksmbd wsdd2; do
	if [ -x "/etc/init.d/$svc" ]; then
		kv "$svc enabled" "$(/etc/init.d/$svc enabled && echo yes || echo no)"
		kv "$svc running" "$(/etc/init.d/$svc running && echo yes || echo no)"
	else
		kv "$svc" "未安装 /etc/init.d/$svc"
	fi
done
ps w 2>/dev/null | grep -E '[k]smbd|[w]sdd2' | sed 's/^/  /'

# wsdd2 必须和 ksmbd 绑在同一接口，否则 WSD/LLMNR 广播到错误的网桥。
KSMBD_NET="$(uci -q get ksmbd.@globals[0].interface)"
KSMBD_NET="${KSMBD_NET%% *}"
KSMBD_NET="${KSMBD_NET:-lan}"
network_get_device KSMBD_DEV "$KSMBD_NET" 2>/dev/null
WSDD_DEV="$(ps w 2>/dev/null | grep '[w]sdd2' | sed -n 's/.*-i \([^ ]*\).*/\1/p' | head -1)"
WSDD_IP=""
[ -n "$WSDD_DEV" ] && WSDD_IP="$(ip -4 addr show dev "$WSDD_DEV" 2>/dev/null | awk '/inet /{sub(/\/.*/,"",$2); print $2; exit}')"
kv "ksmbd 接口 -> 设备" "$KSMBD_NET -> ${KSMBD_DEV:-?}"
kv "wsdd2 -i" "${WSDD_DEV:-<未指定>}"
if [ -n "$KSMBD_DEV" ] && [ -n "$WSDD_DEV" ] && [ "$KSMBD_DEV" != "$WSDD_DEV" ]; then
	echo "  [!] 不一致：WSD/LLMNR 在 $WSDD_DEV 广播，SMB 在 $KSMBD_DEV，名字发现会失败"
fi

say "监听端口（期望 445 / 3702 / 5355）"
if have ss; then
	ss -lunp 2>/dev/null | grep -E ':445|:3702|:5355' | sed 's/^/  /'
	ss -ltnp 2>/dev/null | grep -E ':445|:139' | sed 's/^/  /'
else
	netstat -lunp 2>/dev/null | grep -E ':445|:3702|:5355' | sed 's/^/  /'
	netstat -ltnp 2>/dev/null | grep -E ':445|:139' | sed 's/^/  /'
fi
echo "  (445=smbd, 3702=WSD, 5355=LLMNR)"

say "ksmbd 运行配置（关键项）"
CONF=/var/etc/ksmbd/ksmbd.conf
[ -f "$CONF" ] || CONF=/etc/ksmbd/ksmbd.conf
if [ -f "$CONF" ]; then
	kv "配置文件" "$CONF"
	grep -E '^\s*(netbios name|interfaces|bind interfaces only|workgroup|map to guest|server min protocol)' "$CONF" | sed 's/^/  /'
else
	echo "  未找到 ksmbd.conf"
fi
kv "ksmbd UCI interface" "$(uci -q get ksmbd.@globals[0].interface)"
kv "ksmbd UCI allow_guest_ipc" "$(uci -q get ksmbd.@globals[0].allow_guest_ipc)"

say "UCI 服务开关"
kv "ksmbd.@globals[0].enabled" "$(uci -q get ksmbd.@globals[0].enabled)"

say "防火墙 lan 区 input 策略（应为 ACCEPT）"
if have fw4; then
	fw4 print 2>/dev/null | grep -A4 "chain input_lan" | sed 's/^/  /'
else
	kv "fw4" "不可用"
fi

say "wsdd2 / ksmbd 日志"
logread 2>/dev/null | grep -iE 'wsdd|ksmbd' | tail -20 | sed 's/^/  /'

say "WSD/LLMNR 防火墙规则"
if have nft; then
	nft list ruleset 2>/dev/null | grep -E 'udp dport.*(3702|5355)' | head -6 | sed 's/^/  /'
	nft list ruleset 2>/dev/null | grep -qE 'udp dport.*(3702|5355)' \
		|| echo "  未找到 3702/5355 放行规则（跨 zone 访问会被 REJECT）"
else
	echo "  nft 不可用，跳过"
fi

say "WSD 自探测（239.255.255.250:3702）"
if have socat && [ -n "$WSDD_IP" ]; then
	probe='<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/08/addressing" xmlns:wsd="http://schemas.xmlsoap.org/ws/2005/04/discovery"><soap:Header><wsa:Action>http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</wsa:Action><wsa:MessageID>urn:uuid:00000000-0000-0000-0000-000000000001</wsa:MessageID><wsa:To>urn:schemas-xmlsoap-org:ws:2005:04:discovery</wsa:To></soap:Header><soap:Body><wsd:Probe/></soap:Body></soap:Envelope>'
	printf '%s' "$probe" | socat -T3 - UDP4-DATAGRAM:239.255.255.250:3702,ip-multicast-if="$WSDD_IP",ttl=1 2>/dev/null \
		| grep -oE 'http://[0-9.]+:3702/[0-9a-zA-Z-]+' | sort -u | sed 's/^/  /'
else
	echo "  socat 不可用或 wsdd2 未运行，跳过"
fi

say "macOS / Bonjour（_smb._tcp）"
kv "umdns network" "$(uci -q get umdns.@umdns[0].network)"
if [ -f /etc/avahi/services/smb.service ]; then
	kv "avahi smb.service" "present"
else
	kv "avahi smb.service" "missing"
fi
if ps w 2>/dev/null | grep -q '[a]vahi-daemon'; then
	kv "avahi-daemon" "running"
else
	kv "avahi-daemon" "not running"
fi
nft list ruleset 2>/dev/null | grep -E 'udp dport 5353' | head -3 | sed 's/^/  /'

say "桥接组播成员（应能看到 239.255.255.250 / 224.0.0.251）"
MCAST_DEV="${WSDD_DEV:-$LANDEV}"
if [ -n "$MCAST_DEV" ]; then
	ip maddr show dev "$MCAST_DEV" 2>/dev/null | sed 's/^/  /'
else
	ip maddr show 2>/dev/null | sed 's/^/  /'
fi

say "下一步：抓包确认 Windows 的 WSD 探测有没有到设备"
cat <<EOF
  在 Windows 上打开“此电脑 -> 网络”，同时在本机执行：
    tcpdump -ni ${MCAST_DEV:-br-lan} -c 20 'udp port 3702 or udp port 5355'
  看到 239.255.255.250.3702 的包 => 网络能到，问题在 wsdd2/配置；
  一个包都看不到            => 组播没过来（AP 隔离 / 交换机 IGMP snooping / 不在同一二层）。

  macOS 侧另测 Bonjour：
    dns-sd -B _smb._tcp local
    dns-sd -L <hostname> _smb._tcp local
EOF
