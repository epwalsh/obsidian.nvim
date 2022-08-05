" Vim syntax file.
" Language:	Markdown
" Remark:	Meant to complement existing Markdown syntax files, not replace.

" In headers:
"
" Zettel date links '[[xxxx-xx-xx]]':
syntax region ZettelDateHeader matchgroup=ZettelDateDelim start="\v\[\[" skip="\v[0-9]{4}-[0-9]{2}-[0-9]{2}" end="\v\]\]" oneline concealends
highlight ZettelDateHeader cterm=bold ctermfg=166
" Zettel links '[[link|name]]':
syntax region ZettelLinkHeader matchgroup=ZettelLinkDelim start="\v\[\[[^\|\]]+\|" end="\v\]\]" oneline concealends
highlight ZettelLinkHeader cterm=bold ctermfg=166

" Same things, but not in headers:
"
syntax region ZettelDate matchgroup=ZettelDateDelim start="\v\[\[" skip="\v[0-9]{4}-[0-9]{2}-[0-9]{2}" end="\v\]\]" oneline concealends
highlight ZettelDate ctermfg=blue
syntax region ZettelLink matchgroup=ZettelLinkDelim start="\v\[\[[^\|\]]+\|" end="\v\]\]" oneline concealends
highlight ZettelLink ctermfg=blue

" Need to override these region definitions from vim-markdown to contain our ZettelLink / ZettelLinkHeader.
"
syn region mkdListItemLine start="^\s*\%([-*+]\|\d\+\.\)\s\+" end="$" oneline contains=@mkdNonListItem,mkdListItem,@Spell,ZettelLink,ZettelDate
syn region mkdNonListItemBlock start="\(\%^\(\s*\([-*+]\|\d\+\.\)\s\+\)\@!\|\n\(\_^\_$\|\s\{4,}[^ ]\|\t+[^\t]\)\@!\)" end="^\(\s*\([-*+]\|\d\+\.\)\s\+\)\@=" contains=@mkdNonListItem,@Spell,ZettelLink,ZettelDate
syn region htmlH1       matchgroup=mkdHeading     start="^\s*#"                   end="$" contains=mkdLink,mkdInlineURL,@Spell,ZettelLinkHeader,ZettelDateHeader
syn region htmlH2       matchgroup=mkdHeading     start="^\s*##"                  end="$" contains=mkdLink,mkdInlineURL,@Spell,ZettelLinkHeader,ZettelDateHeader
syn region htmlH3       matchgroup=mkdHeading     start="^\s*###"                 end="$" contains=mkdLink,mkdInlineURL,@Spell,ZettelLinkHeader,ZettelDateHeader
syn region htmlH4       matchgroup=mkdHeading     start="^\s*####"                end="$" contains=mkdLink,mkdInlineURL,@Spell,ZettelLinkHeader,ZettelDateHeader
syn region htmlH5       matchgroup=mkdHeading     start="^\s*#####"               end="$" contains=mkdLink,mkdInlineURL,@Spell,ZettelLinkHeader,ZettelDateHeader
syn region htmlH6       matchgroup=mkdHeading     start="^\s*######"              end="$" contains=mkdLink,mkdInlineURL,@Spell,ZettelLinkHeader,ZettelDateHeader

" Todo lists
"
syntax match my_todo '\v(\s+)?-\s\[\s\]'hs=e-4 conceal cchar=☐
syntax match my_todo_done '\v(\s+)?-\s\[x\]'hs=e-4 conceal cchar=✔
syntax match my_todo_skip '\v(\s+)?-\s\[\~\]'hs=e-4 conceal cchar=✗
