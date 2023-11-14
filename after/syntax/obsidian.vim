if exists("b:current_syntax")
  finish
endif

if !exists("b:obsidian_todo_char")
  let b:obsidian_todo_char = "☐"
endif

if !exists("b:obsidian_todo_done_char")
  let b:obsidian_todo_done_char = "✔"
endif

syntax region WikiLink matchgroup=WikiLinkDelim start="\v\[\[" skip="\v[^\|\]]+" end="\v\]\]" oneline concealends
syntax region WikiLinkWithAlias matchgroup=WikiLinkDelim start="\v\[\[[^\|\]]+\|" end="\v\]\]" oneline concealends

highlight link WikiLink htmlLink
highlight link WikiLinkWithAlias htmlLink

execute 'syntax match mkdToDo "\v^(\s+)?-\s\[\s\]"hs=e-4 conceal cchar=' . b:obsidian_todo_char
execute 'syntax match mkdToDoDone "\v^(\s+)?-\s\[x\]"hs=e-4 conceal cchar=' . b:obsidian_todo_done_char

let b:current_syntax = "obsidian"
