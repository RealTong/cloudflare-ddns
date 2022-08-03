#!/bin/bash

set -u
set -e
#####################请填入所需要的参数#####################
CF_API_KEY=
CF_USER_MAIL=

TG_BOT_TOKEN=
TG_CHAT_ID=

RECORD_TYPE=A
SECOND_LEVEL_DOMAIN=			#Example	example.com
THIRD_LEVEL_DOMAIN=				#Example	ddns.example.com


PROXY_ADDR=
PROXY_PORT=
###########################end#############################

if [ "$PROXY_ADDR" != "" ] && [ "$PROXY_PORT" != "" ]; then
	CURL_PROXY="-x socks5://$PROXY_ADDR:$PROXY_PORT"
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
IP_FILE=$HOME/.ip-$THIRD_LEVEL_DOMAIN.txt


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

CF_ID=$HOME/.cf-id-$THIRD_LEVEL_DOMAIN.txt

if [ -f $CF_ID ] && [ $(wc -l $CF_ID | cut -d " " -f 1) -gt 0 ]; then
    

    CF_ZONE_ID=$(sed -n '1,1p' "$CF_ID")
	CF_RECORD_ID=$(sed -n '2,1p' "$CF_ID")
else
    CF_ZONE_ID=$(curl $CURL_PROXY -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$SECOND_LEVEL_DOMAIN" -H "X-Auth-Email: $CF_USER_MAIL" -H "X-Auth-Key: $CF_API_KEY" -H "Content-Type: application/json" | grep -Po '(?<="id":")[^"]*' | head -1 )
    CF_RECORD_ID=$(curl $CURL_PROXY -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=$THIRD_LEVEL_DOMAIN" -H "X-Auth-Email: $CF_USER_MAIL" -H "X-Auth-Key: $CF_API_KEY" -H "Content-Type: application/json"  | grep -Po '(?<="id":")[^"]*' | head -1 )
	printf "$CF_ZONE_ID\n" > $CF_ID
	printf "$CF_RECORD_ID\n" >> $CF_ID
	printf "$SECOND_LEVEL_DOMAIN\n" >> $CF_ID
	printf "$THIRD_LEVEL_DOMAIN" >> $CF_ID
fi

LOG_TIME=`date --rfc-3339 sec`
printf "$LOG_TIME: 正在将 $THIRD_LEVEL_DOMAIN 解析记录更改到 $IP_CURRENT...\n"
# 发送更改IP请求
PUT_DNS_API_RESPONSE=$(curl $CURL_PROXY -o /dev/null -s -w "%{http_code}\n"  -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID" -H "X-Auth-Email: $CF_USER_MAIL" -H "X-Auth-Key: $CF_API_KEY" -H "Content-Type: application/json" --data "{\"id\":\"$CF_ZONE_ID\",\"type\":\"$RECORD_TYPE\",\"name\":\"$THIRD_LEVEL_DOMAIN\",\"content\":\"$IP_CURRENT\", \"ttl\":120}")
printf "$PUT_DNS_API_RESPONSE"
if [ "$PUT_DNS_API_RESPONSE" != 200 ]; then
	LOG_TIME=`date --rfc-3339 sec`
	printf "$LOG_TIME: 域名记录更新失败.\n"
	exit 1
else
	LOG_TIME=`date --rfc-3339 sec`
	printf "$LOG_TIME: 成功将 $IP_CURRENT 更新至 $THIRD_LEVEL_DOMAIN.\n"
    # 将新IP重新持久化
	printf $IP_CURRENT > $IP_FILE
	if [ "$TG_BOT_TOKEN" != "" ]; then
	# 发送更改IP通知
		LOG_TIME=`date --rfc-3339 sec`
		TG_API_RESPONSE=`curl $CURL_PROXY -o /dev/null -s -w "%{http_code}\n" "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage?chat_id=$TG_CHAT_ID&parse_mode=HTML&text=域%20$THIRD_LEVEL_DOMAIN%20现在成功指向%20$IP_CURRENT"`
		if [ "$TG_API_RESPONSE" != 200 ]; then
			LOG_TIME=`date --rfc-3339 sec`
			printf "$LOG_TIME: Bot消息发送失败.\n"
			exit 2
		else
			LOG_TIME=`date --rfc-3339 sec`
			printf "$LOG_TIME: Bot消息发送成功.\n"
			exit 0
		fi
	else
		exit 0
	fi
fi