#!/usr/bin/env bash
# target、kernel 与 base system 源码修正。

is_libwrt_build() {
    [[ "$REPO_URL" == *"LiBwrt/LibWrt"* || "$BUILD_DIR" == *"libwrt"* ]]
}

is_vikingyfy_nss_build() {
    [[ "$REPO_URL" == *"VIKINGYFY/immortalwrt"* || "$BUILD_DIR" == *"imm-nss"* ]]
}

fix_mtwifi_security_defaults() {
    local file="$BUILD_DIR/package/mtk/applications/mtwifi-cfg-ucode/files/lib/wifi/mtwifi.uc"

    if [ ! -f "$file" ]; then
        return 0
    fi

    if grep -q '"encryption": "none"' "$file"; then
        sed -i "s|\"encryption\": \"none\"|\"encryption\": \"psk2\", \"key\": \"${WIFI_PASSWORD:-kaiwater/wrt_release}\"|" "$file"
        echo "已将 mtwifi 首次启动默认 WiFi 改为 psk2 + 默认密码。"
    fi

    if ! grep -q '"key":' "$file"; then
        echo "警告：未找到 mtwifi.uc 的默认 key 注入点，保留上游默认。" >&2
    fi
}


fix_mtwifi_temperature() {
    # mt_wifi7 厂商驱动不向上暴露芯片温度，LuCI 概览只剩 CPU 温度。
    # 补丁给每个 band 建一个 /proc/net/mt_wifi/tempN，恢复 WiFi 温度显示。
    # 注：不能用 hwmon/thermal，那些 API 是 GPL-only，mt_wifi 是 Proprietary。
    local patch_dir="$BUILD_DIR/package/mtk/drivers/mt_wifi7/patches"
    local src="$BASE_PATH/patches/mtwifi-temperature-proc.patch"
    local dst="900-add-temperature-proc.patch"

    if [ ! -d "$patch_dir" ] || [ ! -f "$src" ]; then
        echo "未找到 mt_wifi7 驱动源码目录，跳过 WiFi 温度补丁。"
        return 0
    fi

    install -Dm644 "$src" "$patch_dir/$dst"
    echo "已为 mt_wifi7 增加 /proc/net/mt_wifi 芯片温度接口。"
}


write_release_identity() {
    local etc_dir="$BUILD_DIR/package/base-files/files/etc"
    local build_date="${BUILD_DATE:-$(TZ=Asia/Shanghai date +%y.%m.%d_%H.%M.%S)}"
    local build_model="${BUILD_MODEL:-unknown}"
    local build_id="${BUILD_ID:-${build_date}_${build_model}}"
    local source_rev="${SOURCE_REV:-$(git -C "$BUILD_DIR" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)}"
    local source_url="${REPO_URL:-unknown}"
    local source_branch="${REPO_BRANCH:-unknown}"
    local run_id="${GITHUB_RUN_ID:-local}"
    local lan_addr="${LAN_ADDR:-192.168.50.1}"
    local lan_cidr="${lan_addr}/24"
    local wifi_password="${WIFI_PASSWORD:-kaiwater/wrt_release}"

    if [ ! -d "$etc_dir" ]; then
        echo "警告：未找到 base-files/etc，跳过 release identity 写入。" >&2
        return 0
    fi

    mkdir -p "$etc_dir/uci-defaults"
    cat > "$etc_dir/wrt_release" <<EOF
RELEASE_ID='$build_id'
BUILD_DATE='$build_date'
BUILD_MODEL='$build_model'
SOURCE_REPO='$source_url'
SOURCE_BRANCH='$source_branch'
SOURCE_REV='$source_rev'
BUILD_RUN='$run_id'
LAN_ADDR='$lan_addr'
LAN_CIDR='$lan_cidr'
WIFI_PASSWORD='$wifi_password'
EOF
    chmod 0644 "$etc_dir/wrt_release"

    # runtime 追加到 /etc/openwrt_release，让 `ubus call system board`
    # 也能直接看到构建标识。
    cat > "$etc_dir/uci-defaults/98-wrt-release" <<'EOF'
#!/bin/sh

[ -f /etc/wrt_release ] || exit 0
. /etc/wrt_release

[ -f /etc/openwrt_release ] || : > /etc/openwrt_release

add_field() {
    key="$1"
    value="$2"
    sed -i "/^${key}=/d" /etc/openwrt_release
    printf "%s='%s'\n" "$key" "$value" >> /etc/openwrt_release
}

add_field DISTRIB_BUILD_ID "$RELEASE_ID"
add_field DISTRIB_BUILD_DATE "$BUILD_DATE"
add_field DISTRIB_BUILD_MODEL "$BUILD_MODEL"
add_field DISTRIB_SOURCE_REV "$SOURCE_REV"
add_field DISTRIB_BUILD_RUN "$BUILD_RUN"

exit 0
EOF
    chmod 0755 "$etc_dir/uci-defaults/98-wrt-release"

    echo "构建标识：${build_id}（source ${source_rev}）"
}

