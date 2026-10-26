#!/bin/sh

WIFI_COUNTRY="__WIFI_COUNTRY__"

board_name=$(cat /tmp/sysinfo/board_name)

configure_wifi() {
	local radio=$1
	local channel=$2
	local htmode=$3
	local txpower=$4
	local ssid=$5
	local key=$6
	local encryption=${7:-"psk2+ccmp"} # 新增 encryption 参数，如果为空则默认为 psk2+ccmp
	local now_encryption=$(uci -q get wireless.default_radio${radio}.encryption)

	# 射频级参数始终写入，避免从其他固件迁移后因为接口已有加密而跳过，
	# 导致某个频段继续使用旧国家码/auto 信道。
	uci -q batch <<EOF
set wireless.radio${radio}.channel="${channel}"
set wireless.radio${radio}.htmode="${htmode}"
set wireless.radio${radio}.mu_beamformer='1'
set wireless.radio${radio}.country="${WIFI_COUNTRY}"
set wireless.radio${radio}.txpower="${txpower}"
set wireless.radio${radio}.cell_density='0'
set wireless.radio${radio}.disabled='0'
EOF

	# 接口级 SSID/加密只在尚未配置时写入，保留用户已有设置。
	if [ -z "$now_encryption" ] || [ "$now_encryption" = "none" ]; then
		uci -q batch <<EOF
set wireless.default_radio${radio}.ssid="${ssid}"
set wireless.default_radio${radio}.encryption="${encryption}"
set wireless.default_radio${radio}.key="${key}"
set wireless.default_radio${radio}.ieee80211k='1'
set wireless.default_radio${radio}.time_advertisement='2'
set wireless.default_radio${radio}.time_zone='CST-8'
set wireless.default_radio${radio}.bss_transition='1'
set wireless.default_radio${radio}.wnm_sleep_mode='1'
set wireless.default_radio${radio}.wnm_sleep_mode_no_keys='1'
EOF
	fi
}

configure_wifi7() {
	local radio=$1
	local channel=$2
	local htmode=$3
	local txpower=$4
	local ssid=$5
	local key=$6
	local encryption=${7:-"psk2"} # 新增 encryption 参数，如果为空则默认为 psk2
	local now_encryption=$(uci -q get wireless.default_radio${radio}.encryption)
	local bandmode=$(uci -q get wireless.radio${radio}.band)
	local country="$WIFI_COUNTRY"

	# 6G 使用 world 国家码，避免 CN 直接禁用 6G 频段。
	[ "$bandmode" = "6g" ] && country='00'

	# 射频级参数始终写入，避免接口已有加密时跳过国家码/信道。
	uci -q batch <<EOF
set wireless.radio${radio}.channel="${channel}"
set wireless.radio${radio}.htmode="${htmode}"
set wireless.radio${radio}.disabled='0'
set wireless.radio${radio}.country="${country}"
set wireless.radio${radio}.sku_idx='0'
set wireless.radio${radio}.he_twt_responder='1'
set wireless.radio${radio}.cell_density='0'
set wireless.radio${radio}.txpower="${txpower}"
set wireless.radio${radio}.noscan='0'
EOF

	if [ -z "$now_encryption" ] || [ "$now_encryption" = "none" ]; then
		uci -q batch <<EOF
set wireless.default_radio${radio}.ssid="${ssid}"
set wireless.default_radio${radio}.encryption="${encryption}"
set wireless.default_radio${radio}.key="${key}"
set wireless.default_radio${radio}.vif_txpower="${txpower}"
set wireless.default_radio${radio}.ieee80211k='1'
set wireless.default_radio${radio}.time_zone='CST-8'
set wireless.default_radio${radio}.bss_transition='1'
set wireless.default_radio${radio}.wmm='1'
EOF
	fi
	if [ "$bandmode" = "2g" ]; then
		uci -q batch <<EOF
set wireless.radio${radio}.legacy_rates='1'
set wireless.radio${radio}.sr_enable='1'
set wireless.radio${radio}.etxbfen='1'
EOF
	elif [ "$bandmode" = "5g" ]; then
		uci -q batch <<EOF
set wireless.radio${radio}.background_radar='0'
EOF
	elif [ "$bandmode" = "6g" ]; then
		uci -q batch <<EOF
set wireless.radio${radio}.lpi_enable='0'
EOF
	fi
}

