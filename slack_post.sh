#! /bin/bash

set -eu
CHANNEL="post-from-mgt01a-test" # DONOT USE '#'
USERNAME="slack_post_shell"
MESSAGE="TEST"
HOOKS_URL="https://hooks.slack.com/services/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"

for OPT in $*
do
    case $OPT in
        '-c' )
            CHANNEL=$2
            shift 2
            ;; 
        '-u' )
            USERNAME=$2
            shift 2
            ;; 
        '-h' )
            HOOKS_URL=$2
            shift 2
            ;; 
        '-m' )
            MESSAGE=$2
            shift 2
            ;; 
    esac
done

# slackのために無理やり\nを出力させる
MESSAGEFILE=/tmp/webhooks
if [ -f ${MESSAGEFILE} ] ; then
rm ${MESSAGEFILE}
fi

if [ -p /dev/stdin ] ; then
    cat - | tr '\n' '\\' | sed 's/\\/\\n/g'  > ${MESSAGEFILE}
fi

POST_MSG="${MESSAGE}\n"`cat ${MESSAGEFILE}`'\n'

curl -X POST --data-urlencode "payload={\"channel\": \"#${CHANNEL}\", \"username\": \"${USERNAME}\", \"text\": \"${POST_MSG}\"}" ${HOOKS_URL} 1>/dev/null 2>&1
