#!/usr/bin/env bash
#
# 이 레포의 에이전트/커맨드를 ~/.claude/ 로 심링크합니다.
# 심링크라서 이 레포에서 파일을 고치면 즉시 반영됩니다.
# 커밋도, 재설치도, 느린 CI도 필요 없습니다.
#
#   ./install.sh              설치
#   ./install.sh --dry-run    뭐가 걸릴지만 보기
#   ./uninstall.sh            제거
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$REPO_DIR/plugins/parallel-dev"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

info()  { printf '  %s\n' "$*"; }
warn()  { printf '  ! %s\n' "$*" >&2; }

link_dir() {
  local src_dir="$1" dst_dir="$2" kind="$3"

  [[ -d "$src_dir" ]] || { warn "없음: $src_dir — 건너뜀"; return 0; }

  (( DRY_RUN )) || mkdir -p "$dst_dir"

  local found=0
  while IFS= read -r -d '' src; do
    found=1
    local base dst
    base="$(basename "$src")"
    dst="$dst_dir/$base"

    # 이미 우리가 건 심링크면 그냥 갱신
    if [[ -L "$dst" ]]; then
      local cur
      cur="$(readlink "$dst")"
      if [[ "$cur" == "$src" ]]; then
        info "= $kind/$base (이미 연결됨)"
        continue
      fi
      info "~ $kind/$base (심링크 대상 변경: $cur -> $src)"
      (( DRY_RUN )) || ln -sfn "$src" "$dst"
      continue
    fi

    # 실제 파일이 있으면 덮어쓰지 않고 백업
    if [[ -e "$dst" ]]; then
      warn "이미 실제 파일이 있음: $dst"
      if (( DRY_RUN )); then
        info "  -> $base.bak 으로 백업 후 링크 예정"
      else
        mv "$dst" "$dst.bak"
        info "  -> $base.bak 으로 백업함"
        ln -sfn "$src" "$dst"
      fi
      continue
    fi

    info "+ $kind/$base"
    (( DRY_RUN )) || ln -sfn "$src" "$dst"
  done < <(find "$src_dir" -maxdepth 1 -type f -name '*.md' -print0 | sort -z)

  (( found )) || info "  ($kind 에 .md 파일 없음)"
}

echo
echo "레포:   $REPO_DIR"
echo "설치처: $CLAUDE_HOME"
(( DRY_RUN )) && echo "모드:   DRY RUN (실제로 아무것도 바꾸지 않음)"
echo

echo "[agents]"
link_dir "$PLUGIN_DIR/agents"   "$CLAUDE_HOME/agents"   "agents"
echo
echo "[commands]"
link_dir "$PLUGIN_DIR/commands" "$CLAUDE_HOME/commands" "commands"
echo

if (( DRY_RUN )); then
  echo "dry run 끝. 실제로 걸려면 인자 없이 다시 실행하세요."
  exit 0
fi

cat <<'EOF'
설치 완료.

다음으로 할 것
  1. 작업할 리포에서 `claude` 실행
  2. /parallel 로 병렬 작업 시작

주의
  - permissions 는 심링크로 안 따라갑니다. 프로젝트 리포의
    .claude/settings.json 에 settings.example.json 내용을 넣어야
    워커가 권한 프롬프트에서 멈추지 않습니다.
  - 이 레포에서 파일을 고치면 다음 세션부터 바로 반영됩니다.
EOF
