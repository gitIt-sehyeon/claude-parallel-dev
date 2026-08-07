# claude-agents

Claude Code 병렬 개발 에이전트 모음. **프로젝트 레포와 분리된 별도 레포**입니다.

분리한 이유는 하나입니다. 에이전트 프롬프트는 **자주 고치게 되는데**, 프로젝트 레포에
넣어두면 한 줄 고칠 때마다 그 레포의 느린 CI를 통과해야 합니다. 여기 두면 그럴 일이 없습니다.

```
claude-agents/                          ← 이 레포 (CI 없음, 마음껏 커밋)
├── install.sh                          심링크 설치
├── uninstall.sh
├── .claude-plugin/
│   └── marketplace.json                팀 배포용 (2단계에서 사용)
└── plugins/
    └── parallel-dev/
        ├── .claude-plugin/plugin.json
        ├── agents/
        │   ├── feature-worker.md       worktree 격리 구현 워커
        │   ├── pr-reviewer.md          읽기 전용 리뷰어
        │   └── analyst.md              읽기 전용 감사관
        ├── commands/
        │   ├── parallel.md             /parallel
        │   ├── parallel-status.md      /parallel-status
        │   └── audit.md                /audit
        ├── settings.example.json       프로젝트 레포에 넣을 권한 설정
        └── worktreeinclude.example     프로젝트 레포에 넣을 .worktreeinclude
```

## 두 가지 워크플로

같은 "레인으로 쪼개서 동시에 돌린다"는 구조지만, **쓰는 목적과 부작용이 다릅니다.**

| | `/parallel` | `/audit` |
|---|---|---|
| 하는 일 | 구현 | 조사 |
| 워커 | `feature-worker` | `analyst` |
| 파일 수정 | 한다 | **안 한다** (리포트 파일도 안 만듦) |
| worktree | 레인마다 격리 | 안 씀 (읽기만 하니 충돌 없음) |
| 결과물 | 브랜치 + PR | 터미널 출력뿐 |
| 후속 | `pr-reviewer` 로 리뷰 | 없음 |

```
/parallel 결제 모듈을 웹훅 / 환불 / 재시도 세 갈래로 나눠서 병렬로 진행해줘
/audit CLAUDE.md 규칙을 백엔드 전체가 지키고 있는지 봐줘
```

`/audit` 은 감사 기준(`CLAUDE.md` 등)을 **오케스트레이터가 직접 읽고** 검증 가능한 항목으로
분해한 뒤, 겹치지 않는 레인 3~5개로 나눠 `analyst` 를 동시에 띄웁니다.
모든 발견에 **파일:줄 + 원문 인용**이 붙고, 확신 없는 건 "확인 필요"로 따로 분류됩니다.
못 본 범위는 **감사 사각지대**로 같이 보고합니다 — 다 봤다고 주장하지 않습니다.

---

## 1단계 — 혼자 쓰기 (심링크)

지금은 이걸로 시작하세요. 프로젝트 레포에 커밋이 **0번** 들어갑니다.

```bash
git clone <이 레포 주소> ~/dev/claude-agents
cd ~/dev/claude-agents
./install.sh --dry-run    # 뭐가 걸릴지 먼저 확인
./install.sh
```

`~/.claude/agents/`, `~/.claude/commands/` 로 심링크가 걸립니다.
**심링크라서 이 레포에서 파일을 고치면 다음 세션에 바로 반영됩니다.**
재설치도, 커밋도, CI도 필요 없습니다.

```bash
cd <작업할 프로젝트>
claude
```
```
/parallel 결제 모듈을 웹훅 / 환불 / 재시도 세 갈래로 나눠서 병렬로 진행해줘
/audit    CLAUDE.md 규칙을 백엔드 전체가 지키고 있는지 봐줘
```

제거는 `./uninstall.sh`. 이 레포를 가리키는 심링크만 지우고, 다른 건 안 건드립니다.

### 한 가지 예외

`settings.example.json`의 **권한 설정만은 프로젝트 레포에 있어야 합니다.**
권한은 프로젝트 스코프라 심링크로 안 따라옵니다. 워커가 여기 없는 명령을 만나면
권한 프롬프트에서 멈추고 병렬성이 죽습니다.

프로젝트 레포에 이 두 개만 한 번 넣으세요. 이후로는 손댈 일이 없습니다.

```bash
cp ~/dev/claude-agents/plugins/parallel-dev/settings.example.json .claude/settings.json
cp ~/dev/claude-agents/plugins/parallel-dev/worktreeinclude.example .worktreeinclude
# 내용을 프로젝트 실제 lint/test 명령에 맞게 수정
```

`.gitignore` 에 추가:

```gitignore
.claude/worktrees/
.claude/settings.local.json
```

### 프로젝트 레포 CI 제외 설정

이왕 커밋하는 김에 같이 넣으세요. `.claude/**` 변경이 풀 CI를 도는 건 낭비고,
README 고칠 때도 똑같이 당합니다.

```yaml
# GitHub Actions — .github/workflows/*.yml
on:
  push:
    paths-ignore:
      - '.claude/**'
      - '**/*.md'
      - 'docs/**'
  pull_request:
    paths-ignore:
      - '.claude/**'
      - '**/*.md'
      - 'docs/**'
```

