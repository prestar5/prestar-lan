#include <sdktools>
#include <sdkhooks>
#include <shavit/core>

#pragma semicolon 1

public Plugin myinfo = {
	name = "LandFix",
	author = "Haze",
	description = "",
	version = "1.0",
	url = ""
}

#define CHERRY 0
#define HAZE 1

int gI_TicksOnGround[MAXPLAYERS + 1];
int gI_Jump[MAXPLAYERS + 1];

bool gB_LandfixType[MAXPLAYERS + 1] = {false, ...};
bool gB_Enabled[MAXPLAYERS+1] = {false, ...};

public void OnPluginStart()
{
	RegConsoleCmd("sm_landfix", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_lfix", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_land", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_64fix", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_64", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_landfixtype", Command_LandFixType, "Landfix Type");
	RegConsoleCmd("sm_lfixtype", Command_LandFixType, "Landfix Type");

	HookEvent("player_jump", PlayerJump);

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
	AutoExecConfig();
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_GroundEntChangedPost, OnGroundChange);
	gI_Jump[client] = 0;
	gB_Enabled[client] = false;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(!IsClientConnected(client) || !IsPlayerAlive(client) || IsFakeClient(client) || !gB_Enabled[client])
	{
		return Plugin_Continue;
	}

	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		if(gI_TicksOnGround[client] > 15)
		{
			gI_Jump[client] = 0;
		}
		gI_TicksOnGround[client]++;

		if(buttons & IN_JUMP && gI_TicksOnGround[client] == 1)
		{
			gI_TicksOnGround[client] = 0;
		}
	}
	else
	{
		gI_TicksOnGround[client] = 0;
	}

	return Plugin_Continue;
}

public PlayerJump(Handle event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);

	if(!gB_Enabled[client] || gB_LandfixType[client] == view_as<bool>(HAZE))
	{
		return;
	}

	if(IsFakeClient(client))
	{
		return;
	}

	if(gB_Enabled[client])
	{
		gI_Jump[client]++;
		if(gI_Jump[client] > 1)
		{
			CreateTimer(0.1, TimerFix, client);
		}
	}
}

public void OnGroundChange(int client)
{
	if(!gB_Enabled[client])
	{
		return;
	}

	if(gB_LandfixType[client])
	{
		RequestFrame(DoLandFix, client);
	}
}

public Action Command_LandFixType(int client, int args) {
	if(client == 0)
	{
		return Plugin_Handled;
	}

	gB_LandfixType[client] = !gB_LandfixType[client];
	Shavit_PrintToChat(client, "Land Fix Type: %s.", gB_LandfixType[client] ? "Haze" : "Cherry");
	return Plugin_Handled;
}

public Action Command_LandFix(int client, int args) {
	if(client == 0)
	{
		return Plugin_Handled;
	}

	gB_Enabled[client] = !gB_Enabled[client];
	Shavit_PrintToChat(client, "Land Fix: %s.", gB_Enabled[client] ? "On" : "Off");
	return Plugin_Handled;
}

//Thanks MARU for the idea/http://steamcommunity.com/profiles/76561197970936804
float GetGroundUnits(int client)
{
	if (!IsPlayerAlive(client) || GetEntityMoveType(client) != MOVETYPE_WALK || GetEntProp(client, Prop_Data, "m_nWaterLevel") > 1)
	{
		return 0.0;
	}

	float origin[3], originBelow[3], landingMins[3], landingMaxs[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
	GetEntPropVector(client, Prop_Data, "m_vecMins", landingMins);
	GetEntPropVector(client, Prop_Data, "m_vecMaxs", landingMaxs);

	originBelow[0] = origin[0];
	originBelow[1] = origin[1];
	originBelow[2] = origin[2] - 2.0;

	TR_TraceHullFilter(origin, originBelow, landingMins, landingMaxs, MASK_PLAYERSOLID, PlayerFilter, client);

	if(TR_DidHit())
	{
		TR_GetEndPosition(originBelow, null);
		float defaultheight = originBelow[2] - RoundToFloor(originBelow[2]);

		if(defaultheight > 0.03125)
		{
			defaultheight = 0.03125;
		}

		float heightbug = origin[2] - originBelow[2] + defaultheight;
		return heightbug;
	}
	else
	{
		return 0.0;
	}
}

void DoLandFix(int client)
{
	if(GetEntPropEnt(client, Prop_Data, "m_hGroundEntity") != -1)
	{
		float difference = (1.50 - GetGroundUnits(client)), origin[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
		origin[2] += difference;
		SetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
	}
}

Action TimerFix(Handle timer, any client)
{
	float cll[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", cll);
	cll[2] += 1.0;
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, cll);

	CreateTimer(0.05, TimerFix2, client);
	return Plugin_Handled;
}

Action TimerFix2(Handle timer, any client)
{
	if(!(GetEntityFlags(client) & FL_ONGROUND))
	{
		float cll[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", cll);
		cll[2] -= 1.5;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, cll);
	}
	return Plugin_Handled;
}

public bool PlayerFilter(int entity, int mask)
{
	return !(1 <= entity <= MaxClients);
}
