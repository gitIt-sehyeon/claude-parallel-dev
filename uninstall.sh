#!/usr/bin/env bash
#
# install.sh 가 건 심링크만 제거합니다.
# 이 레포를 가리키지 않는 파일/심링크는 건드리지 않습니다.
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

removed=0
for dir in agents commands; do
  target="$CLAUDE_HOME/$dir"
  [[ -d "$target" ]] || continue

  while IFS= read -r -d '' link; do
    dest="$(readlink "$link")"
    if [[ "$dest" == "$REPO_DIR"/* ]]; then
      rm "$link"
      printf '  - %s/%s\n' "$dir" "$(basename "$link")"
      removed=$((removed + 1))

      # install.sh 가 남긴 백업이 있으면 되돌림
      if [[ -e "$link.bak" ]]; then
        mv "$link.bak" "$link"
        printf '    (백업 복원: %s)\n' "$(basename "$link")"
      fi
    fi
  done < <(find "$target" -maxdepth 1 -type l -print0)
done

echo
if (( removed )); then
  echo "심링크 $removed 개 제거 완료."
else
  echo "이 레포를 가리키는 심링크가 없습니다."
fi
