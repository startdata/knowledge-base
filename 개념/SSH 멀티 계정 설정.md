# SSH 멀티 계정 설정 (GitHub 계정 여러 개)

한 컴퓨터에서 GitHub 계정 두 개 이상을 쓰려면 계정마다 SSH 키를 따로 만들고, `~/.ssh/config`에 **호스트 별칭**을 둬서 어떤 키를 쓸지 고른다.

## 구조
```
Host github.com              # 기존 계정
  IdentityFile ~/.ssh/id_rsa
  IdentitiesOnly yes

Host github-second           # 두 번째 계정용 별칭
  HostName github.com        # 실제 접속 주소는 같다
  User git
  IdentityFile ~/.ssh/id_ed25519_second
  IdentitiesOnly yes
```
- 클론할 때 주소의 호스트를 별칭으로 바꾼다: `git@github.com:owner/repo.git` → `git@github-second:owner/repo.git`
- 이미 클론한 레포는 `git remote set-url origin git@github-second:owner/repo.git`
- 확인: `ssh -T git@github-second` → `Hi <계정>!` (종료 코드 1은 GitHub가 셸을 안 주기 때문이라 정상)

## ⚠️ 함정: `IdentitiesOnly`가 없으면 계정이 뒤섞인다
- ssh는 `IdentityFile`로 지정한 키만 쓰는 게 아니라, **ssh-agent에 올라온 키를 먼저 내밀 수 있다.**
- GitHub는 **처음 인증에 성공한 키의 계정**으로 사용자를 판단한다. 그래서 agent에 두 번째 계정 키가 올라가 있으면, 기존 `github.com` 호스트로 접속해도 두 번째 계정으로 인증될 수 있다.
- `IdentitiesOnly yes`는 "설정에 적힌 키만 쓴다"는 뜻이다. **모든 GitHub 호스트 블록에** 넣어야 한다. 새 블록에만 넣으면 기존 블록이 뚫린다.
- `AddKeysToAgent yes` + `UseKeychain yes`(macOS) 조합이면 한 번 쓴 키가 agent에 계속 남아서 이 문제가 쉽게 생긴다.

## 커밋 작성자는 별개
SSH 키는 **push 권한(인증)**만 정한다. 커밋 작성자(`user.name`/`user.email`)는 git 설정에서 따로 정해진다.
- 레포별: `git config user.email ...` (전역 설정보다 우선)
- 폴더별 자동 전환: `~/.gitconfig`의 `[includeIf "gitdir:~/work/"]`

## 관련
[[SSH 터널]]

#flashcards
- Q: 호스트 별칭을 만들었는데도 기존 github.com이 두 번째 계정으로 인증되는 이유? → A: ssh-agent의 키를 먼저 내밀기 때문. 모든 블록에 `IdentitiesOnly yes`.
- Q: SSH 키를 바꾸면 커밋 작성자도 바뀌나? → A: 아니다. 작성자는 git `user.name/email` 설정이 정한다.

## 출처
- [OpenSSH ssh_config — IdentitiesOnly](https://man.openbsd.org/ssh_config)
- [GitHub Docs — Managing multiple accounts](https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-personal-account-on-github/managing-your-personal-account/managing-multiple-accounts)

#stub
