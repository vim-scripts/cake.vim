" cake.vim - Utility for CakePHP developpers.
" Maintainer:  Yuhei Kagaya <yuhei.kagaya@gmail.com>
" License:     This file is placed in the public domain.
" Last Change: 2011/05/09


if exists('g:loaded_cake_vim')
    finish
endif
let g:loaded_cake_vim = 1

let s:save_cpo = &cpo
set cpo&vim

" SECTION: Global Variables {{{
" Please write $MYVIMRC. (Also work to write.)
" ============================================================
" let g:cakephp_root = "/path/to/cakephp_root/"
" let g:cakephp_auto_set_project = 1
" let g:cakephp_use_theme = "admin"
" }}}
" SECTION: Script Variables {{{
" ============================================================
let s:cake_vim_version = '1.1.0'
let s:paths = {}
let s:controllers = {}
let s:models = {}
" }}}

" Function: s:initialize() {{{
" ============================================================
function! s:initialize(path)

    " プロジェクトのルートの指定。方法は、引数で指定するか、グローバル変数で指定するかのどちらか。
    if a:path != ''
        let s:paths.root = fnamemodify(a:path, ":p")
    elseif exists("g:cakephp_root") && g:cakephp_root != ''
        let s:paths.root = g:cakephp_root
    endif

    if !exists("s:paths.root") || s:paths.root == '' || !isdirectory(s:paths.root)
        echoerr "[cake.vim] please set g:cakephp_root or :Cinit {path}."
        return
    endif

    let s:paths.app = s:paths.root . "app/"
    let s:paths.controllers = s:paths.app . "controllers/"
    let s:paths.models = s:paths.app . "models/"
    let s:paths.views= s:paths.app . "views/"

    call s:cache_controllers()
    call s:cache_models()

endfunction
" }}}

" Function: s:cache_controllers() {{{
" ============================================================
function! s:cache_controllers()

    for controller_path in split(globpath(s:paths.app, "**/*_controller.php"), "\n")
        let key = s:path_to_name_controller(controller_path)
        let s:controllers[key] = controller_path
    endfor

endfunction
" }}}
" Function: s:cache_models() {{{
" ============================================================
function! s:cache_models()

    for model_path in split(globpath(s:paths.models, "*.php"), "\n")
        let s:models[s:path_to_name_model(model_path)] = model_path
    endfor

endfunction
" }}}

" Function: s:jump_controller() {{{
" ============================================================
function! s:jump_controller(...)

    let split_option = a:1

    " ジャンプ先controllerの決定。
    let target = ''
    let func_name = ''

    if a:0 >= 2
        " コントローラのリストから検索。
        let target = a:2
    else
        " 現在開いているファイルから推測。
        let path = expand("%:p")

        if s:is_view(path)
            let target = expand("%:p:h:t")
            let func_name = expand("%:p:t:r")
        elseif s:is_model(path)
            let target = s:pluralize(expand("%:p:t:r"))
        else
            return
        endif

    endif


    if !has_key(s:controllers, target)
        " 実はファイルが存在しているかも。再チャレンジ。
        " 次に、無ければつくるか聞く。
        if filewritable(s:name_to_path_controller(target))
            let s:controllers[target] = s:name_to_path_controller(target)
        elseif s:confirm_create_controller(target)
            let s:controllers[target] = s:name_to_path_controller(target)
        else
            call s:echo_warning(target . "_controller is not nound.")
            return
        endif
    endif


    " 指定行にジャンプ
    let line = 0
    if func_name != ''
        let cmd = 'grep -n -E "^\s*function\s*' . func_name . '\s*\(" ' . s:name_to_path_controller(target) . ' | cut -f 1'
        " 99: から行番号を抽出。
        let n = matchstr(system(cmd), '\(^\d\+\)')
        if strlen(n) > 0
            let line = str2nr(n)
        endif
    endif

    " バッファオープン。
    call s:open_file(s:controllers[target], split_option, line)

