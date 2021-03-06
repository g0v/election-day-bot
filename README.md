選舉日倒數機器人
==============

本處為 [@ElectionDay_bot][1] 推持機器人的源碼。

## 事前準備：設定檔 twitter.yml

`twitter.yml` 的內容需要四組值，範例如下：

    consumer_key: ...
    consumer_secret: ...
    access_token: ...
    access_token_secret: ...

## 執行

執行檔 `tweet.pl` 可接受 `-c` 與 `-y` 兩個參數。

其中 `-c` 參數提供 `twitter.yml` 檔之路徑。但必需加上 `-y` 旗標參數才會真
的發出推文，否則只會在畫面上顯示出推文內容。

    # 顯示
    perl tweet.pl

    # 顯示 + 發文
    perl tweet.pl -c twitter.yml -y

## 設定 cronjob

原則上一天執行一次。同一天內執行數次的話，也只是發出內容相同的推文。

    CRON_TZ=Asia/Taipei
    1 0 * * * perl /app/tweet.pl -c /app/twitter.yml -y

## 於 GitHub Action 中執行

執行檔 `tweet.pl` 可接受 `--github-secret` 旗標，表示 twitter token 存
在於 GitHub Action 提供的環境變數 `TWITTER_TOKENS` 當中。便於讓此機器
人於 GitHub Action 中運行。

秘值 `TWITTER_TOKENS` 內容需與 `twitter.yml` 內容相同，且事先添加於
GitHub repo 設定當中。

實際運作的 Workflow 為： `.github/workflows/tweet.yml`

[1]: https://twitter.com/ElectionDay_bot
