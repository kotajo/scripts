#!/bin/sh

###############################################
#
# delete ec2 backup(AMI $ Snapshot)
# initial 2017/01/19
# create by k.jo
#
###############################################

OLD_YYYYMMDD=`date '+%Y%m%d' --date "14 days ago"`
LOGFILE="/tmp/delete_ec2_backup.log"

#ログ用関数
function log() {
  echo "`date "+%Y/%m/%d %H:%M:%S"` $1" >> ${LOGFILE}
}

##########引数の数をチェック##########
if [ $# -gt 0 ];then
    #引数があった場合、エラーメッセージを標準出力とログに出力し、処理終了
    log_stdout "ERROR : 引数の数が不正です。"
    exit 1
fi

##########rotate-AMIs-Snamshots##########
log "START rotate-AMIs-Snamshots"

#BackupTypeタグがAuto、かつ、CreateDateタグが2週刊前のamiの情報を取得
ami_id=`aws ec2 describe-images \
            --filter \
            "Name=tag:BackupType, Values=Auto" \
            "Name=tag:CreateDate, Values=${OLD_YYYYMMDD}" \
            --query="Images[].[ImageId]" \
            --output=text |\
            sed -e 's/ /\n/g' 2>&1`

while read line
do

if [ "$line" = "" ];then
    log "OLD AMI is nothing."
    log "END"
    exit 0
fi

    ##########get-SnapshotsId##########
    snapshot_id=`aws ec2 describe-images \
                    --image-ids ${line} \
                    --query="Images[].BlockDeviceMappings[].Ebs[].[SnapshotId]" \
                    --output=text 2>&1`

    #########deregister-image##########
    log "START deregister-image ${line}"

    aws ec2 deregister-image --image-id ${line}

        #戻り値判定
        if [ $? -ne 0 ];then
           log "ERROR deregister-image ${line}"
        fi


    ##########delete-snapshot##########
    log "START delete-snapshot ${snapshot_id} (${line})"

    aws ec2 delete-snapshot --snapshot-id ${snapshot_id}

        #戻り値判定
        if [ $? -ne 0 ];then
           log "ERROR delete-snapshot ${line}"
        fi

done <<END
${ami_id}
END

log "END"