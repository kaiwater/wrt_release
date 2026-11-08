#!/usr/bin/env bash
# 对比四条固件线的上游新增提交。
#
# 用法:
#   ./tools/upstream-check.sh            # 只输出摘要和每条线的新提交
#   MAX_COMMITS=60 ./tools/upstream-check.sh
#
# 依赖: gh（已登录）、curl 不需要
#
# 四条线:
#   1) LibWrt         LiBwrt/LibWrt 25.12-nss        （AX6600 / JD CS-02）
#   2) VIKINGYFY      VIKINGYFY/immortalwrt main     （AP8220）
#   3) chasey wifi7   chasey-dev/immortalwrt-mt798x-rebase 25.12-dev-wifi7（BE12 Pro）
#   4) chasey 25.12   chasey-dev/immortalwrt-mt798x-rebase 25.12（RAX3000M）
#
# 基线取自各自最近一次 release：
#   1-3: release 正文里的 "Source: ... @ <rev>"
#   4:   latest release 对应构建的 staging 缓存 key 中的 upstream commit
# 取不到时回退为 release 日期之前的最后一个上游提交。

set -uo pipefail

GH=${GH:-gh}
REL_REPO=${REL_REPO:-kaiwater/wrt_release}
RAX_REPO=${RAX_REPO:-kaiwater/immortalwrt-mt798x-25.12}
CHASEY_REPO=${CHASEY_REPO:-chasey-dev/immortalwrt-mt798x-rebase}
MAX_COMMITS=${MAX_COMMITS:-30}

die() { echo "$*" >&2; exit 1; }

command -v "$GH" >/dev/null 2>&1 || die "需要 gh CLI"
"$GH" auth status >/dev/null 2>&1 || die "gh 未登录，先执行 gh auth login"

latest_release_for() { # model-substring
	"$GH" release list -R "$REL_REPO" --limit 100 --json tagName,createdAt \
		--jq '.[] | [.tagName,.createdAt] | @tsv' |
		awk -v m="$1" 'index($1, m) { print $1; exit }'
}

release_source_rev() { # tag
	"$GH" release view "$1" -R "$REL_REPO" --json body --jq '.body' 2>/dev/null |
		sed -n 's/.*@ `\([0-9a-f]\{7,40\}\)`.*/\1/p' | head -n1
}

release_date() { # tag -> YYYY-MM-DD
	"$GH" release view "$1" -R "$REL_REPO" --json createdAt --jq '.createdAt' 2>/dev/null |
		cut -c1-10
}

head_of() { # repo branch
	"$GH" api "repos/$1/commits/$2" --jq '.sha' 2>/dev/null
}

first_commit_before() { # repo branch YYYY-MM-DD
	"$GH" api "repos/$1/commits?sha=$2&until=${3}T23:59:59Z&per_page=1" --jq '.[0].sha' 2>/dev/null
}

classify() {
	local s
	s=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
	case "$s" in
		*openssl* | *ca-certificates* | *firewall* | *cve* | *security* | *hostapd*)
			echo "SECURITY" ;;
		*ath11k* | *ath12k* | *mt76* | *mtwifi* | *mac80211* | *wifi* | *dfs* | *mlo*)
			echo "WIFI" ;;
		*"kernel:"* | *"bump 6."*)
			echo "KERNEL" ;;
		*nss* | *ppe* | *dsa* | *ethernet* | *"phy"*)
			echo "DRIVER" ;;
		*)
			echo "OTHER" ;;
	esac
}

TRACK_N=0
declare -a SUM_NAME SUM_DELTA SUM_NOTE

