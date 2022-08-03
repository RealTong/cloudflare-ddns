<h1 align="center">CloudFlare-DDNS</h1>

使用Shell编写的动态DNS脚本. 由CloudFlareAPI驱动

## 特性
* 定时检测IP变化更新
* Telegram Bot 通知
* 支持Socks代理

## 使用方法

#### 使用传统方式
1. `git clone https://github.com/RealTong/cloudflare-ddns.git`
2. 使用编辑器编辑 `cloudflare-ddns.sh` .
3. 将CloudFlare所需的认证信息填入
4. `chmod +x cloudflare-ddns.sh`
5. `./cloudflare-ddns.sh`
6. `使用crontab添加定时任务`
   ` */1 * * * *  /path/cloudflare-ddns.sh ` # 脚本将每分钟运行一次

### 参考文档
* [https://core.telegram.org/bots/api#sendmessage](https://core.telegram.org/bots/api#sendmessage)
* [https://api.cloudflare.com/#dns-records-for-a-zone-properties](https://api.cloudflare.com/#dns-records-for-a-zone-properties)