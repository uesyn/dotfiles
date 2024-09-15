#!/usr/bin/env zsh

ab=""
ahead=0
behind=0
staged=0
unstaged=0
unmerged=0
untracked=0
ignored=0

while read -r line; do
  case "$line" in
    "# branch.oid "*) oid="${line#\# branch.oid }" ;;
    "# branch.head "*) head="${line#\# branch.head }" ;;
    "# branch.upstream "*) upstream="${line#\# branch.upstream }" ;;
    "# branch.ab "*) ab="${line#\# branch.ab }" ;;
    1* | 2*)
      line="${line#* }"
      xy="${line%% *}"
      case "$(echo "$xy" | cut -c1)" in
        M|A|D|R|C) staged=$((staged + 1)) ;;
      esac
      case "$(echo "$xy" | cut -c2)" in
        M|A|D|R|C) unstaged=$((unstaged + 1)) ;;
      esac
      ;;
    "u "*) unmerged=$((unmerged + 1)) ;;
    "? "*) untracked=$((untracked + 1)) ;;
    "! "*) ignored=$((ignored + 1)) ;;
    *) "$line: invalid git status line" ;;
  esac
done < <(git status --porcelain=v2 --branch)

if [ -n "$ab" ]; then
  ahead="${ab% -*}"
  ahead="${ahead#+}"
  behind="${ab#+* }"
  behind="${behind#-}"
fi

git_prompt="${head}"
if [[ -n "${upstream}" ]]; then
  git_prompt="${git_prompt}..${upstream}"
  if [[ "${ahead}" -gt 0 ]]; then
    git_prompt="${git_prompt} ↑${ahead}"
  fi
  if [[ "${behind}" -gt 0 ]]; then
    git_prompt="${git_prompt} ↓${behind}"
  fi
fi

if [[ "${staged}" -gt 0 ]]; then
  git_prompt="${git_prompt} +${staged}"
fi

if [[ "${unstaged}" -gt 0 ]]; then
  git_prompt="${git_prompt} !${unstaged}"
fi

if [[ "${untracked}" -gt 0 ]]; then
  git_prompt="${git_prompt} ?${untracked}"
fi

print " ${git_prompt}"

