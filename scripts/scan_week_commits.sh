#!/usr/bin/env zsh
# 扫描本机所有 workspace 下，指定时间区间、指定作者的 git 提交。
# 用法：zsh scan_week_commits.sh [SINCE] [UNTIL]
#   SINCE / UNTIL 缺省时自动取"本周一 00:00:00"到"今天 23:59:59"。
#
# 输出特性：
#   - commit 行格式：HASH|ISO_TIME|AUTHOR|SUBJECT|QUALITY|FILES_CHANGED|INSERTIONS|DELETIONS
#       * QUALITY: HIGH / LOW （subject 质量分级，详见下文规则）
#   - 按 (repo, hash) 去重，避免同一 commit 被多个 author pattern 重复匹配
#   - 头部会额外输出 REPORT_DATE=YYYYMMDD（本周五；若本周还没到周五则取今天）
#   - 对 QUALITY=LOW 的 commit，额外输出 BODY / STAT / DIFF 摘要块，供模型反推意图
#
# Subject 质量判定（在脚本内置 Python 里执行）：
#   LOW 触发条件（命中任意一条即为 LOW）：
#     - 长度 < 8 字符（去除前后空白后）
#     - 全部命中如下"垃圾词"集合之一（不区分大小写、忽略前后标点）：
#         fix bug / fixbug / bug fix / bugfix / fix / update / updates /
#         wip / tmp / temp / test / tests / 修复 / 修改 / 调整 / 优化 /
#         同步 / 同步代码 / commit / save / misc / chore / cleanup
#     - 不含任何"具体名词"（粗糙判定：subject 里没有任何长度 ≥ 4 的字母/数字片段，
#       且没有任何中文字符）
#   其余视为 HIGH。
#
# 低质量 commit 附带的 diff 摘要做了多重限制，避免把 token 撑爆：
#   - 只输出 git show --stat（最多 30 行）
#   - 只输出 git show（patch）的前 120 行
#   - 单文件 diff 超过 300 行则截断并标注

set -eu -o pipefail

# 0) 单 commit diff 摘要的硬性上限（行数）
MAX_STAT_LINES=30
MAX_DIFF_LINES=120

