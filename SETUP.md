# 다기기 세팅 가이드

집/회사 Mac에서 같은 저장소를 쓰기 위한 설명서 + 체크리스트.
저장소: `git@github.com:startdata/knowledge-base.git` (개인 private)

---

## 현재 상태 (집 Mac)
- [x] GitHub private repo 생성
- [x] 집 Mac SSH 키 등록
- [x] clone: `~/knowledge-base`
- [x] 골격: `CLAUDE.md`, `.gitignore`, 폴더(`정리/` `세션/` `개념/` `private/`)
- [x] 자동화: `/마무리` 커맨드 + commit 환기 훅 (설정은 `_setup/`에 백업됨)

---

## 회사 Mac 세팅

> 회사 Mac은 **GitHub 계정이 집과 다르다.** 접근 권한 설정이 핵심.

### 1. SSH 키 준비
```
ls ~/.ssh/*.pub                          # 기존 키 확인
ssh-keygen -t ed25519 -C "회사_이메일"    # 없으면 생성
ssh-add --apple-use-keychain ~/.ssh/id_ed25519   # passphrase 걸었으면 키체인 저장
```

### 2. 저장소 접근 권한 (둘 중 하나)
- **방법 A (권장·단순)** — 회사 Mac 공개키를 **개인 계정(startdata)** 에 등록
  GitHub(startdata 로그인) → Settings → SSH and GPG keys → New SSH key → 공개키 붙여넣기
- **방법 B** — 회사 계정을 repo collaborator로 초대 (회사 Mac에서 회사 계정을 쓸 경우)

공개키 복사: `pbcopy < ~/.ssh/id_ed25519.pub`

### 3. 연결 확인 + clone
```
ssh -T git@github.com
git clone git@github.com:startdata/knowledge-base.git ~/knowledge-base
```
호스트키 경고가 뜨면: `ssh-keygen -R github.com` 후 재시도.

### 4. Obsidian
- 설치 → "Open folder as vault" → `~/knowledge-base`
- 커뮤니티 플러그인(나중에): Spaced Repetition(복습), Obsidian Git(자동 동기화)

### 5. 자동화 트리거 설정 (★ 중요)
정리 자동화(커맨드·훅)는 `~/.claude/`에 있어 **git으로 따라오지 않는다.** repo의 `_setup/`에 백업해뒀으니 회사 Mac에서 복사한다:

```
# /마무리 커맨드
mkdir -p ~/.claude/commands
cp ~/knowledge-base/_setup/마무리.md ~/.claude/commands/마무리.md

# commit 환기 훅 스크립트
mkdir -p ~/.claude/hooks
cp ~/knowledge-base/_setup/notify-organize.sh ~/.claude/hooks/notify-organize.sh
```
그다음 `~/.claude/settings.json`에 훅을 등록한다 — `_setup/settings-hook.json`의 `"hooks"` 블록을 settings.json에 **병합**한다(이미 settings.json이 있으면 `hooks` 키만 추가). 경로는 `~/`를 쓰므로 사용자명 무관.

설정 후 Claude Code에서 `/hooks`를 한 번 열어 훅을 로드한다.

---

## 작업 루틴 (양쪽 공통)
- **시작**: `git pull`
- **작업**: Claude로 대화·정리. 세션 노트에 과정·수치·검증 기록
- **끝**: `/마무리` (또는 commit 시 환기) → 선별·정리 → `git add . && git commit && git push`

> `private/`는 `.gitignore`라 동기화 안 됨 — 각 Mac 로컬에만 존재.
