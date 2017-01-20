#!/bin/sh

###############################################
#
# for getting ec2 backup(AMI) by manually
# initial 2017/01/20
# create by k.jo
#
###############################################

YYYYMMDD=`date '+%Y%m%d'`
LOGFILE="/tmp/manual_get_ec2_backup.log"
#arg="$@"

#ログ用関数（標準出力 + ファイル出力)
function log_stdout() {
  echo "`date "+%Y/%m/%d %H:%M:%S"` $1" | tee -a ${LOGFILE}
}

##########引数の数をチェック##########
if [ $# -eq 0 ] && [ $# -gt 2 ];then
    #引数の数が0、または2より大きい場合、エラーメッセージを標準出力とログに出力し、処理終了
    log_stdout "ERROR : 引数の数が不正です。"
    exit 1
fi


##########オプションの判別##########
for arg in $@
do
    
    #引数が --no-reboot の場合 (Default)
    if [ ${arg} = "--no-reboot" ];then
        CMD_OPT="--no-reboot"

    #引数が --rebootの場合
    elif [ ${arg} = "--reboot" ];then
        CMD_OPT="--reboot"

    else
        #ホスト名の複数指定をエラーとする処理
        if [ "${instance_name}" = "" ];then
             instance_name=${arg}
 
        else
        #それ以外の場合、エラーメッセージを標準出力とログに出力し、処理終了
        log_stdout "ERROR オプションの指定が不正です。"
        exit 1
        
        fi
    fi

    #CMD_OPTのデフォルト（指定なしの場合）は--no-rebootとする
    if [ "${CMD_OPT}" = "" ];then
        CMD_OPT="--no-reboot"
    fi

done

#CMD_OPTのデフォルト（指定なしの場合）は--no-rebootとする
if [ "${CMD_OPT}" = "" ];then
    CMD_OPT="--no-reboot"
fi

#ホスト名が空の場合はエラーメッセージを標準出力とログに出力し、処理終了
if [ "${instance_name}" = "" ];then
    log_stdout "ERROR オプションの指定が不正です。"
    exit 1
fi


##########get-instance-id##########
log_stdout "START get-instance-id of ${instance_name}"

instance_id=`aws ec2 describe-tags \
                --filter \
                "Name=tag:Name, Values=${instance_name}" \
                --query="Tags[].[ResourceId]" \
                --output=text`

#対象ホスト名のインスタンスIDが存在しない場合はエラーメッセージを標準出力とログに出力し、処理終了
if [ "${instance_id}" = "" ];then
    log_stdout "ERROR 指定されたインスタンスは存在しません。 (${instance_name})"
    exit 1
fi


##########create-image,tags##########
log_stdout "START create-image from ${instance_id} (${instance_name})"

    #AMI名を定義
    ami_name="AMI_${instance_name}_${YYYYMMDD}"
    log_stdout ${ami_name}

    #AMI取得、出力を変数へ格納
    ami_ret=`aws ec2 create-image --instance-id ${instance_id} --name ${ami_name} ${CMD_OPT} 2>&1`

    
    #戻り値判定
    if [ $? = 0 ];then
       
        #正常（戻り値：0）の場合
        #出力されたAMI-idを変数へ格納
        ami_id=`echo "${ami_ret}" | grep "ImageId" | awk -F'"' '{print $4}'`       
        log_stdout ${ami_id}

        ##########create-tags##########
        log_stdout "START create-tags ${ami_id}"

        #取得したAMIにタグを付与
        tag_ret=`aws ec2 create-tags \
            --resources ${ami_id} \
            --tags \
            Key=BackupType,Value=Auto \
            Key=CreateDate,Value=${YYYYMMDD} \
            Key=InstanceName,Value=${instance_name} 2>&1`

        #戻り値判定
        if [ $? -ne 0 ];then
           #異常（戻り値：0以外）の場合、出力されたエラーを標準出力とログに出力
           log_stdout "ERROR `echo ${tag_ret} | sed -e s/[\r\n]\+//g`"
        fi

    else
        #異常（戻り値：0以外）の場合、出力されたエラーを標準出力とログに出力
        log_stdout "ERROR `echo ${ami_ret} | sed -e s/[\r\n]\+//g`"
    fi

log_stdout "END"
