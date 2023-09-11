#!/bin/zsh

zmodload zsh/curses

typeset -a pid pnames pvisibility pstatus pvisibility_orig pnooffiles velements

source data/snippets.zsh

setopt EXTENDED_GLOB

view.snippets.load ()
{
    (( pagesize=LINES-headerlines-statuslines-2 ))
    currentpage=$1
    pid=()
    pvisibility=()
    pnooffiles=()
    pname=()
    typeset -i statuswinline=1
    zcurses addwin statuswin 4 30 3 3 stdscr
    zcurses clear statuswin
    zcurses border statuswin
    zcurses move statuswin $statuswinline 2
    (( statuswinline = statuswinline+1 ))
    zcurses string statuswin "Loading snipptes data ..."
    zcurses refresh statuswin
    dataFile=$(snippets.datafile $2 $userid $pagesize $currentpage)
    zcurses move statuswin $statuswinline 2
    zcurses string statuswin "Done"
    zcurses delwin statuswin
    while read c1 c2 c3 c4; do
        pid=($pid[@] "$(print ${c1//"gid:\/\/gitlab\/PersonalSnippet\/"/})")
        pvisibility=($pvisibility[@] "$(print $c2)")
        pnooffiles=($pnooffiles[@] "$(print $c3)")
        pname=($pname[@] "$(print $c4)")
    done <$dataFile
    pvisibility_orig=($pvisibility)
    pstatus=(${(@)pid/*/ })
    pn=${#pid}
    numberofpages=$(snippets.numberofpages $userid $pagesize)
    [[ currentpage -eq 1 ]] && (( prevpage=1 )) || (( prevpage=currentpage - 1 ))
    [[ currentpage -eq numberofpages ]] && (( nextpage=numberofpages )) || (( nextpage=currentpage + 1 ))
    format="%s%-12s%-12s%-58s%-3s"
    velements[1]=$(print -f $format " " "ID"  "VISIBILITY" "NAME" "FILES")
    view.snippets.model
}

view.snippets.init ()
{
    statusmsg=
    userid=$1
    velements=()
    headerlines=1
    statuslines=1
    updates=0
    selected=1+headerlines
    view.snippets.load 1 true
    view.snippets.draw
}

view.snippets.resetView ()
{
    zcurses end
    tput clear
    selected=1+headerlines
    zcurses refresh
}

view.snippets.model ()
{
    for (( idx = 1; idx < pn+1; idx++ ));
    do
        pname[idx]=${(r(55)( ))pname[idx]}
        velements[idx+headerlines]="$(print -f $format $pstatus[idx] $pid[idx] $pvisibility[idx] $pname[idx] $pnooffiles[idx]) "
    done
}

view.snippets.loop ()
{
    while true; do
        unset raw
        unset key
        zcurses timeout stdscr 500
        zcurses input stdscr raw key
        view.snippets.read $raw $key || return
    done
}

view.snippets.update ()
{
    typeset -i statuswinline=1
    zcurses addwin statuswin 4 60 3 3 stdscr
    zcurses clear statuswin
    zcurses border statuswin
    for (( idx = 1; idx < pn+1; idx++ )); do
        zcurses clear statuswin
        zcurses refresh statuswin
        zcurses border statuswin
        if [[ $pstatus[idx] == "*" ]]
        then 
            (( statuswinline = 1 ))
            zcurses move statuswin $statuswinline 2
            zcurses string statuswin "Set visibility $pvisibility[idx] for snippet id: $pid[idx]"
            zcurses refresh statuswin
            if [[ $pvisibility[idx] == "public" ]]
            then
                local GIT_PROJECT_VISIBILITY_UPDATE=$(glab api --method=PUT "/snippets/$pid[idx]?visibility=$pvisibility[idx]") 2>/dev/null
            else
                local GIT_PROJECT_VISIBILITY_UPDATE=$(glab api --method=PUT "/snippets/$pid[idx]?visibility=$pvisibility[idx]") 2>/dev/null
            fi
            newpvisibility=$(print -f %s "$GIT_PROJECT_VISIBILITY_UPDATE" | jq -r '.visibility')
            if [[ $newpvisibility == $pvisibility[idx] ]]
            then
                snippets.updatedatafile $userid $pagesize $currentpage $pid[idx] $pvisibility[idx]
                (( statuswinline = statuswinline+1 ))
                zcurses move statuswin $statuswinline 2
                zcurses string statuswin " ... done!"
                pstatus[idx]=" "
                pvisibility_orig[idx]=$pvisibility[idx]
                (( updates++ ))
            else
                (( statuswinline = statuswinline+1 ))
                zcurses move statuswin $statuswinline 2
                zcurses string statuswin " ... failed!"
            fi
        fi
    done
    (( statuswinline = statuswinline+1 ))
    zcurses move statuswin $statuswinline 2
    zcurses string statuswin "Done"
    zcurses delwin statuswin
}

view.snippets.reload ()
{
    velements=()
    selected=1+headerlines
    currentpage=1
    view.snippets.load $currentpage $1
    view.snippets.resetView
}

view.snippets.read ()
{
    if [[ -v argv[1] && (( $#1>0 )) ]];
    then
        case $1 in
            'c')
                view.snippets.reload false
                ;;
            'q')
                zcurses end
                return 1
                ;;
            's')
                if [[ $pvisibility[selected-headerlines] == "private" ]] 
                then
                    pvisibility[selected-headerlines]="public"
                else
                    pvisibility[selected-headerlines]="private"
                fi

                if [[ $pvisibility[selected-headerlines] == $pvisibility_orig[selected-headerlines] ]]
                then 
                    pstatus[selected-headerlines]=" "
                else
                    pstatus[selected-headerlines]="*"
                fi
                view.snippets.model
                ;;
            'u')
                zcurses move stdscr $statusline[1] $statusline[2]
                zcurses attr stdscr white/black
                zcurses string stdscr "processing update visibilities on GitLab ...                                                                           "
                zcurses attr stdscr default/default
                zcurses refresh
                view.snippets.update
                view.snippets.load $currentpage true
                view.snippets.model
                ;;
            'U')
                zcurses move stdscr $statusline[1] $statusline[2]
                zcurses attr stdscr white/black
                zcurses string stdscr "processing update visibilities on GitLab ...                                                                           "
                zcurses attr stdscr default/default
                zcurses refresh
                view.snippets.update
                view.snippets.load $currentpage false
                view.snippets.model 
                ;;
            "UP")
                if (( selected > 1+headerlines )); then
                    (( selected-- ))
                fi
                ;;
            "DOWN")
                if (( selected < ${#velements} )); then
                    (( selected++ ))
                fi
                ;;
            "RIGHT")
            if (( currentpage < nextpage )); then
                velements=()
                selected=1+headerlines
                view.snippets.load $nextpage true
            fi
            ;;
            "LEFT")
            if (( currentpage > prevpage )); then
                velements=()
                selected=1+headerlines
                view.snippets.load $prevpage true
            else
                zcurses end
                return 1
            fi
            ;;
        esac
    fi;

    view.snippets.draw
}

view.snippets.draw ()
{
    zcurses clear stdscr
    for (( i=1; i < LINES; i++ )); do
        out=${(r($COLUMNS-1)( ))velements[i]} 
        if (( i == selected )); then
            zcurses attr stdscr white/black
            zcurses string stdscr $out
            zcurses char stdscr ' '
            zcurses attr stdscr default/default
        else
            zcurses string stdscr $out
            zcurses char stdscr ' '
        fi
    done
    zcurses position stdscr statusline
    zcurses attr stdscr white/black
    now=$(command date)
    statusmsg="GitLab Personal Snippets page $currentpage/$numberofpages line $((( selected-headerlines ))) ('q' return to main view, 's' toggle visibility, 'u' update visibility, 'U' update visibility and reload all)"
    out=${(r($COLUMNS-1)( ))statusmsg} 
    zcurses string stdscr $out
    zcurses attr stdscr default/default
    zcurses refresh
}