#!/bin/sh

###############################################
#
# for getting ec2 backup(AMI)
# initial 2016/08/27
# create by k.jo
#
###############################################

EC2_IDLIST="/tmp/ec2backup_idlist"
YYYYMMDD=`date '+%Y%m%d'`
LOGFILE="/tmp/get_ec2_backup.log"

function log() {
  echo "`date "+%Y/%m/%d %H:%M:%S"` $1" >> ${LOGFILE}
}


##########引数の数をチェック##########
if [ $# -gt 1 ];then
    #引数の数が1より大きい場合、エラーメッセージを標準出力とログに出力し、処理終了
    echo "ERROR : 引数の数が不正です。" | tee ${LOGFILE}
    exit 1
fi


##########引数の文字列をチェック##########
ARG=$1

#引数が --reboot または 指定なしの場合
if [ -n ${ARG} ] || [ ${ARG} = "--reboot" ];then
    CMD_OPT="--reboot"

#引数が --no-rebootの場合
elif [ ${ARG} = "--no-reboot" ];then
    CMD_OPT="--no-reboot"

else
    #それ以外の場合、エラーメッセージを標準出力とログに出力し、処理終了
    echo "ERROR : オプションは --reboot または --no-reboot のどちらかを指定してください。" | tee ${LOGFILE}
    exit 1
fi


##########get-instance-ids##########
log "START get-instance-ids"

#AutoBackupタグがtrueになっているインスタンスのidのリストを取得
aws ec2 describe-tags --filters "Name=tag:AutoBackup, Values=true" | grep "ResourceId" | awk -F'"' '{print $4}' > ${EC2_IDLIST}

#LOG
cat ${EC2_IDLIST} >> ${LOGFILE}
log "END"


##########エラーチェック用##########
#EC2_IDLIST=/tmp/err-check_ec2backup_idlist


##########create-image,tags##########
#AMI取得、タグ付与をidリストに記載のインスタンスに繰り返す
while read line
do
    ##########create-image##########
    log "START create-image from ${line}"
    ami_name="AMI_${line}_${YYYYMMDD}"

    #AMI取得、出力を変数へ格納
    ami_ret=`aws ec2 create-image --instance-id ${line} --name ${ami_name} ${CMD_OPT} 2>&1`

    #戻り値判定
    if [ $? = 0 ];then
       
       #正常（戻り値：0）の場合
       #出力されたAMI-idを変数へ格納
       ami_id=`echo ${ami_ret} | grep "ImageId" | awk -F'"' '{print $4}'`
       
       log ${ami_id}

    else
       #異常（戻り値：0以外）の場合、出力されたエラーをログに記入
       log "ERROR : `echo ${ami_ret} | sed -e s/[\r\n]\+//g`"
    fi

    log "END"


    ##########create-tags##########
    log "START create-tags ${ami_id}"

    #取得したAMIにタグを付与
    tag_ret=`aws ec2 create-tags --resources ${ami_id} --tags Key=BackupType,Value=Auto Key=CreateDate,Value=${YYYYMMDD} 2>&1`

    #戻り値判定
    if [ $? -ne 0 ];then
        log "ERROR : `echo ${tag_ret} | sed -e s/[\r\n]\+//g`"
    fi

    log "END"

done < ${EC2_IDLIST}
