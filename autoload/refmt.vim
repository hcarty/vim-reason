
function! refmt#Strip(input_string)
  return substitute(a:input_string, '\s*$', '\1', '')
endfunction


function! refmt#Refmt(...)
    let type = a:0 ? a:1 : &filetype
    "Support composite filetypes by replacing dots with underscores
    let type = substitute(type, "[.]", "_", "g")

    "Get formatprg config
    let s:vimreason_var = "g:vimreason_".type
    let s:vimreason_args_var = "g:vimreason_args_".type
    let s:vimreason_args_expr_var = "g:vimreason_args_expr_".type
    let s:vimreason_extra_args_expr_var = "g:vimreason_extra_args_expr_".type

    if !exists(s:vimreason_var)
        "No formatprg defined
        if exists("g:autoformat_verbosemode")
            echoerr "refmt formatter defined for filetype '".type."'."
        endif
        return 0
    endif
    let s:formatprg = eval(s:vimreason_var)

    let s:vimreason_args = ""
    if exists(s:vimreason_args_expr_var)
        let s:vimreason_args = eval(eval(s:vimreason_args_expr_var))
    elseif exists(s:vimreason_args_var)
        let s:vimreason_args = eval(s:vimreason_args_var)
    endif
    let s:vimreason_extra_args = ""
    if exists(s:vimreason_extra_args_expr_var)
        let s:vimreason_extra_args = eval(eval(s:vimreason_extra_args_expr_var))
    endif

    let totalCommand = s:formatprg." ".s:vimreason_extra_args." ".s:vimreason_args
    let inLines = getline(1,'$')
    let buffContents = join(inLines, "\n")
    let out = esy#ExecWithStdIn(totalCommand, buffContents)
    if v:shell_error
      " Grab the original output.
      let originalOut = substitute(out, "\001", '', 'g')
      let originalOut = substitute(originalOut, '\n', ' ', 'g')
      let originalOut = substitute(originalOut, '\m\s\{2,}', ' ', 'g')
      let originalOut = substitute(originalOut, '\m^\s\+', '', '')
      let originalOut = substitute(originalOut, '\m\s\+$', '', '')
      " Now we'll go see if it was actually due to refmt not being in the
      " path. We didn't want to do this before trying to refmt because it
      " slows down refmts to *valid* installs. This way, we'll only pay the
      " which refmt delay to check the path when there was some error.
      call esy#Exec('which ' . s:formatprg)
      if v:shell_error
        let res = reason#VimReasonShortMsg("ReasonPrettyPrint: refmt not found. Open a .re file in a built esy project or install refmt globally.")
        return 0
      endif
      let res = reason#VimReasonShortMsg(originalOut)
      return 0
    else
      let numModifications = 0
      let outLines = split(out, '\n')
      let i = 0
      while i < len(outLines)
        if i < len(inLines)
          let outLine = refmt#Strip(outLines[i])
          let inLine = inLines[i]
          if outLine != inLine
            let numModifications = numModifications + 1
            call setline(i + 1, outLine)
          endif
        else
          let outLine = refmt#Strip(outLines[i])
          " Notice no + 1
          call append(i, outLine)
          let numModifications = numModifications + 1
        endif
        let i = i + 1
      endwhile
      let stopDeletingAt = i
      let i = len(inLines) - 1
      while i >= stopDeletingAt
        execute ((i + 1) . " delete")
        let numModifications = numModifications + 1
        let i = i - 1
      endwhile
      if numModifications == 0
        let res = reason#VimReasonShortMsg("Refmt: Already Formatted")
      endif
      return 1
    endif
  endfunction
