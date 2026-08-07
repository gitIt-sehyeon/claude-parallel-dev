---
description: 현재 떠 있는 worktree와 워커가 만든 PR 상태를 한눈에 요약한다
allowed-tools: ["Bash(git *)", "Bash(gh *)", "Read"]
model: sonnet
---

현재 병렬 작업 상태를 조회해서 요약한다. 아무것도 수정하지 않는다.

```bash
git worktree list
git branch -vv --sort=-committerdate | head -20
gh pr list --draft --limit 20 --json number,title,headRefName,statusCheckRollup,isDraft,url
```

`gh`가 없거나 인증이 안 되어 있으면 git 정보만으로 요약한다.

아래 형식으로 출력한다.

```
━━━ 진행 중 ━━━
feat/user-auth-refactor   worktree ✓   PR #123 draft   CI ✓   커밋 4개 (2시간 전)
feat/billing-webhook      worktree ✓   PR #124 draft   CI ✗   커밋 2개 (40분 전)

━━━ 정리 가능 ━━━
feat/old-thing            머지 완료 — git worktree remove .claude/worktrees/old-thing

━━━ 주의 ━━━
- billing-webhook CI 실패
- user-auth-refactor 와 billing-webhook 이 src/middleware/ 를 함께 수정 중 (충돌 가능)
```

겹치는 파일이 있는지는 아래로 확인한다.

```bash
git diff --name-only main...<브랜치A> > /tmp/a.txt
git diff --name-only main...<브랜치B> > /tmp/b.txt
comm -12 <(sort /tmp/a.txt) <(sort /tmp/b.txt)
```
