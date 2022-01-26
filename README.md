# CS:GO Advanced Report (Gelişmiş Rapor)

**[EN]**
It ensures that players who are disturbed by the server or suspected of cheating are reported to the authorities. The reports are recorded both on the Discord server and on the database. The authorized person dealing with the report can send a message to request a response from the user in this report. Reports that are not updated for a certain period of time are automatically closed. In addition, spam can be prevented by banning from the report.

**[TR]**
Oyuncuların sunucu içerisinde rahatsız oldukları veya hile olduğundan şüphelendikleri kişileri yetkililere rapor edilmesini sağlamaktadır. Edilen raporlar hem Discord sunucusuna hem de veritabanı üzerinde kayıt edilmektedir. Rapor ile ilgilenen yetkili bu raporda kullanıcıdan deyay istemek amacıyla mesaj gönderip yanıt bekleyebilmektedir. Belirli süre güncellenmeyen raporlar otomatik olarak kapatılmaktadır. Ayrıca rapordan yasaklama sayesinde spam engellenebilir.

# Dependencies (Bağımlılık)

> [Discord Api](https://github.com/Deathknife/sourcemod-discord)

# Description (Açıklama)

**[EN]**

"Counter-Strike: Global Offensive" allows a player to report a different player on the community server. The reporting person cannot create a new report or report the same person during the period determined on the CFG. Authorities can respond to the reported person and wait for a response. Authorities or the reporter can send a message until the report is closed. If too many unnecessary reports are used, this person may be banned from using the report system. Authorities have the opportunity to view and analyze other reports of the players.

**[TR]**

"Counter-Strike: Global Offensive" topluluk sunucusunda bir oyuncunun farklı bir oyuncuyu rapor etmesini olacak sağlamaktadır. Rapor eden kişi CFG üzerinden belirlenen süre boyunca yeni rapor oluşturamaz veya aynı kişiyi raporlayamaz. Rapor edilen kişiye yetkililer yanıt verebilir ve yanıt bekleyebilir. Rapor kapatılana kadar yetkililer veya rapor eden kişi mesaj gönderebilir. Eğer çok gereksiz rapor kullanımı olursa bu kişinin rapor sistemini kullanması yasaklanabilir. Yetkililer oyuncuların diğer raporlarını da görüntüleyip analiz yapabilme olanağına sahiptir.

# Setup (Kurulum)
> database.cfg:
```
"csgotr_advanced_report"
{
  "driver"             "sqlite"
  "database"           "csgotr_advanced_report"
}
```
> Reasons File (Nedenler Dosyası): csgo/addons/sourcemod/configs/csgotr-advanced_report_reasons.txt

# Commands (Komutlar)

-  sm_createreport || sm_raporolustur

**[EN]**

It allows you to generate reports.

**[TR]**

Rapor oluşturmanızı sağlar.

-  sm_reportban || sm_raporban

**[EN]**

Prohibits the player from generating reports.

**[TR]**

Oyuncunun rapor oluşturmasını yasaklar.

-  sm_reportbansteamid || sm_raporbansteamid

**[EN]**

Applies a report generation ban to the specified STEAM ID.

**[TR]**

Belirtilen STEAM ID bilgisine rapor oluşturma yasağı uygular.

-  sm_reportunban || sm_raporunban

**[EN]**

Removes the report generation ban.

**[TR]**

Rapor oluşturma yasağını kaldırır.

-  sm_reports || sm_raporlar

**[EN]**

Opens the Reports menu.

**[TR]**

Raporlar menüsünü açar. 

-  sm_myreports || sm_raporlarim

**[EN]**

Lists your reports.

**[TR]**

Raporlarınızı listeler.

-  sm_reportquery || sm_raporsorgu

**[EN]**

Question the report.

**[TR]**

Rapor sorgular.

-  sm_reportbans || sm_raporbanlari

**[EN]**

Lists the report bans.

**[TR]**

Rapor yasaklarını listeler.

-  sm_reportbanquery || sm_raporbansorgu

**[EN]**

Question the report ban.

**[TR]**

Rapor yasağını sorgular.

-  sm_reportmenu || sm_rapormenu (ROOT)

**[EN]**

Opens the report menu.

**[TR]**

Rapor menüsünü açar.

#Settings (Ayarlar) [ cvar => csgo/cfg/CSGO_Turkiye/advanced-report.cfg ]

| cvar          | Default       | EN            | TR            |
| ------------- | ------------- | ------------- | ------------- |
| sm_ars_flags |   | Who can read reports and apply report ban. ROOT is automatically authorized. You can put a comma (,) between letters. Maximum 32 characters. If you use dash (-), any authority can use it. | Kimler raporları okuyabilir ve rapor yasağı uygulayabilir. ROOT otomatik olarak yetkilendirilir. Harflerin arasına virgül (,) koyabilirsiniz. Maksimum 32 karakter. Kısa çizgi (-) kullanırsanız, herhangi bir yetkili bunu kullanabilir. |
| sm_ars_webhooks |   | Webhook URL | Webhook Bağlantısı |
| sm_ars_wait_timer | 60 | After how many seconds after submitting a report, give the right to send a new report? If -1 is entered, it will not wait. | Rapor gönderdikten kaç saniye sonra yeni rapor gönderme hakkı verilsin? -1 girilirse beklemez. |
| sm_ars_same_player_wait_timer | 3600 | How soon can the same player report a reported player again? If -1 is on, it will not regenerate. | Aynı oyuncu rapor edilen bir oyuncuyu ne kadar sürede tekrar rapor edebilir? -1 girilirse diğer rapor kapatılana kadar oluşturamaz. |
| sm_ars_auto_close_time | 10080 | After how many minutes should the reports be closed automatically?\nIf you don't want it to be turned off, enter -1. | Raporlar kaç dakika sonra otomatik olarak kapatılmalıdır? Kapatılmasını istemiyorsanız -1 girin. |


