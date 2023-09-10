#!/bin/zsh

zmodload zsh/terminfo

LOGFILE="${0:a:h}/data/tmp/log.txt"

cd ${0:a:h}

log()
{
  if [[ ! -f $LOGFILE ]]; then
    echo "$(date +%s): $1 " >$LOGFILE
  else
    echo "$(date +%s): $1 " >>$LOGFILE
  fi
}

source view.zsh

TRAPINT() 
{
    for jobs in $jobstates ; do
      jobid=${${jobs##*:*:}%=*}
      kill ${${jobs##*:*:}%=*}
    done
    zcurses end
    exit
}

echoti civis
view.init $1
view.loop
echoti cnorm

for jobs in $jobstates ; do
  jobid=${${jobs##*:*:}%=*}
  kill ${${jobs##*:*:}%=*}
done