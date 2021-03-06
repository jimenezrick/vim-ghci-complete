function! s:connect_ghci() abort
	let l:addr = readfile('.ghci_complete')[0]
	echomsg printf('Connecting to GHCi server: %s', l:addr)
	let b:ghci_chan = ch_open(l:addr, {"timeout": g:ghci_complete_timeout})
endfunction

function! s:send_command(command) abort
	if !exists('b:ghci_chan')
		call s:connect_ghci()
	elseif ch_status(b:ghci_chan) != 'open'
		call s:connect_ghci()
	endif

	if ch_status(b:ghci_chan) != 'open'
		echohl WarningMsg | echomsg 'Error: failed to connect to GHCi server' | echohl None
		throw 'error_ghci_connect'
	endif

	"echomsg printf('GHCi <= Command: %s', l:cmd)
	let l:resp = ch_evalexpr(b:ghci_chan, a:command)
	"echomsg printf('GHCi => Response: %s', l:resp)
	if type(l:resp) == v:t_string && l:resp == ""
		echohl ErrorMsg | echomsg "Error: timeout waiting for GHCi server reply" | echohl None
		throw 'error_ghci_timeout'
	endif

	return l:resp
endfunction

function! ghci#omnifunc(findstart, base) abort
	if a:findstart
		let b:ghci_current_line= getline('.')
		let b:ghci_current_col = col('.')
	endif

	let l:cmd = {
	\    'command': 'findstart',
	\    'line': b:ghci_current_line,
	\    'column': b:ghci_current_col,
	\    'complete_first': 1,
	\    'complete_last': g:ghci_complete_batch_size,
	\ }

	if !a:findstart
		let l:cmd['command'] = 'complete'
	endif

	while 1
		try
			let l:resp = s:send_command(l:cmd)
		catch
			return -1
		endtry

		if a:findstart
			return l:resp['start']
		else
			if empty(l:resp['results'])
				return []
			endif

			for r in l:resp['results']
				call complete_add(r)
			endfor

			if !l:resp['more']
				return []
			endif

			if complete_check()
				return []
			endif

			let l:cmd['complete_first'] += g:ghci_complete_batch_size
			let l:cmd['complete_last'] += g:ghci_complete_batch_size
		endif
	endwhile
endfunction

function! ghci#typeat() abort
	let l:cmd = {
	\    'command': 'typeat',
	\    'file': expand('%'),
	\    'line': line('.'),
	\    'column': col('.'),
	\    'under': expand('<cWORD>'),
	\ }

	try
		let l:resp = s:send_command(l:cmd)
		echomsg printf("%s :: %s", l:resp['expr'], l:resp['type'])
	catch
	endtry
endfunction

function! ghci#load(...) abort
	if a:0 == 0
		let l:cmd = {
		\    'command': 'reload',
		\ }
	else
		let l:cmd = {
		\    'command': 'load',
		\    'file': a:1,
		\ }
	endif

	try
		s:send_command(l:cmd)
	catch
	endtry
endfunction
