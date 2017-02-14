#!/bin/sh

###############################################
#
# for getting ec2 backup(AMI)
# initial 2016/08/27
# create by k.jo
#
###############################################

YYYYMMDD=`date '+%Y%m%d'`
LOGFILE="/var/log/scripts/get_ec2_backup.log"

#ログ用関数（ファイル出力のみ)
function log() {
  echo "`date "+%Y/%m/%d %H:%M:%S"` $1" >> ${LOGFILE}
}

#ログ用関数（標準出力 + ファイル出力)
function log_stdout() {
  echo "`date "+%Y/%m/%d %H:%M:%S"` $1" | tee -a ${LOGFILE}
}

##########引数の数をチェック##########
if [ $# -gt 1 ];then
    #引数の数が1より大きい場合、エラーメッセージを標準出力とログに出力し、処理終了
    log_stdout "ERROR : 引数の数が不正です。"
    exit 1
fi


##########引数の文字列をチェック##########
ARG=$1

#引数が 指定なし または --no-reboot の場合 (Default)
if [ -z ${ARG} ] || [ ${ARG} = "--no-reboot" ];then
    CMD_OPT="--no-reboot"

#引数が --rebootの場合
elif [ ${ARG} = "--reboot" ];then
    CMD_OPT="--reboot"

else
    #それ以外の場合、エラーメッセージを標準出力とログに出力し、処理終了
    log_stdout "ERROR : オプションは --reboot または --no-reboot のどちらかを指定してください。"
    exit 1
fi


##########get-instance-ids##########
log "START get-instance-ids"

#AutoBackupタグがtrueになっているインスタンス情報を取得
INSTANCE_INFO=`aws ec2 describe-tags --filters "Name=tag:AutoBackup, Values=true" 2>&1`

    #戻り値判定
    if [ $? = 0 ];then

       #正常（戻り値：0）の場合
       #出力されたインスタンス情報からIDのみを変数へ格納
       INSTANCE_IDS=`echo "${INSTANCE_INFO}" | grep "ResourceId" | awk -F'"' '{print $4}'`

    else
       #異常（戻り値：0以外）の場合、出力されたエラーメッセージを標準出力とログに出力し、処理終了
       log_stdout "ERROR : `echo ${INSTANCE_INFO} | sed -e s/[\r\n]\+//g`"
       exit 1
    fi

while read id
do
    log ${id}
done <<END
${INSTANCE_IDS}
END

log "END"


##########create-image,tags##########
#AMI取得、タグ付与をidリストに記載のインスタンスに繰り返す
while read line
do
    ##########create-image##########
    log "START create-image from ${line}"

    #Nameタグの値を取得
    instance_name=`aws ec2 describe-tags --filters "Name=tag:Name, Values=*" "Name=resource-id, Values=${line}" | grep Value | awk -F'"' '{print $4}'`

    #AMI名を定義
    ami_name="AMI_${instance_name}_${YYYYMMDD}"
    log ${ami_name}

    #AMI取得、出力を変数へ格納
    ami_ret=`aws ec2 create-image --instance-id ${line} --name ${ami_name} ${CMD_OPT} 2>&1`

    #戻り値判定
    if [ $? = 0 ];then
       
       #正常（戻り値：0）の場合
       #出力されたAMI-idを変数へ格納
       ami_id=`echo "${ami_ret}" | grep "ImageId" | awk -F'"' '{print $4}'`
       
       log ${ami_id}
       log "END"


       ##########create-tags##########
       log "START create-tags ${ami_id}"

       #取得したAMIにタグを付与
       tag_ret=`aws ec2 create-tags \
                   --resources ${ami_id} \
                   --tags \
                   Key=BackupType,Value=Auto \
                   Key=CreateDate,Value=${YYYYMMDD} \
                   Key=InstanceName,Value=${instance_name} 2>&1`

       #戻り値判定
       if [ $? -ne 0 ];then
           log "ERROR : `echo ${tag_ret} | sed -e s/[\r\n]\+//g`"
       fi

    else
       #異常（戻り値：0以外）の場合、出力されたエラーをログに記入
       log "ERROR : `echo ${ami_ret} | sed -e s/[\r\n]\+//g`"
    fi

log "END"

done <<END
${INSTANCE_IDS}
END
