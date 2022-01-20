#include <sourcemod>
#include <discord>
#include <multicolors>
#include <csgoturkiye>
#include <steamworks>

#pragma semicolon 1

public Plugin myinfo = 
{
	name = "Advanced Report", 
	author = "oppa", 
	description = "Advanced Report System - Discord & Database", 
	version = "1.0", 
	url = "csgo-turkiye.com"
};

Handle h_database = INVALID_HANDLE;
ConVar cv_wait_time = null, cv_same_player_wait_time = null, cv_flags = null, cv_webhook = null, cv_auto_close_time = null;
int i_wait_time, i_same_player_wait_time, i_client_temp[ MAXPLAYERS + 1 ], i_client_temp2[ MAXPLAYERS + 1 ];
// Say Type = 0 -> No Action ; 1 -> New Report ; 2 -> Report Message ; 3 -> Report Ban Reason
char s_file[ PLATFORM_MAX_PATH ], s_flags[32], s_webhook[256], c_say_type[ MAXPLAYERS + 1 ] ;

public void OnPluginStart()
{   
    CVAR_Load();

    RegConsoleCmd("sm_createreport", CreateReport, "It allows you to generate reports.");
    RegConsoleCmd("sm_reportban", ReportBan, "Prohibits the player from generating reports.");
    RegConsoleCmd("sm_reportbansteamid", ReportBanSteamID, "Applies a report generation ban to the specified STEAM ID.");
    RegConsoleCmd("sm_reportunban", ReportUnBan, "Removes the report generation ban.");
    RegConsoleCmd("sm_reports", Reports, "Opens the Reports menu.");
    RegConsoleCmd("sm_myreports", MyReports, "Lists your reports.");
    RegConsoleCmd("sm_reportquery", ReportQuery, "Question the report.");
    RegConsoleCmd("sm_reportbans", ReportBans, "Lists the report bans.");
    RegConsoleCmd("sm_reportbanquery", ReportBanQuery, "Question the report ban.");
    RegAdminCmd("sm_reportmenu", ReportMenu, ADMFLAG_ROOT, "Opens the report menu.");

    RegConsoleCmd("sm_raporolustur", CreateReport, "Rapor oluşturmanızı sağlar.");
    RegConsoleCmd("sm_raporban", ReportBan, "Oyuncunun rapor oluşturmasını yasaklar.");
    RegConsoleCmd("sm_raporbansteamid", ReportBanSteamID, "Belirtilen STEAM ID bilgisine rapor oluşturma yasağı uygular.");
    RegConsoleCmd("sm_raporunban", ReportUnBan, "Rapor oluşturma yasağını kaldırır.");
    RegConsoleCmd("sm_raporlar", Reports, "Raporlar menüsünü açar.");
    RegConsoleCmd("sm_raporlarim", MyReports, "Raporlarınızı listeler.");
    RegConsoleCmd("sm_raporsorgu", ReportQuery, "Rapor sorgular.");
    RegConsoleCmd("sm_raporbanlari", ReportBans, "Rapor yasaklarını listeler.");
    RegConsoleCmd("sm_raporbansorgu", ReportBanQuery, "Rapor yasağını sorgular.");
    RegAdminCmd("sm_rapormenu", ReportMenu, ADMFLAG_ROOT, "Rapor menüsünü açar.");

    for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i)) OnClientPostAdminCheck(i);
}