endfunction
"}}}
" Function: s:jump_model() {{{
" ============================================================
function! s:jump_model(...)

    let split_option = a:1

    let target = ''

    if a:0 >= 2
        " モデルのリストから検索。
        let target = a:2

    else
        " 現在開いているファイルから推測。
        let path = expand("%:p")

        if s:is_controller(path)
            let target = s:singularize(substitute(expand("%:p:t:r"), "_controller$", "", ""))
        else
            return
        endif

    endif

    if !has_key(s:models, target)
        " 実はファイルが存在しているかも。再チャレンジ。
        " 次に、無ければつくるか聞く。
        if filewritable(s:name_to_path_model(target))
            let s:models[target] = s:name_to_path_model(target)
        elseif s:confirm_create_model(target)
            let s:models[target] = s:name_to_path_model(target)
        else
            call s:echo_warning(target . " is not nound.")
            return
        endif
    endif

    let line = 0

    " バッファオープン。
    call s:open_file(s:models[target], split_option, line)

endfunction
"}}}
" Function: s:jump_view() {{{
" ============================================================
function! s:jump_view(...)

    if !s:is_controller(expand("%:p"))
        return
    endif

    let split_option = a:1
    let view_name = a:2

    if a:0 >= 3
        let theme = 'themed/' . a:3 . '/'
    else
        let theme = (exists("g:cakephp_use_theme") && g:cakephp_use_theme != '')? 'themed/' . g:cakephp_use_theme . '/' : ''
    endif

    let view_path = s:paths.views . theme . s:path_to_name_controller(expand("%:p")) . "/" . view_name . ".ctp"

    " なかったらつくるかどうか聞く。
    if !filewritable(view_path)
        if !s:confirm_create_view(view_path)
            call s:echo_warning(view_name . ".ctp is not nound.")
            return
        endif
    endif

    let line = 0

    " バッファオープン。
    call s:open_file(view_path, split_option, line)

endfunction
"}}}

" Function: s:confirm_create_controller() {{{
" ============================================================
function! s:confirm_create_controller(controller_name)
    let choice = confirm("[cake.vim] " . s:name_to_path_controller(a:controller_name) . " is not found. Do you make a file ?", "&Yes\n&No", 1)

    if choice == 0
        " EscやCtrl-Cで割り込みしたとき。
        return 0
    elseif choice == 1
        " TODO:touchじゃなくて、cp plugin/cake/skel/controller.php とかどうだろうなー。
        let result = system("touch " .  s:name_to_path_controller(a:controller_name))
        if strlen(result) != 0
            call s:echo_warning(result)
            return 0
        else
            return 1
        endif
    endif

    return 0
endfunction
" }}}
" Function: s:confirm_create_model() {{{
" ============================================================
function! s:confirm_create_model(model_name)
    let choice = confirm("[cake.vim] " . s:name_to_path_model(a:model_name) . " is not found. Do you make a file ?", "&Yes\n&No", 1)

    if choice == 0
        " EscやCtrl-Cで割り込みしたとき。
        return 0
    elseif choice == 1
        " TODO:touchじゃなくて、cp plugin/cake/skel/model.php とかどうだろうなー。
        let result = system("touch " .  s:name_to_path_model(a:model_name))
        if strlen(result) != 0
            call s:echo_warning(result)
            return 0
        else
            return 1
        endif
    endif

    return 0
endfunction
" }}}
" Function: s:confirm_create_view() {{{
" ============================================================
function! s:confirm_create_view(view_path)

    let choice = confirm("[cake.vim] " . a:view_path . " is not found. Do you make a file ?", "&Yes\n&No", 1)

    if choice == 0
        " EscやCtrl-Cで割り込みしたとき。
        return 0
    elseif choice == 1
        let result1 = system("mkdir -p " . fnamemodify(a:view_path, ":p:h"))
        let result2 = system("touch " . a:view_path)
        if strlen(result1) != 0 && strlen(result2) != 0
            call s:echo_warning(result2)
            return 0
        else
            return 1
        endif
    endif

    return 0
endfunction
" }}}

