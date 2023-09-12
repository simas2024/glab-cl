#!/bin/zsh

zmodload zsh/curses

view.status.add ()
{
    (( width=$3 ))
    (( height=$4 ))
    (( xpos=(COLUMNS/2)-(width/2) ))
    (( ypos=(LINES/2)-(height/2) ))
    zcurses addwin $1 $height $width $ypos $xpos $2
    zcurses clear $1
    zcurses border $1
}

view.status.println () 
{
    zcurses move $1 $2 $3
    zcurses string $1 $4
    zcurses refresh $1
}

view.status.clear () 
{
    zcurses clear $1
    zcurses refresh $1
    zcurses border $1
}

view.status.del () 
{
    zcurses delwin $1
}