public void OnMapStart()
{
    CVAR_Load();
    LoadTranslations("csgotr-advanced_report.phrases.txt");
    LoadTranslations("common.phrases");
    SQL_TConnect(OnSQLConnect, "csgotr_advanced_report");
    BuildPath(Path_SM, s_file, sizeof(s_file), "configs/csgotr-advanced_report_reasons.txt");
    CreateTimer(300.0, GetReportCount, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void CVAR_Load(){
    PluginSetting();
    cv_flags = CreateConVar("sm_ars_flags", "", "Who can read reports and apply report ban. ROOT is automatically authorized. You can put a comma (,) between letters. Maximum 32 characters. If you use dash (-), any authority can use it.");
    cv_webhook = CreateConVar("sm_ars_webhooks", "", "Webhook URL");
    cv_wait_time = CreateConVar("sm_ars_wait_timer", "60", "After how many seconds after submitting a report, give the right to send a new report?\nIf -1 is entered, it will not wait.");
    cv_same_player_wait_time = CreateConVar("sm_ars_same_player_wait_timer", "3600", "How soon can the same player report a reported player again? \nIf -1 is on, it will not regenerate.");
    cv_auto_close_time = CreateConVar("sm_ars_auto_close_time", "10080", "After how many minutes should the reports be closed automatically?\nIf you don't want it to be turned off, enter -1.");
    AutoExecConfig(true, "advanced_report","CSGO_Turkiye");
    i_wait_time = GetConVarInt(cv_wait_time);
    i_same_player_wait_time = GetConVarInt(cv_same_player_wait_time);
    GetConVarString(cv_flags, s_flags, sizeof(s_flags));
    GetConVarString(cv_webhook, s_webhook, sizeof(s_webhook));
    HookConVarChange(cv_flags, OnCvarChanged);
    HookConVarChange(cv_webhook, OnCvarChanged);
    HookConVarChange(cv_wait_time, OnCvarChanged);
    HookConVarChange(cv_same_player_wait_time, OnCvarChanged);
}

public void OnClientPostAdminCheck(int client){
    if(IsValidClient(client)){
        c_say_type[ client ] = '0';
        i_client_temp[ client ] = -1;
        i_client_temp2[ client ] = -1;
    }
}

public int OnCvarChanged(Handle convar, const char[] oldVal, const char[] newVal)
{
    if(convar == cv_wait_time) i_wait_time = StringToInt(newVal);
    else if(convar == cv_same_player_wait_time) i_same_player_wait_time = StringToInt(newVal);
    else if(convar == cv_flags) strcopy(s_flags, sizeof(s_flags), newVal);
    else if(convar == cv_webhook) strcopy(s_webhook, sizeof(s_webhook), newVal);
}

int OnSQLConnect(Handle owner, Handle handle, char[] error, any data)
{
    if (handle == INVALID_HANDLE)
    {
        CPrintToChatAll("%s%s %t", s_tag_color, s_tag, "Database Connect Error");
        SetFailState("%t","Database Connect Error Log");
    }else
    {
        PrintToServer("%s %t", s_tag, "Database Connect Success");
        h_database = handle;
        char s_temp[3096];
        SQL_GetDriverIdent(SQL_ReadDriver(h_database), s_temp, sizeof(s_temp));
        SQL_FastQuery(h_database, "SET NAMES UTF8");
        SQL_FastQuery(h_database, "SET CHARACTER SET utf8mb4_unicode_ci");
        // Status = 0 -> Closed ; 1 -> Open ; 2 -> Awaiting Response
        Format(s_temp, sizeof(s_temp), "CREATE TABLE IF NOT EXISTS `reports` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `steam_id` varchar(32) NOT NULL, `player_name` varchar(32) NOT NULL, `steam_id_reported` varchar(32) NOT NULL, `player_name_reported` varchar(32) NOT NULL, `status` TINYINT(2) DEFAULT 1 NOT NULL, `update_time` INTEGER NOT NULL, `creation_time` INTEGER NOT NULL)");
        SQL_TQuery(h_database, SqlCallback, s_temp);
        Format(s_temp, sizeof(s_temp), "CREATE TABLE IF NOT EXISTS `messages` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `report_id` INTEGER NOT NULL, `steam_id` varchar(32) NOT NULL, `player_name` varchar(32) NOT NULL, `message` varchar(255) NOT NULL, `creation_time` INTEGER NOT NULL)");
        SQL_TQuery(h_database, SqlCallback, s_temp);
        // Event = 0 -> Report Generated ; 1 -> Report Status Set to Open ; 2 -> Report Status Set to Awaiting Response ; 3 -> Report Status Set to Closed ; 4 -> Message Sent
        Format(s_temp, sizeof(s_temp), "CREATE TABLE IF NOT EXISTS `events` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `report_id` INTEGER NOT NULL, `steam_id` varchar(32) NOT NULL, `player_name` varchar(32) NOT NULL, `event` TINYINT(4) DEFAULT 0 NOT NULL, `creation_time` INTEGER NOT NULL)");
        SQL_TQuery(h_database, SqlCallback, s_temp);
        Format(s_temp, sizeof(s_temp), "CREATE TABLE IF NOT EXISTS `bans` (`id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, `steam_id` varchar(32) NOT NULL, `player_name` varchar(32) NOT NULL, `steam_id_admin` varchar(32) NOT NULL, `player_name_admin` varchar(32) NOT NULL, `reason` varchar(255) NOT NULL, `creation_time` INTEGER NOT NULL)");
        SQL_TQuery(h_database, SqlCallback, s_temp);
        if(cv_auto_close_time.IntValue > 0){
            int i_time = GetTime()-(cv_auto_close_time.IntValue*60);
            Format(s_temp, sizeof(s_temp),  "SELECT `id` FROM `reports` WHERE `update_time` < %d and `status` != %d;", i_time, 0);
            DBResultSet DBRS_Query = SQL_Query(h_database, s_temp);
            if (DBRS_Query ==  INVALID_HANDLE || DBRS_Query ==  null){
                char s_error[255];
                SQL_GetError(h_database, s_error, sizeof(s_error));
                DatabaseQueryError(s_error ,s_temp);
                PrintToServer("%s %t", s_tag, "Closed Auto Report Error");
            }else if(SQL_HasResultSet(DBRS_Query))
            {
                int i_count_success = 0, i_count_error = 0;
                while (SQL_FetchRow(DBRS_Query)){
                    int i_report_id = SQL_FetchInt(DBRS_Query, 0);
                    Format(s_temp, sizeof(s_temp),  "UPDATE `reports` SET `status`= %d, `update_time` = %d WHERE `id` = %d;", 0, GetTime(), i_report_id);
                    if(SQLQueryNoData(s_temp)){
                        i_count_success++;
                        Format(s_temp, sizeof(s_temp),  "%t", "Timed Out");
                        Format(s_temp, sizeof(s_temp), "INSERT INTO `events` (`report_id`,`steam_id`,`player_name`,`event`,`creation_time`) VALUES (%d, '%s', '%s', %d, %d);", i_report_id, 0, s_temp, 3, GetTime());
                        SQLQueryNoData(s_temp);
                    }else i_count_error++;              
                }
                if((i_count_success > 0 || i_count_error > 0)){
                    FormatTime(s_temp, sizeof(s_temp), "%d.%m.20%y ✪ %X", i_time);
                    PrintToServer("%s %t", s_tag, "Closed Auto Report Info", i_count_success+i_count_error, i_count_success, i_count_error, s_temp);
                    if(!StrEqual(s_webhook, "") ){
                        char s_temp_2[32];
                        DiscordWebHook hook = new DiscordWebHook(s_webhook);
                        hook.SlackMode = true;
                        MessageEmbed Embed = new MessageEmbed();
                        Format(s_temp, sizeof(s_temp), "%t", "Auto Close Report Title", s_temp);
                        Embed.SetTitle(s_temp);
                        Format(s_temp, sizeof(s_temp), "%s ★ %t", s_tag, "Advanced Report");
                        Embed.SetAuthor(s_temp);
                        Embed.SetAuthorLink(s_plugin_url);
                        Embed.SetAuthorIcon(s_plugin_image);
                        Embed.SetColor("#FDA22E");
                        Embed.SetThumb("https://csgo-turkiye.com/assets/plugin_images/advanced-report/autoclosereport.png");
                        Format(s_temp, sizeof(s_temp), "%t", "Total Closed Title");
                        Format(s_temp_2, sizeof(s_temp_2), "%t", "Total Closed Value", i_count_success+i_count_error);
                        Embed.AddField(s_temp, s_temp_2, true);
                        Format(s_temp, sizeof(s_temp), "%t", "Success Closed Title");
                        Format(s_temp_2, sizeof(s_temp_2), "%t", "Success Closed Value", i_count_success);
                        Embed.AddField(s_temp, s_temp_2, true);
                        Format(s_temp, sizeof(s_temp), "%t", "Fail Closed Title");
                        Format(s_temp_2, sizeof(s_temp_2), "%t", "Fail Closed Value", i_count_error);
                        Embed.AddField(s_temp, s_temp_2, true);
                        FormatTime(s_temp, sizeof(s_temp), "%d.%m.%Y %X", GetTime());
                        Format(s_temp, sizeof(s_temp), "%t", "Auto Close Footer", s_temp);
                        Embed.SetFooter(s_temp);
                        Embed.SetFooterIcon("https://csgo-turkiye.com/assets/plugin_images/advanced-report/console.png");  
                        hook.Embed(Embed);
                        hook.Send();
                        delete hook;
                    }
                }else PrintToServer("%s %t", s_tag, "Closed Auto Report Not Found");
            }else PrintToServer("%s %t", s_tag, "Closed Auto Report Not Found");
            delete DBRS_Query;
        }
    }
}

int SqlCallback(Handle owner, Handle handle, char[] error, any data)
{
    if (handle == INVALID_HANDLE)
    {
        DatabaseQueryError(error , "SqlCallback");
        return;
    }
}

public Action CreateReport(int client,int args)
{
    if(client!=0){
        if(IsValidClient(client)){
            char s_steam_id[32], s_temp[512];
            if(!GetClientAuthId(client, AuthId_Steam2, s_steam_id, sizeof(s_steam_id)))Format(s_steam_id, sizeof(s_steam_id), "%t", "Unknown Steam ID"); 
            DiscordSQL_EscapeString(s_steam_id, sizeof(s_steam_id));
            Format(s_temp, sizeof(s_temp), "SELECT * FROM `bans` WHERE `steam_id` >= '%s'", s_steam_id);
            if(!IsThereRecord(s_temp)){
                Format(s_temp, sizeof(s_temp), "SELECT `creation_time` FROM `reports` WHERE `steam_id` = '%s' and `creation_time` >= %d ORDER BY `id` DESC LIMIT 1", s_steam_id, GetTime() - i_wait_time);
                int i_time = SQLFirstDataInt(s_temp);
                if(i_wait_time < 1 || i_time == 0 ) Rules_Menu().Display(client, MENU_TIME_FOREVER);
                else{
                    i_time += i_wait_time;
                    FormatTime(s_temp, sizeof(s_temp), "%d.%m.20%y ✪ %X", i_time);
                    CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Generation Waiting Time", s_temp);
                }
            }else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Reporting Prohibited");
        }
    }else PrintToServer("%s %t", s_tag, "Console Message");
    return Plugin_Handled;
}

public Action MyReports(int client,int args)
{
    if(client!=0){
        if(IsValidClient(client)){
            char s_steam_id[32];
            if(!GetClientAuthId(client, AuthId_Steam2, s_steam_id, sizeof(s_steam_id)))Format(s_steam_id, sizeof(s_steam_id), "%t", "Unknown Steam ID"); 
            ClientReports_Menu(client, s_steam_id).Display(client, MENU_TIME_FOREVER);
        }
    }else PrintToServer("%s %t", s_tag, "Console Message");
    return Plugin_Handled;
}

public Action ReportBan(int client,int args)
{
    if(ClientControl(client)){
        if (args < 1)ReplyToCommand(client, "%s %t", s_tag, "Report Ban Usage");
        else{
            char s_temp[255];
            GetCmdArg(1, s_temp, sizeof(s_temp));
            int i_target = FindTarget(client, s_temp, true, true);
            if (i_target == -1 || !IsValidClient(i_target)) ReplyToCommand(client, "%s %t", s_tag, "Target Error");
            else{
                char s_reason[255], s_username_target[32], s_steam_id_target[32];
                if(args >= 2){
                    for (int i = 2; i <= args; i++){
                        GetCmdArg(i, s_temp, sizeof(s_temp));
                        Format(s_reason, sizeof(s_reason), "%s %s", s_reason, s_temp);
                    }  
                }
                if(!GetClientAuthId(i_target, AuthId_Steam2, s_steam_id_target, sizeof(s_steam_id_target)))Format(s_steam_id_target, sizeof(s_steam_id_target), "%t", "Unknown Steam ID"); 
                if(!GetClientName(i_target, s_username_target, sizeof(s_username_target)))Format(s_username_target, sizeof(s_username_target), "%t", "Unnamed");     
                AddBan(client, s_steam_id_target, s_username_target, s_reason);
            }
        }
    }
    return Plugin_Handled;
}

public Action ReportBanSteamID(int client,int args)
{
    if(ClientControl(client)){
        if (args < 1)ReplyToCommand(client, "%s %t", s_tag, "Report Ban Steam ID Usage");
        else{
            char s_steam_id[32];
            GetCmdArg(1, s_steam_id, sizeof(s_steam_id));
            if(StrContains(s_steam_id, "STEAM_")!=0 || strlen(s_steam_id) < 11)ReplyToCommand(client, "%s %t", s_tag, "Steam ID Error");
            else{
                char s_reason[255], s_temp[255], s_username[32];
                if(args >= 2){
                    for (int i = 2; i <= args; i++){
                        GetCmdArg(i, s_temp, sizeof(s_temp));
                        Format(s_reason, sizeof(s_reason), "%s %s", s_reason, s_temp);
                    }  
                }
                Format(s_username, sizeof(s_username), "%t", "Unnamed");
                AddBan(client, s_steam_id, s_username, s_reason);
            }
        }
    }
    return Plugin_Handled;
}

public Action ReportBans(int client,int args)
{
    if(client!=0){
        if(ClientControl(client))ReportBans_Menu(client).Display(client, MENU_TIME_FOREVER);
    }else PrintToServer("%s %t", s_tag, "Console Message");
    return Plugin_Handled;
}

public Action ReportUnBan(int client,int args)
{
    if(ClientControl(client)){
        if (args < 1)ReplyToCommand(client, "%s %t", s_tag, "Report UnBan Usage");
        else{
            char s_temp[32];
            GetCmdArgString(s_temp,sizeof(s_temp));
            UnBan(client, s_temp);
        }
    }
    return Plugin_Handled;
}

public Action Reports(int client,int args)
{
    if(client!=0){
        if(ClientControl(client)){
            if(args < 1)Reports_Menu("").Display(client, MENU_TIME_FOREVER);
            else{
                char s_temp[32];
                GetCmdArgString(s_temp,sizeof(s_temp));
                if(StrContains(s_temp, "STEAM_")==0 && strlen(s_temp) >= 11) ClientReports_Menu(client, s_temp).Display(client, MENU_TIME_FOREVER);
                else{
                    int i_target = FindTarget(client, s_temp, true, true);
                    if (i_target > 0 && IsValidClient(i_target)){
                        if(!GetClientAuthId(i_target, AuthId_Steam2, s_temp, sizeof(s_temp)))Format(s_temp, sizeof(s_temp), "%t", "Unknown Steam ID");
                        ClientReports_Menu(client, s_temp).Display(client, MENU_TIME_FOREVER);
                    }ReplyToCommand(client, "%s %t", s_tag, "Report STEAM ID Error");
                }
            }
        }
    }else PrintToServer("%s %t", s_tag, "Console Message");
    return Plugin_Handled;
}

public Action ReportQuery(int client,int args)
{
    if(client!=0){
        if(IsValidClient(client)){
            if(args < 1)ReplyToCommand(client, "%s %t", s_tag, "Report Query ");
            else{
                char s_temp[32];
                GetCmdArgString(s_temp,sizeof(s_temp));
                ReplaceString(s_temp, sizeof(s_temp), "$", "");
                ReportDetail_Menu(client, StringToInt(s_temp)).Display(client, MENU_TIME_FOREVER);
            }
        }
    }else PrintToServer("%s %t", s_tag, "Console Message");
    return Plugin_Handled;
}

public Action ReportBanQuery(int client,int args)
{
    if(client ==0 || IsValidClient(client)){
        char s_steam_id[32];
        if(args > 0 && ClientControl(client)){
            GetCmdArgString(s_steam_id,sizeof(s_steam_id));
            if(StrContains(s_steam_id, "STEAM_")!=0 ){
                if(StrContains(s_steam_id, "$")==0 && strlen(s_steam_id) >= 2){
                    char s_temp[255];
                    ReplaceString(s_steam_id, sizeof(s_steam_id), "$", "");
                    Format(s_temp, sizeof(s_temp), "SELECT `steam_id` FROM `bans` WHERE `id`=%d", StringToInt(s_steam_id));
                    DBResultSet DBRS_Query = SQL_Query(h_database, s_temp);
                    if (DBRS_Query == INVALID_HANDLE || DBRS_Query == null)
                    {
                        char s_error[255];
                        SQL_GetError(h_database, s_error, sizeof(s_error));
                        DatabaseQueryError(s_error, s_temp);
                    }else if (SQL_GetRowCount(DBRS_Query) || SQL_FetchRow(DBRS_Query)) SQL_FetchString(DBRS_Query, 0, s_steam_id, sizeof(s_steam_id));
                    delete DBRS_Query;
                }else{
                    int i_target = FindTarget(client, s_steam_id, true, true);
                    if (i_target > 0 && IsValidClient(i_target))if(!GetClientAuthId(i_target, AuthId_Steam2, s_steam_id, sizeof(s_steam_id)))Format(s_steam_id, sizeof(s_steam_id), "%t", "Unknown Steam ID");          
                }
            }
        }else{
            if(client != 0){
                if(!GetClientAuthId(client, AuthId_Steam2, s_steam_id, sizeof(s_steam_id)))Format(s_steam_id, sizeof(s_steam_id), "%t", "Unknown Steam ID");
            }else PrintToServer("%s %t", s_tag, "Report Ban Query Usage");   
        }
        if(StrContains(s_steam_id, "STEAM_")==0 && strlen(s_steam_id) >= 11) ReportBanDetail(client, s_steam_id);
        else ReplyToCommand(client, "%s %t", s_tag, "Report Ban Not Found");
    }
    return Plugin_Handled;
}

public Action ReportMenu(int client,int args)
{
    if(client!=0){
        if(IsValidClient(client)){
            char s_temp[256];
            Menu menu = new Menu(Report_MenuCallback);
            menu.SetTitle("%t", "Advanced Report");
            Format(s_temp, sizeof(s_temp), "%t", "All Delete Report");
            menu.AddItem("All Delete Report 2", s_temp);
            Format(s_temp, sizeof(s_temp), "%t", "All Delete Bans");
            menu.AddItem("All Delete Bans 2", s_temp);
            Format(s_temp, sizeof(s_temp), "%t", "All Delete");
            menu.AddItem("All Delete 2", s_temp);
            menu.Display(client, MENU_TIME_FOREVER);
        }
    }else PrintToServer("%s %t", s_tag, "Console Message");
    return Plugin_Handled;
}

int Report_MenuCallback(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char s_option[32], s_temp[128];
        menu.GetItem(param2, s_option, sizeof(s_option));
        if(StrEqual(s_option, "All Delete Report 2") || StrEqual(s_option, "All Delete 2"))
        {
            Format(s_temp, sizeof(s_temp), "DELETE FROM `reports`;");
            SQLQueryNoData(s_temp);
            Format(s_temp, sizeof(s_temp), "DELETE FROM `messages`;");
            SQLQueryNoData(s_temp);
            Format(s_temp, sizeof(s_temp), "DELETE FROM `events`;");
            SQLQueryNoData(s_temp);
        }

        if(StrEqual(s_option, "All Delete Bans 2") || StrEqual(s_option, "All Delete 2"))
        {
            Format(s_temp, sizeof(s_temp), "DELETE FROM `bans`;");
            SQLQueryNoData(s_temp);
        }
        menu.Display(client, MENU_TIME_FOREVER);
        CPrintToChat(client, "%s%s %t %t", s_tag_color, s_tag, "Report Menu Successful", s_option);
        if(!StrEqual(s_webhook, "") ){
            char s_steam_id[32], s_username[32];
            DiscordWebHook hook = new DiscordWebHook(s_webhook);
            hook.SlackMode = true;
            MessageEmbed Embed = new MessageEmbed();
            Format(s_temp, sizeof(s_temp), "%s ★ %t", s_tag, "Advanced Report");
            Embed.SetAuthor(s_temp);
            Embed.SetAuthorLink(s_plugin_url);
            Embed.SetAuthorIcon(s_plugin_image);
            Embed.SetColor("#F0BC5E");
            Embed.SetThumb("https://csgo-turkiye.com/assets/plugin_images/advanced-report/reportmenu.png");
            Format(s_temp, sizeof(s_temp), "%t", s_option);
            Embed.SetTitle(s_temp);
            FormatTime(s_temp, sizeof(s_temp), "%d.%m.%Y %X", GetTime());
            if(!GetClientAuthId(client, AuthId_Steam2, s_steam_id, sizeof(s_steam_id)))Format(s_steam_id, sizeof(s_steam_id), "%t", "Unknown Steam ID"); 
            if(!GetClientName(client, s_username, sizeof(s_username)))Format(s_username, sizeof(s_username), "%t", "Unnamed");
            Format(s_temp, sizeof(s_temp), "%t", "Report Menu Footer",s_username, s_steam_id, s_temp);
            Embed.SetFooter(s_temp);
            Embed.SetFooterIcon("https://csgo-turkiye.com/assets/plugin_images/advanced-report/user.png");  
            hook.Embed(Embed);
            hook.Send();
            delete hook;
        }
    }
    else if (action == MenuAction_End) delete menu;
}


Menu Reports_Menu(char condition[64])
{
    char s_temp[1024], s_temp_2[128];
    Menu menu = new Menu(Reports_MenuCallback);
    menu.SetTitle("%t", "Reports Menu Title");

    if(StrEqual(condition, ""))Format(s_temp, sizeof(s_temp), "SELECT COUNT(*) FROM `reports`");
    else Format(s_temp, sizeof(s_temp), "SELECT COUNT(*) FROM `reports` WHERE %s", condition);
    Format(s_temp_2, sizeof(s_temp_2), "%t", "All Reports", SQLFirstDataInt(s_temp));
    if(StrEqual(condition, ""))Format(s_temp, sizeof(s_temp), "SELECT `id`,`status`,`creation_time` FROM `reports` ORDER BY `id` DESC LIMIT 999");
    else Format(s_temp, sizeof(s_temp), "SELECT `id`,`status`,`creation_time` FROM `reports` WHERE %s ORDER BY `id` DESC LIMIT 999", condition);
    menu.AddItem(s_temp, s_temp_2);

    if(StrEqual(condition, ""))Format(s_temp, sizeof(s_temp), "SELECT COUNT(*) FROM `reports` WHERE `status` = 1");
    else Format(s_temp, sizeof(s_temp), "SELECT COUNT(*) FROM `reports` WHERE WHERE `status` = 1 and %s", condition);
    Format(s_temp_2, sizeof(s_temp_2), "%t", "Open Reports", SQLFirstDataInt(s_temp));
    if(StrEqual(condition, ""))Format(s_temp, sizeof(s_temp), "SELECT `id`,`status`,`creation_time` FROM `reports` WHERE `status` = 1 ORDER BY `id` DESC LIMIT 999");
    else Format(s_temp, sizeof(s_temp), "SELECT `id`,`status`,`creation_time` FROM `reports` WHERE `status` = 1 and %s ORDER BY `id` DESC LIMIT 999", condition);
    menu.AddItem(s_temp, s_temp_2);

    if(StrEqual(condition, ""))Format(s_temp, sizeof(s_temp), "SELECT COUNT(*) FROM `reports` WHERE `status` = 2");
    else Format(s_temp, sizeof(s_temp), "SELECT COUNT(*) FROM `reports` WHERE WHERE `status` = 2 and %s", condition);
    Format(s_temp_2, sizeof(s_temp_2), "%t", "Awaiting Response Reports", SQLFirstDataInt(s_temp));
    if(StrEqual(condition, ""))Format(s_temp, sizeof(s_temp), "SELECT `id`,`status`,`creation_time` FROM `reports` WHERE `status` = 2 ORDER BY `id` DESC LIMIT 999");
    else Format(s_temp, sizeof(s_temp), "SELECT `id`,`status`,`creation_time` FROM `reports` WHERE `status` = 2 and %s ORDER BY `id` DESC LIMIT 999", condition);
    menu.AddItem(s_temp, s_temp_2);

    if(StrEqual(condition, ""))Format(s_temp, sizeof(s_temp), "SELECT COUNT(*) FROM `reports` WHERE `status` = 0");
    else Format(s_temp, sizeof(s_temp), "SELECT COUNT(*) FROM `reports` WHERE WHERE `status` = 0 and %s", condition);
    Format(s_temp_2, sizeof(s_temp_2), "%t", "Closed Reports", SQLFirstDataInt(s_temp));
    if(StrEqual(condition, ""))Format(s_temp, sizeof(s_temp), "SELECT `id`,`status`,`creation_time` FROM `reports` WHERE `status` = 0 ORDER BY `id` DESC LIMIT 999");
    else Format(s_temp, sizeof(s_temp), "SELECT `id`,`status`,`creation_time` FROM `reports` WHERE `status` = 0 and %s ORDER BY `id` DESC LIMIT 999", condition);
    menu.AddItem(s_temp, s_temp_2);

    return menu;
}

int Reports_MenuCallback(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char s_temp[1024];
        menu.GetItem(param2, s_temp, sizeof(s_temp));
        ReportList_Menu(client, s_temp).Display(client, MENU_TIME_FOREVER);
    }
    else if (action == MenuAction_End) delete menu;
}

