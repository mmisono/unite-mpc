let s:save_cpo = &cpo
set cpo&vim

let s:source = { 
\   'name': 'mpc',
\   'max_candidates': 1000
\ }

let s:cache = {}

function! s:source.gather_candidates(args, context)
    if len(a:args) > 0 
        if index([
                    \"playlist",
                    \"playlist2",
                    \"ls",
                    \"lsplaylists",
                    \"listall",
                    \"listall2",
                    \"artist",
                    \]
                    \,a:args[0]) != -1
            let cmd = a:args[0]
        else
            echoerr "Unite mpc: invalid arg"
            return [{"word":"","source":""}]
        endif
    else
        let cmd = "listall"
    endif

    if !a:context.is_redraw && has_key(s:cache,cmd)
        echo "use cahce"
        return s:cache[cmd]
    endif

    if cmd == "playlist"
        echo "caching... please wait"
        let r = split(system('echo "playlistinfo'.nr2char(10).'close"| nc '
                        \.g:mpd_host.' '.g:mpd_port),"\n")[1:-2]
        
        let info = s:parse_info(r)
        let s:cache.playlist = s:generate_candidate_from_info(info,"mpc_playlist_music")
        return s:cache.playlist

    elseif cmd == "playlist2"
        echo "caching... please wait"
        let s:cache.playlist2 =  
            \ map(split(system('mpc playlist'), "\n"), '{
            \ "word": v:val,
            \ "source": "mpc",
            \ "kind": "mpc_playlist_music",
            \ "action__num": v:key+1,
            \ "action__name": v:val,
            \ }')
        return s:cache.playlist2

    elseif cmd == "lsplaylists"
        echo "caching... please wait"
        let s:cache.lsplaylists =  
            \ map(split(system('mpc lsplaylists'), "\n"), '{
            \ "word": v:val,
            \ "source": "mpc",
            \ "kind": "mpc_playlist",
            \ "action__num": v:key+1,
            \ }')
        return s:cache.lsplaylists

    elseif cmd == "artist"
        let back = [{
                    \ "word" : "[..]",
                    \ "source" : "mpc",
                    \ "kind" : "mpc_back",
                    \ "action__cmd" : "artist"
                    \ }]
        if len(a:args) > 2
            let back[0].action__arg = a:args[1]
            return back + 
                \map(split(system('mpc find Artist "'.a:args[1].'"'
                \.' Album "'.a:args[2].'"'), "\n"), '{
                \ "word": v:val,
                \ "source": "mpc",
                \ "kind": "mpc_music",
                \ "action__num": v:key+1,
                \ "action__artist":  a:args[1],
                \ "action__album":  a:args[2],
                \ }')
        elseif len(a:args) > 1
            return back + 
                \map(split(system('mpc list Album Artist "'.a:args[1].'"'
                \),"\n"), '{
                \ "word": v:val,
                \ "source": "mpc",
                \ "kind": "mpc_album",
                \ "action__num": v:key+1,
                \ "action__artist":  a:args[1],
                \ }')
        else
            return map(split(system('mpc list Artist'), "\n"), '{
                \ "word": v:val,
                \ "source": "mpc",
                \ "kind": "mpc_artist",
                \ "action__num": v:key+1,
                \ }')
        endif

    elseif cmd == "ls"
        if len(a:args) > 1
            let dir = a:args[1]
        else
            let dir = ""
        endif
        if has('win32') || has('win64')
            let back_dir = join(split(dir,'\\')[:-2],'\\')
        else
            let back_dir = join(split(dir,'/')[:-2],'/')
        endif
        let back = [{
                    \ "word" : "[..]",
                    \ "source" : "mpc",
                    \ "kind" : "mpc_back",
                    \ "action__cmd" : "ls",
                    \ "action__arg" : back_dir,
                    \ }]
        return  back + 
            \ map(split(system('mpc ls "'.dir.'"'), "\n"), '{
            \ "word": v:val,
            \ "source": "mpc",
            \ "kind":
            \ v:val =~ ".mp3$" || 
            \ v:val =~ ".m4a$" || 
            \ v:val =~ ".ogg$" ||
            \ v:val =~ ".wav$" || 
            \ v:val =~ ".flac$" ? 
            \ "mpc_music" : "mpc_dir"
            \ }')

    elseif cmd == "listall2"
        echo "caching... please wait"
        let s:cache.listall2 =  
            \ map(split(system('mpc listall'), "\n"), '{
            \ "word": v:val,
            \ "source": "mpc",
            \ "kind": "mpc_music",
            \ "action__num": v:key+1,
            \ "action__name": v:val,
            \ }')
        return s:cache.listall2

    else  "listall
        echo "caching... please wait"
        let r = split(system('echo "listallinfo'.nr2char(10).'close"| nc '
                        \.g:mpd_host.' '.g:mpd_port),"\n")[1:-2]
        
        let info = s:parse_info(r)
        let s:cache.listall = s:generate_candidate_from_info(info,"mpc_music")
        return s:cache.listall

    endif
