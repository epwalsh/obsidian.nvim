set rtp+=.
if $PLENARY != "" && isdirectory($PLENARY)
  set rtp+=$PLENARY
endif
runtime! plugin/plenary.vim