" Function: s:path_to_name_controller() {{{
" ============================================================
function! s:path_to_name_controller(controller_path)
    return substitute(fnamemodify(a:controller_path, ":t:r"), "_controller$", "", "")
endfunction
" }}}
" Function: s:path_to_name_model() {{{
" ============================================================
function! s:path_to_name_model(model_path)
    return fnamemodify(a:model_path, ":t:r")
endfunction
" }}}
" Function: s:name_to_path_controller() {{{
" ============================================================
function! s:name_to_path_controller(controller_name)
    return s:paths.controllers . a:controller_name . "_controller.php"
endfunction
" }}}
" Function: s:name_to_path_model() {{{
" ============================================================
function! s:name_to_path_model(model_name)
    return s:paths.models . a:model_name . ".php"
endfunction
" }}}

" Function: s:is_view() {{{
" ============================================================
function! s:is_view(path)

    if filereadable(a:path) && match(a:path, "app\/views") != -1 && fnamemodify(a:path, ":e") == "ctp"
        return 1
    endif

    return 0

endfunction
" }}}
" Function: s:is_model() {{{
" ============================================================
function! s:is_model(path)

    if filereadable(a:path) && match(a:path, "app\/models") != -1 && fnamemodify(a:path, ":e") == "php"
        return 1
    endif

    return 0

endfunction
" }}}
" Function: s:is_controller() {{{
" ============================================================
function! s:is_controller(path)

    if filereadable(a:path) && match(a:path, "app\/controllers") != -1 && match(a:path, "_controller\.php$") != -1
        return 1
    endif

    return 0

endfunction
" }}}

" Function: s:singularize() {{{
" rails.vim(http://www.vim.org/scripts/script.php?script_id=1567)
" rails#singularize
" ============================================================
function! s:singularize(word)

    let word = a:word
    if word == ''
        return word
    endif

    let word = substitute(word, '\v\Ceople$', 'ersons', '')
    let word = substitute(word, '\v\C[aeio]@<!ies$','ys', '')
    let word = substitute(word, '\v\Cxe[ns]$', 'xs', '')
    let word = substitute(word, '\v\Cves$','fs', '')
    let word = substitute(word, '\v\Css%(es)=$','sss', '')
    let word = substitute(word, '\v\Cs$', '', '')
    let word = substitute(word, '\v\C%([nrt]ch|tatus|lias)\zse$', '', '')
    let word = substitute(word, '\v\C%(nd|rt)\zsice$', 'ex', '')

    return word
endfunction
" }}}
" Function: s:pluralize() {{{
" rails.vim(http://www.vim.org/scripts/script.php?script_id=1567)
" rails#pluralize
" ============================================================
function! s:pluralize(word)

    let word = a:word
    if word == ''
        return word
    endif

    let word = substitute(word, '\v\C[aeio]@<!y$', 'ie', '')
    let word = substitute(word, '\v\C%(nd|rt)@<=ex$', 'ice', '')
    let word = substitute(word, '\v\C%([osxz]|[cs]h)$', '&e', '')
    let word = substitute(word, '\v\Cf@<!f$', 've', '')
    let word .= 's'
    let word = substitute(word, '\v\Cersons$','eople', '')

    return word
endfunction
" }}}

" Function: s:get_complelist_controller() {{{
" ============================================================
function! s:get_complelist_controller(ArgLead, CmdLine, CursorPos)
    let list = sort(keys(s:controllers))
    return filter(list, 'v:val =~ "^'. fnameescape(a:ArgLead) . '"')
endfunction
" }}}
" Function: s:get_complelist_model() {{{
" ============================================================
function! s:get_complelist_model(ArgLead, CmdLine, CursorPos)
    let list = sort(keys(s:models))
    return filter(list, 'v:val =~ "^'. fnameescape(a:ArgLead) . '"')
