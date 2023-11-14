if exists("b:current_syntax")
  finish
endif

syntax region WikiLink matchgroup=WikiLinkDelim start="\v\[\[" skip="\v[^\|\]]+" end="\v\]\]" oneline concealends
syntax region WikiLinkWithAlias matchgroup=WikiLinkDelim start="\v\[\[[^\|\]]+\|" end="\v\]\]" oneline concealends

highlight link WikiLink htmlLink
highlight link WikiLinkWithAlias htmlLink

syntax match mkdToDo '\v^(\s+)?-\s\[\s\]'hs=e-4 conceal cchar=☐
syntax match mkdToDoDone '\v^(\s+)?-\s\[x\]'hs=e-4 conceal cchar=✔
syntax match mkdToDoSkip '\v^(\s+)?-\s\[\~\]'hs=e-4 conceal cchar=✗
syntax match mkdToDoQuestion '\v^(\s+)?-\s\[\?\]'hs=e-4 conceal cchar=❓
syntax match mkdToDoFollowup '\v^(\s+)?-\s\[\>\]'hs=e-4 conceal cchar=⇨

let b:current_syntax = "obsidian"