track() { # name repo branch base note
	local name=$1 repo=$2 branch=$3 base=$4 note=$5
	local head ahead status
	TRACK_N=$((TRACK_N + 1))

	echo
	echo "=== ${TRACK_N}) ${name}"
	echo "  上游: ${repo} @ ${branch}"

	if [ -z "$base" ]; then
		echo "  基线: 未找到（跳过）"
		SUM_NAME+=("$name"); SUM_DELTA+=("?"); SUM_NOTE+=("baseline-missing")
		return
	fi

	echo "  基线: ${base:0:12}  (${note})"
	head=$(head_of "$repo" "$branch")
	if [ -z "$head" ]; then
		echo "  读取上游 HEAD 失败"
		SUM_NAME+=("$name"); SUM_DELTA+=("?"); SUM_NOTE+=("head-error")
		return
	fi
	echo "  HEAD: ${head:0:12}"

	local cmp
	cmp=$("$GH" api "repos/$repo/compare/${base}...${branch}" --jq '[.status, (.ahead_by|tostring)] | @tsv' 2>/dev/null)
	if [ -z "$cmp" ]; then
		echo "  compare 失败（基线可能不可达）"
		SUM_NAME+=("$name"); SUM_DELTA+=("?"); SUM_NOTE+=("compare-error")
		return
	fi

	status=$(printf '%s' "$cmp" | cut -f1)
	ahead=$(printf '%s' "$cmp" | cut -f2)

	if [ "${ahead:-0}" = "0" ]; then
		echo "  新增: 0（${status}）"
		SUM_NAME+=("$name"); SUM_DELTA+=("0"); SUM_NOTE+=("none")
		return
	fi

	echo "  新增: ${ahead} 个提交（${status}）"
	local list
	list=$("$GH" api "repos/$repo/compare/${base}...${branch}" \
		--jq '.commits[] | "\(.commit.committer.date[0:10])\t\(.sha[0:8])\t\(.commit.message|split("\n")[0])"' 2>/dev/null)
	local i=0 sec=0 ker=0 wifi=0
	while IFS=$'\t' read -r date sha subj; do
		[ -n "${subj:-}" ] || continue
		i=$((i + 1))
		[ "$i" -gt "$MAX_COMMITS" ] && { echo "  ...（其余 $((ahead - MAX_COMMITS)) 条省略）"; break; }
		local cat
		cat=$(classify "$subj")
		case "$cat" in SECURITY) sec=$((sec + 1)) ;; KERNEL) ker=$((ker + 1)) ;; WIFI) wifi=$((wifi + 1)) ;; esac
		printf '    %s  %s  [%-8s] %s\n' "$date" "$sha" "$cat" "$subj"
	done <<<"$list"

	local note_rec="optional"
	if [ $((sec + ker + wifi)) -gt 0 ]; then note_rec="review"; fi
	SUM_NAME+=("$name"); SUM_DELTA+=("+$ahead"); SUM_NOTE+=("$note_rec")
}

# 1) LibWrt
tag=$(latest_release_for "jdcloud_ipq60xx_libwrt")
base=""
[ -n "$tag" ] && base=$(release_source_rev "$tag")
[ -z "$base" ] && [ -n "$tag" ] && base=$(first_commit_before "LiBwrt/LibWrt" "25.12-nss" "$(release_date "$tag")")
track "LibWrt 25.12-nss (AX6600 / CS-02)" "LiBwrt/LibWrt" "25.12-nss" "$base" "release ${tag:-unknown}"

# 2) VIKINGYFY main
tag=$(latest_release_for "aliyun_ap8220_immwrt")
base=""
[ -n "$tag" ] && base=$(release_source_rev "$tag")
[ -z "$base" ] && [ -n "$tag" ] && base=$(first_commit_before "VIKINGYFY/immortalwrt" "main" "$(release_date "$tag")")
track "VIKINGYFY main (AP8220)" "VIKINGYFY/immortalwrt" "main" "$base" "release ${tag:-unknown}"

# 3) chasey wifi7 (BE12 Pro)
tag=$(latest_release_for "tenda_be12_pro_immwrt")
base=""
[ -n "$tag" ] && base=$(release_source_rev "$tag")
[ -z "$base" ] && [ -n "$tag" ] && base=$(first_commit_before "$CHASEY_REPO" "25.12-dev-wifi7" "$(release_date "$tag")")
track "chasey 25.12-dev-wifi7 (BE12 Pro)" "$CHASEY_REPO" "25.12-dev-wifi7" "$base" "release ${tag:-unknown}"

# 4) chasey 25.12 (RAX3000M), 基线来自构建缓存 key
rax_tag=$("$GH" release list -R "$RAX_REPO" --limit 1 --json tagName --jq '.[0].tagName' 2>/dev/null)
base=""
if [ -n "$rax_tag" ]; then
	rax_date=${rax_tag#build-}
	rax_date=${rax_date%%-*}
	cache_key=$("$GH" api "repos/$RAX_REPO/actions/caches" --jq '.actions_caches[].key' 2>/dev/null |
		grep -m1 -- "-${rax_date}-" || true)
	[ -n "$cache_key" ] && base=$(printf '%s' "$cache_key" | sed -n 's/.*-staging-\([0-9a-f]\{40\}\)-.*/\1/p')
	[ -z "$base" ] && base=$(first_commit_before "$CHASEY_REPO" "25.12" "${rax_date:0:4}-${rax_date:4:2}-${rax_date:6:2}")
fi
track "chasey 25.12 (RAX3000M)" "$CHASEY_REPO" "25.12" "$base" "release ${rax_tag:-unknown}"

# 摘要
echo
echo "================ SUMMARY ================"
for i in "${!SUM_NAME[@]}"; do
	printf '  %-38s %-4s %s\n' "${SUM_NAME[$i]}" "${SUM_DELTA[$i]}" "${SUM_NOTE[$i]}"
done
echo "========================================="
echo "提示: review = 有安全/内核/无线相关提交，建议评估重编；optional = 仅有其他改动；0 = 无需处理"
