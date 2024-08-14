#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <shavit>
#include <dhooks>

#define LEFT 0
#define RIGHT 1
#define YAW 1

ConVar g_hSpecialString;
DynamicHook g_hTeleportDhook;

char g_sSpecialString[stylestrings_t::sSpecialString];

float g_fLastAngles[MAXPLAYERS + 1][3];
float g_fYawDiff[MAXPLAYERS + 1];

int g_iTurnDir[MAXPLAYERS + 1];
int g_iGroundTicks[MAXPLAYERS + 1];
int g_iTicksSinceTeleport[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "Sync style for shavit.",
	author = "nimmy",
	description = "Provides sync style.",
	version = "1.2.0",
	url = "https://github.com/Nimmy2222/shavit-syncstyle"
};

public void OnPluginStart()
{
	g_hSpecialString = CreateConVar("autostrafer", "autosync", "Special string value to use in shavit-styles.cfg"); //not changing cvar name since its already in cfgs
	g_hSpecialString.AddChangeHook(ConVar_OnSpecialStringChanged);
	g_hSpecialString.GetString(g_sSpecialString, sizeof(g_sSpecialString));
	InitializeTeleportDHook();
	AutoExecConfig();

	for(int i = 0; i < MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			OnClientPutInServer(i);
		}
	}
}

void InitializeTeleportDHook()
{
	Handle gamedataConf = LoadGameConfigFile("sdktools.games");
	if (gamedataConf == INVALID_HANDLE)
	{
		LogError("Shavit-Syncstyle: Couldn't load Gamedata: sdktools.games");
	}

	int offset = GameConfGetOffset(gamedataConf, "Teleport");
	if (offset == -1)
	{
		LogError("Shavit-Syncstyle: Couldn't load Teleport DHook.");
	}

	g_hTeleportDhook = new DynamicHook(offset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity);
	g_hTeleportDhook.AddParam(HookParamType_VectorPtr);
	g_hTeleportDhook.AddParam(HookParamType_VectorPtr);
	g_hTeleportDhook.AddParam(HookParamType_VectorPtr);
	delete gamedataConf;
}

public MRESReturn DHooks_OnTeleport(int client, Handle hParams)
{
	g_iTicksSinceTeleport[client] = 0;
	return MRES_Ignored;
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}
	g_hTeleportDhook.HookEntity(Hook_Post, client, DHooks_OnTeleport);

	if(!g_hTeleportDhook)
	{
		LogError("Failed to Dhook Teleport on client %i.", client);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if(!IsValidClient(client, true) || !IsAutostrafeStyle(Shavit_GetBhopStyle(client)))
	{
		return Plugin_Continue;
	}

	MoveType movetype = GetEntityMoveType(client);
	if(movetype == MOVETYPE_NONE || movetype == MOVETYPE_NOCLIP || movetype == MOVETYPE_LADDER || GetEntProp(client, Prop_Data, "m_nWaterLevel") >= 2)
	{
		return Plugin_Continue;
	}

	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		g_iGroundTicks[client]++;
		if ((buttons & IN_JUMP) > 0 && g_iGroundTicks[client] == 1)
		{
			g_iGroundTicks[client] = 0;
		}
	}
	else
	{
		g_iGroundTicks[client] = 0;
	}

	g_fYawDiff[client] = GetAngleDiff(angles[YAW], g_fLastAngles[client][YAW]);
	g_iTurnDir[client] = g_fYawDiff[client] > 0 ? LEFT:RIGHT;

	float temp[3];
	for(int i = 0; i < 3; i++)
	{
		temp[i] = g_fLastAngles[client][i];
		g_fLastAngles[client][i] = angles[i];
		angles[i] = temp[i];
	}

	if(g_iGroundTicks[client] == 0 && FloatAbs(g_fYawDiff[client]) > 0.01 && g_iTicksSinceTeleport[client] > 8 && !IsSurfing(client))
	{
		if(g_iTurnDir[client] == RIGHT)
		{
			vel[1] = 400.0;
			buttons |= IN_MOVERIGHT;
			buttons &= ~IN_MOVELEFT;
		}
		else if(g_iTurnDir[client] == LEFT)
		{
			vel[1] = -400.0;
			buttons |= IN_MOVELEFT;
			buttons &= ~IN_MOVERIGHT;
		}
	}
	g_iTicksSinceTeleport[client]++;
	return Plugin_Changed;
}

public void ConVar_OnSpecialStringChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.GetString(g_sSpecialString, sizeof(g_sSpecialString));
}

//thanks shavit tas
bool IsSurfing(int client)
{
	float fPosition[3];
	GetClientAbsOrigin(client, fPosition);

	float fEnd[3];
	fEnd = fPosition;
	fEnd[2] -= 64.0;

	float fMins[3];
	GetEntPropVector(client, Prop_Send, "m_vecMins", fMins);

	float fMaxs[3];
	GetEntPropVector(client, Prop_Send, "m_vecMaxs", fMaxs);

	Handle hTR = TR_TraceHullFilterEx(fPosition, fEnd, fMins, fMaxs, MASK_PLAYERSOLID, TRFilter_NoPlayers, client);

	if(TR_DidHit(hTR))
	{
	    float fNormal[3];
	    TR_GetPlaneNormal(hTR, fNormal);
	    delete hTR;
	    // If the plane normal's Z axis is 0.7 or below (alternatively, -0.7 when upside-down) then it's a surf ramp.
	    return (-0.7 <= fNormal[2] <= 0.7);
	}

	delete hTR;
	return false;
}

bool TRFilter_NoPlayers(int entity, int mask, any data)
{
	return (entity != view_as<int>(data) || (entity < 1 || entity > MaxClients));
}

bool IsAutostrafeStyle(int style)
{
    char sSpecial[256];
    if (style >= 0)
	{
        Shavit_GetStyleStrings(style, sSpecialString, sSpecial, sizeof(sSpecial));
        if(StrContains(sSpecial, g_sSpecialString, false) != -1)
		{
			return true;
		}

    }
    return false;
}
