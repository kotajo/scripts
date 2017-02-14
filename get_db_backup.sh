#!/bin/sh

###############################################
#
# for getting db backup
# initial 2017/01/20
# create by k.jo
#
###############################################

DATE=`date '+%Y%m%d%H%M%S'`
LOGFILE="/var/log/scripts/get_db_backup.log"
DIR="/usr/local/share/dbdump"
DBPASS=""

#ログ用関数（ファイル出力のみ)
function log() {
  echo "`date "+%Y/%m/%d %H:%M:%S"` $1" >> ${LOGFILE}
}

##########get-db-dump##########
if [ ! -d ${DIR} ];then
    mkdir ${DIR}
fi

log "START get-db-dump"
mysqldump -uroot -p${DBPASS} --all-databases --lock-all-tables > ${DIR}/dbdump_${DATE}.db


##########dumpfile-rotation###########
log "START dumpfile-rotation"

del_files=`find ${DIR} -mtime +7 -print -exec rm {} \; | sed -e 's/ /\n/g'`
#find ${DIR} -mtime +7 -print -exec ls -l {} \;

if [ "${del_files}" != "" ];then

while read line
do
    log "DONE delete ${line}"

done <<END
${del_files}
END

else
log "nothing to do ..."

fi

log "END"


