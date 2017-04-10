function! s:logs_clear()
  if input('Clear logs [y=yes]? ') == 'y'
    if expand('%') == '[gdb]logs'
      set ma
      norm! ggdG
      set noma
    endif
  endif
endfun

function! gdb#layout#update_buffer(bufnr, content)
  exe bufnr . 'bufdo setlocal ma'
  exe bufnr . 'bufdo normal! ggdG'
  exe bufnr . 'bufdo call append(0, '.string(content).')'
  exe bufnr . 'bufdo setlocal noma'
endfun

" Given the regex, extracts the match from the current line in the buffer.
" If there's no match, the fallback_str is returned.
function! s:matchstr_with_fallback(line, regex, fallback_str)
  let matched = matchstr(a:line, a:regex)
  if matched == ""
    return a:fallback_str
  else
    return matched
  endif
endfun

" Returns [thread_id, frame_id] corresponding to the line in the backtrace buffer.
" If any entry of the pair has no result, empty string will be used.
function! gdb#layout#backtrace_retrieve()
  let frame_idx_pattern = '^\s*\*\= frame #\zs\d\+'
  let thread_idx_pattern = '^\s*\*\= thread #\zs\d\+'
  let frame_id = matchstr(getline('.'), frame_idx_pattern)
  let line_offset = frame_id == '' ? -1 : +frame_id
  let thread_id = matchstr(getline(line('.') - line_offset - 1), thread_idx_pattern)
  if frame_id == '-1'
    let frame_id = ''
  endif
  return [thread_id, frame_id]
endfun

" Returns breakpoint id correnponding to the line in the breakpoint buffer.
" If the result is invalid, empty string will be returned.
function! gdb#layout#breakpoint_retrieve()
  let bp_idx_pattern = '^\s*\zs\d\+\.\=\d*'
  let frame_id = matchstr(getline('.'), bp_idx_pattern)
  return frame_id
endfun

function! gdb#layout#init_buffers()
  let s:buffers = [ 'backtrace', 'breakpoints', 'disassembly',
                  \ 'locals', 'logs', 'registers', 'threads' ]
  let s:buffer_map = {}
  let u_bnr = bufnr('%')
  for bname in s:buffers
    let bnr = bufnr('[gdb]' . bname, 1)
    call setbufvar(bnr, '&ft', 'gdb')
    call setbufvar(bnr, '&bt', 'nofile')
    call setbufvar(bnr, '&swf', 0)
    call setbufvar(bnr, '&ma', 0)
    call setbufvar(bnr, '&bl', 0)
    let s:buffer_map[bname] = bnr
  endfor
  exe 'silent b ' . u_bnr
  return s:buffer_map
endfun

function! gdb#layout#init_window(width, split, bnr)
  exe 'belowright ' . a:width . a:split . '+b' . a:bnr
  set nonu
  set nornu
  if s:buffer_map['logs'] == a:bnr
    nnoremap <buffer> i :call gdb#remote#stdin_prompt()<CR>
    nnoremap <silent> <buffer> <nowait> d :call <SID>logs_clear()<CR>
    nnoremap <silent> <buffer> <nowait> q :drop #<CR>
  elseif s:buffer_map['backtrace'] == a:bnr || s:buffer_map['threads'] == a:bnr
    if s:buffer_map['backtrace'] == a:bnr
      nnoremap <silent> <buffer> a :call gdb#remote#__notify("btswitch")<CR>
      nnoremap <silent> <buffer> t :drop [gdb]threads<CR>
    else
      nnoremap <silent> <buffer> a :drop [gdb]backtrace<CR>
    endif
    nnoremap <silent> <buffer> <CR>
            \ :call gdb#remote#__notify("select_thread_and_frame", gdb#layout#backtrace_retrieve())<CR>
  elseif s:buffer_map['breakpoints'] == a:bnr
    nnoremap <silent> <buffer> <nowait> x
            \ :call gdb#remote#__notify("breakdelete", gdb#layout#breakpoint_retrieve())<CR>
  endif
endfun

function! gdb#layout#setup(mode)
  if a:mode != 'debug'
    return
  endif
  if !exists('s:buffer_map') || empty(s:buffer_map)
    call gdb#layout#init_buffers()
  endif
  0tab sp
  let winw2 = winwidth(0)*2/5
  let winw3 = winwidth(0)*3/5
  let winh2 = winheight(0)*2/3
  call gdb#layout#init_window(winw3, 'vsp', s:buffer_map['threads'])
  call gdb#layout#init_window(winh2, 'sp', s:buffer_map['disassembly'])
  call gdb#layout#init_window(winw3/2, 'vsp', s:buffer_map['registers'])
  2wincmd h
  0tab sp
  call gdb#layout#init_window(winw2, 'vsp', s:buffer_map['backtrace'])
  call gdb#layout#init_window(winh2, 'sp', s:buffer_map['breakpoints'])
  call gdb#layout#init_window(winh2/2, 'sp', s:buffer_map['locals'])
  wincmd h
  call gdb#layout#init_window(winh2/2, 'sp', s:buffer_map['logs'])
  set cole=2 cocu=nc
  wincmd k
endfun

" tears down windows (and tabs) containing debug buffers
function! gdb#layout#teardown(...)
  if !exists('s:buffer_map') || empty(s:buffer_map)
    return
  endif
  let tabcount = tabpagenr('$')
  let bufnrs = values(s:buffer_map)
  for tabnr in range(tabcount, 1, -1)
    let blist = tabpagebuflist(tabnr)
    let bcount = len(blist)
    let bdcount = 0
    exe 'tabn ' . tabnr
    for bnr in blist
      if index(bufnrs, bnr) >= 0
        let bdcount += 1
        exe bufwinnr(bnr) . 'close'
      endif
    endfor
    if bcount < 2*bdcount && bcount > bdcount
      " close tab if majority of windows were gdb buffers
      tabc
    endif
  endfor
endfun

function! gdb#layout#signjump(bufnr, signid)
  if bufwinnr(a:bufnr) < 0
    let wnr = -1
    let ll_bufnrs = values(s:buffer_map)
    for i in range(winnr('$'))
      if index(ll_bufnrs, winbufnr(i+1)) < 0
        let wnr = i+1
        break
      endif
    endfor
    if wnr < 0
      return
    endif
    exe wnr . "wincmd w"
    exe a:bufnr . 'b'
  endif
  exe 'sign jump ' . a:signid . ' buffer=' . a:bufnr
endfun
