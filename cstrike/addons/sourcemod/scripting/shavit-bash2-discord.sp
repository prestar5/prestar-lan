#include <bash2>
#include <json>
#include <SteamWorks>

#pragma newdecls required
#pragma semicolon 1

ConVar gCV_Webhook;
ConVar gCV_OnlyBans;
ConVar gCV_UseEmbeds;

public Plugin myinfo =
{
	name = "[BASH] Discord",
	author = "Eric",
	description = "",
	version = "1.1.0",
	url = "https://github.com/Nimmy2222/bash2"
};

public void OnPluginStart()
{
	gCV_Webhook = CreateConVar("bash_discord_webhook", "", "Discord webhook.", FCVAR_PROTECTED);
	gCV_OnlyBans = CreateConVar("bash_discord_only_bans", "0", "Only send ban messages and no logs.", _, true, 0.0, true, 1.0);
	gCV_UseEmbeds = CreateConVar("bash_discord_use_embeds", "1", "Send embed messages.", _, true, 0.0, true, 1.0);
	AutoExecConfig(true, "bash-discord", "sourcemod");
}

public void Bash_OnDetection(int client, char[] buffer)
{
	if (gCV_OnlyBans.BoolValue)
	{
		return;
	}

	if (gCV_UseEmbeds.BoolValue)
	{
		FormatEmbedMessage(client, buffer);
	}
	else
	{
		FormatMessage(client, buffer);
	}
}

public void Bash_OnClientBanned(int client)
{
	if (gCV_UseEmbeds.BoolValue)
	{
		FormatEmbedMessage(client, "Banned for cheating.");
	}
	else
	{
		FormatMessage(client, "Banned for cheating.");
	}
}

void FormatEmbedMessage(int client, char[] buffer)
{
	char hostname[128];
	FindConVar("hostname").GetString(hostname, sizeof(hostname));

	char steamId[32];
	GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId));

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	SanitizeName(name);

	char player[512];
	Format(player, sizeof(player), "[%s](http://www.steamcommunity.com/profiles/%s)", name, steamId);

	// https://discord.com/developers/docs/resources/channel#embed-object
	// https://discord.com/developers/docs/resources/channel#embed-object-embed-field-structure
	// https://discord.com/developers/docs/resources/webhook#webhook-object-jsonform-params
	JSON_Object playerField = new JSON_Object();
	playerField.SetString("name", "Player");
	playerField.SetString("value", player);
	playerField.SetBool("inline", true);

	JSON_Object eventField = new JSON_Object();
	eventField.SetString("name", "Event");
	eventField.SetString("value", buffer);
	eventField.SetBool("inline", true);

	JSON_Array fields = new JSON_Array();
	fields.PushObject(playerField);
	fields.PushObject(eventField);

	JSON_Object embed = new JSON_Object();
	embed.SetString("title", hostname);
	embed.SetString("color", "16720418");
	embed.SetObject("fields", fields);

	JSON_Array embeds = new JSON_Array();
	embeds.PushObject(embed);

	JSON_Object json = new JSON_Object();
	json.SetString("username", "BASH 2.0");
	json.SetObject("embeds", embeds);

	SendMessage(json);

	json_cleanup_and_delete(json);
}

void FormatMessage(int client, char[] buffer)
{
	char hostname[128];
	FindConVar("hostname").GetString(hostname, sizeof(hostname));

	char steamId[32];
	GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId));

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	SanitizeName(name);

	char content[1024];
	Format(content, sizeof(content), "[%s](http://www.steamcommunity.com/profiles/%s) %s", name, steamId, buffer);

	// Suppress Discord mentions and embeds.
	// https://discord.com/developers/docs/resources/channel#allowed-mentions-object
	// https://discord.com/developers/docs/resources/channel#message-object-message-flags
	JSON_Array parse = new JSON_Array();
	JSON_Object allowedMentions = new JSON_Object();
	allowedMentions.SetObject("parse", parse);

	JSON_Object json = new JSON_Object();
	json.SetString("username", hostname);
	json.SetString("content", content);
	json.SetObject("allowed_mentions", allowedMentions);
	json.SetInt("flags", 4);

	SendMessage(json);

	json_cleanup_and_delete(json);
}

void SendMessage(JSON_Object json)
{
	char webhook[256];
	gCV_Webhook.GetString(webhook, sizeof(webhook));

	if (webhook[0] == '\0')
	{
		LogError("Discord webhook is not set.");
		return;
	}

	char body[2048];
	json.Encode(body, sizeof(body));

	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, webhook);
	SteamWorks_SetHTTPRequestRawPostBody(request, "application/json", body, strlen(body));
	SteamWorks_SetHTTPRequestAbsoluteTimeoutMS(request, 15000);
	SteamWorks_SetHTTPCallbacks(request, OnMessageSent);
	SteamWorks_SendHTTPRequest(request);
}

public void OnMessageSent(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode, DataPack pack)
{
	if (failure || !requestSuccessful || statusCode != k_EHTTPStatusCode204NoContent)
	{
		LogError("Failed to send message to Discord. Response status: %d.", statusCode);
	}

	delete request;
}

void SanitizeName(char[] name)
{
	ReplaceString(name, MAX_NAME_LENGTH, "(", "", false);
	ReplaceString(name, MAX_NAME_LENGTH, ")", "", false);
	ReplaceString(name, MAX_NAME_LENGTH, "]", "", false);
	ReplaceString(name, MAX_NAME_LENGTH, "[", "", false);
}