fix_default_set() {
    # 注入默认主题、系统设置和目标平台通用补丁。
    if [ -d "$BUILD_DIR/feeds/luci/collections/" ]; then
        find "$BUILD_DIR/feeds/luci/collections/" -type f -name "Makefile" -exec sed -i "s/luci-theme-bootstrap/luci-theme-$THEME_SET/g" {} \;
    fi

    local wifi_uci_script="$BUILD_DIR/package/base-files/files/etc/uci-defaults/992_set-wifi-uci.sh"

    install -Dm544 "$BASE_PATH/patches/990_set_argon_primary" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/990_set_argon_primary"
    install -Dm544 "$BASE_PATH/patches/991_custom_settings" "$BUILD_DIR/package/base-files/files/etc/uci-defaults/991_custom_settings"
    install -Dm544 "$BASE_PATH/patches/992_set-wifi-uci.sh" "$wifi_uci_script"
    sed -i "s/__WIFI_COUNTRY__/${WIFI_COUNTRY:-CN}/g" "$wifi_uci_script"
    sed -i "s|__WIFI_PASSWORD__|${WIFI_PASSWORD:-kaiwater/wrt_release}|g" "$wifi_uci_script"

    if [ -f "$BUILD_DIR/package/emortal/autocore/files/tempinfo" ]; then
        if [ -f "$BASE_PATH/patches/tempinfo" ]; then
            \cp -f "$BASE_PATH/patches/tempinfo" "$BUILD_DIR/package/emortal/autocore/files/tempinfo"
        fi
    fi
}


fix_miniupnpd() {
    local miniupnpd_dir="$BUILD_DIR/feeds/packages/net/miniupnpd"
    local patch_file="999-chanage-default-leaseduration.patch"

    if [ -d "$miniupnpd_dir" ] && [ -f "$BASE_PATH/patches/$patch_file" ]; then
        install -Dm644 "$BASE_PATH/patches/$patch_file" "$miniupnpd_dir/patches/$patch_file"
    fi
}


change_dnsmasq2full() {
    if ! grep -q "dnsmasq-full" $BUILD_DIR/include/target.mk; then
        sed -i 's/dnsmasq/dnsmasq-full/g' ./include/target.mk
    fi
}


fix_mk_def_depends() {
    sed -i 's/libustream-mbedtls/libustream-openssl/g' $BUILD_DIR/include/target.mk 2>/dev/null
    if [ -f $BUILD_DIR/target/linux/qualcommax/Makefile ]; then
        sed -i 's/wpad-openssl/wpad-mesh-openssl/g' $BUILD_DIR/target/linux/qualcommax/Makefile
    fi
}


fix_kconfig_recursive_dependency() {
    local file="$BUILD_DIR/scripts/package-metadata.pl"
    if [ -f "$file" ]; then
        sed -i 's/<PACKAGE_\$pkgname/!=y/g' "$file"
        echo "已修复 package-metadata.pl 的 Kconfig 递归依赖生成逻辑。"
    fi
}


