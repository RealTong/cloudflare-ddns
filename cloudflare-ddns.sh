#!/bin/bash

set -u
set -e

CF_API_KEY=
CF_RECORD_NAME=
CF_USER_MAIL=
CF_ZONE_NAME=
RECORD_TYPE=
TG_BOT_ID=
TG_CHAT_ID=
PROXY_ADDR=
PROXY_PORT=



if [ "$PROXY_ADDR" != "" ] && [ "$PROXY_PORT" != "" ]; then
	CURL_PROXY="-x socks5h://$PROXY_ADDR:$PROXY_PORT"
else
	CURL_PROXY=""
fi


if [ "$RECORD_TYPE" = "A" ]; then
	IP_API="https://4.ipw.cn"
elif [ "$RECORD_TYPE" = "AAAA" ]; then
	IP_API="https://6.ipw.cn"
else
	LOG_TIME=`date --rfc-3339 sec`
	printf "$LOG_TIME: 记录类型不正确, 仅支持 A 或 AAAA \n"
	exit 2
fi

IP_CURRENT=`curl -s $IP_API`
IP_FILE=$HOME/.ip-$CF_RECORD_NAME.txt


# 判断ID文件是否存在
if [ ! -f $IP_FILE ]; then
    IP_LAST=""
else
    IP_LAST=`cat $IP_FILE`
fi

if [ "$IP_CURRENT" = "$IP_LAST" ] ; then
	LOG_TIME=`date --rfc-3339 sec`
    printf "$LOG_TIME: IP 没有变化, 不需要更新 \n"
	exit 0
fi

CF_ID=$HOME/.cf-id-$CF_RECORD_NAME.txt

if [ -f $CF_ID ] && [ $(wc -l $CF_ID | cut -d " " -f 1) -gt 0 ]; then
    

    CF_ZONE_ID=$(sed -n '1,1p' "$CF_ID")
	CF_RECORD_ID=$(sed -n '2,1p' "$CF_ID")
else
    CF_ZONE_ID=$(curl $CURL_PROXY -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$CF_ZONE_NAME" -H "X-Auth-Email: $CF_USER_MAIL" -H "X-Auth-Key: $CF_API_KEY" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
    CF_RECORD_ID=$(curl $CURL_PROXY -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=$CF_RECORD_NAME" -H "X-Auth-Email: $CF_USER_MAIL" -H "X-Auth-Key: $CF_API_KEY" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*' | head -1 )
	printf "$CF_ZONE_ID\n" > $CF_ID
	printf "$CF_RECORD_ID\n" >> $CF_ID
	printf "$CF_ZONE_NAME\n" >> $CF_ID
	printf "$CF_RECORD_NAME" >> $CF_ID
fi

LOG_TIME=`date --rfc-3339 sec`
printf "$LOG_TIME: 正在将 $CF_RECORD_NAME 解析记录更改到 $IP_CURRENT...\n"

PUT_DNS_API_RESPONSE=$(curl $CURL_PROXY -o /dev/null -s  -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID" -H "X-Auth-Email: $CF_USER_MAIL" -H "X-Auth-Key: $CF_API_KEY" -H "Content-Type: application/json" --data "{\"id\":\"$CF_ZONE_ID\",\"type\":\"$RECORD_TYPE\",\"name\":\"$CF_RECORD_NAME\",\"content\":\"$IP_CURRENT\", \"ttl\":120}")

if [ "$PUT_DNS_API_RESPONSE" != 200 ]; then
	LOG_TIME=`date --rfc-3339 sec`
	printf "$LOG_TIME: 域名记录更新失败.\n"
	exit 1
else
	LOG_TIME=`date --rfc-3339 sec`
	printf "$LOG_TIME: 成功将 $IP_CURRENT 更新至 $CF_RECORD_NAME.\n"
    # 将新IP持久化
	printf $IP_CURRENT > $IP_FILE
fi