jdc_ax1800_pro_wifi_cfg() {
	configure_wifi 0 149 HE80 20 'JDC_AX1800PRO_5G' '12345678'
	configure_wifi 1 1 HE20 20 'JDC_AX1800PRO' '12345678'
}

jdc_ax6600_wifi_cfg() {
	configure_wifi 0 149 HE80 22 'JDC_AX6600_5G1' '12345678'
	configure_wifi 1 1 HE20 22 'JDC_AX6600' '12345678'
	configure_wifi 2 44 HE160 23 'JDC_AX6600_5G2' '12345678'
}

redmi_ax5_wifi_cfg() {
	configure_wifi 0 149 HE80 20 'Redmi_AX5_5G' '12345678'
	configure_wifi 1 1 HE20 20 'Redmi_AX5' '12345678'
}

find_radio_by_band() {
	local band=$1
	local i

	for i in 0 1 2 3; do
		if [ "$(uci -q get wireless.radio${i}.band)" = "$band" ]; then
			echo "$i"
			return 0
		fi
	done

	return 1
}

aliyun_ap8220_wifi_cfg() {
	local radio5 radio2

	radio5=$(find_radio_by_band 5g)
	radio2=$(find_radio_by_band 2g)

	# 旧版/未生成 band 时退回 AP8220 的默认顺序。
	[ -n "$radio5" ] || radio5=0
	[ -n "$radio2" ] || radio2=1

	configure_wifi "$radio5" 149 HE80 26 'Aliyun_AP8220_5G' '12345678'
	configure_wifi "$radio2" 1 HE20 23 'Aliyun_AP8220' '12345678'
}

cmcc_rax3000m_wifi_cfg() {
	configure_wifi 0 1 HE20 23 'CMCC_RAX3000M' '12345678'
	configure_wifi 1 44 HE160 25 'CMCC_RAX3000M_5G' '12345678'
}

redmi_ax6_wifi_cfg() {
	configure_wifi 0 149 HE80 22 'Redmi_AX6_5G' '12345678'
	configure_wifi 1 1 HE20 21 'Redmi_AX6' '12345678'
}

qihoo_360v6_wifi_cfg() {
	configure_wifi 0 1 HE80 20 'Qihoo_360V6' '12345678'
	configure_wifi 1 149 HE20 20 'Qihoo_360V6_5G' '12345678'
}

linksys_mx4x00_wifi_cfg() {
	configure_wifi 0 1 HE20 22 'Linksys_MX4X00' '12345678'
	configure_wifi 1 149 HE80 21 'Linksys_MX4X00_5G1' '12345678'
	configure_wifi 2 44 HE80 21 'Linksys_MX4X00_5G2' '12345678'
}

gemtek_w1701k_wifi_cfg() {
	configure_wifi7 0 1 EHT20 23 'Gemtek_W1701K' '12345678'
	configure_wifi7 1 44 EHT160 23 'Gemtek_W1701K_5G' '12345678'
	configure_wifi7 2 1 EHT320 23 'Gemtek_W1701K_6G' '12345678' 'sae'
	uci set wireless.radio2.disabled='1'
}

link_nn6000_wifi_cfg() {
	configure_wifi 0 149 HE80 19 'Link_NN6000_5G' '12345678'
	configure_wifi 1 1 HT20 19 'Link_NN6000' '12345678'
}

case "${board_name}" in
jdcloud,ax1800-pro | \
	jdcloud,re-ss-01)
	jdc_ax1800_pro_wifi_cfg
	;;
jdcloud,ax6600 | \
	jdcloud,re-cs-02)
	jdc_ax6600_wifi_cfg
	;;
redmi,ax5 | \
	redmi,ax5-jdcloud)
	redmi_ax5_wifi_cfg
	;;
aliyun,ap8220)
	aliyun_ap8220_wifi_cfg
	;;
cmcc,rax3000m)
	cmcc_rax3000m_wifi_cfg
	;;
redmi,ax6 | \
	redmi,ax6-stock)
	redmi_ax6_wifi_cfg
	;;
qihoo,360v6)
	qihoo_360v6_wifi_cfg
	;;
linksys,mx4200v1 | \
	linksys,mx4200v2 | \
	linksys,mx4300)
	linksys_mx4x00_wifi_cfg
	;;
gemtek,w1701k-ubi)
	gemtek_w1701k_wifi_cfg
	;;
link,nn6000-v2)
	link_nn6000_wifi_cfg
	;;
*)
	exit 0
	;;
esac

uci commit wireless
/etc/init.d/network restart