endfunction
" }}}
" Function: s:get_complelist_view() {{{
" ============================================================
function! s:get_complelist_view(ArgLead, CmdLine, CursorPos)

    if !s:is_controller(expand("%:p"))
        return []
    else

        let complelist = []

        " 関数名を抜き出す。
        let cmd = 'grep -E "^\s*function\s*\w+\s*\(" ' . expand("%:p")
        for line in split(system(cmd), "\n")

            let s = matchend(line, "\s*function\s*.")
            let e = match(line, "(")
            let func_name = strpart(line, s, e-s)

            " コールバック関数とかは抜く。
            if func_name !~ "^_" && func_name !=? "beforeFilter" && func_name !=? "beforeRender" && func_name !=? "afterFilter"
                let complelist = add(complelist, func_name)
            endif
        endfor

        return filter(sort(complelist), 'v:val =~ "^'. fnameescape(a:ArgLead) . '"')

    endif
endfunction
" }}}

" Function: s:echo_warning() {{{
" ============================================================
function! s:echo_warning(message)
    let prefix = "[cake.vim] "
    echohl WarningMsg | echo prefix . a:message | echohl None
endfunction
" }}}
" Function: s:open_file() {{{
" ============================================================
function! s:open_file(path, option, line)
    exec "badd " . a:path
    let buf_no = bufnr(a:path)
    if buf_no != -1
        if a:option == 's'
            exec "sb" . buf_no
        elseif a:option == 'v'
            exec "vert sb" . buf_no
        elseif a:option == 't'
            exec "tabedit"
            exec "b" . buf_no
        else
            exec "b" . buf_no
        endif

        if type(a:line) == type(0)
            exec a:line
            exec "normal z\<CR>"
            exec "normal ^"
        endif

    endif
endfunction
" }}}

" SECTION: Auto commands {{{
"============================================================
if exists("g:cakephp_auto_set_project") && g:cakephp_auto_set_project == 1
        autocmd VimEnter * call s:initialize('')
endif
" }}}
" SECTION: Commands {{{
" ============================================================
" 初期化。引数を指定した場合、そのパスで初期化する。
command! -n=? -complete=dir Cakephp :call s:initialize(<f-args>)

" * -> Controller
" 引数はコントローラ名。ViewやModelを開いている時で、引数を指定しない場合は現在開いているファイルから推測する。
command! -n=? -complete=customlist,s:get_complelist_controller Ccontroller call s:jump_controller('n', <f-args>)
command! -n=? -complete=customlist,s:get_complelist_controller Ccontrollersp call s:jump_controller('s', <f-args>)
command! -n=? -complete=customlist,s:get_complelist_controller Ccontrollervsp call s:jump_controller('v', <f-args>)
command! -n=? -complete=customlist,s:get_complelist_controller Ccontrollertab call s:jump_controller('t', <f-args>)

" -> Model
" 引数はモデル名。Controllerを開いているときで、引数を指定しない場合は現在開いているファイルから推測する。
command! -n=? -complete=customlist,s:get_complelist_model Cmodel call s:jump_model('n', <f-args>)
command! -n=? -complete=customlist,s:get_complelist_model Cmodelsp call s:jump_model('s', <f-args>)
command! -n=? -complete=customlist,s:get_complelist_model Cmodelvsp call s:jump_model('v', <f-args>)
command! -n=? -complete=customlist,s:get_complelist_model Cmodeltab call s:jump_model('t', <f-args>)

" Controller -> View
" 引数はビュー名、テーマ名。
command! -n=+ -complete=customlist,s:get_complelist_view Cview call s:jump_view('n', <f-args>)
command! -n=+ -complete=customlist,s:get_complelist_view Cviewsp call s:jump_view('s', <f-args>)
command! -n=+ -complete=customlist,s:get_complelist_view Cviewvsp call s:jump_view('v', <f-args>)
command! -n=+ -complete=customlist,s:get_complelist_view Cviewtab call s:jump_view('t', <f-args>)

" }}}

let &cpo = s:save_cpo
unlet s:save_cpo
" vim:set sts=4 sw=4 tw=0 fenc=utf-8 ff=unix ft=vim et fdm=marker:
