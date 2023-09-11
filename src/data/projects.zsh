#!/bin/zsh

MYDIR=${0:a:h}

setopt EXTENDED_GLOB
setopt nullglob

projects._update ()
{
    ts=$(date +%s)

    pageSize="100"
    
    json=
    ptitle=()
    pid=()
    pvisibility=()
    pfullPath=()
    pcountFiles=()
    projectsCursor=
    moreProjectPages='true'
    filesCursor=()
    projectFiles=()
    while [[ $moreProjectPages == "true" ]]; do
        nooffiles=0
        json=$( glab api graphql -F pageSize=$pageSize -F lastProjectsCursor=$projectsCursor -f query='
    query ($lastProjectsCursor: String, $pageSize: Int) {
        projects(membership:true, first:$pageSize, after:$lastProjectsCursor) {
            nodes {
                id
                fullPath
                name
                visibility
                repository {
                    tree(recursive: true) {
                        blobs(first: $pageSize) {
                            nodes {
                                name
                            }
                            pageInfo {
                                endCursor
                                hasNextPage
                            }
                        }
                    }
                }
            }
            pageInfo {
                endCursor
                hasNextPage
            }
        }
    }
    ') 2>>/dev/null
        projectFiles=($projectFiles[@] "${(@f)$(print -f %s "$json" | jq -r '.data.projects.nodes[] | .repository.tree.blobs.pageInfo.hasNextPage')}")
        filesCursor=($filesCursor[@] "${(@f)$(print -f %s "$json" | jq -r '.data.projects.nodes[] | .repository.tree.blobs.pageInfo.endCursor')}")
        moreProjectPages=$(print -f %s $json | jq -r '.data.projects.pageInfo.hasNextPage')
        projectsCursor=$(print -f %s $json | jq -r '.data.projects.pageInfo.endCursor')
        ptitle=($ptitle[@] "${(@f)$(print -f %s "$json" | jq -r '.data.projects.nodes[] | .name')}")
        pid=($pid[@] "${(@f)$(print -f %s "$json" | jq -r '.data.projects.nodes[] | .id')}")
        pvisibility=($pvisibility[@] "${(@f)$(print -f %s "$json" | jq -r '.data.projects.nodes[] | .visibility')}")
        pfullPath=($pfullPath[@] "${(@f)$(print -f %s "$json" | jq -r '.data.projects.nodes[] | .fullPath')}")
        pcountFiles=($pcountFiles[@] "${(@f)$(print -f %s "$json" | jq -r '.data.projects.nodes[].repository.tree | [select(.blobs.nodes[].name) ] | length')}")
        projectIdx=$projectFiles[(i)true]
        while [[ $projectIdx -le ${#projectFiles} ]]; do
            > "/tmp/status_info.txt" <<< "Processing project ($projectIdx/${#projectFiles})"
            kill -USR1 $$
            while [[ $projectFiles[$projectIdx] == "true" ]]; do
                json=$( glab api graphql -F projectPath=$pfullPath[$projectIdx] -F pageSize=$pageSize -F after=$filesCursor[$projectIdx] -f query='
    query ($projectPath: ID!, $after: String, $pageSize: Int) {
        project(fullPath: $projectPath) {
            repository {
                tree(recursive: true) {
                    blobs(first: $pageSize, after: $after) {
                        nodes {
                            name
                        }
                        pageInfo {
                            endCursor
                            hasNextPage
                        }
                    }
                }
            }
        }
    }
    ') 2>>/dev/null
                (( pcountFiles[$projectIdx]=pcountFiles[$projectIdx]+$(print -f %s $json | jq -r '[.data.project.repository.tree.blobs.nodes[] | select(.name) ] | length') ))
                projectFiles[$projectIdx]=$(print -f %s $json | jq -r '.data.project.repository.tree.blobs.pageInfo.hasNextPage')
                filesCursor[$projectIdx]=$(print -f %s $json | jq -r '.data.project.repository.tree.blobs.pageInfo.endCursor')
            done
            projectIdx=$projectFiles[(i)true]
        done
    done
    print -C 4  "$pid[@]" "$pvisibility[@]" "$pcountFiles[@]" "$ptitle[@]" >$MYDIR/tmp/$ts"_project_data_$1".txt
    if [[ -f $MYDIR/tmp/$ts"_project_data_$1".txt ]]
    then
        command mv $MYDIR/tmp/$ts"_project_data_$1".txt $MYDIR/tmp/"current_project_data_$1".txt
    fi
}

projects._load () 
{
    useCache=$1
    if [[ $useCache == "false" ]]
    then
        projects.clearcache
        projects._update $2
    fi
    if [[ -f $MYDIR/tmp/current_project_data_$2_$3_$4.txt ]]
    then
        res="$MYDIR/tmp/current_project_data_$2_$3_$4.txt"
    else
        if [[ ! -f $MYDIR/tmp/current_project_data_$2.txt ]]
        then
            projects._update $2
        fi
        if [[ -f $MYDIR/tmp/current_project_data_$2.txt ]]
        then
            pid=()
            pvisibility=()
            pcountFiles=()
            ptitle=()
            while read c1 c2 c3 c4; do
                pid=($pid[@] "$(print $c1)")
                pvisibility=($pvisibility[@] "$(print $c2)")
                pcountFiles=($pcountFiles[@] "$(print $c3)")
                ptitle=($ptitle[@] "$(print $c4)")
            done <$MYDIR/tmp/current_project_data_$2.txt
            (( pagesize=$argv[3], page=1, start_idx=1, end_idx=$pagesize ))
            while [[ $start_idx -le ${#pid} ]]; do
                c1=($pid[$start_idx,$end_idx])
                c2=($pvisibility[$start_idx,$end_idx])
                c3=($pcountFiles[$start_idx,$end_idx])
                c4=($ptitle[$start_idx,$end_idx])
                print -C 4 "$c1[@]" "$c2[@]" "$c3[@]" "$c4[@]" >$MYDIR/tmp/current_project_data_$2_${pagesize}_$page.txt
                (( start_idx=end_idx+1, end_idx=end_idx+pagesize, page=page+1 ))
            done
            res="$MYDIR/tmp/current_project_data_$2_$3_$4.txt"
        fi
    fi
    print $res
}

projects.clearcache._allpages ()
{
    currentFiles=($MYDIR/tmp/current_project_data_*_*_*.txt) > /dev/null 2>&1
    if (( ${#currentFiles}>0 ))
    then
        ts=$(date +%s)
        command mkdir $MYDIR/tmp/"$ts"_cache > /dev/null 2>&1 
        command mv $MYDIR/tmp/current_project_data_*_*_*.txt $MYDIR/tmp/"$ts"_cache/ > /dev/null 2>&1
    fi
}

projects.numberofpages ()
{
    pagesize=$2
    command wc -l $MYDIR/tmp/current_project_data_$1.txt | read noofprojects tmp
    [[ noofprojects -le  pagesize ]] && (( res=1 )) || [[ noofprojects%pagesize -eq  0 ]] && ((res=noofprojects/pagesize)) || ((res=noofprojects/pagesize+1))
    print $res
}

projects.updatedatafile () 
{
    if [ ! -f "$MYDIR/tmp/current_project_data_$1.txt" ]; then
        return 1
    fi
    projects.clearcache._allpages
    sed -E -i '' "s|^(gid://gitlab/Project/$4)([[:space:]]*)([[:alnum:]]*)(.*)|\1\2$5\4 |" "$MYDIR/tmp/current_project_data_$1.txt" 

    return $?
}

projects.datafile ()
{
    print $(projects._load $1 $2 $3 $4)
}

projects.clearcache ()
{
    currentFiles=($MYDIR/tmp/current_project_*) 2>/dev/null
    if (( ${#currentFiles}>0 ))
    then
        ts=$(date +%s)
        command mkdir $MYDIR/tmp/"$ts"_cache
        command mv $MYDIR/tmp/current_project_* $MYDIR/tmp/"$ts"_cache/
    fi
}

projects.clearcache.page ()
{
    currentFiles=($MYDIR/tmp/current_project_data_$1_$2_$3.txt) 2>/dev/null
    if (( ${#currentFiles}>0 ))
    then
        ts=$(date +%s)
        command mkdir $MYDIR/tmp/"$ts"_cache
        command mv $MYDIR/tmp/current_project_data_$1_$2_$3.txt $MYDIR/tmp/"$ts"_cache/
    fi
}