update_default_lan_addr() {
    local CFG_PATH="$BUILD_DIR/package/base-files/files/bin/config_generate"
    if [ -f $CFG_PATH ]; then
        sed -i 's/192\.168\.[0-9]*\.[0-9]*/'$LAN_ADDR'/g' $CFG_PATH
    fi
}


remove_something_nss_kmod() {
    local ipq_mk_path="$BUILD_DIR/target/linux/qualcommax/Makefile"
    local target_mks=("$BUILD_DIR/target/linux/qualcommax/ipq60xx/target.mk" "$BUILD_DIR/target/linux/qualcommax/ipq807x/target.mk")

    for target_mk in "${target_mks[@]}"; do
        if [ -f "$target_mk" ]; then
            sed -i 's/kmod-qca-nss-crypto//g' "$target_mk"
        fi
    done

    if [ -f "$ipq_mk_path" ]; then
        sed -i '/kmod-qca-nss-drv-eogremgr/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-gre/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-map-t/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-match/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-mirror/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-tun6rd/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-tunipip6/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-vxlanmgr/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-drv-wifi-meshmgr/d' "$ipq_mk_path"
        sed -i '/kmod-qca-nss-macsec/d' "$ipq_mk_path"

        sed -i 's/automount //g' "$ipq_mk_path"
        sed -i 's/cpufreq //g' "$ipq_mk_path"
    fi
}


update_affinity_script() {
    local affinity_script_dir="$BUILD_DIR/target/linux/qualcommax"

    if [ -d "$affinity_script_dir" ]; then
        find "$affinity_script_dir" -name "set-irq-affinity" -exec rm -f {} \;
        find "$affinity_script_dir" -name "smp_affinity" -exec rm -f {} \;
        install -Dm755 "$BASE_PATH/patches/smp_affinity" "$affinity_script_dir/base-files/etc/init.d/smp_affinity"
    fi
}


fix_hash_value() {
    local makefile_path="$1"
    local old_hash="$2"
    local new_hash="$3"
    local package_name="$4"

    if [ -f "$makefile_path" ]; then
        sed -i "s/$old_hash/$new_hash/g" "$makefile_path"
        echo "已修正 $package_name 的哈希值。"
    fi
}


apply_hash_fixes() {
    fix_hash_value \
        "$BUILD_DIR/package/feeds/packages/smartdns/Makefile" \
        "860a816bf1e69d5a8a2049483197dbebe8a3da2c9b05b2da68c85ef7dee7bdde" \
        "582021891808442b01f551bc41d7d95c38fb00c1ec78a58ac3aaaf898fbd2b5b" \
        "smartdns"

    fix_hash_value \
        "$BUILD_DIR/package/feeds/packages/smartdns/Makefile" \
        "320c99a65ca67a98d11a45292aa99b8904b5ebae5b0e17b302932076bf62b1ec" \
        "43e58467690476a77ce644f9dc246e8a481353160644203a1bd01eb09c881275" \
        "smartdns"
}