Menu ReportList_Menu(int client, char temp[1024])
{
    Menu menu = new Menu(ReportList_MenuCallback);
    menu.SetTitle("%t", "Reports Menu Title");
    DBResultSet DBRS_Query = SQL_Query(h_database, temp);
    bool b_data = false;
    if (DBRS_Query ==  INVALID_HANDLE || DBRS_Query ==  null){
        char s_error[255];
        SQL_GetError(h_database, s_error, sizeof(s_error));
        DatabaseQueryError(s_error ,temp);
        CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report List Error");
    }else if(SQL_HasResultSet(DBRS_Query))
	{
        while (SQL_FetchRow(DBRS_Query)){
            b_data = true;
            char s_temp[32];
            Format(s_temp, sizeof(s_temp), "Status %d", SQL_FetchInt(DBRS_Query, 1));
            Format(s_temp, sizeof(s_temp), "%t", s_temp);
            FormatTime(temp, sizeof(temp), "%d.%m.20%y ✪ %X", SQL_FetchInt(DBRS_Query, 2));
            Format(temp, sizeof(temp), "%t", "Report List Item", SQL_FetchInt(DBRS_Query, 0), s_temp,temp );
            Format(s_temp, sizeof(s_temp), "%d", SQL_FetchInt(DBRS_Query, 0));
            menu.AddItem(s_temp, temp);
		}
	}
    delete DBRS_Query;
    if(!b_data){
        Format(temp, sizeof(temp), "%t", "No Data");
        menu.AddItem("null", temp, ITEMDRAW_DISABLED);
    }
    return menu;
}

int ReportList_MenuCallback(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char s_temp[32];
        menu.GetItem(param2, s_temp, sizeof(s_temp));
        ReportDetail_Menu(client, StringToInt(s_temp)).Display(client, MENU_TIME_FOREVER);
    }
    else if (action == MenuAction_End) delete menu;
}

Menu ReportBans_Menu(int client)
{
    Menu menu = new Menu(ReportBans_MenuCallback);
    menu.SetTitle("%t", "Report Bans Title");
    DBResultSet DBRS_Query = SQL_Query(h_database, "SELECT `id`,`steam_id`, `player_name`, `creation_time` FROM `bans`");
    bool b_data = false;
    if (DBRS_Query ==  INVALID_HANDLE || DBRS_Query ==  null){
        char s_error[255];
        SQL_GetError(h_database, s_error, sizeof(s_error));
        DatabaseQueryError(s_error ,"SELECT `id`,`steam_id`, `player_name`, `creation_time` FROM `bans`");
        CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Ban List Error");
    }else if(SQL_HasResultSet(DBRS_Query))
	{
        while (SQL_FetchRow(DBRS_Query)){
            b_data = true;
            char s_steam_id[32], s_username[32], s_temp[256];
            SQL_FetchString(DBRS_Query, 1, s_steam_id,sizeof(s_steam_id));
            SQL_FetchString(DBRS_Query, 2, s_username,sizeof(s_username));
            FormatTime(s_temp, sizeof(s_temp), "%d.%m.20%y ✪ %X", SQL_FetchInt(DBRS_Query, 3));
            Format(s_temp, sizeof(s_temp), "%t", "Report Bans Item", SQL_FetchInt(DBRS_Query, 0), s_steam_id, s_username, s_temp );
            menu.AddItem(s_steam_id, s_temp);
		}
	}
    delete DBRS_Query;
    if(!b_data){
        char s_temp[128];
        Format(s_temp, sizeof(s_temp), "%t", "No Data");
        menu.AddItem("null", s_temp, ITEMDRAW_DISABLED);
    }
    return menu;
}

int ReportBans_MenuCallback(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char s_temp[32];
        menu.GetItem(param2, s_temp, sizeof(s_temp));
        ReportBanDetail(client, s_temp);
    }
    else if (action == MenuAction_End) delete menu;
}

