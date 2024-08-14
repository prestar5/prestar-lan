
#define PLUGIN_NAME           "GCMeasure"
#define PLUGIN_AUTHOR         "GameChaos"
#define PLUGIN_DESCRIPTION    "An advanced measuring tool."
#define PLUGIN_VERSION        "1.00"
#define PLUGIN_URL            "https://bitbucket.org/GameChaos/gcmeasure"

#define PREFIX					"{default}[{olive}GC{default}]"

#define C_WHITE					{ 255, 255, 255, 255 }
#define C_GREEN					{   0, 255,   0, 255 }
#define C_RED					{ 255,   0,   0, 255 }
#define C_YELLOW				{ 255,   255,   0, 255 }

#define MINS					view_as<float>({ -16.0, -16.0, 0.0 })
#define MAXS					view_as<float>({ 16.0, 16.0, 0.0 })

#define MAX_DISTANCE			56756.0

#include <sourcemod>
#include <sdktools>
#include <gamechaos>
#include <colors>

#pragma semicolon 1
#pragma newdecls required

enum
{
	MEASURETYPE_HULL,
	MEASURETYPE_POINT,
	MEASURETYPE_GAP,
	MEASURETYPE_COUNT
};

char g_szMeasureType[MEASURETYPE_COUNT][] =
{
	"Hull",
	"Point",
	"Gap"
};

int g_iBeam;

int g_iMeasureType[MAXPLAYERS + 1];
float g_fMeasurePoint1[MAXPLAYERS + 1][3];
float g_fMeasurePoint2[MAXPLAYERS + 1][3];

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_gcmeasure", Command_SmGcmeasure);
}

public void OnConfigsExecuted()
{
	g_iBeam = PrecacheModel("materials/sprites/laser.vmt", true);
}

public Action Command_SmGcmeasure(int client, int args)
{
	if (!IsValidClientExt(client, true))
	{
		return Plugin_Handled;
	}
	
	Showmenu_GCMeasure(client);
	
	return Plugin_Handled;
}

bool MeasurePoint(int client, int measureType, float result[3])
{
	float life = 3.0;
	float width = 2.0;
	switch (measureType)
	{
		case MEASURETYPE_HULL:
		{
			float fOrigin[3];
			GetClientEyePosition(client, fOrigin);
			float fAngles[3];
			GetClientEyeAngles(client, fAngles);
			if (TraceHullDirection(fOrigin, fAngles, MINS, MAXS, result, MAX_DISTANCE))
			{
				TE_SendBeamRectangle(client, result, MINS, MAXS, g_iBeam, 0, life, width, C_WHITE);
				// make a nice cross
				TE_SendBeamCross(client, result, g_iBeam, 0, life, width, C_GREEN, width);
				return true;
			}
			return false;
		}
		case MEASURETYPE_POINT:
		{
			if (GetEyeRayPosition(client, result))
			{
				TE_SendBeamCross(client, result, g_iBeam, 0, life, width, C_GREEN, width);
				return true;
			}
			return false;
		}
		case MEASURETYPE_GAP:
		{
			GetEyeRayPosition(client, result);
			
			float start[3];
			float angle[3];
			
			GetClientEyePosition(client, start);
			GetClientEyeAngles(client, angle);
			
			Handle hTrace = TR_TraceRayFilterEx(start, angle, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer, client);
			
			if (!TR_DidHit(hTrace))
			{
				CloseHandle(hTrace);
				return false;
			}
			
			// point 1
			TR_GetEndPosition(result, hTrace);
			
			// point 2
			float normal[3];
			TR_GetPlaneNormal(hTrace, normal);
			CloseHandle(hTrace);
			
			GetVectorAngles(normal, angle);
			TR_TraceRayFilter(result, angle, MASK_PLAYERSOLID, RayType_Infinite, TraceEntityFilterPlayer, client);
			
			if (!TR_DidHit())
			{
				return false;
			}
			TR_GetEndPosition(g_fMeasurePoint2[client]);
			
			TE_SetupBeamPoints(g_fMeasurePoint1[client], g_fMeasurePoint2[client], g_iBeam, 0, 0, 0, life, width, width, 0, 0.0, C_WHITE, 0);
			TE_SendToClient(client);
			
			TE_SendBeamCross(client, g_fMeasurePoint1[client], g_iBeam, 0, life, width, C_GREEN, width);
			TE_SendBeamCross(client, g_fMeasurePoint2[client], g_iBeam, 0, life, width, C_RED, width);
			return true;
		}
	}
	return false;
}

