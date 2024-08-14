#include <cstrike>
#include <sdktools>

#pragma newdecls required
#pragma semicolon 1

enum struct weapon_t {
	char name[256];
	int slot;
}

weapon_t gS_WeaponCommands[] = {
	{"sm_ak47",      CS_SLOT_PRIMARY},
	{"sm_aug",       CS_SLOT_PRIMARY},
	{"sm_awp",       CS_SLOT_PRIMARY},
	{"sm_famas",     CS_SLOT_PRIMARY},
	{"sm_g3sg1",     CS_SLOT_PRIMARY},
	{"sm_galil",     CS_SLOT_PRIMARY},
	{"sm_m249",      CS_SLOT_PRIMARY},
	{"sm_m3",        CS_SLOT_PRIMARY},
	{"sm_m4a1",      CS_SLOT_PRIMARY},
	{"sm_mac10",     CS_SLOT_PRIMARY},
	{"sm_mp5navy",   CS_SLOT_PRIMARY},
	{"sm_p90",       CS_SLOT_PRIMARY},
	{"sm_scout",     CS_SLOT_PRIMARY},
	{"sm_sg550",     CS_SLOT_PRIMARY},
	{"sm_sg552",     CS_SLOT_PRIMARY},
	{"sm_tmp",       CS_SLOT_PRIMARY},
	{"sm_ump45",     CS_SLOT_PRIMARY},
	{"sm_xm1014",    CS_SLOT_PRIMARY},
	{"sm_deagle",    CS_SLOT_SECONDARY},
	{"sm_elite",     CS_SLOT_SECONDARY},
	{"sm_fiveseven", CS_SLOT_SECONDARY},
	{"sm_glock",     CS_SLOT_SECONDARY},
	{"sm_p228",      CS_SLOT_SECONDARY},
	{"sm_usp",       CS_SLOT_SECONDARY},
	{"sm_knife",     CS_SLOT_KNIFE}
};

public Plugin myinfo =
{
	name = "Give Weapons",
	author = "Eric",
	description = "Weapon commands for Counter-Strike: Source",
	version = "1.1.0",
	url = "http://steamcommunity.com/id/-eric"
};

public void OnPluginStart()
{
	for (int i = 0; i < sizeof(gS_WeaponCommands); i++)
	{
		RegConsoleCmd(gS_WeaponCommands[i].name, Command_GiveWeapon);
	}
}

public Action Command_GiveWeapon(int client, int args)
{
	if (!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if (!IsPlayerAlive(client))
	{
		PrintToChat(client, "You must be alive to use this command.");
		return Plugin_Handled;
	}

	char weapon[32];
	GetCmdArg(0, weapon, sizeof(weapon));

	for (int i = 0; i < sizeof(gS_WeaponCommands); i++)
	{
		if (StrEqual(weapon, gS_WeaponCommands[i].name))
		{
			ReplaceString(weapon, sizeof(weapon), "sm_", "weapon_");
			GiveWeapon(client, weapon, gS_WeaponCommands[i].slot);
			break;
		}
	}

	return Plugin_Handled;
}

void GiveWeapon(int client, const char[] weapon, int slot)
{
	int entity = GetPlayerWeaponSlot(client, slot);

	if (entity != INVALID_ENT_REFERENCE)
	{
		RemovePlayerItem(client, entity);
		RemoveEntity(entity);
	}

	GivePlayerItem(client, weapon);
}

bool IsValidClient(int client)
{
	return (0 < client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}