void ReportBanDetail(int client, char steam_id[32]){
    char s_temp[255];
    Format(s_temp, sizeof(s_temp), "SELECT * FROM `bans` WHERE `steam_id` = '%s'", steam_id);
    DBResultSet DBRS_Query = SQL_Query(h_database, s_temp);
    if (DBRS_Query == INVALID_HANDLE || DBRS_Query == null)
    {
        char s_error[255];
        SQL_GetError(h_database, s_error, sizeof(s_error));
        DatabaseQueryError(s_error, s_temp);
        if(client == 0) PrintToServer("%s %t", s_tag, "Detail Ban Error Console");
        else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Detail Ban Error");
    }else if (SQL_GetRowCount(DBRS_Query) || SQL_FetchRow(DBRS_Query)){
        char s_username[32], s_steam_id_admin[32], s_username_admin[32], s_reason[255], s_time[32];
        SQL_FetchString(DBRS_Query, 2, s_username,sizeof(s_username));
        SQL_FetchString(DBRS_Query, 3, s_steam_id_admin,sizeof(s_steam_id_admin));
        SQL_FetchString(DBRS_Query, 4, s_username_admin,sizeof(s_username_admin));
        SQL_FetchString(DBRS_Query, 5, s_reason,sizeof(s_reason));
        FormatTime(s_time, sizeof(s_time), "%d.%m.20%y ✪ %X", SQL_FetchInt(DBRS_Query, 6));
        if(client == 0) PrintToServer("%s %t", s_tag, "Ban Detail Console" , SQL_FetchInt(DBRS_Query, 0), steam_id, s_username, s_steam_id_admin, s_username_admin, s_reason, s_time);
        else{
            char s_client_steam_id[32];
            if(!GetClientAuthId(client, AuthId_Steam2, s_client_steam_id, sizeof(s_client_steam_id)))Format(s_client_steam_id, sizeof(s_client_steam_id), "%t", "Unknown Steam ID");
            Menu menu = new Menu(ReportBanDetail_MenuCallback);
            menu.SetTitle("%t", "Ban Detail Menu Title", SQL_FetchInt(DBRS_Query, 0));
            Format(s_temp, sizeof(s_temp), "%t", "Banned Player", s_username, steam_id);
            menu.AddItem(steam_id, s_temp,( StrEqual(s_client_steam_id, steam_id) || CheckAdminFlag(client, s_flags) ) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
            Format(s_temp, sizeof(s_temp), "%t", "Banned by Admin", s_username_admin, s_steam_id_admin);
            menu.AddItem(s_steam_id_admin, s_temp,( !StrEqual(s_username_admin,"0") && StrEqual(s_client_steam_id, s_steam_id_admin) || CheckAdminFlag(client, s_flags) )? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
            Format(s_temp, sizeof(s_temp), "%t", "Ban Time", s_time);
            menu.AddItem("null", s_temp, ITEMDRAW_DISABLED);
            Format(s_temp, sizeof(s_temp), "%t", "Ban Reason", s_reason);
            menu.AddItem("null", s_temp, ITEMDRAW_DISABLED);
            Format(s_temp, sizeof(s_temp), "%t", "Ban Detail UnBan", s_reason);
            Format(steam_id, sizeof(steam_id), "$%d", SQL_FetchInt(DBRS_Query, 0));
            menu.AddItem(steam_id, s_temp, CheckAdminFlag(client, s_flags) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
            menu.Display(client, MENU_TIME_FOREVER);
        }
    }else{
        if(client == 0) PrintToServer("%s %t", s_tag, "Detail Ban Not Found Console", steam_id);
        else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Detail Ban Not Found", steam_id);
    }
    delete DBRS_Query;
}

int ReportBanDetail_MenuCallback(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char s_temp[32];
        menu.GetItem(param2, s_temp, sizeof(s_temp));
        if (StrContains(s_temp, "STEAM_")==0 && strlen(s_temp) >= 11) ClientReports_Menu(client, s_temp).Display(client, MENU_TIME_FOREVER);
        else if (StrContains(s_temp, "$")==0 && strlen(s_temp) >= 2) UnBan(client, s_temp);
    }
    else if (action == MenuAction_End) delete menu;
}

Menu ReportDetail_Menu(int client, int id)
{
    i_client_temp[client] = id;
    char s_temp[1024];
    Menu menu = new Menu(ReportDetail_MenuCallback);
    menu.SetTitle("%t", "Report Detail Menu Title", id);
    Format(s_temp, sizeof(s_temp), "SELECT * FROM `reports` WHERE `id` = %d", id);
    DBResultSet DBRS_Query = SQL_Query(h_database, s_temp);
    bool b_data = false;
    if (DBRS_Query == INVALID_HANDLE || DBRS_Query == null)
    {
        char s_error[255];
        SQL_GetError(h_database, s_error, sizeof(s_error));
        DatabaseQueryError(s_error, s_temp);
        CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Detail Error");
    }else if (SQL_GetRowCount(DBRS_Query) || SQL_FetchRow(DBRS_Query)){
        b_data = true;
        char s_steam_id[32], s_client_steam_id[32];
        if(!GetClientAuthId(client, AuthId_Steam2, s_client_steam_id, sizeof(s_client_steam_id)))Format(s_client_steam_id, sizeof(s_client_steam_id), "%t", "Unknown Steam ID");
        SQL_FetchString(DBRS_Query, 1, s_steam_id,sizeof(s_steam_id));
        if(StrEqual(s_client_steam_id, s_steam_id) || CheckAdminFlag(client, s_flags)){
            char s_username[32], s_steam_id_reported[32], s_username_reported[32];
            SQL_FetchString(DBRS_Query, 2, s_username,sizeof(s_username));
            SQL_FetchString(DBRS_Query, 3, s_steam_id_reported,sizeof(s_steam_id_reported));
            SQL_FetchString(DBRS_Query, 4, s_username_reported,sizeof(s_username_reported));
            Format(s_temp, sizeof(s_temp), "%t", "Report Creator", s_username, s_steam_id);
            menu.AddItem(s_steam_id, s_temp,( StrEqual(s_client_steam_id, s_steam_id) || CheckAdminFlag(client, s_flags) ) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
            Format(s_temp, sizeof(s_temp), "%t", "Reported Player", s_username_reported, s_steam_id_reported);
            menu.AddItem(s_steam_id_reported, s_temp,( StrEqual(s_client_steam_id, s_steam_id_reported) || CheckAdminFlag(client, s_flags) )? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
            FormatTime(s_temp, sizeof(s_temp), "%d.%m.20%y ✪ %X", SQL_FetchInt(DBRS_Query, 7));
            Format(s_temp, sizeof(s_temp), "%t", "Creation Time", s_temp);
            menu.AddItem("null", s_temp, ITEMDRAW_DISABLED);
            FormatTime(s_temp, sizeof(s_temp), "%d.%m.20%y ✪ %X", SQL_FetchInt(DBRS_Query, 6));
            Format(s_temp, sizeof(s_temp), "%t", "Update Time", s_temp);
            menu.AddItem("null", s_temp, ITEMDRAW_DISABLED);
            int i_status = SQL_FetchInt(DBRS_Query, 5);
            Format(s_temp, sizeof(s_temp), "Status %d", i_status);
            Format(s_temp, sizeof(s_temp), "%t", s_temp);
            Format(s_temp, sizeof(s_temp), "%t: %s", "Report Status", s_temp);
            menu.AddItem("null", s_temp, ITEMDRAW_DISABLED);
            Format(s_temp, sizeof(s_temp), "SELECT `message` FROM `messages` WHERE `report_id` = %d ORDER BY `id` LIMIT 1", id);
            DBRS_Query = SQL_Query(h_database, s_temp);
            bool b_data_2 = false;
            if (DBRS_Query == INVALID_HANDLE || DBRS_Query == null)
            {
                char s_error[255];
                SQL_GetError(h_database, s_error, sizeof(s_error));
                DatabaseQueryError(s_error, s_temp);
            }else if (SQL_GetRowCount(DBRS_Query) || SQL_FetchRow(DBRS_Query)){
                b_data_2 = true;
                SQL_FetchString(DBRS_Query, 0, s_temp,sizeof(s_temp));
            }
            if(!b_data_2)Format(s_temp, sizeof(s_temp), "%t", "No Data");
            Format(s_temp, sizeof(s_temp), "%t", "Report Detail Reason", s_temp);
            menu.AddItem("null", s_temp, ITEMDRAW_DISABLED);
            Format(s_temp, sizeof(s_temp), "%t", "Messages", s_temp);
            menu.AddItem("messages", s_temp);
            Format(s_temp, sizeof(s_temp), "%t", "Send Message", s_temp);
            menu.AddItem("sendmessage", s_temp, i_status==0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
            Format(s_temp, sizeof(s_temp), "%t", "Transaction Records", s_temp);
            menu.AddItem("transactionrecords", s_temp);
            Format(s_temp, sizeof(s_temp), "%t", "Report Status Change", s_temp);
            menu.AddItem("reportstatuschange", s_temp, CheckAdminFlag(client, s_flags) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
            Format(s_temp, sizeof(s_temp), "SELECT * FROM `bans` WHERE `steam_id` = '%s'", s_steam_id);
            if(IsThereRecord(s_temp)){
                Format(s_temp, sizeof(s_temp), "%t", "Report Detail UnBan");
                menu.AddItem("reportunban", s_temp, CheckAdminFlag(client, s_flags) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
            }else{
                Format(s_temp, sizeof(s_temp), "%t", "Report Detail Ban");
                menu.AddItem("reportban", s_temp, CheckAdminFlag(client, s_flags) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
            }         
            Format(s_temp, sizeof(s_temp), "%t", "Report Delete");
            menu.AddItem("reportdelete", s_temp, CheckAdminFlag(client, "") ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
        }else{
            SQL_FetchString(DBRS_Query, 1, s_steam_id,sizeof(s_steam_id));
            Format(s_temp, sizeof(s_temp), "%t", "The Report Is Not Yours");
            menu.AddItem("null", s_temp, ITEMDRAW_DISABLED);
        }  
    }
    delete DBRS_Query;
    if(!b_data){
        Format(s_temp, sizeof(s_temp), "%t", "No Data");
        menu.AddItem("null", s_temp, ITEMDRAW_DISABLED);
    }
    return menu;
}

int ReportDetail_MenuCallback(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char s_temp[32];
        menu.GetItem(param2, s_temp, sizeof(s_temp));
        if(StrEqual(s_temp, "messages")) Messages_Menu(client).Display(client, MENU_TIME_FOREVER);
        else if(StrEqual(s_temp, "sendmessage")){
            c_say_type[client] = '2';
            i_client_temp2[client] = GetTime()+60;
            CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Message Say");
        }else if(StrEqual(s_temp, "transactionrecords")) TransactionRecords_Menu(client).Display(client, MENU_TIME_FOREVER);
        else if(StrEqual(s_temp, "reportstatuschange")) ReportStatusChange_Menu(client).Display(client, MENU_TIME_FOREVER);
        else if(StrEqual(s_temp, "reportban")){
            c_say_type[client] = '3';
            i_client_temp2[client] = GetTime()+60;
            CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Ban Say");
        }else if(StrEqual(s_temp, "reportunban")){
            char s_temp_2[255];
            Format(s_temp_2, sizeof(s_temp_2), "SELECT `steam_id` FROM `reports` WHERE `id` = %d",  i_client_temp[client]);
            DBResultSet DBRS_Query = SQL_Query(h_database, s_temp_2);
            if (DBRS_Query ==  INVALID_HANDLE || DBRS_Query ==  null){
            char s_error[255];
            SQL_GetError(h_database, s_error, sizeof(s_error));
            DatabaseQueryError(s_error, s_temp);
            CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Detail UnBan Error");
            }else if (SQL_GetRowCount(DBRS_Query) || SQL_FetchRow(DBRS_Query)){
                SQL_FetchString(DBRS_Query, 0, s_temp, sizeof(s_temp));
                UnBan(client, s_temp);
            }
            delete DBRS_Query;
            ReportDetail_Menu(client, i_client_temp[client]).DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
        }else if(StrEqual(s_temp, "reportdelete")){
            ReportDelete(client, i_client_temp[client]);
        }else if (StrContains(s_temp, "STEAM_")==0 && strlen(s_temp) >= 11) ClientReports_Menu(client, s_temp).Display(client, MENU_TIME_FOREVER);
    }
    else if (action == MenuAction_End) delete menu;
}

Menu ClientReports_Menu(int client, char steam_id[32])
{
    DiscordSQL_EscapeString(steam_id, sizeof(steam_id));
    char s_steam_id_client[32], s_temp[512], s_temp_2[64];
    int i_report_count;
    if(!GetClientAuthId(client, AuthId_Steam2, s_steam_id_client, sizeof(s_steam_id_client)))Format(s_steam_id_client, sizeof(s_steam_id_client), "%t", "Unknown Steam ID"); 
    Menu menu = new Menu(ClientReports_MenuCallback);
    menu.SetTitle("%t", "Client Reports Menu Title", steam_id);
    Format(s_temp, sizeof(s_temp), "SELECT COUNT(*) FROM `reports` WHERE `steam_id`='%s'", steam_id);
    i_report_count = SQLFirstDataInt(s_temp);
    Format(s_temp, sizeof(s_temp), "%t", "Submitted Reports", i_report_count);
    Format(s_temp_2, sizeof(s_temp_2), "`steam_id`='%s'", steam_id);
    menu.AddItem(s_temp_2, s_temp, ( (StrEqual(s_steam_id_client, steam_id) || CheckAdminFlag(client, s_flags)) && i_report_count > 0 )? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    Format(s_temp, sizeof(s_temp), "SELECT COUNT(*) FROM `reports` WHERE `steam_id_reported`='%s'", steam_id);
    i_report_count = SQLFirstDataInt(s_temp);
    Format(s_temp, sizeof(s_temp), "%t", "Reports Received", i_report_count );
    Format(s_temp_2, sizeof(s_temp_2), "`steam_id_reported`='%s'", steam_id);
    menu.AddItem(s_temp_2, s_temp, ( CheckAdminFlag(client, s_flags) && i_report_count > 0 ) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
    return menu;
}

int ClientReports_MenuCallback(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char s_temp[64];
        menu.GetItem(param2, s_temp, sizeof(s_temp));
        Reports_Menu(s_temp).Display(client, MENU_TIME_FOREVER);
    }
    else if (action == MenuAction_End) delete menu;
}

Menu ReportStatusChange_Menu(int client)
{
    char s_temp[512];
    Menu menu = new Menu(ReportStatusChange_MenuCallback);
    menu.SetTitle("%t", "Report Status Change Menu Title", i_client_temp[client]);
    Format(s_temp, sizeof(s_temp), "%t", "Back to Report", i_client_temp[client]);
    menu.AddItem("backtoreport", s_temp);
    Format(s_temp, sizeof(s_temp), "SELECT `status` FROM `reports` WHERE `id` = %d",  i_client_temp[client]);
    DBResultSet DBRS_Query = SQL_Query(h_database, s_temp);
    bool b_data = false;
    if (DBRS_Query ==  INVALID_HANDLE || DBRS_Query ==  null){
        char s_error[255];
        SQL_GetError(h_database, s_error, sizeof(s_error));
        DatabaseQueryError(s_error, s_temp);
        CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Status Change Record Error");
    }else if (SQL_GetRowCount(DBRS_Query) || SQL_FetchRow(DBRS_Query)){
        b_data = true;
        int i_report_status = SQL_FetchInt(DBRS_Query, 0);
        Format(s_temp, sizeof(s_temp), "%t", "Status 1");
        menu.AddItem("1",s_temp , i_report_status==1 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        Format(s_temp, sizeof(s_temp), "%t", "Status 2");
        menu.AddItem("2",s_temp , i_report_status==2 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
        Format(s_temp, sizeof(s_temp), "%t", "Status 0");
        menu.AddItem("0",s_temp , i_report_status==0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    }
    delete DBRS_Query;
    if(!b_data){
        Format(s_temp, sizeof(s_temp), "%t", "No Data");
        menu.AddItem("null", s_temp, ITEMDRAW_DISABLED);
    }
    return menu;
}

int ReportStatusChange_MenuCallback(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char s_temp[1024];
        menu.GetItem(param2, s_temp, sizeof(s_temp));
        if(StrEqual(s_temp, "backtoreport")){
            ReportDetail_Menu(client, i_client_temp[client]).Display(client, MENU_TIME_FOREVER);
        }else{
            int i_status = StringToInt(s_temp);
            if(i_status>=0 && i_status<=2){
                Format(s_temp, sizeof(s_temp), "UPDATE `reports` SET `status`=%d, `update_time`=%d WHERE `id`=%d;", i_status, GetTime(), i_client_temp[client]);
                if(SQLQueryNoData(s_temp)){
                    char s_steam_id[32], s_username[32];
                    if(!GetClientAuthId(client, AuthId_Steam2, s_steam_id, sizeof(s_steam_id)))Format(s_steam_id, sizeof(s_steam_id), "%t", "Unknown Steam ID"); 
                    if(!GetClientName(client, s_username, sizeof(s_username)))Format(s_username, sizeof(s_username), "%t", "Unnamed");
                    DiscordSQL_EscapeString(s_steam_id, sizeof(s_steam_id));
                    DiscordSQL_EscapeString(s_username, sizeof(s_username));
                    Format(s_temp, sizeof(s_temp), "INSERT INTO `events` (`report_id`,`steam_id`,`player_name`,`event`,`creation_time`) VALUES (%d, '%s', '%s', %d, %d);", i_client_temp[client], s_steam_id, s_username, (i_status==0 ? 3 : i_status) , GetTime());
                    SQLQueryNoData(s_temp);
                    CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Status Change Successful", i_client_temp[client]);
                    if(!StrEqual(s_webhook, "")){
                        char s_temp_2[256];
                        DiscordWebHook hook = new DiscordWebHook(s_webhook);
                        hook.SlackMode = true;
                        MessageEmbed Embed = new MessageEmbed();
                        Format(s_temp, sizeof(s_temp), "%s ★ %t", s_tag, "Advanced Report");
                        Embed.SetAuthor(s_temp);
                        Embed.SetAuthorLink(s_plugin_url);
                        Embed.SetAuthorIcon(s_plugin_image);
                        Embed.SetColor("#2693FF");
                        Embed.SetThumb("https://csgo-turkiye.com/assets/plugin_images/advanced-report/updatereport.png");
                        Format(s_temp, sizeof(s_temp), "%t", "Report Status Update Title");
                        Embed.SetTitle(s_temp);
                        Format(s_temp, sizeof(s_temp), "%t", "Status Update Report ID Title");
                        Format(s_temp_2, sizeof(s_temp_2), "%t", "Status Update Report ID Value", i_client_temp[client]);
                        Embed.AddField(s_temp, s_temp_2, true);
                        Format(s_temp, sizeof(s_temp), "%t", "Status Update - Status Title");
                        Format(s_temp_2, sizeof(s_temp_2), "Status %d", i_status);
                        Format(s_temp_2, sizeof(s_temp_2), "%t", s_temp_2);
                        Embed.AddField(s_temp, s_temp_2, true);
                        FormatTime(s_temp, sizeof(s_temp), "%d.%m.%Y %X", GetTime());
                        Format(s_temp, sizeof(s_temp), "%t", "Status Update Footer", s_username, s_steam_id, s_temp);
                        Embed.SetFooter(s_temp);
                        Embed.SetFooterIcon("https://csgo-turkiye.com/assets/plugin_images/advanced-report/user.png");  
                        hook.Embed(Embed);
                        hook.Send();
                        delete hook;
                    }
                }else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Status Change Error");
            }else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Status Change Number Error");
            ReportStatusChange_Menu(client).Display(client, MENU_TIME_FOREVER);
        }
    }
    else if (action == MenuAction_End) delete menu;
}

Menu TransactionRecords_Menu(int client)
{
    char s_temp[512];
    Menu menu = new Menu(TransactionRecords_MenuCallback);
    menu.SetTitle("%t", "Transaction Records Menu Title", i_client_temp[client]);
    Format(s_temp, sizeof(s_temp), "%t", "Back to Report", i_client_temp[client]);
    menu.AddItem("backtoreport", s_temp);
    Format(s_temp, sizeof(s_temp), "SELECT * FROM `events` WHERE `report_id` = %d ORDER BY `id`",  i_client_temp[client]);
    DBResultSet DBRS_Query = SQL_Query(h_database, s_temp);
    bool b_data = false;
    if (DBRS_Query ==  INVALID_HANDLE || DBRS_Query ==  null){
        char s_error[255];
        SQL_GetError(h_database, s_error, sizeof(s_error));
        DatabaseQueryError(s_error, s_temp);
        CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Transaction Records Error");
    }else if(SQL_HasResultSet(DBRS_Query))
	{
        char s_username[32], s_steam_id[32], s_time[32];
        while (SQL_FetchRow(DBRS_Query)){
            b_data = true;
            SQL_FetchString(DBRS_Query, 2, s_steam_id, sizeof(s_steam_id));
            SQL_FetchString(DBRS_Query, 3, s_username, sizeof(s_username));
            Format(s_temp, sizeof(s_temp), "Event %d", SQL_FetchInt(DBRS_Query,4));
            Format(s_temp, sizeof(s_temp), "%t", s_temp);
            FormatTime(s_time, sizeof(s_time), "%d.%m.20%y ✪ %X", SQL_FetchInt(DBRS_Query,5));
            Format(s_temp, sizeof(s_temp), "%t", "Transaction Records List Item", s_steam_id, s_username, s_time, s_temp);
            menu.AddItem(s_temp, s_temp);
		}
	}
    delete DBRS_Query;
    if(!b_data){
        Format(s_temp, sizeof(s_temp), "%t", "No Data");
        menu.AddItem("null", s_temp, ITEMDRAW_DISABLED);
    }
    return menu;
}

int TransactionRecords_MenuCallback(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char s_temp[512];
        menu.GetItem(param2, s_temp, sizeof(s_temp));
        if(StrEqual(s_temp, "backtoreport")){
            ReportDetail_Menu(client, i_client_temp[client]).Display(client, MENU_TIME_FOREVER);
        }else{
            PrintHintText(client, s_temp);
            TransactionRecords_Menu(client).DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
        }
    }
    else if (action == MenuAction_End) delete menu;
}


Menu Messages_Menu(int client)
{
    char s_temp[512];
    Menu menu = new Menu(Messages_MenuCallback);
    menu.SetTitle("%t", "Messages Menu Title", i_client_temp[client]);
    Format(s_temp, sizeof(s_temp), "%t", "Back to Report", i_client_temp[client]);
    menu.AddItem("backtoreport", s_temp);
    Format(s_temp, sizeof(s_temp), "SELECT * FROM `messages` WHERE `report_id` = %d ORDER BY `id`",  i_client_temp[client]);
    DBResultSet DBRS_Query = SQL_Query(h_database, s_temp);
    bool b_data = false;
    if (DBRS_Query ==  INVALID_HANDLE || DBRS_Query ==  null){
        char s_error[255];
        SQL_GetError(h_database, s_error, sizeof(s_error));
        DatabaseQueryError(s_error, s_temp);
        CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Messages Error");
    }else if(SQL_HasResultSet(DBRS_Query))
	{
        char s_username[32], s_steam_id[32], s_time[32];
        while (SQL_FetchRow(DBRS_Query)){
            b_data = true;
            SQL_FetchString(DBRS_Query, 2, s_steam_id, sizeof(s_steam_id));
            SQL_FetchString(DBRS_Query, 3, s_username, sizeof(s_username));
            SQL_FetchString(DBRS_Query, 4, s_temp, sizeof(s_temp));
            FormatTime(s_time, sizeof(s_time), "%d.%m.20%y ✪ %X", SQL_FetchInt(DBRS_Query,5));
            Format(s_temp, sizeof(s_temp), "%t", "Messages List Item", s_steam_id, s_username, s_time, s_temp);
            menu.AddItem(s_temp, s_temp);
		}
	}
    delete DBRS_Query;
    if(!b_data){
        Format(s_temp, sizeof(s_temp), "%t", "No Data");
        menu.AddItem("null", s_temp, ITEMDRAW_DISABLED);
    }
    return menu;
}

int Messages_MenuCallback(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char s_temp[512];
        menu.GetItem(param2, s_temp, sizeof(s_temp));
        if(StrEqual(s_temp, "backtoreport")){
            ReportDetail_Menu(client, i_client_temp[client]).Display(client, MENU_TIME_FOREVER);
        }else{
            PrintHintText(client, s_temp);
            Messages_Menu(client).DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
        }
    }
    else if (action == MenuAction_End) delete menu;
}

Menu Rules_Menu()
{
    char s_temp[128];
    Menu menu = new Menu(Rules_MenuCallback);
    menu.SetTitle("%t", "Report Generation Rules");
    Format(s_temp, sizeof(s_temp), "%t", "Yes");
    menu.AddItem("yes", s_temp);
    Format(s_temp, sizeof(s_temp), "%t", "No");
    menu.AddItem("no", s_temp);
    return menu;
}

int Rules_MenuCallback(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char s_option[4];
        menu.GetItem(param2, s_option, sizeof(s_option));
        if (StrEqual(s_option, "yes"))  Players_Menu(client).Display(client, 60);
        else if(StrEqual(s_option, "no")) CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Not Accepted");
    }
    else if (action == MenuAction_End) delete menu;
}

Menu Players_Menu(int client)
{
    char s_temp[128], s_steam_id[32], s_username[32];
    bool b_user = false;
    Menu menu = new Menu(Players_MenuCallback);
    menu.SetTitle("%t", "Players Menu Title");
    for(int i = 1; i <= MaxClients; i++)
            if (client != i && IsValidClient(i) ){
                b_user = true;
                if(!GetClientAuthId(i, AuthId_Steam2, s_steam_id, sizeof(s_steam_id)))Format(s_steam_id, sizeof(s_steam_id), "%t", "Unknown Steam ID"); 
                if(!GetClientName(i, s_username, sizeof(s_username)))Format(s_username, sizeof(s_username), "%t", "Unnamed");
                Format(s_temp, sizeof(s_temp), "%t", "Players Menu User", s_steam_id, s_username);
                Format(s_steam_id, sizeof(s_steam_id), "%d", i);
                menu.AddItem( s_steam_id , s_temp);
            }
    if(!b_user){
        Format(s_temp, sizeof(s_temp), "%t", "No Player");
        menu.AddItem("null", s_temp, ITEMDRAW_DISABLED);
    }
    return menu;
}

int Players_MenuCallback(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char s_temp[512];
        menu.GetItem(param2, s_temp, sizeof(s_temp));
        i_client_temp[ client ] = StringToInt(s_temp);
        if(IsValidClient(i_client_temp[ client ])){
            char s_steam_id[32], s_steam_id_target[32];
            if(!GetClientAuthId(i_client_temp[ client ], AuthId_Steam2, s_steam_id_target, sizeof(s_steam_id_target) ))Format(s_steam_id_target, sizeof(s_steam_id_target), "%t", "Unknown Steam ID");
            if(!GetClientAuthId(client, AuthId_Steam2, s_steam_id, sizeof(s_steam_id) ))Format(s_steam_id, sizeof(s_steam_id), "%t", "Unknown Steam ID");
            DiscordSQL_EscapeString(s_steam_id_target, sizeof(s_steam_id_target));
            DiscordSQL_EscapeString(s_steam_id, sizeof(s_steam_id));
            Format(s_temp, sizeof(s_temp), "SELECT `creation_time` FROM `reports` WHERE `steam_id` = '%s' and `steam_id_reported` = '%s' and `creation_time` >= %d and `status`!=%d ORDER BY `id` DESC LIMIT 1", s_steam_id, s_steam_id_target, GetTime() - i_same_player_wait_time, 0);
            int i_time = SQLFirstDataInt(s_temp);
            if(i_same_player_wait_time<1 || i_time == 0 ){
                CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Player Select", i_client_temp[ client ]);
                Reason_Menu().Display(client, 60);
            }else{
                i_time += i_same_player_wait_time;
                FormatTime(s_temp, sizeof(s_temp), "%d.%m.20%y ✪ %X", i_time);
                CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Same Player Report Creation Waiting Time", s_temp);
            }
        }else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Target Error");
    }
    else if (action == MenuAction_End) delete menu;
}

Menu Reason_Menu()
{
    char s_temp[128];
    Menu menu = new Menu(Reason_MenuCallback);
    menu.SetTitle("%t", "Reason Menu Title");
    if (FileExists(s_file)){
        Handle h_reasons = OpenFile(s_file, "r");
        while (!IsEndOfFile(h_reasons))
        {
            ReadFileLine(h_reasons, s_temp, sizeof(s_temp));
            TrimString(s_temp);
            if(!StrEqual(s_temp, "")) menu.AddItem(s_temp, s_temp);
        }
        delete h_reasons;
    }
    Format(s_temp, sizeof(s_temp), "%t", "Other");
    menu.AddItem("other", s_temp);
    return menu;
}

int Reason_MenuCallback(Menu menu, MenuAction action, int client, int param2)
{
    if (action == MenuAction_Select)
    {
        char s_option[255];
        menu.GetItem(param2, s_option, sizeof(s_option));
        if(StrEqual(s_option, "other")){
            c_say_type[client] = '1';
            i_client_temp2[client] = GetTime()+60;
            CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "New Report Reason Say");
        }else{
            AddReport(client, s_option);
        }
    }
    else if (action == MenuAction_End) delete menu;
}

void SendMessage(int client, char message[255])
{
    char s_temp[1024];
    Format(s_temp, sizeof(s_temp), "SELECT `steam_id`,`status` FROM `reports` WHERE `id` = %d", i_client_temp[client]);
    DBResultSet DBRS_Query = SQL_Query(h_database, s_temp);
    if (DBRS_Query == INVALID_HANDLE || DBRS_Query == null)
    {
        char s_error[255];
        SQL_GetError(h_database, s_error, sizeof(s_error));
        DatabaseQueryError(s_error, s_temp);
        CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Send Message Error");
    }else if (SQL_GetRowCount(DBRS_Query) || SQL_FetchRow(DBRS_Query)){
        if(SQL_FetchInt(DBRS_Query,1) != 0){
            char s_steam_id[32], s_username[32], s_report_steam_id[32];
            if(!GetClientAuthId(client, AuthId_Steam2, s_steam_id, sizeof(s_steam_id)))Format(s_steam_id, sizeof(s_steam_id), "%t", "Unknown Steam ID"); 
            if(!GetClientName(client, s_username, sizeof(s_username)))Format(s_username, sizeof(s_username), "%t", "Unnamed");
            SQL_FetchString(DBRS_Query, 0, s_report_steam_id, sizeof(s_report_steam_id));
            if(StrEqual(s_report_steam_id, s_steam_id) || CheckAdminFlag(client, s_flags)){
                DiscordSQL_EscapeString(s_steam_id, sizeof(s_steam_id));
                DiscordSQL_EscapeString(s_username, sizeof(s_username));
                DiscordSQL_EscapeString(message, sizeof(message));
                Format(s_temp, sizeof(s_temp), "INSERT INTO `messages` (`report_id`,`steam_id`,`player_name`,`message`,`creation_time`) VALUES (%d, '%s', '%s', '%s',%d);", i_client_temp[client], s_steam_id, s_username, message,  GetTime());
                if(SQLQueryNoData(s_temp)){
                    Format(s_temp, sizeof(s_temp), "INSERT INTO `events` (`report_id`,`steam_id`,`player_name`,`event`,`creation_time`) VALUES (%d, '%s', '%s', %d, %d);", i_client_temp[client], s_steam_id, s_username, 4, GetTime());
                    SQLQueryNoData(s_temp);
                    CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Send Message Successful", i_client_temp[client]);
                    int i_report_status, i_admin_player = 0;
                    if(StrEqual(s_report_steam_id, s_steam_id)) i_report_status = 1;
                    else i_report_status = 2;
                    Format(s_temp, sizeof(s_temp), "UPDATE `reports` SET `status`=%d, `update_time`=%d WHERE `id`=%d;", i_report_status, GetTime(), i_client_temp[client]);
                    SQLQueryNoData(s_temp);
                    char s_admins[ MAXPLAYERS+1 ][ MAX_NAME_LENGTH+1 ];
                    for (int i = 1; i <= MaxClients; i++)
                    if(IsValidClient(i)){
                        if(!GetClientAuthId(i, AuthId_Steam2, s_temp, sizeof(s_temp)))Format(s_temp, sizeof(s_temp), "%t", "Unknown Steam ID"); 
                        if(StrEqual(s_temp, s_report_steam_id) && i_report_status==2){
                            SetHudTextParams(-1.0, 0.1, 5.0, GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), 0, 2, 1.0, 0.1, 0.2);
                            ShowHudText(i, 1, "%t", "Send Message Player Hud", i_client_temp[client]);
                            CPrintToChat(i, "%s%s %t", s_tag_color, s_tag, "Send Message Player Say Text", i_client_temp[client]);
                        }else if(CheckAdminFlag(i, s_flags) && i_report_status==1){
                            if(!StrEqual(s_temp, s_report_steam_id)){
                                SetHudTextParams(-1.0, 0.1, 5.0, GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), 0, 2, 1.0, 0.1, 0.2);
                                ShowHudText(i, 1, "%t", "Send Message Admin Hud", i_client_temp[client]);
                                CPrintToChat(i, "%s%s %t", s_tag_color, s_tag, "Send Message Admin Say Text", i_client_temp[client]);
                            }
                            char s_username_admin[32],s_steam_id_admin[32];
                            if(!GetClientAuthId(i, AuthId_Steam2, s_steam_id_admin, sizeof(s_steam_id_admin)))Format(s_steam_id_admin, sizeof(s_steam_id_admin), "%t", "Unknown Steam ID"); 
                            if(!GetClientName(i, s_username_admin, sizeof(s_username_admin)))Format(s_username_admin, sizeof(s_username_admin), "%t", "Unnamed");
                            DiscordSQL_EscapeString(s_username_admin, sizeof(s_username_admin));
                            DiscordSQL_EscapeString(s_steam_id_admin, sizeof(s_steam_id_admin));
                            Format(s_admins[i_admin_player],sizeof(s_admins[]),"`%s • [%s]`",s_username_admin,s_steam_id_admin);
                            i_admin_player++;
                        }
                    }
                    if(!StrEqual(s_webhook, "")){
                        char s_temp_2[256];
                        DiscordWebHook hook = new DiscordWebHook(s_webhook);
                        hook.SlackMode = true;
                        MessageEmbed Embed = new MessageEmbed();
                        Format(s_temp, sizeof(s_temp), "%s ★ %t", s_tag, "Advanced Report");
                        Embed.SetAuthor(s_temp);
                        Embed.SetAuthorLink(s_plugin_url);
                        Embed.SetAuthorIcon(s_plugin_image);
                        Embed.SetColor("#A300D9");
                        Embed.SetThumb("https://csgo-turkiye.com/assets/plugin_images/advanced-report/newmessage.png");
                        Format(s_temp, sizeof(s_temp), "%t", "Send Message Title");
                        Embed.SetTitle(s_temp);
                        Format(s_temp, sizeof(s_temp), "%t", "Send Message Report ID Title");
                        Format(s_temp_2, sizeof(s_temp_2), "%t", "Send Message Report ID Value", i_client_temp[client]);
                        Embed.AddField(s_temp, s_temp_2, true);
                        Format(s_temp, sizeof(s_temp), "%t", "Send Message Status Title");
                        Format(s_temp_2, sizeof(s_temp_2), "Status %d", i_report_status);
                        Format(s_temp_2, sizeof(s_temp_2), "%t", s_temp_2);
                        Embed.AddField(s_temp, s_temp_2, true);
                        Format(s_temp, sizeof(s_temp), "%t", "Send Message - Message Title");
                        Format(s_temp_2, sizeof(s_temp_2), "%t", "Send Message - Message Field Value", message);
                        Embed.AddField(s_temp, s_temp_2,false);
                        MessageEmbed Embed2 = new MessageEmbed();
                        Embed2.SetColor("#c9c9c9");
                        Format(s_temp_2, sizeof(s_temp_2), "%t", "Send Message Admin Title");
                        if(i_admin_player<1)Format(s_temp, sizeof(s_temp), "%t", "No Admin on Server");
                        else ImplodeStrings(s_admins, i_admin_player, "\n", s_temp, sizeof(s_temp));
                        Embed2.AddField(s_temp_2, s_temp, false);
                        FormatTime(s_temp, sizeof(s_temp), "%d.%m.%Y %X", GetTime());
                        Format(s_temp, sizeof(s_temp), "%t", "Send Message Footer", s_username, s_steam_id, s_temp);
                        Embed2.SetFooter(s_temp);
                        Embed2.SetFooterIcon("https://csgo-turkiye.com/assets/plugin_images/advanced-report/user.png");  
                        hook.Embed(Embed);
                        hook.Embed(Embed2);
                        hook.Send();
                        delete hook;
                    }
                }else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Send Message Error");
            }else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Send Message Flag Error");
        }else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Send Message Closed Error");
    }else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Send Message Error 2");
    delete DBRS_Query;
    ReportDetail_Menu(client, i_client_temp[client]).Display(client, MENU_TIME_FOREVER);
}

void AddReport(int client, char reason[255])
{
    char s_temp[1024], s_steam_id[32], s_username[32], s_steam_id_reported[32], s_username_reported[32] ;
    if(!GetClientAuthId(client, AuthId_Steam2, s_steam_id, sizeof(s_steam_id)))Format(s_steam_id, sizeof(s_steam_id), "%t", "Unknown Steam ID"); 
    if(!GetClientName(client, s_username, sizeof(s_username)))Format(s_username, sizeof(s_username), "%t", "Unnamed");
    if(!GetClientAuthId(i_client_temp[client], AuthId_Steam2, s_steam_id_reported, sizeof(s_steam_id_reported)))Format(s_steam_id_reported, sizeof(s_steam_id_reported), "%t", "Unknown Steam ID"); 
    if(!GetClientName(i_client_temp[client], s_username_reported, sizeof(s_username_reported)))Format(s_username_reported, sizeof(s_username_reported), "%t", "Unnamed");
    DiscordSQL_EscapeString(s_steam_id, sizeof(s_steam_id));   
    DiscordSQL_EscapeString(s_username, sizeof(s_username));   
    DiscordSQL_EscapeString(s_steam_id_reported, sizeof(s_steam_id_reported));
    DiscordSQL_EscapeString(s_username_reported, sizeof(s_username_reported));
    Format(s_temp, sizeof(s_temp), "INSERT INTO `reports` (`steam_id`,`player_name`,`steam_id_reported`,`player_name_reported`,`update_time`,`creation_time`) VALUES ('%s', '%s', '%s', '%s',%d , %d);", s_steam_id, s_username, s_steam_id_reported, s_username_reported, GetTime(), GetTime());
    int i_report_id = SQLQueryIDData(s_temp);
    if (i_report_id != 0)
    {
        DiscordSQL_EscapeString(reason, sizeof(reason));   
        Format(s_temp, sizeof(s_temp), "INSERT INTO `messages` (`report_id`,`steam_id`,`player_name`,`message`,`creation_time`) VALUES (%d, '%s', '%s', '%s',%d);", i_report_id, s_steam_id, s_username, reason,  GetTime());
        if(!SQLQueryNoData(s_temp)) PrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Create Report Error 2");
        Format(s_temp, sizeof(s_temp), "INSERT INTO `events` (`report_id`,`steam_id`,`player_name`,`creation_time`) VALUES (%d, '%s', '%s',%d);", i_report_id, s_steam_id, s_username,  GetTime());
        SQLQueryNoData(s_temp);
        CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Create Report Successful", s_steam_id_reported, s_username_reported, i_report_id);
        char s_admins[ MAXPLAYERS+1 ][ MAX_NAME_LENGTH+1 ];
        int i_admin_player = 0;
        for (int i = 1; i <= MaxClients; i++)
        if(IsValidClient(i)){
            if(CheckAdminFlag(i, s_flags)){
                SetHudTextParams(-1.0, 0.1, 5.0, GetRandomInt(0, 255), GetRandomInt(0, 255), GetRandomInt(0, 255), 0, 2, 1.0, 0.1, 0.2);
                ShowHudText(i, 1, "%t", "Create Report Admin Hud Text", i_report_id);
                CPrintToChat(i, "%s%s %t", s_tag_color, s_tag, "Create Report Admin Say Text", i_report_id);
                char s_username_admin[32],s_steam_id_admin[32];
                if(!GetClientAuthId(i, AuthId_Steam2, s_steam_id_admin, sizeof(s_steam_id_admin)))Format(s_steam_id_admin, sizeof(s_steam_id_admin), "%t", "Unknown Steam ID"); 
                if(!GetClientName(i, s_username_admin, sizeof(s_username_admin)))Format(s_username_admin, sizeof(s_username_admin), "%t", "Unnamed");
                DiscordSQL_EscapeString(s_username_admin, sizeof(s_username_admin));
                DiscordSQL_EscapeString(s_steam_id_admin, sizeof(s_steam_id_admin));
                Format(s_admins[i_admin_player],sizeof(s_admins[]),"`%s • [%s]`",s_username_admin,s_steam_id_admin);
                i_admin_player++;
            }
        }  
        if(!StrEqual(s_webhook, "")){
                char s_temp_2[256];
                DiscordWebHook hook = new DiscordWebHook(s_webhook);
                hook.SlackMode = true;
                MessageEmbed Embed = new MessageEmbed();
                Format(s_temp, sizeof(s_temp), "%s ★ %t", s_tag, "Advanced Report");
                Embed.SetAuthor(s_temp);
                Embed.SetAuthorLink(s_plugin_url);
                Embed.SetAuthorIcon(s_plugin_image);
                Embed.SetColor("#FFD05B");
                Embed.SetThumb("https://csgo-turkiye.com/assets/plugin_images/advanced-report/newreport.png");
                Format(s_temp, sizeof(s_temp), "%t", "Create Report Title");
                Embed.SetTitle(s_temp);
                Format(s_temp, sizeof(s_temp), "%t", "Create Report ID Title");
                Format(s_temp_2, sizeof(s_temp_2), "%t", "Create Report ID Value", i_report_id);
                Embed.AddField(s_temp, s_temp_2, true);
                Format(s_temp, sizeof(s_temp), "%t", "Create Report Player Field Title");
                if(GetCommunityID(s_steam_id_reported, s_temp_2, sizeof(s_temp_2)))Format(s_temp_2, sizeof(s_temp_2), "http://steamcommunity.com/profiles/%s", s_temp_2);
                else Format(s_temp_2, sizeof(s_temp_2), "http://steamcommunity.com");
                Format(s_temp_2, sizeof(s_temp_2), "%t", "Create Report Player Field Value", s_username_reported,  s_steam_id_reported, s_temp_2);
                Embed.AddField(s_temp, s_temp_2,true);
                Format(s_temp, sizeof(s_temp), "%t", "Create Report Reason Title");
                Format(s_temp_2, sizeof(s_temp_2), "%t", "Create Report Reason Field Value", reason);
                Embed.AddField(s_temp, s_temp_2,false);
                MessageEmbed Embed2 = new MessageEmbed();
                Embed2.SetColor("#c9c9c9");
                Format(s_temp_2, sizeof(s_temp_2), "%t", "Create Report Admin Title");
                if(i_admin_player<1)Format(s_temp, sizeof(s_temp), "%t", "No Admin on Server");
                else ImplodeStrings(s_admins, i_admin_player, "\n", s_temp, sizeof(s_temp));
                Embed2.AddField(s_temp_2, s_temp, false);
                FormatTime(s_temp, sizeof(s_temp), "%d.%m.%Y %X", GetTime());
                Format(s_temp, sizeof(s_temp), "%t", "Create Report Footer", s_username, s_steam_id, s_temp);
                Embed2.SetFooter(s_temp);
                Embed2.SetFooterIcon("https://csgo-turkiye.com/assets/plugin_images/advanced-report/user.png");  
                hook.Embed(Embed);
                hook.Embed(Embed2);
                hook.Send();
                delete hook;
        }
    }else PrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Create Report Error");
}

int DetailAddBan(int client, char reason[255]){
    char s_temp[512];
    Format(s_temp, sizeof(s_temp), "SELECT `steam_id`,`player_name` FROM `reports` WHERE `id` = %d", i_client_temp[client]);
    DBResultSet DBRS_Query = SQL_Query(h_database, s_temp);
    if (DBRS_Query == INVALID_HANDLE || DBRS_Query == null)
    {
        char s_error[255];
        SQL_GetError(h_database, s_error, sizeof(s_error));
        DatabaseQueryError(s_error, s_temp);
        CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Detail Ban Error");
    }else if (SQL_GetRowCount(DBRS_Query) || SQL_FetchRow(DBRS_Query)){
        char s_steam_id[32], s_username[32];
        SQL_FetchString(DBRS_Query, 0, s_steam_id, sizeof(s_steam_id));
        SQL_FetchString(DBRS_Query, 1, s_username, sizeof(s_username));
        AddBan(client, s_steam_id, s_username, reason);
    }else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Detail Ban Error");
    delete DBRS_Query;
    ReportDetail_Menu(client, i_client_temp[client]).Display(client, MENU_TIME_FOREVER);
}

void AddBan(int client, char steam_id_target[32], char username_target[32], char reason[255]) {
    char s_temp[1024];
    DiscordSQL_EscapeString(steam_id_target, sizeof(steam_id_target));
    Format(s_temp, sizeof(s_temp), "SELECT * FROM `bans` WHERE `steam_id` = '%s'", steam_id_target);
    if(!IsThereRecord(s_temp)){
        char s_username[32], s_steam_id[32];
        if(client == 0){
            Format(s_username, sizeof(s_username), "%t", "Console");
            Format(s_steam_id, sizeof(s_steam_id), "0");
        }else{
            if(!GetClientAuthId(client, AuthId_Steam2, s_steam_id, sizeof(s_steam_id)))Format(s_steam_id, sizeof(s_steam_id), "%t", "Unknown Steam ID"); 
            if(!GetClientName(client, s_username, sizeof(s_username)))Format(s_username, sizeof(s_username), "%t", "Unnamed");
        }
        if(strlen(reason)<1)Format(reason, sizeof(reason), "%t", "Unknown Reason");
        DiscordSQL_EscapeString(username_target, sizeof(username_target));   
        DiscordSQL_EscapeString(s_username, sizeof(s_username));   
        DiscordSQL_EscapeString(s_steam_id, sizeof(s_steam_id));
        DiscordSQL_EscapeString(reason, sizeof(reason));
        Format(s_temp, sizeof(s_temp), "INSERT INTO `bans` (`steam_id`,`player_name`,`steam_id_admin`,`player_name_admin`,`reason`,`creation_time`) VALUES ('%s', '%s', '%s', '%s','%s' , %d);", steam_id_target, username_target, s_steam_id, s_username, reason, GetTime());
        int i_ban_id = SQLQueryIDData(s_temp);
        if (i_ban_id != 0)
        {
            if(client == 0) PrintToServer("%s %t", s_tag, "Add Ban Successful Console", steam_id_target, username_target, i_ban_id);
            else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Add Ban Successful", steam_id_target, username_target, i_ban_id);
            if(!StrEqual(s_webhook, "")){
                char s_temp_2[256];
                DiscordWebHook hook = new DiscordWebHook(s_webhook);
                hook.SlackMode = true;
                MessageEmbed Embed = new MessageEmbed();
                Format(s_temp, sizeof(s_temp), "%s ★ %t", s_tag, "Advanced Report");
                Embed.SetAuthor(s_temp);
                Embed.SetAuthorLink(s_plugin_url);
                Embed.SetAuthorIcon(s_plugin_image);
                Embed.SetColor("#00B200");
                Embed.SetThumb("https://csgo-turkiye.com/assets/plugin_images/advanced-report/addban.png");
                Format(s_temp, sizeof(s_temp), "%t", "Add Ban Title");
                Embed.SetTitle(s_temp);
                Format(s_temp, sizeof(s_temp), "%t", "Add Ban ID Title");
                Format(s_temp_2, sizeof(s_temp_2), "%t", "Add Ban ID Field Value", i_ban_id);
                Embed.AddField(s_temp, s_temp_2, true);
                Format(s_temp, sizeof(s_temp), "%t", "Add Ban Player Field Title");
                if(GetCommunityID(steam_id_target, s_temp_2, sizeof(s_temp_2)))Format(s_temp_2, sizeof(s_temp_2), "http://steamcommunity.com/profiles/%s", s_temp_2);
                else Format(s_temp_2, sizeof(s_temp_2), "http://steamcommunity.com");
                Format(s_temp_2, sizeof(s_temp_2), "%t", "Add Ban Player Field Value", username_target,  steam_id_target, s_temp_2);
                Embed.AddField(s_temp, s_temp_2,true);
                Format(s_temp, sizeof(s_temp), "%t", "Add Ban Reason Title");
                Format(s_temp_2, sizeof(s_temp_2), "%t", "Add Ban Reason Field Value", reason);
                Embed.AddField(s_temp, s_temp_2,false);
                FormatTime(s_temp, sizeof(s_temp), "%d.%m.%Y %X", GetTime());
                if(client==0)Format(s_temp, sizeof(s_temp), "%t", "Add Ban Console Footer", s_temp);
                else Format(s_temp, sizeof(s_temp), "%t", "Add Ban Admin Footer", s_username, s_steam_id, s_temp);
                Embed.SetFooter(s_temp);
                Embed.SetFooterIcon("https://csgo-turkiye.com/assets/plugin_images/advanced-report/user.png");  
                hook.Embed(Embed);
                hook.Send();
                delete hook;
            }
        }else{
            if(client == 0) PrintToServer("%s %t", s_tag, "Add Ban Error Console");
            else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Add Ban Error");
        }
    }else{
        if(client == 0) PrintToServer("%s %t", s_tag, "Add Ban Available Error Console");
        else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Add Ban Available Error");
    }
}

void UnBan(int client, char info[32]){
    char s_temp[1024];
    if(StrContains(info, "$")==0 && strlen(info) >= 2){
        ReplaceString(info, sizeof(info), "$", "");
        int i_id = StringToInt(info);
        if(i_id > 0)Format(s_temp, sizeof(s_temp), "SELECT `id`,`player_name`,`steam_id` FROM `bans` WHERE `id` = %d", i_id);
    }else if(StrContains(info, "STEAM_")==0 && strlen(info) >= 11){
        DiscordSQL_EscapeString(info, sizeof(info));
        Format(s_temp, sizeof(s_temp), "SELECT `id`,`player_name`,`steam_id` FROM `bans` WHERE `steam_id` = '%s'", info);
    }else{
        int i_target = FindTarget(client, info, true, true);
        if (i_target > 0 && IsValidClient(i_target)){
            if(!GetClientAuthId(i_target, AuthId_Steam2, info, sizeof(info)))Format(info, sizeof(info), "%t", "Unknown Steam ID");
            DiscordSQL_EscapeString(info, sizeof(info));
            Format(s_temp, sizeof(s_temp), "SELECT `id`,`player_name`,`steam_id` FROM `bans` WHERE `steam_id` = '%s'", info);
        }  
    }

    if(StrEqual(s_temp, "")){
        if(client == 0) PrintToServer("%s %t", s_tag, "Remove Ban Query Error Console");
        else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Remove Ban Query Error");
    }else{
        int i_ban_id;
        char s_username[32], s_steam_id[32];
        DBResultSet DBRS_Query = SQL_Query(h_database, s_temp);
        if (DBRS_Query == INVALID_HANDLE || DBRS_Query == null)
        {
            char s_error[255];
            SQL_GetError(h_database, s_error, sizeof(s_error));
            DatabaseQueryError(s_error, s_temp);
        }else if (SQL_HasResultSet(DBRS_Query) && SQL_FetchRow(DBRS_Query))
        {  
            i_ban_id = SQL_FetchInt(DBRS_Query, 0);
            SQL_FetchString(DBRS_Query, 1, s_username, sizeof(s_username));
            DiscordSQL_EscapeString(s_username, sizeof(s_username));
            SQL_FetchString(DBRS_Query, 2, s_steam_id, sizeof(s_steam_id));
            DiscordSQL_EscapeString(s_steam_id, sizeof(s_steam_id));
        }
        delete DBRS_Query;
        if(i_ban_id>0){
            Format(s_temp, sizeof(s_temp), "DELETE FROM `bans` WHERE `id`= %d;", i_ban_id);
            if (SQLQueryNoData(s_temp))
            {
                if(client == 0) PrintToServer("%s %t", s_tag, "Remove Ban Successful Console", s_steam_id, s_username, i_ban_id);
                else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Remove Ban Successful", s_steam_id, s_username, i_ban_id);
                if(!StrEqual(s_webhook, "")){
                    char s_temp_2[256];
                    DiscordWebHook hook = new DiscordWebHook(s_webhook);
                    hook.SlackMode = true;
                    MessageEmbed Embed = new MessageEmbed();
                    Format(s_temp, sizeof(s_temp), "%s ★ %t", s_tag, "Advanced Report");
                    Embed.SetAuthor(s_temp);
                    Embed.SetAuthorLink(s_plugin_url);
                    Embed.SetAuthorIcon(s_plugin_image);
                    Embed.SetColor("#D90000");
                    Embed.SetThumb("https://csgo-turkiye.com/assets/plugin_images/advanced-report/unban.png");
                    Format(s_temp, sizeof(s_temp), "%t", "Remove Ban Title");
                    Embed.SetTitle(s_temp);
                    Format(s_temp, sizeof(s_temp), "%t", "Remove Ban ID Title");
                    Format(s_temp_2, sizeof(s_temp_2), "%t", "Remove Ban ID Field Value", i_ban_id);
                    Embed.AddField(s_temp, s_temp_2, true);
                    Format(s_temp, sizeof(s_temp), "%t", "Remove Ban Player Field Title");
                    if(GetCommunityID(s_steam_id, s_temp_2, sizeof(s_temp_2)))Format(s_temp_2, sizeof(s_temp_2), "http://steamcommunity.com/profiles/%s", s_temp_2);
                    else Format(s_temp_2, sizeof(s_temp_2), "http://steamcommunity.com");
                    Format(s_temp_2, sizeof(s_temp_2), "%t", "Remove Ban Player Field Value", s_username,  s_steam_id, s_temp_2);
                    Embed.AddField(s_temp, s_temp_2,true);
                    FormatTime(s_temp, sizeof(s_temp), "%d.%m.%Y %X", GetTime());
                    if(client==0)Format(s_temp, sizeof(s_temp), "%t", "Remove Ban Console Footer", s_temp);
                    else{
                        if(!GetClientAuthId(client, AuthId_Steam2, s_steam_id, sizeof(s_steam_id)))Format(s_steam_id, sizeof(s_steam_id), "%t", "Unknown Steam ID"); 
                        if(!GetClientName(client, s_username, sizeof(s_username)))Format(s_username, sizeof(s_username), "%t", "Unnamed");
                        DiscordSQL_EscapeString(s_steam_id, sizeof(s_steam_id));
                        DiscordSQL_EscapeString(s_username, sizeof(s_username));
                        Format(s_temp, sizeof(s_temp), "%t", "Remove Ban Admin Footer", s_username, s_steam_id, s_temp);
                    }
                    Embed.SetFooter(s_temp);
                    Embed.SetFooterIcon("https://csgo-turkiye.com/assets/plugin_images/advanced-report/user.png");  
                    hook.Embed(Embed);
                    hook.Send();
                    delete hook;
                }
            }else{
                if(client == 0) PrintToServer("%s %t", s_tag, "Remove Ban Error Console");
                else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Remove Ban Error");
            }
        }else{
            if(client == 0) PrintToServer("%s %t", s_tag, "Not Banned Error Console");
            else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Not Banned Error");
        }
        
    }

}

void ReportDelete(int client, int id){
    char s_temp[255];
    Format(s_temp, sizeof(s_temp), "SELECT * FROM `reports` WHERE `id` = %d", id);
    if(IsThereRecord(s_temp)){
        Format(s_temp, sizeof(s_temp), "DELETE FROM `reports` WHERE `id` = %d", id);
        if(SQLQueryNoData(s_temp)){
            Format(s_temp, sizeof(s_temp), "DELETE FROM `events` WHERE `report_id` = %d", id);
            SQLQueryNoData(s_temp);
            Format(s_temp, sizeof(s_temp), "DELETE FROM `messages` WHERE `report_id` = %d", id);
            SQLQueryNoData(s_temp);
            CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Delete Report Successful", id);
            if(!StrEqual(s_webhook, "")){
                char s_temp_2[256];
                DiscordWebHook hook = new DiscordWebHook(s_webhook);
                hook.SlackMode = true;
                MessageEmbed Embed = new MessageEmbed();
                Format(s_temp, sizeof(s_temp), "%s ★ %t", s_tag, "Advanced Report");
                Embed.SetAuthor(s_temp);
                Embed.SetAuthorLink(s_plugin_url);
                Embed.SetAuthorIcon(s_plugin_image);
                Embed.SetColor("#FF4000");
                Embed.SetThumb("https://csgo-turkiye.com/assets/plugin_images/advanced-report/deletereport.png");
                Format(s_temp, sizeof(s_temp), "%t", "Delete Report Title");
                Embed.SetTitle(s_temp);
                Format(s_temp, sizeof(s_temp), "%t", "Delete Report ID Title");
                Format(s_temp_2, sizeof(s_temp_2), "%t", "Delete Report ID Value", id);
                Embed.AddField(s_temp, s_temp_2, true);
                FormatTime(s_temp, sizeof(s_temp), "%d.%m.%Y %X", GetTime());
                char s_steam_id[32], s_username[32];
                if(!GetClientAuthId(client, AuthId_Steam2, s_steam_id, sizeof(s_steam_id)))Format(s_steam_id, sizeof(s_steam_id), "%t", "Unknown Steam ID"); 
                if(!GetClientName(client, s_username, sizeof(s_username)))Format(s_username, sizeof(s_username), "%t", "Unnamed");
                Format(s_temp, sizeof(s_temp), "%t", "Status Update Footer", s_username, s_steam_id, s_temp);
                Embed.SetFooter(s_temp);
                Embed.SetFooterIcon("https://csgo-turkiye.com/assets/plugin_images/advanced-report/user.png");  
                hook.Embed(Embed);
                hook.Send();
                delete hook;
            }
        }else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Delete Error"); 
    }else CPrintToChat(client, "%s%s %t", s_tag_color, s_tag, "Report Delete Found Error");       
}

bool ClientControl(int client){
    if(client == 0 || IsValidClient(client))
        if(client == 0 || CheckAdminFlag(client, s_flags))return true;
        else ReplyToCommand(client, "%s %t", s_tag, "CheckAdminFlag Error");
    return false;
}

Action GetReportCount(Handle hTimer)
{
    char s_temp[256];
    for (int i = 1; i <= MaxClients; i++)if (IsValidClient(i)){
        if(GetClientAuthId(i, AuthId_Steam2, s_temp, sizeof(s_temp)))
        Format(s_temp, sizeof(s_temp), "SELECT COUNT(*) FROM `reports` WHERE `steam_id`='%s' and `status` = %d", s_temp, 2);
        int i_count = SQLFirstDataInt(s_temp);
        if(i_count>0) CPrintToChat(i, "%s%s %t", s_tag_color, s_tag, "Client Report Count 2", i_count);
        Format(s_temp, sizeof(s_temp), "SELECT COUNT(*) FROM `reports` WHERE `steam_id`='%s' and `status` = %d", s_temp, 1);
        i_count = SQLFirstDataInt(s_temp);
        if(i_count>0) CPrintToChat(i, "%s%s %t", s_tag_color, s_tag, "Client Report Count 1", i_count);
        if(CheckAdminFlag(i, s_flags)){
            Format(s_temp, sizeof(s_temp), "SELECT COUNT(*) FROM `reports` WHERE `status` = %d", 1);
            i_count = SQLFirstDataInt(s_temp);
            if(i_count>0) CPrintToChat(i, "%s%s %t", s_tag_color, s_tag, "Admin Report Count", i_count);
        }
    }
}

bool IsThereRecord(char[] query)
{
    bool b_status =  false;
    DBResultSet DBRS_Query = SQL_Query(h_database, query);
    if (DBRS_Query == INVALID_HANDLE || DBRS_Query == null)
    {
        char s_error[255];
        SQL_GetError(h_database, s_error, sizeof(s_error));
        DatabaseQueryError(s_error, query);
    }else if (SQL_GetRowCount(DBRS_Query) || SQL_FetchRow(DBRS_Query)) b_status = true;
    delete DBRS_Query;
    return b_status;
}

int SQLQueryIDData(char[] query)
{
    if (!SQL_FastQuery(h_database, query))
    {
        char s_error[255];
        SQL_GetError(h_database, s_error, sizeof(s_error));
        DatabaseQueryError(s_error, query);
        return 0;
    }
    return SQL_GetInsertId(h_database);
}

bool SQLQueryNoData(char[] query)
{
    if (!SQL_FastQuery(h_database, query))
    {
        char s_error[255];
        SQL_GetError(h_database, s_error, sizeof(s_error));
        DatabaseQueryError(s_error, query);
        return false;
    }
    return true;
}

int SQLFirstDataInt(char[] query)
{
    int i_time =  0;
    DBResultSet DBRS_Query = SQL_Query(h_database, query);
    if (DBRS_Query == INVALID_HANDLE || DBRS_Query == null)
    {
        char s_error[255];
        SQL_GetError(h_database, s_error, sizeof(s_error));
        DatabaseQueryError(s_error, query);
    }else if (SQL_GetRowCount(DBRS_Query) || SQL_FetchRow(DBRS_Query)) i_time = SQL_FetchInt(DBRS_Query, 0);
    delete DBRS_Query;
    return i_time;
}

stock void DiscordSQL_EscapeString(char[] string, int maxlen)
{
    ReplaceString(string, maxlen, "@", "＠");
    ReplaceString(string, maxlen, "'", "＇");
    ReplaceString(string, maxlen, "\"", "＂");
    TrimString(string);
    SQL_EscapeString(h_database, string, string, maxlen);
}

bool GetCommunityID(char[] AuthID, char[] FriendID, int size)
{
	if (strlen(AuthID) < 11 || AuthID[0] != 'S' || AuthID[6] == 'I')
	{
		FriendID[0] = 0;
		return false;
	}
	int iUpper = 765611979;
	int iFriendID = StringToInt(AuthID[10]) * 2 + 60265728 + AuthID[8] - 48;
	int iDiv = iFriendID / 100000000;
	int iIdx = 9 - (iDiv ? iDiv / 10 + 1:0);
	iUpper += iDiv;
	IntToString(iFriendID, FriendID[iIdx], size - iIdx);
	iIdx = FriendID[9];
	IntToString(iUpper, FriendID, size);
	FriendID[9] = iIdx;
	return true;
}

void DatabaseQueryError(char[] error, char[] query){
    PrintToServer("%s %t", s_tag, "Database Query Error", error, query);
    LogError("%s %t", s_tag, "Database Query Error", error, query);
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
    if(IsValidClient(client) && c_say_type[client]!='0'){
        if(GetTime() <= i_client_temp2[client]){
            if(!StrEqual(sArgs, "x", false)){
                char s_temp[255];
                strcopy(s_temp, sizeof(s_temp), sArgs);
                if(c_say_type[client]=='1') AddReport(client, s_temp);
                else if(c_say_type[client]=='2') SendMessage(client, s_temp);
                else if(c_say_type[client]=='3') DetailAddBan(client, s_temp);
            }
        }
        c_say_type[client]= '0';
        i_client_temp2[client] = -1;
        return Plugin_Handled;
    }
    return Plugin_Continue;
}