endfunction

function! s:parse_info(info)
    let info = []
    let i = -1
    for line  in a:info
        let [k,v] = split(line,": ")[:1]
        if k == "directory"
            continue
        elseif k == "file"
            let i += 1
            call add(info,{})
        endif
        let info[i][k] = v
    endfor

    return info
endfunction

function! s:generate_candidate_from_info(info,kind)
    let candidates = []
    let i = 1
    for info in a:info
        let abbr = s:padding(i,5)
        let word = i
        let word .= "n".(i/1000)*1000
    
        if has_key(info,"Title")
            if has_key(info,"Artist")
                let abbr .= s:padding("  ".info["Artist"],30)
                let word .= " ".info["Artist"]
            else
                let abbr .= "  ".repeat(' ',30)
            endif

            let abbr .= s:padding("  ".info["Title"],40)
            let word .= " ".info["Title"]

            if has_key(info,"Album")
                let abbr .= s:padding("  ".info["Album"],40)
                let word .= " ".info["Album"]
            else
                let abbr .= "  ".repeat(' ',40)
            endif

            if has_key(info,"Track")
                let abbr .= s:padding("  ".info["Track"],8)
                let word .= " ".info["Track"]
            else
                let abbr .= "  ".repeat(' ',8)
            endif

            if has_key(info,"Date")
                let abbr .= s:padding(" (".info["Date"].")",8)
                let word .= " ".info["Date"]
            else
                let abbr .= repeat(' ',8)
            endif

            if has_key(info,"Time")
                let time = info["Time"]
                let min = time / 60
                let min = len(min) == 1 ? " ".min : min
                let sec = time % 60
                let sec = len(sec) == 1 ? "0".sec : sec
                let time = min.":".sec
                let abbr .= "  ".s:padding(time,5)
                let word .= " ".time
            else 
                let abbr = "  ".repeat(' ',5)
            endif
            if has_key(info,"Genre")
                let abbr .= "  ".info["Genre"]
                let word .= "  ".info["Genre"]
            endif
        else
            let abbr .= "  ".simplify(info["file"])
            let word .= "  ".simplify(info["file"])
        endif
    
        let candidate = {}
        let candidate.word = word
        let candidate.abbr = abbr
        let candidate.source = "mpc"
        let candidate.kind = a:kind
        let candidate.action__num = i
        let candidate.action__name = info["file"]
        if has_key(info,"Artist")
            let candidate.action__artist = info["Artist"]
        endif
        if has_key(info,"Title") 
            let candidate.action__title = info["Title"]
        endif
        call add(candidates,candidate)
        let i += 1
    endfor
    return candidates
endfunction

function! s:padding(str,width)
    if v:version >= 703
        if strwidth(a:str) > a:width 
            let str = s:trim(a:str,a:width-3)."..."
            let str = str.repeat(' ',a:width-strwidth(str))
        else
            let str = a:str.repeat(' ',a:width-strwidth(a:str))
        endif   
    else
        if len(a:str) > a:width
            let str =  a:str[:a:width-1]
        else
            let str = a:str.repeat(' ',a:width-len(a:str))
        endif
    endif
    return str
endfunction

" Trim string after a:n display cells.
" thanks: tyru [https://gist.github.com/833618]
function! s:trim(s, n)
    let s = ''
    for c in split(a:s, '\zs')
        if strwidth(s . c) > a:n
            return s
        endif
        let s .= c
    endfor
    return s
endfunction

function! unite#sources#mpc#define()
    if !exists('g:mpd_host')
        let g:mpd_host = "localhost"
    endif
    if !exists('g:mpd_port')
        let g:mpd_port = "6600"
    endif
    return executable('mpc') && executable('nc') ? [s:source] : []
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
