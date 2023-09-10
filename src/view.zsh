#!/bin/zsh

zmodload zsh/curses

typeset -a pid pnames pvisibility pstatus pvisibility_orig pnooffiles velements

source view/projectsview.zsh
source view/snippetsview.zsh

setopt EXTENDED_GLOB

local pviews=(projects snippets)
local velements=()
local headerlines=1
local statuslines=1
local currentview=

view.load ()
{
    (( pagesize=LINES-headerlines-statuslines-2 ))

    format="%s%-12s%-12s"
    velements[1]=$(print -f $format " " "NR"  "VIEW")
    view.model
}

view.init ()
{
    userid=$1
    velements=()
    headerlines=1
    statuslines=1
    selected=1+headerlines
    view.load
    zcurses init
    view.draw
    monitorwindowresize=1
}

view.resetView ()
{
    zcurses end
    tput clear
    selected=1+headerlines
    zcurses refresh
}

view.model ()
{
    for (( idx = 1; idx < $#pviews+1; idx++ ));
    do
        velements[idx+headerlines]="$(print -f $format " " $idx "View ${(U)pviews[idx]}") "
    done
}

resize()
{
    if (( monitorwindowresize = 1 )); then
        view.resetView
        view.draw
        if [[ !  $currentview == "" ]];
        then
            view.$currentview.reload true
        fi
    fi
}

trap resize SIGWINCH

view.loop ()
{
    while true; do
        unset raw
        unset key
        zcurses timeout stdscr 500
        zcurses input stdscr raw key
        view.read $raw $key || return
    done
}

view.read ()
{   
    if [[ -v argv[1] && (( $#1>0 )) ]];
    then
        if [[ $1 =~ [1-9] && (( $1>0 && $1<$#pviews+1 )) ]]; 
        then 
            currentview=$pviews[$1]
            view.$pviews[$1].init $userid
            view.$pviews[$1].loop
            currentview=
            velements=()
            selected=1+headerlines
            view.load
            view.resetView
        else 
            case $1 in
                'q')
                    zcurses end
                    return 1
                    ;;
                "RIGHT")
                    (( viewidx=selected-headerlines ))
                    currentview=$pviews[$viewidx]
                    view.$pviews[$viewidx].init $userid
                    view.$pviews[$viewidx].loop
                    currentview=
                    velements=()
                    selected=1+headerlines
                    view.load
                    view.resetView
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
            esac
        fi
    fi
    view.draw
}

view.draw ()
{
    defaultColorScheme="default/default"
    zcurses clear stdscr
    for (( i=1; i < LINES; i++ )); do
        out=${(r($COLUMNS-1)( ))velements[i]} 
        if (( i == selected )); then
            zcurses attr stdscr white/black
            zcurses string stdscr $out
            zcurses char stdscr ' '
            zcurses attr stdscr $defaultColorScheme
        else
            zcurses string stdscr $out
            zcurses char stdscr ' '
        fi
    done
    zcurses position stdscr statusline
    zcurses attr stdscr white/black
    now=$(date)
    statusmsg="GitLab select view ('q' exit, '[1..$#pviews]' NR)"
    out=${(r($COLUMNS-1)( ))statusmsg} 
    zcurses string stdscr $out
    zcurses attr stdscr $defaultColorScheme
    zcurses refresh
}