```yaml
# GitLab CI — .gitlab-ci.yml (각 job 또는 workflow 레벨)
workflow:
  rules:
    - changes:
        - '.claude/**/*'
        - '**/*.md'
      when: never
    - when: always
```

```groovy
// Jenkins — Declarative Pipeline
when {
  not { changeset pattern: ".claude/**", comparator: "ANT" }
}
```

> 주의: GitHub Actions에서 해당 워크플로가 **required status check**로 걸려 있으면,
> `paths-ignore`로 스킵된 PR은 체크가 "대기 중"으로 남아 머지가 막힐 수 있습니다.
> 이 경우 워크플로를 스킵하는 대신, 항상 실행하되 job 내부에서 조기 종료하는
> 패턴을 쓰거나 required check 설정을 함께 조정하세요.

---

## 2단계 — 팀에 배포하기 (플러그인)

프롬프트가 안정되고 다른 팀원이 달라고 하면 그때 넘어갑니다.
**파일은 그대로 두고 배포 방식만 바꾸는 것**이라 옮기는 비용이 거의 없습니다.
`marketplace.json`과 `plugin.json`은 이미 들어 있습니다.

### 배포하는 쪽 (이 레포)

`.claude-plugin/marketplace.json` 의 `TODO` 항목을 채우고 푸시합니다.
버전을 고정하고 싶으면 `version` 을 올리세요. 생략하면 커밋 SHA를 따라갑니다.

### 받는 쪽 (각 프로젝트 레포)

`.claude/settings.json` 에 두 키를 추가합니다. 이게 느린 CI를 통과하는 **마지막 커밋**입니다.

```json
{
  "extraKnownMarketplaces": {
    "claude-tools": {
      "source": { "source": "github", "repo": "<org>/claude-agents" },
      "autoUpdate": true
    }
  },
  "enabledPlugins": {
    "parallel-dev@claude-tools": true
  }
}
```

팀원이 그 레포에서 `claude`를 켜면 설치 프롬프트가 뜨고, 승인하면 자동으로 붙습니다.
이후 프롬프트 수정은 전부 이 레포에서만 일어납니다.

사내 GitLab이나 자체 호스팅 git도 됩니다.

```json
{ "source": { "source": "url", "url": "https://gitlab.company.com/team/claude-agents.git", "ref": "v1.0" } }
```

인증은 기존 git credential helper / ssh-agent 를 그대로 씁니다.

### 수동 설치 (settings.json 없이)

```
/plugin marketplace add <org>/claude-agents
/plugin install parallel-dev@claude-tools
```

### 이름이 바뀝니다

플러그인으로 설치하면 커맨드에 네임스페이스가 붙습니다.

| 심링크 모드 | 플러그인 모드 |
|---|---|
| `/parallel` | `/claude-tools:parallel` |
| `/parallel-status` | `/claude-tools:parallel-status` |
| `/audit` | `/claude-tools:audit` |

두 모드를 동시에 켜두면 같은 에이전트가 중복 로드되니, 전환할 때 `./uninstall.sh` 를 먼저 돌리세요.

---

## 프롬프트 고치는 법

실전에서 워커가 이런 식으로 어긋납니다. 그때마다 해당 파일을 여기서 고치고 커밋하면 끝입니다.

| 증상 | 고칠 곳 |
|---|---|
| 워커가 배정 범위 밖 파일을 건드림 | `agents/feature-worker.md` 의 "반드시 지킬 것" |
| 테스트 명령이 안 맞음 | `agents/feature-worker.md` 4단계 검증 / `settings.example.json` allow |
| 권한 프롬프트에서 멈춤 | 프로젝트 레포의 `.claude/settings.json` allow 목록 |
| 보고 JSON 형식을 지 맘대로 바꿈 | `agents/feature-worker.md` 최종 보고 형식 |
| 작업을 너무 잘게 쪼갬 | `commands/parallel.md` 2단계 분해 원칙 |
| 실패를 낙관적으로 요약함 | `commands/parallel.md` 4단계 취합 |
| 리뷰어가 취향 지적만 함 | `agents/pr-reviewer.md` "하지 말 것" |
| 감사관이 없는 위반을 지어냄 | `agents/analyst.md` "조사 원칙" (Read 로 직접 검증) |
| 감사 발견에 인용이 안 붙음 | `agents/analyst.md` 반환 형식 / `commands/audit.md` 5단계 보고 규칙 |
| 감사 레인이 같은 파일을 중복해서 봄 | `commands/audit.md` 2단계 레인 분해 |
| 감사 결과를 파일로 써버림 | `commands/audit.md` "이 커맨드의 원칙" |

---

## 참고

- [서브에이전트](https://code.claude.com/docs/en/sub-agents)
- [worktree 병렬 세션](https://code.claude.com/docs/en/worktrees)
- [플러그인 레퍼런스](https://code.claude.com/docs/en/plugins-reference)
- [플러그인 마켓플레이스](https://code.claude.com/docs/en/plugin-marketplaces)
- [설정 / 권한](https://code.claude.com/docs/en/settings)