update_ath11k_fw() {
    local makefile="$BUILD_DIR/package/firmware/ath11k-firmware/Makefile"
    local new_mk="$BASE_PATH/patches/ath11k_fw.mk"
    local url="https://raw.githubusercontent.com/VIKINGYFY/immortalwrt/refs/heads/main/package/firmware/ath11k-firmware/Makefile"
    local ipq60_target="$BUILD_DIR/target/linux/qualcommax/ipq60xx/target.mk"
    local ipq807_target="$BUILD_DIR/target/linux/qualcommax/ipq807x/target.mk"

    if [ -d "$(dirname "$makefile")" ]; then
        if [ -s "$new_mk" ]; then
            echo "使用仓库内置的 ath11k-firmware Makefile：$new_mk"
        else
            echo "正在更新 ath11k-firmware Makefile..."
            if ! curl_retry -fsSL -o "$new_mk" "$url"; then
                echo "错误：从 $url 下载 ath11k-firmware Makefile 失败" >&2
                exit 1
            fi
            if [ ! -s "$new_mk" ]; then
                echo "错误：下载的 ath11k-firmware Makefile 为空文件" >&2
                exit 1
            fi
        fi
        cp -f "$new_mk" "$makefile"

        local ipq50_target="$BUILD_DIR/target/linux/qualcommax/ipq50xx/target.mk"
        local target_mk
        for target_mk in "$ipq50_target" "$ipq60_target" "$ipq807_target"; do
            [ -f "$target_mk" ] || continue
            sed -i 's/ath11k-firmware-ipq5018\([^-[:alnum:]_]\|$\)/ath11k-firmware-ipq5018-ddwrt\1/g' "$target_mk"
            sed -i 's/ath11k-firmware-ipq6018\([^-[:alnum:]_]\|$\)/ath11k-firmware-ipq6018-ddwrt\1/g' "$target_mk"
            sed -i 's/ath11k-firmware-ipq8074\([^-[:alnum:]_]\|$\)/ath11k-firmware-ipq8074-ddwrt\1/g' "$target_mk"
            sed -i 's/ath11k-firmware-qcn9074\([^-[:alnum:]_]\|$\)/ath11k-firmware-qcn9074-ddwrt\1/g' "$target_mk"

            if grep -qE 'ath11k-firmware-(ipq5018|ipq6018|ipq8074|qcn9074)([^-[:alnum:]_]|$)' "$target_mk"; then
                echo "错误：$target_mk 中仍存在未转换为 -ddwrt 的 ath11k 固件包名" >&2
                return 1
            fi
        done

        # 设备定义（image/*.mk）也会直接写死默认固件包名；只改 target.mk
        # 会留下 ath11k-firmware-qcn9074 之类的旧名，apk 在 target install 阶段会报 no such package。
        local image_dir="$BUILD_DIR/target/linux/qualcommax/image"
        local image_mk
        for image_mk in "$image_dir/ipq50xx.mk" "$image_dir/ipq60xx.mk" "$image_dir/ipq807x.mk"; do
            [ -f "$image_mk" ] || continue
            sed -i 's/ath11k-firmware-ipq5018\([^-[:alnum:]_]\|$\)/ath11k-firmware-ipq5018-ddwrt\1/g' "$image_mk"
            sed -i 's/ath11k-firmware-ipq6018\([^-[:alnum:]_]\|$\)/ath11k-firmware-ipq6018-ddwrt\1/g' "$image_mk"
            sed -i 's/ath11k-firmware-ipq8074\([^-[:alnum:]_]\|$\)/ath11k-firmware-ipq8074-ddwrt\1/g' "$image_mk"
            sed -i 's/ath11k-firmware-qcn9074\([^-[:alnum:]_]\|$\)/ath11k-firmware-qcn9074-ddwrt\1/g' "$image_mk"

            if grep -qE 'ath11k-firmware-(ipq5018|ipq6018|ipq8074|qcn9074)([^-[:alnum:]_]|$)' "$image_mk"; then
                echo "错误：$image_mk 中仍存在未转换为 -ddwrt 的 ath11k 固件包名" >&2
                return 1
            fi
        done

        if [ -f "$ipq50_target" ] || [ -f "$ipq60_target" ] || [ -f "$ipq807_target" ]; then
            echo "已同步 ipq50xx/ipq60xx/ipq807x ath11k 固件依赖为 ddwrt 包名。"
        fi
    fi
}