void CalculateDistance(int client)
{
	if (GetVectorLength(g_fMeasurePoint1[client], true) == 0.0
		|| GetVectorLength(g_fMeasurePoint2[client], true) == 0.0)
	{
		return;
	}
	
	float life = 3.0;
	float width = 2.0;
	
	if (g_iMeasureType[client] == MEASURETYPE_HULL)
	{
		TE_SendBeamRectangle(client, g_fMeasurePoint1[client], MINS, MAXS, g_iBeam, 0, life, width, C_WHITE);
		TE_SendBeamRectangle(client, g_fMeasurePoint2[client], MINS, MAXS, g_iBeam, 0, life, width, C_WHITE);
	}
	
	TE_SetupBeamPoints(g_fMeasurePoint1[client], g_fMeasurePoint2[client], g_iBeam, 0, 0, 0, life, width, width, 0, 0.0, C_YELLOW, 0);
	TE_SendToClient(client);
	
	TE_SendBeamCross(client, g_fMeasurePoint1[client], g_iBeam, 0, life, width, C_GREEN, width);
	TE_SendBeamCross(client, g_fMeasurePoint2[client], g_iBeam, 0, life, width, C_RED, width);
	
	// chat
	float fDistance = GetVectorDistance(g_fMeasurePoint1[client], g_fMeasurePoint2[client]);
	float fHorDistance = GetVectorHorDistance(g_fMeasurePoint1[client], g_fMeasurePoint2[client]);
	float fVerDistance = FloatAbs(g_fMeasurePoint1[client][2] - g_fMeasurePoint2[client][2]);
	
	CPrintToChat(client, "%s {grey}Distance: [{lime}%.2f{grey} | Horizontal: {lime}%.2f{grey} | Vertical: {lime}%.2f{grey}]", PREFIX, fDistance, fHorDistance, fVerDistance);
}

void ResetVars(int client)
{
	g_fMeasurePoint1[client] = NULL_VECTOR;
	g_fMeasurePoint2[client] = NULL_VECTOR;
}

// =======
//  MENUS
// =======

public void Showmenu_GCMeasure(int client)
{
	Menu menu = new Menu(Menu_GCMeasure, MENU_ACTIONS_ALL);
	menu.Pagination = MENU_NO_PAGINATION;
	menu.SetTitle("GCMeasure");
	menu.AddItem("0", "Point #1");
	menu.AddItem("1", "Point #2");
	menu.AddItem("2", "Get distance");
	
	char szMeasureType[32];
	Format(szMeasureType, sizeof(szMeasureType), "Measure type: %s", g_szMeasureType[g_iMeasureType[client]]);
	menu.AddItem("3", szMeasureType);
	
	// end
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Menu_GCMeasure(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char szInfo[32];
			menu.GetItem(param2, szInfo, sizeof(szInfo));
			int iInfo = StringToInt(szInfo);
			
			switch (iInfo)
			{
				// point 1
				case 0:
				{
					MeasurePoint(param1, g_iMeasureType[param1], g_fMeasurePoint1[param1]);
					Showmenu_GCMeasure(param1);
				}
				// point 2
				case 1:
				{
					MeasurePoint(param1, g_iMeasureType[param1], g_fMeasurePoint2[param1]);
					Showmenu_GCMeasure(param1);
				}
				// Get distance
				case 2:
				{
					CalculateDistance(param1);
					Showmenu_GCMeasure(param1);
				}
				// measure type
				case 3:
				{
					g_iMeasureType[param1]++;
					g_iMeasureType[param1] %= MEASURETYPE_COUNT;
					Showmenu_GCMeasure(param1);
				}
			}
		}
		
		case MenuAction_DrawItem:
		{
			int style;
			char szInfo[32];
			menu.GetItem(param2, szInfo, sizeof(szInfo), style);
			int iInfo = StringToInt(szInfo);
			
			if (g_iMeasureType[param1] != MEASURETYPE_GAP)
			{
				return style;
			}
			
			if (iInfo == 1)
			{
				return ITEMDRAW_DISABLED;
			}
		}
		
		case MenuAction_Cancel:
		{
			ResetVars(param1);
		}
		
		case MenuAction_End:
		{
			ResetVars(param1);
			delete menu;
		}
	}
	return 0;
}