#!/usr/bin/env bash
# 生成 Release Note 中的“本次变更”段落。
# 优先使用 GitHub Release 列表找到上一次发布，然后只输出该时间之后
# 提交过的 changelogs/*.md；没有历史或 API 不可用时回退到最近文件。

set -euo pipefail

BUILD_DATE="${BUILD_DATE:-}"
REPO="${GITHUB_REPOSITORY:-kaiwater/wrt_release}"
PREV_TAG=""
PREV_DATE=""

if command -v gh >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && [ -n "$BUILD_DATE" ]; then
    releases_json=$(gh release list -R "$REPO" --limit 100 --json tagName,createdAt 2>/dev/null || true)
    if [ -n "$releases_json" ]; then
        PREV_TAG=$(printf '%s' "$releases_json" | jq -r --arg cur "$BUILD_DATE" '
            [.[] | select((.tagName | startswith($cur)) | not)]
            | sort_by(.createdAt)
            | last
            | .tagName // empty
        ' 2>/dev/null || true)
        PREV_DATE=$(printf '%s' "$releases_json" | jq -r --arg cur "$BUILD_DATE" '
            [.[] | select((.tagName | startswith($cur)) | not)]
            | sort_by(.createdAt)
            | last
            | .createdAt // empty
        ' 2>/dev/null || true)
    fi
fi

FILES=()
if [ -n "$PREV_DATE" ] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r file; do
        [ -n "$file" ] && FILES+=("$file")
    done < <(
        git log --since="$PREV_DATE" --name-only --pretty=format: -- changelogs 2>/dev/null \
            | sed '/^[[:space:]]*$/d' \
            | sort -u
    )
fi

# 没有上一次 Release 或拿不到历史时，回退到最近三个 changelog 文件。
if [ ${#FILES[@]} -eq 0 ]; then
    while IFS= read -r file; do
        FILES+=("$file")
    done < <(find changelogs -maxdepth 1 -type f -name '*.md' ! -name 'README.md' 2>/dev/null | sort | tail -n 3)
fi

echo
if [ -n "$PREV_TAG" ]; then
    echo "## 本次变更（自 \`$PREV_TAG\` 以来）"
else
    echo "## 本次变更"
fi
echo

if [ ${#FILES[@]} -eq 0 ]; then
    echo "没有找到可用的 changelog。"
    exit 0
fi

for file in "${FILES[@]}"; do
    [ -f "$file" ] || continue
    echo "### ${file#changelogs/}"
    echo
    sed -n '1,200p' "$file"
    echo
done
