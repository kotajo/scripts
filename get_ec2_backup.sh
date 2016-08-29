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
LOGFILE=/tmp/get_ec2_backup_${YYYYMMDD}.log


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
    CMD_OPT="--reboot "

#引数が --no-rebootの場合
elif [ ${ARG} = "--no-reboot" ];then
    CMD_OPT="--no-reboot "

else
    #それ以外の場合、エラーメッセージを標準出力とログに出力し、処理終了
    echo "ERROR : オプションは --reboot または --no-reboot のどちらかを指定してください。" | tee ${LOGFILE}
    exit 1
fi


##########get-instance-ids##########
#LOG
echo "`date "+%Y/%m/%d %H:%M:%S"` START get-instance-ids" >> ${LOGFILE}

#AutoBackupタグがtrueになっているインスタンスのidのリストを取得
aws ec2 describe-tags --filters "Name=tag:AutoBackup, Values=true" | grep "ResourceId" | awk -F'"' '{print $4}' > ${EC2_IDLIST}

#LOG
cat ${EC2_IDLIST} >> ${LOGFILE}
echo "`date "+%Y/%m/%d %H:%M:%S"` END" >> ${LOGFILE}


##########エラーチェック用##########
#EC2_IDLIST=/tmp/err-check_ec2backup_idlist


##########create-image,tags##########
#LOG
echo "`date "+%Y/%m/%d %H:%M:%S"` START create-image from ${line}"

#AMI取得、タグ付与をidリストに記載のインスタンスに繰り返す
while read line
do
    ##########create-image##########
    #LOG
    echo "`date "+%Y/%m/%d %H:%M:%S"` START create-image from ${line}" >> ${LOGFILE}

    #AMI取得、出力を変数へ格納
    AMI_RET=`aws ec2 create-image --instance-id ${line} --name AMI_${line}_${YYYYMMDD} ${CMD_OPT} 2>&1`

    #戻り値判定
    if [ $? = 0 ];then
       
       #正常（戻り値：0）の場合
       #AMI取得完了までwait
       aws ec2 wait image-available --filter "Name=name,Values=AMI_${line}_${YYYYMMDD}" 2>> ${LOGFILE}

       #出力されたAMI-idを変数へ格納
       AMI_ID=`echo ${AMI_RET} | grep "ImageId" | awk -F'"' '{print $4}'`
       
       #LOG
       echo "`date "+%Y/%m/%d %H:%M:%S"` ${AMI_ID}" >> ${LOGFILE}

    else
       #異常（戻り値：0以外）の場合、出力されたエラーをログに記入
       echo "`date "+%Y/%m/%d %H:%M:%S"` ${AMI_RET}" >> ${LOGFILE}
    fi

    #LOG
    echo "`date "+%Y/%m/%d %H:%M:%S"` END" >> ${LOGFILE}


    ##########create-tags##########
    #LOG
    echo "`date "+%Y/%m/%d %H:%M:%S"` START create-tags ${AMI_ID}" >> ${LOGFILE}

    #取得したAMIにタグを付与
    aws ec2 create-tags --resources ${AMI_ID} --tags Key=BackupType,Value=Auto Key=CreateDate,Value=${YYYYMMDD} 2>> ${LOGFILE} 

    #LOG
    echo "`date "+%Y/%m/%d %H:%M:%S"` END" >> ${LOGFILE}

done < ${EC2_IDLIST}