change_cpuusage() {
    local luci_rpc_path="$BUILD_DIR/feeds/luci/modules/luci-base/root/usr/share/rpcd/ucode/luci"
    local qualcommax_sbin_dir="$BUILD_DIR/target/linux/qualcommax/base-files/sbin"
    local filogic_sbin_dir="$BUILD_DIR/target/linux/mediatek/filogic/base-files/sbin"

    if [ -f "$luci_rpc_path" ]; then
        sed -i "s#const fd = popen('top -n1 | awk \\\'/^CPU/ {printf(\"%d%\", 100 - \$8)}\\\'')#const cpuUsageCommand = access('/sbin/cpuusage') ? '/sbin/cpuusage' : 'top -n1 | awk \\\'/^CPU/ {printf(\"%d%\", 100 - \$8)}\\\''#g" "$luci_rpc_path"
        sed -i '/cpuUsageCommand/a \\t\t\tconst fd = popen(cpuUsageCommand);' "$luci_rpc_path"
    fi

    local old_script_path="$BUILD_DIR/package/base-files/files/sbin/cpuusage"
    if [ -f "$old_script_path" ]; then
        rm -f "$old_script_path"
    fi

    if [ -d "$BUILD_DIR/target/linux/qualcommax" ]; then
        install -Dm755 "$BASE_PATH/patches/cpuusage" "$qualcommax_sbin_dir/cpuusage"
    fi
    if [ -d "$BUILD_DIR/target/linux/mediatek" ]; then
        install -Dm755 "$BASE_PATH/patches/hnatusage" "$filogic_sbin_dir/cpuusage"
    fi
}


ensure_vikingyfy_libffi() {
    local libffi_dir="$BUILD_DIR/package/libs/libffi"
    local tmp_dir
    local source_dir

    if ! is_vikingyfy_nss_build; then
        return 0
    fi

    if [ -f "$libffi_dir/Makefile" ]; then
        return 0
    fi

    echo "VIKINGYFY 源码缺少 package/libs/libffi，正在从 immortalwrt 官方补入..."
    tmp_dir=$(mktemp -d)
    source_dir="$tmp_dir/immortalwrt"

    if ! git_retry clone --depth 1 --filter=blob:none --sparse \
        -b master https://github.com/immortalwrt/immortalwrt.git "$source_dir"; then
        rm -rf "$tmp_dir"
        echo "错误：无法获取 immortalwrt 的 libffi 包" >&2
        exit 1
    fi

    if ! (cd "$source_dir" && git_retry sparse-checkout set package/libs/libffi); then
        rm -rf "$tmp_dir"
        echo "错误：无法 sparse-checkout immortalwrt/package/libs/libffi" >&2
        exit 1
    fi

    mkdir -p "$libffi_dir"
    cp -a "$source_dir/package/libs/libffi/." "$libffi_dir/"
    rm -rf "$tmp_dir"

    if [ ! -f "$libffi_dir/Makefile" ]; then
        echo "错误：libffi 补入后仍未找到 $libffi_dir/Makefile" >&2
        exit 1
    fi

    echo "已补入 libffi，用于 Python3/ctypes 等包编译。"
}


fix_ath11k_nss_stats_layout() {
    local makefile="$BUILD_DIR/package/kernel/mac80211/Makefile"
    local tmp_file

    if ! is_libwrt_build; then
        echo "非 LibWrt 构建，跳过 NSS 12.5 结构体 define 修正。"
        return 0
    fi

    if [ ! -f "$makefile" ]; then
        return 0
    fi

    # qca-nss-drv / ECM 在 12.5 固件下使用 -DNSS_FIRMWARE_VERSION_12_5，
    # 该宏会让 nss_wifili 的 peer stats 结构体多出 16 字节。ath11k 如果
    # 没有同样的宏，会按旧结构体解析，多个 peer 的统计会错位，表现为
    # iw station dump 的速率、信号、RX/TX 计数在运行一段时间后丢失。
    if grep -q -- '-DNSS_FIRMWARE_VERSION_12_5' "$makefile"; then
        echo "ath11k 已包含 NSS_FIRMWARE_VERSION_12_5 定义。"
        return 0
    fi

    if ! grep -q '^C_DEFINES[[:space:]]*=' "$makefile"; then
        echo "错误：$makefile 中未找到 C_DEFINES，无法添加 NSS 12.5 定义" >&2
        exit 1
    fi

    tmp_file="${makefile}.tmp"
    awk '
        /^C_DEFINES[[:space:]]*=/ {
            print
            print "ifeq ($(CONFIG_NSS_FIRMWARE_VERSION_12_5),y)"
            print "\tC_DEFINES+=-DNSS_FIRMWARE_VERSION_12_5"
            print "endif"
            next
        }
        { print }
    ' "$makefile" > "$tmp_file"

    if ! grep -q -- '-DNSS_FIRMWARE_VERSION_12_5' "$tmp_file"; then
        rm -f "$tmp_file"
        echo "错误：无法在 $makefile 中写入 NSS_FIRMWARE_VERSION_12_5 定义" >&2
        exit 1
    fi

    mv "$tmp_file" "$makefile"
    echo "已为 ath11k 添加 NSS_FIRMWARE_VERSION_12_5，修复 12.5 peer stats 结构体偏移。"
}


