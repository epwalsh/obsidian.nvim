" Vim syntax file.
" Language:	Markdown
" Remark:	Meant to complement existing Markdown syntax files, not replace.

" Zettel date links '[[xxxx-xx-xx]]' and regular links '[[link|alias]]' in
" headers:
syntax region ZettelDateHeader matchgroup=ZettelDateDelim start="\v\[\[" skip="\v[0-9]{4}-[0-9]{2}-[0-9]{2}" end="\v\]\]" oneline concealends
syntax region ZettelLinkHeader matchgroup=ZettelLinkDelim start="\v\[\[[^\|\]]+\|" end="\v\]\]" oneline concealends
highlight link ZettelDateHeader htmlLink
highlight link ZettelLinkHeader htmlLink

" Same things, but not in headers:
syntax region ZettelDate matchgroup=ZettelDateDelim start="\v\[\[" skip="\v[0-9]{4}-[0-9]{2}-[0-9]{2}" end="\v\]\]" oneline concealends
syntax region ZettelLink matchgroup=ZettelLinkDelim start="\v\[\[[^\|\]]+\|" end="\v\]\]" oneline concealends
highlight link ZettelDate htmlLink
highlight link ZettelLink htmlLink

" Need to override these region definitions from vim-markdown to contain our ZettelLink / ZettelLinkHeader.
syntax region mkdListItemLine start="^\s*\%([-*+]\|\d\+\.\)\s\+" end="$" oneline contains=@mkdNonListItem,mkdListItem,@Spell,ZettelLink,ZettelDate
syntax region mkdNonListItemBlock start="\(\%^\(\s*\([-*+]\|\d\+\.\)\s\+\)\@!\|\n\(\_^\_$\|\s\{4,}[^ ]\|\t+[^\t]\)\@!\)" end="^\(\s*\([-*+]\|\d\+\.\)\s\+\)\@=" contains=@mkdNonListItem,@Spell,ZettelLink,ZettelDate
syntax region htmlH1       matchgroup=mkdHeading     start="^\s*#"                   end="$" contains=mkdLink,mkdInlineURL,@Spell,ZettelLinkHeader,ZettelDateHeader
syntax region htmlH2       matchgroup=mkdHeading     start="^\s*##"                  end="$" contains=mkdLink,mkdInlineURL,@Spell,ZettelLinkHeader,ZettelDateHeader
syntax region htmlH3       matchgroup=mkdHeading     start="^\s*###"                 end="$" contains=mkdLink,mkdInlineURL,@Spell,ZettelLinkHeader,ZettelDateHeader
syntax region htmlH4       matchgroup=mkdHeading     start="^\s*####"                end="$" contains=mkdLink,mkdInlineURL,@Spell,ZettelLinkHeader,ZettelDateHeader
syntax region htmlH5       matchgroup=mkdHeading     start="^\s*#####"               end="$" contains=mkdLink,mkdInlineURL,@Spell,ZettelLinkHeader,ZettelDateHeader
syntax region htmlH6       matchgroup=mkdHeading     start="^\s*######"              end="$" contains=mkdLink,mkdInlineURL,@Spell,ZettelLinkHeader,ZettelDateHeader

" Todo lists
syntax match mkdToDo '\v(\s+)?-\s\[\s\]'hs=e-4 conceal cchar=☐
syntax match mkdToDoDone '\v(\s+)?-\s\[x\]'hs=e-4 conceal cchar=✔
syntax match mkdToDoSkip '\v(\s+)?-\s\[\~\]'hs=e-4 conceal cchar=✗
syntax match mkdToDoQuestion '\v(\s+)?-\s\[\?\]'hs=e-4 conceal cchar=❓
syntax match mkdToDoFollowup '\v(\s+)?-\s\[\>\]'hs=e-4 conceal cchar=⇨
