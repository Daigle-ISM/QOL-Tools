set ruler
set number
set ignorecase
set nobackup nowritebackup
set clipboard=unnamed
silent !echo Hello
syntax on
nnoremap <del> "_x
vnoremap <del> "_x
nnoremap x "xx
vnoremap x "xx
nnoremap d "dd
vnoremap d "dd
nnoremap c "cc
vnoremap c "cc
filetype plugin indent on
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab indentkeys-=<:>

if has("win32")
	" Disable fzf preview because it is broken in PowerShell
	let g:fzf_preview_window = ''

	" Use PowerShell as the shell
	set shell=powershell.exe
	set shellcmdflag=-NoLogo\ -NoProfile\ -NonInteractive\ -command
endif

" This corrects handling for the cursor in Windows terminal since commit df5320c439e9a7f7bf1ebff3cb455d45e223547a
" Note: This should be set after `set termguicolors` or `set t_Co=256`.
if &term =~ 'xterm' || &term == 'win32'
	" Use DECSCUSR escape sequences
	let &t_SI = "\e[5 q"    " blink bar
	let &t_SR = "\e[3 q"    " blink underline
	let &t_EI = "\e[1 q"    " blink block
	let &t_ti ..= "\e[1 q"   "blink block
	let &t_te ..= "\e[0 q"
	" default (depends on terminal, normally blink block)
endif
