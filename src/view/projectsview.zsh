#!/bin/zsh

zmodload zsh/curses

typeset -a pid pnames pvisibility pstatus pvisibility_orig pnooffiles velements

source data/projects.zsh
source view/statusview.zsh

setopt EXTENDED_GLOB

view.projects.progress () 
{
    view.status.println progressview 2 2 "$1"
}

view.projects.load () 
{
    (( pagesize=LINES-headerlines-statuslines-2 ))
    currentpage=$1
    pid=()
    pvisibility=()
    pnooffiles=()
    pname=()
    view.status.add progressview stdscr 30 4
    view.status.println progressview 1 2 "Loading projects data ..."
    dataFile=$(projects.datafile $2 $userid $pagesize $currentpage)
    view.status.println progressview 2 2 "Done!"
    view.status.del progressview
    while read c1 c2 c3 c4; do
        pid=($pid[@] "$(print ${c1//"gid:\/\/gitlab\/Project\/"/})")
        pvisibility=($pvisibility[@] "$(print $c2)")
        pnooffiles=($pnooffiles[@] "$(print $c3)")
        pname=($pname[@] "$(print $c4)")
    done <$dataFile
    pvisibility_orig=($pvisibility)
    pstatus=(${(@)pid/*/ })
    pn=${#pid}
    numberofpages=$(projects.numberofpages $userid $pagesize)
    [[ currentpage -eq 1 ]] && (( prevpage=1 )) || (( prevpage=currentpage - 1 ))
    [[ currentpage -eq numberofpages ]] && (( nextpage=numberofpages )) || (( nextpage=currentpage + 1 ))
    format="%s%-12s%-12s%-50s%-3s"
    velements[1]=$(print -f $format " " "ID"  "VISIBILITY" "NAME" "FILES")
    view.projects.model
}

view.projects.init ()
{
    statusmsg=
    userid=$1
    velements=()
    headerlines=1
    statuslines=1
    updates=0
    selected=1+headerlines
    view.projects.load 1 true
    view.projects.draw
}

view.projects.resetView ()
{
    zcurses end
    tput clear
    selected=1+headerlines
    zcurses refresh
}

view.projects.model ()
{
    for (( idx = 1; idx < pn+1; idx++ ));
    do
        pname[idx]=${(r(47)( ))pname[idx]}
        velements[idx+headerlines]="$(print -f $format $pstatus[idx] $pid[idx] $pvisibility[idx] $pname[idx] $pnooffiles[idx]) "
    done
}

view.projects.loop ()
{
    while true; do
        unset raw
        unset key
        zcurses timeout stdscr 500
        zcurses input stdscr raw key
        view.projects.read $raw $key || return
    done
}

view.projects.update ()
{
    view.status.add updateview stdscr 60 6
    for (( idx = 1; idx < pn+1; idx++ )); do
        view.status.clear updateview
        if [[ $pstatus[idx] == "*" ]]
        then 
            view.status.println updateview 1 2 "Make project $pid[idx] $pvisibility[idx]"
            if [[ $pvisibility[idx] == "public" ]]
            then
                local GIT_PROJECT_VISIBILITY_UPDATE=$(glab api --method=PUT "/projects/$pid[idx]?visibility=$pvisibility[idx]&repository_access_level=enabled") 2>/dev/null
            else
                local GIT_PROJECT_VISIBILITY_UPDATE=$(glab api --method=PUT "/projects/$pid[idx]?visibility=$pvisibility[idx]") 2>/dev/null
            fi
            newpvisibility=$(print -f %s "$GIT_PROJECT_VISIBILITY_UPDATE" | jq -r '.visibility')
            if [[ $newpvisibility == $pvisibility[idx] ]]
            then 
                projects.updatedatafile $userid $pagesize $currentpage $pid[idx] $pvisibility[idx]
                view.status.println updateview 2 2 "Done!"
                pstatus[idx]=" "
                pvisibility_orig[idx]=$pvisibility[idx]
                (( updates++ ))
            else
                view.status.println updateview 2 2 "Failed!"
            fi
        fi
    done
    view.status.println updateview 2 2 "Done!"
    view.status.del updateview
}

view.projects.reload ()
{
    velements=()
    selected=1+headerlines
    currentpage=1
    view.projects.load $currentpage $1
    view.projects.resetView
}

view.projects.read ()
{
    if [[ -v argv[1] && (( $#1>0 )) ]];
    then
        case $1 in
            'c')
                view.projects.reload false
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
                view.projects.model
                ;;
            'u')
                zcurses move stdscr $statusline[1] $statusline[2]
                zcurses attr stdscr white/black
                zcurses string stdscr "processing update visibilities on GitLab ...                                                                           "
                zcurses attr stdscr default/default
                zcurses refresh
                view.projects.update
                view.projects.load $currentpage true
                view.projects.model
                ;;
            'U')
                zcurses move stdscr $statusline[1] $statusline[2]
                zcurses attr stdscr white/black
                zcurses string stdscr "processing update visibilities on GitLab ...                                                                           "
                zcurses attr stdscr default/default
                zcurses refresh
                view.projects.update
                view.projects.load $currentpage false
                view.projects.model 
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
                view.projects.load $nextpage true
            fi
            ;;
            "LEFT")
            if (( currentpage > prevpage )); then
                velements=()
                selected=1+headerlines
                view.projects.load $prevpage true
            else
                zcurses end
                return 1
            fi
            ;;
        esac
    fi;

    view.projects.draw
}

view.projects.draw ()
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
    statusmsg="GitLab Projects page $currentpage/$numberofpages line $((( selected-headerlines ))) ('q' return to main view, 's' toggle visibility, 'u' update visibility, 'U' update visibility and reload all)"
    out=${(r($COLUMNS-1)( ))statusmsg} 
    zcurses string stdscr $out
    zcurses attr stdscr default/default
    zcurses refresh
}