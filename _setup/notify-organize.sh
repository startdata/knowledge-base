#!/bin/sh
# Claude가 git commit을 실행하면(knowledge-base 레포 자체는 제외) knowledge-base 정리를 환기한다.
# 백업본 — ~/.claude/hooks/notify-organize.sh 로 복사하고 settings.json에 등록해야 동작한다.
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
cwd=$(printf '%s' "$input" | jq -r '.cwd // ""')
if printf '%s' "$cmd" | grep -q 'git commit' && ! printf '%s' "$cwd" | grep -q 'knowledge-base'; then
  printf '%s' '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"방금 커밋한 작업에서 다룬 개념·키워드를 ~/knowledge-base에 정리하려면 /마무리 커맨드를 쓰세요."}}'
fi