# 1) 时间区间
if [[ $# -ge 2 ]]; then
  SINCE="$1"
  UNTIL="$2"
else
  SINCE=$(python3 -c "from datetime import datetime,timedelta; t=datetime.now(); m=t-timedelta(days=t.weekday()); print(m.strftime('%Y-%m-%d 00:00:00'))")
  UNTIL=$(python3 -c "from datetime import datetime; print(datetime.now().strftime('%Y-%m-%d 23:59:59'))")
fi

# 2) 本周五日期（供周报文件命名直接复用）
REPORT_DATE=$(python3 -c "
from datetime import datetime, timedelta
t = datetime.now()
if t.weekday() <= 4:
    fri = t + timedelta(days=4 - t.weekday())
else:
    fri = t - timedelta(days=t.weekday() - 4)
print(fri.strftime('%Y%m%d'))
")

# 3) 扫描根目录
ROOTS=(
  "$HOME/workspace_codex"
  "$HOME/workspace"
  "$HOME/workspace_claude"
  "$HOME/workspace_harmony"
  "$HOME/workspace_ios"
  "$HOME/workspace_trae"
  "$HOME/DevEcoStudioProjects"
  "$HOME/PycharmProjects"
)

# 4) 作者
AUTHOR_PATTERNS=("zhouang" "周昂")

# 5) Subject 质量判定函数（Python 子进程，stdin 传 subject，stdout 输出 HIGH/LOW）
quality_of_subject() {
  python3 - "$1" <<'PY'
import sys, re
s = sys.argv[1].strip()
if len(s) < 8:
    print("LOW"); sys.exit(0)

core = re.sub(r'^[\W_]+|[\W_]+$', '', s).lower()
core_no_space = re.sub(r'\s+', ' ', core)

# 1) 整句精确匹配（英文 + 中文）
low_phrases_exact = {
    "fix bug","fixbug","bug fix","bugfix","fix","update","updates",
    "wip","tmp","temp","test","tests","testing",
    "commit","save","misc","chore","cleanup","cleanups",
    "修复","修改","调整","优化","同步","同步代码","同步tools","同步最新tools",
    "更新","提交","暂存","小修","小改",
}
if core_no_space in low_phrases_exact:
    print("LOW"); sys.exit(0)

# 2) 中文无信息量短模板
low_cn_patterns = [
    r'^同步(最新)?[a-z0-9_\-\u4e00-\u9fff]{0,20}$',
    r'^更新[a-z0-9_\-\u4e00-\u9fff]{0,20}$',
    r'^[a-z0-9_\-\u4e00-\u9fff]{0,15}同步(git|代码|最新|tools|数据)?$',
    r'^小[修改优]+$',
    r'^一些(小)?(修改|优化|调整)$',
]
for pat in low_cn_patterns:
    if re.fullmatch(pat, core_no_space):
        print("LOW"); sys.exit(0)

# 3) 既无中文也无长 token —— 视作无信息量
has_cjk = any('\u4e00' <= ch <= '\u9fff' for ch in s)
has_long_token = bool(re.search(r'[A-Za-z0-9_]{4,}', s))
if not has_cjk and not has_long_token:
    print("LOW"); sys.exit(0)

print("HIGH")
PY
}

echo "# 本周提交扫描"
echo "区间: $SINCE  ~  $UNTIL"
echo "作者: ${AUTHOR_PATTERNS[*]}"
echo "REPORT_DATE=$REPORT_DATE"
echo "提示: 每行 commit 末尾的 QUALITY 字段为 LOW 时，下方会附带 BODY / STAT / DIFF 摘要"
echo

# 6) 按 remote URL 去重仓库；按 hash 去重 commit
typeset -A SEEN_REPO

for root in "${ROOTS[@]}"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r gitdir; do
    [[ -z "$gitdir" ]] && continue
    repo="${gitdir%/.git}"
    remote=$(git -C "$repo" config --get remote.origin.url 2>/dev/null || echo "$repo")
    [[ -n "${SEEN_REPO[$remote]:-}" ]] && continue
    SEEN_REPO[$remote]="$repo"

    # 合并所有 author pattern 的结果，再按 hash 去重
    # 注意：subject 里可能含 |，所以用一个不可见分隔符 \x1f 避免冲突
    raw=""
    for a in "${AUTHOR_PATTERNS[@]}"; do
      partial=$(git -C "$repo" log --all --since="$SINCE" --until="$UNTIL" \
        --author="$a" --pretty=format:$'%H\x1f%ai\x1f%an\x1f%s' 2>/dev/null || true)
      if [[ -n "$partial" ]]; then
        [[ -n "$raw" ]] && raw="${raw}"$'\n'"${partial}" || raw="$partial"
      fi
    done

    [[ -z "$raw" ]] && continue

    # 按 hash 去重，并按提交时间升序
    deduped=$(printf "%s\n" "$raw" | awk -v OFS=$'\x1f' 'BEGIN{FS="\x1f"} !seen[$1]++ {print}' | sort -t $'\x1f' -k2,2)

    [[ -z "$deduped" ]] && continue

    echo "=== REPO: $repo ==="
    echo "REMOTE: $remote"

    # 逐行处理 commit：打印结构化行 + 必要时附 diff 摘要
    while IFS=$'\x1f' read -r full_hash ctime author subject; do
      [[ -z "$full_hash" ]] && continue
      short_hash="${full_hash:0:7}"
      quality=$(quality_of_subject "$subject")

      # 取 numstat 总和
      shortstat=$(git -C "$repo" show --shortstat --format="" "$full_hash" 2>/dev/null | tail -n1 || true)
      files_changed=$(echo "$shortstat" | grep -oE '[0-9]+ files? changed' | grep -oE '[0-9]+' || echo "0")
      insertions=$(echo "$shortstat" | grep -oE '[0-9]+ insertions?' | grep -oE '[0-9]+' || echo "0")
      deletions=$(echo "$shortstat" | grep -oE '[0-9]+ deletions?' | grep -oE '[0-9]+' || echo "0")
      [[ -z "$files_changed" ]] && files_changed=0
      [[ -z "$insertions" ]] && insertions=0
      [[ -z "$deletions" ]] && deletions=0

      # 主行（保留原管道分隔，便于人眼阅读；subject 里若有 | 替换为 ／）
      safe_subject=${subject//|/／}
      echo "${short_hash}|${ctime}|${author}|${safe_subject}|${quality}|${files_changed}|${insertions}|${deletions}"

      # 低质量 commit：附 body + stat + diff 摘要
      if [[ "$quality" == "LOW" ]]; then
        body=$(git -C "$repo" show -s --format=%b "$full_hash" 2>/dev/null | sed '/^$/d' || true)
        if [[ -n "$body" ]]; then
          echo "  [BODY]"
          echo "$body" | sed 's/^/    /'
        fi

        stat=$(git -C "$repo" show --stat --format="" "$full_hash" 2>/dev/null | sed '/^$/d' | head -n "$MAX_STAT_LINES")
        if [[ -n "$stat" ]]; then
          echo "  [STAT]"
          echo "$stat" | sed 's/^/    /'
        fi

        diff_excerpt=$(git -C "$repo" show --format="" --no-color --unified=2 "$full_hash" 2>/dev/null | head -n "$MAX_DIFF_LINES")
        if [[ -n "$diff_excerpt" ]]; then
          echo "  [DIFF excerpt, max ${MAX_DIFF_LINES} lines]"
          echo "$diff_excerpt" | sed 's/^/    /'
          echo "    [...truncated if longer]"
        fi
        echo
      fi
    done <<< "$deduped"

    echo
  done < <(find "$root" -maxdepth 5 -type d -name .git 2>/dev/null)
done