fix_ath11k_nss_rxrate_filter() {
    local patch_file="$BUILD_DIR/package/kernel/mac80211/patches/nss/ath11k/199-003-ath11k-add-nss-support.patch"
    local vk_rate_patch="$BUILD_DIR/package/kernel/mac80211/patches/nss/ath11k/999-922-ath11k-nss-fix-station-rate-reporting.patch"

    # VIKINGYFY 已经自带 999-922，不能再改它的 199-003，否则两套补丁会叠加。
    if [ -f "$vk_rate_patch" ] || ! is_libwrt_build; then
        echo "检测到 VIKINGYFY/999-922 或非 LibWrt 构建，跳过 199-003 RX 过滤修正。"
        return 0
    fi

    if [ ! -f "$patch_file" ]; then
        return 0
    fi

    # LibWrt 的 199-003 会无条件用 ppdu_info->frame_control 过滤 RX rate。
    # 6.12/6.18 的 monitor status 路径有时不填 frame_control（fc_valid=0），
    # 结果所有 RX rate 都被当成非数据帧丢弃，webui 的 RX 速率一直是 0。
    # 只在固件明确提供有效 frame_control 时才过滤。
    if grep -q 'frame_control_info_valid' "$patch_file"; then
        echo "ath11k NSS RX rate frame-control filter 已修复。"
        return 0
    fi

    awk '
    /^\+[[:space:]]*if \(!ieee80211_is_data\(__cpu_to_le16\(ppdu_info->frame_control\)\)\)$/ {
        print "+\tif ((user_stats ? user_stats->frame_control_info_valid : ppdu_info->fc_valid) && !ieee80211_is_data(__cpu_to_le16(user_stats ? user_stats->frame_control : ppdu_info->frame_control)))"
        getline
        print "+\t\treturn;"
        next
    }
    { print }
    ' "$patch_file" > "${patch_file}.tmp"
    mv "${patch_file}.tmp" "$patch_file"

    if ! grep -q 'frame_control_info_valid' "$patch_file"; then
        echo "错误：无法修复 $patch_file 中的 RX rate frame-control 过滤" >&2
        exit 1
    fi

    echo "已修复 ath11k NSS RX rate 在 frame_control 无效时被丢弃的问题。"
}


update_nss_pbuf_performance_libwrt() {
    local pbuf_path="$BUILD_DIR/package/kernel/mac80211/files/pbuf.uci"
    local pbuf_init="$BUILD_DIR/package/kernel/mac80211/files/qca-nss-pbuf.init"

    if [ -d "$(dirname "$pbuf_path")" ] && [ -f $pbuf_path ]; then
        sed -i "s/auto_scale '1'/auto_scale 'off'/g" $pbuf_path
        sed -i "s/scaling_governor 'performance'/scaling_governor 'schedutil'/g" $pbuf_path

        # qca-nss-pbuf 默认 stats_disable=1，会在启动/重启时关闭 ath11k
        # 的数据包统计，station dump 的速率和信号会变成 0 或消失。
        # 保持统计开启；需要极限吞吐时可以再手动改回 1。
        if grep -q 'option stats_disable' "$pbuf_path"; then
            sed -i "s/^\([[:space:]]*option stats_disable\).*/\1 '0'/" "$pbuf_path"
        else
            awk -v stats_opt="  option stats_disable '0'" '
                /^config general/ {
                    print
                    print stats_opt
                    next
                }
                { print }
            ' "$pbuf_path" > "${pbuf_path}.tmp"
            mv "${pbuf_path}.tmp" "$pbuf_path"
        fi

        if ! grep -q "option stats_disable '0'" "$pbuf_path"; then
            echo "错误：无法在 $pbuf_path 中设置 stats_disable=0" >&2
            exit 1
        fi
    fi

    # 升级时 /etc/config/pbuf 可能保留旧配置，里面未必有 stats_disable。
    # 同时把 init 的默认值改为 0，保证老配置升级后也默认保留 ath11k 统计。
    if [ -f "$pbuf_init" ]; then
        sed -i 's/config_get stats_disable opt stats_disable 1/config_get stats_disable opt stats_disable 0/' "$pbuf_init"

        if ! grep -q 'config_get stats_disable opt stats_disable 0' "$pbuf_init"; then
            echo "错误：无法将 $pbuf_init 的 stats_disable 默认值改为 0" >&2
            exit 1
        fi
    fi
}


