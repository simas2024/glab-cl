#!/bin/zsh

MYDIR=${0:a:h}

setopt EXTENDED_GLOB
setopt nullglob

snippets._update ()
{
    ts=$(date +%s)

    aid="gid://gitlab/User/$1"
    pageSize="100"
    json=
    ptitle=()
    pid=()
    pvisibility=()
    pcountFiles=()
    snippetsCursor=
    moreSnippetPages='true'
    filesCursor=()
    snippetFiles=()
    while [[ $moreSnippetPages == "true" ]]; do
        json=$( glab api graphql -F authorId=$aid -F pageSize=$pageSize -F lastSnippetsCursor=$snippetsCursor -f query='
    query ($lastSnippetsCursor: String, $pageSize: Int, $authorId: UserID) {
        snippets(authorId: $authorId, type: personal, first: $pageSize, after:$lastSnippetsCursor) {
            nodes {
                id
                title
                visibilityLevel
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
            edges {
                node {
                    fileName
                }
            }
            pageInfo {
                endCursor
                hasNextPage
            }
        }
    }
    ') 2>>/dev/null
        snippetFiles=($snippetFiles[@] "${(@f)$(print -f %s "$json" | jq -r '.data.snippets.nodes[] | .blobs.pageInfo.hasNextPage')}")
        filesCursor=($filesCursor[@] "${(@f)$(print -f %s "$json" | jq -r '.data.snippets.nodes[] | .blobs.pageInfo.endCursor')}")
        moreSnippetPages=$(print -f %s $json | jq -r '.data.snippets.pageInfo.hasNextPage')
        snippetsCursor=$(print -f %s $json | jq -r '.data.snippets.pageInfo.endCursor')
        ptitle=($ptitle[@] "${(@f)$(print -f %s "$json" | jq -r '.data.snippets.nodes[] | .title')}")
        pid=($pid[@] "${(@f)$(print -f %s "$json" | jq -r '.data.snippets.nodes[] | .id')}")
        pvisibility=($pvisibility[@] "${(@f)$(print -f %s "$json" | jq -r '.data.snippets.nodes[] | .visibilityLevel')}")
        pcountFiles=($pcountFiles[@] "${(@f)$(print -f %s "$json" | jq -r '.data.snippets.nodes[] | [select(.blobs.nodes[].name) ] | length')}")
        snippetIdx=$snippetFiles[(i)true]
        while [[ $snippetIdx -le ${#snippetFiles} ]]; do
            while [[ $snippetFiles[$snippetIdx] == "true" ]]; do
                json=$( glab api graphql -F snippetID=$pid[$snippetIdx] -F authorId=$aid -F pageSize=$pageSize -F lastFilesCursor=$filesCursor[$snippetIdx] -f query='
    query ($lastFilesCursor: String, $pageSize: Int, $authorId: UserID, $snippetID: SnippetID!) {
        snippets(ids: [$snippetID],  authorId: $authorId) {
            nodes {
                blobs(first: $pageSize, after:$lastFilesCursor) {
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
    ') 2>>/dev/null
                (( pcountFiles[$snippetIdx]=pcountFiles[$snippetIdx]+$(print -f %s "$json" | jq -r '.data.snippets.nodes[] | [select(.blobs.nodes[].name) ] | length') ))
                snippetFiles[$snippetIdx]=$(print -f %s $json | jq -r '.data.snippets.nodes[] | .blobs.pageInfo.hasNextPage')
                filesCursor[$snippetIdx]=$(print -f %s $json | jq -r '.data.snippets.nodes[] | .blobs.pageInfo.endCursor')
            done
            snippetIdx=$snippetFiles[(i)true]
        done
    done
    print -C 4 "$pid[@]" "$pvisibility[@]" "$pcountFiles[@]" "$ptitle[@]" >$MYDIR/tmp/$ts"_snippet_data_$1".txt
    if [[ -f $MYDIR/tmp/$ts"_snippet_data_$1".txt ]]
    then
        command mv $MYDIR/tmp/$ts"_snippet_data_$1".txt $MYDIR/tmp/"current_snippet_data_$1".txt
    fi
}

snippets._load ()
{
    useCache=$1
    if [[ $useCache == "false" ]]
    then
        snippets.clearcache
        snippets._update $2
    fi
    if [[ -f $MYDIR/tmp/current_snippet_data_$2_$3_$4.txt ]]
    then
        res="$MYDIR/tmp/current_snippet_data_$2_$3_$4.txt"
    else
        if [[ ! -f $MYDIR/tmp/current_snippet_data_$2.txt ]]
        then
            snippets._update $2
        fi
        if [[ -f $MYDIR/tmp/current_snippet_data_$2.txt ]]
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
            done <$MYDIR/tmp/current_snippet_data_$2.txt
            (( pagesize=$argv[3], page=1, start_idx=1, end_idx=$pagesize ))
            while [[ $start_idx -le ${#pid} ]]; do
                c1=($pid[$start_idx,$end_idx])
                c2=($pvisibility[$start_idx,$end_idx])
                c3=($pcountFiles[$start_idx,$end_idx])
                c4=($ptitle[$start_idx,$end_idx])
                print -C 4 "$c1[@]" "$c2[@]" "$c3[@]" "$c4[@]" >$MYDIR/tmp/current_snippet_data_$2_${pagesize}_$page.txt
                (( start_idx=end_idx+1, end_idx=end_idx+pagesize, page=page+1 ))
            done
            res="$MYDIR/tmp/current_snippet_data_$2_$3_$4.txt"
        fi
    fi
    print $res
}

snippets.clearcache._allpages ()
{
    currentFiles=($MYDIR/tmp/current_snippet_*_*_*.txt) > /dev/null 2>&1
    if (( ${#currentFiles}>0 ))
    then
        ts=$(date +%s)
        command mkdir $MYDIR/tmp/"$ts"_cache
        command mv $MYDIR/tmp/current_snippet_*_*_*.txt $MYDIR/tmp/"$ts"_cache/ 2>&1
    fi
}

snippets.numberofpages ()
{
    pagesize=$2
    command wc -l $MYDIR/tmp/current_snippet_data_$1.txt | read noofsnippets tmp
    [[ noofsnippets -le  pagesize ]] && (( res=1 )) || [[ noofsnippets%pagesize -eq  0 ]] && ((res=noofsnippets/pagesize)) || ((res=noofsnippets/pagesize+1))
    print $res
}

snippets.updatedatafile() 
{
    if [ ! -f "$MYDIR/tmp/current_snippet_data_$1.txt" ]; then
        return 1
    fi

    snippets.clearcache._allpages
    sed -E -i '' "s|^(gid://gitlab/PersonalSnippet/$4)([[:space:]]*)([[:alnum:]]*)(.*)|\1\2$5\4 |" "$MYDIR/tmp/current_snippet_data_$1.txt" 

    return $?
}

snippets.datafile ()
{
    print $(snippets._load $1 $2 $3 $4)
}

snippets.clearcache ()
{
    currentFiles=($MYDIR/tmp/current_snippet_*) 2>/dev/null
    if (( ${#currentFiles}>0 ))
    then
        ts=$(date +%s)
        command mkdir $MYDIR/tmp/"$ts"_cache
        command mv $MYDIR/tmp/current_snippet_* $MYDIR/tmp/"$ts"_cache/
    fi
}

snippets.clearcache.page ()
{
    currentFiles=($MYDIR/tmp/current_snippet_data_$1_$2_$3.txt) 2>/dev/null
    if (( ${#currentFiles}>0 ))
    then
        ts=$(date +%s)
        command mkdir $MYDIR/tmp/"$ts"_cache
        command mv $MYDIR/tmp/current_snippet_data_$1_$2_$3.txt $MYDIR/tmp/"$ts"_cache/
    fi
}