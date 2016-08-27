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

#AutoBackupタグがtrueになっているインスタンスのidのリストを取得
aws ec2 describe-tags --filters "Name=tag:AutoBackup, Values=true" | grep "ResourceId" | awk -F'"' '{print $4}' > ${EC2_IDLIST}

#AMI取得、タグ付与をidリストに記載のインスタンスに繰り返す
while read line
do
    #AMI取得、出力されたAMI-idを変数へ格納
    AMI_ID=`aws ec2 create-image --instance-id ${line} --name AMI_${line}_${YYYYMMDD} | grep "ImageId" | awk -F'"' '{print $4}'`
    #取得したAMIにタグを付与
    aws ec2 create-tags --resources ${AMI_ID} --tags Key=BackupType,Value=Auto Key=CreateDate,Value=${YYYYMMDD}

done < ${EC2_IDLIST}