update_nss_pbuf_performance_vikingyfy() {
    local pbuf_init="$BUILD_DIR/package/kernel/mac80211/files/qca-nss-pbuf.init"

    if [ ! -f "$pbuf_init" ]; then
        return 0
    fi

    # VIKINGYFY main 的 qca-nss-pbuf.init 直接硬编码 echo 1，
    # 没有 LibWrt 的 config_get stats_disable。这里只改它自己的 init，
    # 不改 LibWrt 的 pbuf.uci，避免两套 patch 混在一起。
    if grep -q 'echo 1 > "$stats_file"' "$pbuf_init"; then
        sed -i 's/echo 1 > "$stats_file"/echo 0 > "$stats_file"/' "$pbuf_init"
        sed -i 's/"Disabling ath11k stats"/"Enabling ath11k stats"/' "$pbuf_init"
    fi

    if grep -q 'echo 0 > "$stats_file"' "$pbuf_init"; then
        echo "VIKINGYFY: 已保持 ath11k stats 开启。"
    else
        echo "警告：未找到 VIKINGYFY qca-nss-pbuf.init 的 stats_disable 写入点，跳过。" >&2
    fi
}


update_nss_pbuf_performance() {
    if is_vikingyfy_nss_build; then
        update_nss_pbuf_performance_vikingyfy
    else
        update_nss_pbuf_performance_libwrt
    fi
}


update_nss_diag() {
    local file="$BUILD_DIR/package/kernel/mac80211/files/nss_diag.sh"
    if [ -d "$(dirname "$file")" ] && [ -f "$file" ]; then
        \rm -f "$file"
        install -Dm755 "$BASE_PATH/patches/nss_diag.sh" "$file"
    fi
}


fix_compile_coremark() {
    local file="$BUILD_DIR/feeds/packages/utils/coremark/Makefile"
    if [ -d "$(dirname "$file")" ] && [ -f "$file" ]; then
        sed -i 's/mkdir \$/mkdir -p \$/g' "$file"
    fi
}


update_dnsmasq_conf() {
    local file="$BUILD_DIR/package/network/services/dnsmasq/files/dhcp.conf"
    if [ -d "$(dirname "$file")" ] && [ -f "$file" ]; then
        sed -i '/dns_redirect/d' "$file"
    fi
}


add_backup_info_to_sysupgrade() {
    local conf_path="$BUILD_DIR/package/base-files/files/etc/sysupgrade.conf"

    if [ -f "$conf_path" ]; then
        cat >"$conf_path" <<'EOF'
/etc/AdGuardHome.yaml
/etc/zerotier
/etc/lucky/
EOF
    fi
}


fix_rust_compile_error() {
    if [ -f "$BUILD_DIR/feeds/packages/lang/rust/Makefile" ]; then
        sed -i 's/download-ci-llvm=true/download-ci-llvm=false/g' "$BUILD_DIR/feeds/packages/lang/rust/Makefile"
    fi
}
