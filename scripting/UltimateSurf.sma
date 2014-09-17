/*
	AMX Mod X script.

	This plugin is free software; you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation; either version 2 of the License, or (at
	your option) any later version.
	
	This plugin is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
	General Public License for more details.
	
	You should have received a copy of the GNU General Public License
	along with this plugin; if not, write to the Free Software Foundation,
	Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA.
*/

/*
	UltimateSurf
	by tonykaram1993
	
	Please check the main thread of this plugin for much more information. You can
	do so in here: https://forums.alliedmods.net/showthread.php?t=212867
	
	Features:
	---------
	
	Respawn with delay		tonykaram1993
	Spawn protection with timer	tonykaram1993
	Weapons respawn with delay	ConnorMcLeod
	Remove dropped weapons		ConnorMcLeod
	Unlimited bp ammo		New-Era
	Semiclip			coderiz
	Strip on player spawn		tonykaram1993
	Buy zone damage blocker		ConnorMcLeod
	I aim good			XxAvalanchexX
	Player trail			jim_yang
	Speedometer			AcidoX
*/

/*
	Change Log:
	
	+ something added/new
	- something removed
	* important note
	x bug fix or improvement
	
	v0.0.1	beta:	* plugin written
	
	v0.0.2	beta:	x fixed stupid mistake of caching pcvars before there were even initiated
			+ added condition to display trail if player is going faster than 500.0 u/s
	
	v0.1.0	beta:	+ added pragma semicolon 1
			+ added config execution as I have forgot about that :P
			+ plugin will only run on surf maps from now (maps starting with surf_)
			+ added version checker (to see if the plugin installed is outdated)
			+ added multi language support
			x minor code optimisations
			x added check if user connected in a task as it was forgotten
			+ added info at the end of the sma file
			
	v0.1.1	beta:	+ added a center message that tells the player that his spawn protection is off
*/
#define PLUGIN_VERSION		"0.1.1b"

/* Includes */
#include < amxmodx >
#include < amxmisc >
#include < cstrike >
#include < engine >
#include < hamsandwich >
#include < fakemeta >
#include < sockets >
#include < fun >
#include < xs >

#pragma semicolon 1

/* Defines */
#define SetBit(%1,%2)		(%1 |= (1<<(%2&31)))
#define ClearBit(%1,%2)		(%1 &= ~(1 <<(%2&31)))
#define CheckBit(%1,%2)		(%1 & (1<<(%2&31)))

#define PLUGIN_TOPIC		"/showthread.php?t=212867"
#define PLUGIN_HOST		"forums.alliedmods.net"

/*
	Below is the section where normal people can safely edit
	its values.
	Please if you don't know how to code, refrain from editing
	anything outside the safety zone.
	
	Experienced coders are free to edit what they want, but I
	will not reply to any private messages nor emails about hel-
	ping you with it.
	
	SAFETY ZONE STARTS HERE
*/

/*
	Set this to your maximum number of players your server can
	hold.
*/
#define MAX_PLAYERS		32

/*
	This is where you can specify what is the delay between two thinks
	of the player trail task. Also you can specify the life of the beam
	in seconds.
*/
#define TRAIL_FREQUENCY		Float:0.1
#define BEAM_LIFE		1

/*
	This is where you stop. Editing anything below this point
	might lead to some serious errors, and you will not get any
	support if you do.
	
	SAFETY ZONE ENDS HERE
*/

/* Enumerations */
enum ( ) {
	CVAR_RESPAWN		= 0,
	CVAR_SP,
	CVAR_RESPAWNWEAPONS,
	CVAR_RESPAWNWEAPONS_DELAY,
	CVAR_DELETEWEAPONS,
	CVAR_DELETEWEAPONS_DELAY,
	CVAR_AMMO,
	CVAR_SEMICLIP,
	CVAR_SEMICLIP_TRANS,
	CVAR_AIM,
	CVAR_TRAIL,
	CVAR_FALL_DAMAGE
};

enum ( += 154 ) {
	TASK_RESPAWN		= 154,
	TASK_SP,
	TASK_AD,
	TASK_TRAIL,
	TASK_GETANSWER,
	TASK_CLOSECONNECTION,
	TASK_REMOVE_SEMICLIP
};

/* Constants */
new const g_strPluginName[ ]		= "UltimateSurf";
new const g_strPluginVersion[ ]		= PLUGIN_VERSION;
new const g_strPluginAuthor[ ]		= "tonykaram1993";
new const g_strPluginConfig[ ]		= "UltimateSurf.cfg";

new const g_iWeaponBackpack[ 31 ] = {
	0, 52, 0, 90, 1, 32, 1, 100, 90, 1, 120, 100, 100, 90, 90, 90, 
	100, 120, 30, 120, 200, 32, 90, 120, 90, 2, 35, 90, 90, 0, 100
};

/* Variables */
new g_iPlayerTeam[ MAX_PLAYERS + 1 ];
new g_iNormalTrace[ MAX_PLAYERS + 1 ];
new g_iSPGlow;
new g_iBeamSprite;
new g_iTaskEntity;
new g_iAdvertisement;
new g_iSocket;

/* Booleans */
new bool:g_bNeedToUpdate;
new bool:g_bSemiclip = true;

/* Floats */
new Float:g_fRespawnDelay;
new Float:g_fSPTime;
new Float:g_fRespawnWeaponDelay;
new Float:g_fDeleteWeaponDelay;
new Float:g_fSemiclipTime;

/* Bitsums */
new g_bitIsAlive;
new g_bitIsSolid;
new g_bitIsConnected;
new g_bitIsInBuyzone;
new g_bitHasNoDamage;
new g_bitDoRestore;
new g_bitCvarStatus;
new g_bitDisplaySpeed;
new g_bitDisplayTrail;

/* PCVARs */
new g_pcvarRespawn;
new g_pcvarRespawnDelay;
new g_pcvarSP;
new g_pcvarSPTime;
new g_pcvarSPGlow;
new g_pcvarRespawnWeapons;
new g_pcvarRespawnWeaponsDelay;
new g_pcvarDeleteWeapons;
new g_pcvarDeleteWeaponsDelay;
new g_pcvarAmmo;
new g_pcvarSemiclip;
new g_pcvarSemiclipTrans;
new g_pcvarAim;
new g_pcvarTrail;
new g_pcvarPluginPrefix;
new g_pcvarPluginAdvertisement;
new g_pcvarFallDamage;
new g_pcvarSemiclipTime;

/* Messages */
new g_msgHudSync;

/* Strings */
new g_strData[ 1024 ];
new g_strPluginPrefix[ 32 ];
new g_strSocketVersion[ 16 ];

/* Plugin Natives */
public plugin_init( ) {
	register_plugin( g_strPluginName, g_strPluginVersion, g_strPluginAuthor );
	register_cvar( g_strPluginName, g_strPluginVersion, FCVAR_SERVER | FCVAR_EXTDLL | FCVAR_UNLOGGED | FCVAR_SPONLY );
	register_dictionary( "UltimateSurf.txt" );
	
	g_pcvarRespawn				= register_cvar( "us_respawn",			"1" );
	g_pcvarRespawnDelay			= register_cvar( "us_respawn_delay",		"3.0" );
	g_pcvarSP				= register_cvar( "us_sp",			"1" );
	g_pcvarSPTime				= register_cvar( "us_sp_time",			"3.0" );
	g_pcvarSPGlow				= register_cvar( "us_sp_glow",			"1" );
	g_pcvarRespawnWeapons			= register_cvar( "us_respawnweapons",		"1" );
	g_pcvarRespawnWeaponsDelay		= register_cvar( "us_respawnweapons_delay",	"3.0" );
	g_pcvarDeleteWeapons			= register_cvar( "us_deleteweapons",		"1" );
	g_pcvarDeleteWeaponsDelay		= register_cvar( "us_deleteweapons_delay",	"0.0" );
	g_pcvarAmmo				= register_cvar( "us_ammorefill",		"1" );
	g_pcvarSemiclip				= register_cvar( "us_semiclip",			"1" );
	g_pcvarSemiclipTime			= register_cvar( "us_semiclip_time",		"6.0" );
	g_pcvarSemiclipTrans			= register_cvar( "us_semiclip_transparency",	"1" );
	g_pcvarAim				= register_cvar( "us_aim",			"1" );
	g_pcvarTrail				= register_cvar( "us_trail",			"1" );
	g_pcvarPluginPrefix			= register_cvar( "us_prefix",			"[US]" );
	g_pcvarPluginAdvertisement		= register_cvar( "us_advertisement",		"10" );
	g_pcvarFallDamage			= register_cvar( "us_nofalldamage",		"1" );
	
	/* Config Execution */
	ExecConfig( );
	
	/* Load Cvars for the first time */
	ReloadCvars( );
	
	/* Check Surf Map */
	CheckMap( );
	
	register_clcmd( "say /respawn",		"ClCmd_Respawn" );
	register_clcmd( "say /speed",		"ClCmd_Speed" );
	register_clcmd( "say /version",		"ClCmd_Version" );
	
	register_clcmd( "say_team /respawn",	"ClCmd_Respawn" );
	register_clcmd( "say_team /speed",	"ClCmd_Speed" );
	register_clcmd( "say_team /version",	"ClCmd_Version" );
	
	register_concmd( "amx_reloadcvars",	"ConCmd_ReloadCvars",	ADMIN_CVAR,				" - Reloads all the cvars of the plugin" );
	
	RegisterHam( Ham_Killed,		"player",		"Ham_Killed_Player_Post",		true );
	RegisterHam( Ham_Spawn,			"player",		"Ham_Spawn_Player_Post",		true );
	RegisterHam( Ham_TakeDamage,		"player",		"Ham_TakeDamage_Player_Pre",		false );
	RegisterHam( Ham_Touch,			"armoury_entity",	"Ham_Touch_ArmouryEntity_Post",		true );
	RegisterHam( Ham_Think,			"armoury_entity",	"Ham_Think_ArmouryEntity_Pre",		false );
	
	register_forward( FM_PlayerPreThink,	"Forward_PlayerPreThink",		0 );
	register_forward( FM_PlayerPostThink,	"Forward_PlayerPostThink",		0 );
	register_forward( FM_AddToFullPack,	"Forward_AddToFullPack",		1 );
	register_forward( FM_SetModel,		"Forward_SetModel",			0 );
	register_forward( FM_TraceLine,		"Forward_TraceLine",			1 );
	register_forward( FM_Think,		"Forward_Think",			0 );
	
	register_event( "CurWeapon",		"Event_CurWeapon",			"be", 	"1=1" );
	register_event( "HLTV", 		"Event_HLTV", 				"a", 	"1=0", "2=0" );
	register_event( "StatusIcon", 		"Event_StatusIcon_Show_Buyzone", 	"be", 	"1=1", "2=buyzone" );
	register_event( "StatusIcon", 		"Event_StatusIcon_Hide_Buyzone", 	"be", 	"1=0", "2=buyzone" ); 
	
	SetSpeedometer( );
	g_msgHudSync = CreateHudSyncObj( );
	
	if( g_iAdvertisement ) {
		set_task( floatclamp( float( g_iAdvertisement * 60 ), 60.0, 1800.0 ),	"Task_Advertisement",	TASK_AD, _, _, "b" );
	}
	set_task( TRAIL_FREQUENCY, "Task_PlayerTrail",	TASK_TRAIL, _, _, "b" );
}

public plugin_cfg( ) {
	VersionCheckerSocket( );
}

public plugin_precache( ) {
	g_iBeamSprite	= precache_model( "sprites/smoke.spr" );
}

/* Client Natives */
public client_disconnect( iPlayerID ) {
	ClearBit( g_bitIsAlive,		iPlayerID );
	ClearBit( g_bitIsConnected,	iPlayerID );
	ClearBit( g_bitDisplaySpeed,	iPlayerID );
	ClearBit( g_bitIsInBuyzone, 	iPlayerID );
	ClearBit( g_bitDisplayTrail,	iPlayerID );
	
	g_iNormalTrace[ iPlayerID ] = 0;
}

public client_connect( iPlayerID ) {
	SetBit( g_bitIsConnected,	iPlayerID );
	SetBit( g_bitDisplaySpeed,	iPlayerID );
	
	ClearBit( g_bitIsInBuyzone, 	iPlayerID );
	ClearBit( g_bitDisplayTrail, 	iPlayerID );
	
	g_iNormalTrace[ iPlayerID ] = 0;
}

/* ClCmd */
public ClCmd_Respawn( iPlayerID ) {
	if( !CheckBit( g_bitIsAlive, iPlayerID ) ) {
		Task_RespawnPlayer( TASK_RESPAWN + iPlayerID );
	}
	
	return PLUGIN_HANDLED;
}

public ClCmd_Speed( iPlayerID ) {
	if( CheckBit( g_bitDisplaySpeed, iPlayerID ) ) {
		ClearBit( g_bitDisplaySpeed, iPlayerID );
	} else {
		SetBit( g_bitDisplaySpeed, iPlayerID );
	}
}

public ClCmd_Version( iPlayerID ) {
	Task_Advertisement( );
}

/* ConCmd */
public ConCmd_ReloadCvars( iPlayerID, iLevel, iCid ) {
	if( !cmd_access( iPlayerID, iLevel, iCid, 1 ) ) {
		return PLUGIN_CONTINUE;
	}
	
	if( read_argc( ) > 1 ) {
		console_print( iPlayerID, "%s %L", g_strPluginPrefix, iPlayerID, "ERROR_ARGUMENTS_NUM" );
		
		return PLUGIN_CONTINUE;
	}
	
	ReloadCvars( );
	console_print( iPlayerID, "%s %L", g_strPluginPrefix, iPlayerID, "CVARS_RELOADED" );
	
	return PLUGIN_CONTINUE;
}

/* Ham Hooks */
public Ham_Killed_Player_Post( iVictim, iKiller, iShouldGib ) {
	if( is_user_alive( iVictim ) ) {
		return HAM_IGNORED;
	}
	
	ClearBit( g_bitIsAlive, iVictim );
	
	if( CheckBit( g_bitCvarStatus, CVAR_RESPAWN ) ) {
		set_task( g_fRespawnDelay, "Task_RespawnPlayer", TASK_RESPAWN + iVictim );
	}
	
	return HAM_IGNORED;
}

public Ham_Spawn_Player_Post( iPlayerID ) {
	if( !is_user_alive( iPlayerID ) ) {
		return HAM_IGNORED;
	}
	
	SetBit( g_bitIsAlive, iPlayerID );
	
	StripPlayerWeapons( iPlayerID );
	
	return HAM_IGNORED;
}

public Ham_TakeDamage_Player_Pre( iVictim, iInflictor, iAttacker, Float:fDamage, iDamageBits ) {
	if( CheckBit( g_bitIsInBuyzone, iVictim ) || CheckBit( g_bitHasNoDamage, iVictim ) ) {
		SetHamReturnInteger( 0 );
		
		return HAM_SUPERCEDE;
	}
	
	if( CheckBit( g_bitCvarStatus, CVAR_FALL_DAMAGE ) && iDamageBits == DMG_FALL ) {
		SetHamReturnInteger( 0 );
		
		return HAM_SUPERCEDE;
	}
	
	return HAM_IGNORED;
}

public Ham_Think_ArmouryEntity_Pre( iEnt ) {
	if( pev( iEnt, pev_effects ) & EF_NODRAW ) {
		ExecuteHamB( Ham_CS_Restart, iEnt );
	}
}

public Ham_Touch_ArmouryEntity_Post( iEnt ) {
	if( !CheckBit( g_bitCvarStatus, CVAR_RESPAWNWEAPONS ) ) {
		return HAM_IGNORED;
	}
	
	if( pev( iEnt, pev_effects ) & EF_NODRAW ) {
		set_pev( iEnt, pev_nextthink, get_gametime( ) + g_fRespawnWeaponDelay );
	}
	
	return HAM_IGNORED;
}

/* Forwards */
public Forward_PlayerPreThink( iPlayerID ) {
	if( !CheckBit( g_bitCvarStatus, CVAR_SEMICLIP ) || !g_bSemiclip ) {
		return;
	}
	
	static iLoop, iLastThink;
	
	if( iLastThink > iPlayerID ) {
		FirstThink( );
	}
	
	iLastThink = iPlayerID;
	
	if( !CheckBit( g_bitIsSolid, iPlayerID ) ) {
		return;
	}
	
	static iPlayerTeam;
	iPlayerTeam = g_iPlayerTeam[ iPlayerID ];
	
	for( iLoop = 1; iLoop <= MAX_PLAYERS; iLoop++ ) {
		if( !CheckBit( g_bitIsSolid, iLoop ) || iPlayerID == iLoop ) {
			continue;
		}
		
		if( g_iPlayerTeam[ iLoop ] == iPlayerTeam ) {
			set_pev( iLoop, pev_solid, SOLID_NOT );
			SetBit( g_bitDoRestore, iLoop );
		}
	}
}

public Forward_PlayerPostThink( iPlayerID ) {
	if( !CheckBit( g_bitCvarStatus, CVAR_SEMICLIP ) || !g_bSemiclip ) {
		return;
	}
	
	static iLoop;
	
	for( iLoop = 1; iLoop <= MAX_PLAYERS; iLoop++ ) {
		if( CheckBit( g_bitDoRestore, iLoop ) ) {
			set_pev( iLoop, pev_solid, SOLID_SLIDEBOX );
			ClearBit( g_bitDoRestore, iLoop );
		}
	}
}

public Forward_AddToFullPack( iEs, iE, iEnt, iHost, iHostFlags, iPlayer, pSet ) {
	if( !CheckBit( g_bitCvarStatus, CVAR_SEMICLIP ) || !g_bSemiclip ) {
		return;
	}
	
	if( iPlayer ) {
		if( CheckBit( g_bitIsSolid, iHost ) && CheckBit( g_bitIsSolid, iEnt ) &&
		g_iPlayerTeam[ iHost ] == g_iPlayerTeam[ iEnt ] ) {
			set_es( iEs, ES_Solid, SOLID_NOT );
			
			if( CheckBit( g_bitCvarStatus, CVAR_SEMICLIP_TRANS ) ) {
				set_es( iEs, ES_RenderMode, kRenderTransAlpha );
				set_es( iEs, ES_RenderAmt, floatround( floatclamp( entity_range( iEnt, iHost ), 20.0, 255.0 ) ) );
			}
		}
	}
}

public Forward_SetModel( iEnt, strModel[ ] ) {
	if( CheckBit( g_bitCvarStatus, CVAR_DELETEWEAPONS ) && equal( strModel, "models/w_", 9 ) ) {
		static strClassName[ 2 ];
		pev( iEnt, pev_classname, strClassName, 1 );
		
		if( strClassName[ 0 ] == 'w' ) {
			set_pev( iEnt, pev_nextthink, get_gametime( ) + g_fDeleteWeaponDelay );
		}
	}
}

public Forward_TraceLine( Float:fVector1[ 3 ], Float:fVector2[ 3 ], iNoMonsters, iPlayerID, iPointer ) {
	if( !CheckBit( g_bitIsConnected, iPlayerID ) || !CheckBit( g_bitIsAlive, iPlayerID ) ) {
		return FMRES_IGNORED;
	}
	
	if( !CheckBit( g_bitCvarStatus, CVAR_AIM ) ) {
		return FMRES_IGNORED;
	}
	
	if( !g_iNormalTrace[ iPlayerID ] ) {
		g_iNormalTrace[ iPlayerID ] = iPointer;
		
		return FMRES_IGNORED;
	} else if( iPointer == g_iNormalTrace[ iPlayerID ] ) {
		return FMRES_IGNORED;
	}
	
	static iWeapon;
	iWeapon = get_user_weapon( iPlayerID );
	
	switch( iWeapon ) {
		case CSW_HEGRENADE, CSW_FLASHBANG, CSW_SMOKEGRENADE, CSW_C4, CSW_KNIFE:	return FMRES_IGNORED;
	}
	
	static Float:fVectorAim[ 3 ];
	
	GetUserAim( iPlayerID, fVector1, fVectorAim );
	
	static iTrace;
	iTrace = create_tr2( );
	engfunc( EngFunc_TraceLine, fVector1, fVectorAim, iNoMonsters, iPlayerID, iTrace );
	
	set_tr2( iPointer, TR_AllSolid,			get_tr2( iTrace, TR_AllSolid ) );
	set_tr2( iPointer, TR_StartSolid,		get_tr2( iTrace, TR_StartSolid ) );
	set_tr2( iPointer, TR_InOpen,			get_tr2( iTrace, TR_InOpen ) );
	set_tr2( iPointer, TR_InWater,			get_tr2( iTrace, TR_InWater ) );
	set_tr2( iPointer, TR_pHit,			get_tr2( iTrace, TR_pHit ) );
	set_tr2( iPointer, TR_iHitgroup,		get_tr2( iTrace, TR_iHitgroup ) );
	
	get_tr2( iTrace,	TR_flFraction,		fVectorAim[ 0 ] );
	set_tr2( iPointer,	TR_flFraction,		fVectorAim[ 0 ] );
	get_tr2( iTrace,	TR_flPlaneDist,		fVectorAim[ 0 ] );
	set_tr2( iPointer,	TR_flPlaneDist,		fVectorAim[ 0 ] );
	
	get_tr2( iTrace,	TR_vecEndPos,		fVectorAim );
	set_tr2( iPointer,	TR_vecEndPos,		fVectorAim );
	get_tr2( iTrace,	TR_vecPlaneNormal,	fVectorAim );
	set_tr2( iPointer,	TR_vecPlaneNormal,	fVectorAim );
	
	free_tr2( iTrace );
	
	return FMRES_IGNORED;
}

public Forward_Think( iEnt ) {
	if( iEnt == g_iTaskEntity ) {
		PrintInfo( );
		set_pev( iEnt, pev_nextthink, get_gametime( ) + 0.1 );
	}
}

/* Events */
public Event_CurWeapon( iPlayerID ) {
	if( !CheckBit( g_bitIsAlive, iPlayerID ) || !CheckBit( g_bitCvarStatus, CVAR_AMMO ) ) {
		return PLUGIN_CONTINUE;
	}
	
	static iWeaponID;
	iWeaponID = read_data( 2 );
	
	switch( iWeaponID ) {
		case CSW_C4, CSW_KNIFE, CSW_HEGRENADE, CSW_SMOKEGRENADE, CSW_FLASHBANG: return PLUGIN_CONTINUE;
	}
	
	if( cs_get_user_bpammo( iPlayerID, iWeaponID ) != g_iWeaponBackpack[ iWeaponID ] ) {
		cs_set_user_bpammo( iPlayerID, iWeaponID, g_iWeaponBackpack[ iWeaponID ] );
	}
	
	return PLUGIN_CONTINUE;
}

public Event_HLTV( ) {
	if( task_exists( TASK_REMOVE_SEMICLIP ) ) {
		remove_task( TASK_REMOVE_SEMICLIP );
	}
	
	if( CheckBit( g_bitCvarStatus, CVAR_SEMICLIP ) ) {
		g_bSemiclip = true;
		
		if( g_fSemiclipTime > 0.0 ) {
			set_task( g_fSemiclipTime, "Task_RemoveSemiclip", TASK_REMOVE_SEMICLIP );
		}
	}
	
	ReloadCvars( );
}

public Event_StatusIcon_Show_Buyzone( iPlayerID ) {
	SetBit( g_bitIsInBuyzone, iPlayerID );
}

public Event_StatusIcon_Hide_Buyzone( iPlayerID ) {
	ClearBit( g_bitIsInBuyzone, iPlayerID );
}

/* Tasks */
public Task_RespawnPlayer( iTaskID ) {
	new iPlayerID = iTaskID - TASK_RESPAWN;
	
	if( !CheckBit( g_bitIsConnected, iPlayerID ) ) {
		return PLUGIN_HANDLED;
	}
	
	new CsTeams:iPlayerTeam = cs_get_user_team( iPlayerID );
	
	switch( iPlayerTeam ) {
		case CS_TEAM_SPECTATOR, CS_TEAM_UNASSIGNED: return PLUGIN_HANDLED;
	}
	
	ExecuteHamB( Ham_CS_RoundRespawn, iPlayerID );
	
	if( CheckBit( g_bitCvarStatus, CVAR_SP ) ) {
		SetBit( g_bitHasNoDamage, iPlayerID );
		
		switch( g_iSPGlow ) {
			case 1:	{
				switch( iPlayerTeam ) {
					case CS_TEAM_CT:	set_user_rendering( iPlayerID, kRenderFxGlowShell, 0, 0, 255, kRenderNormal, 5 );
					case CS_TEAM_T:		set_user_rendering( iPlayerID, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 5 );
				}
			}
			
			case 2: {
				set_user_rendering( iPlayerID, kRenderFxGlowShell, 255, 255, 255, kRenderNormal, 5 );
			}
		}
		
		set_task( g_fSPTime, "Task_SpawnProtection", TASK_SP + iPlayerID );
		
		// client_print( iPlayerID, print_center, "You have been respawned. You have spawn protection for %i seconds.", floatround( g_fSPTime ) );
		client_print( iPlayerID, print_center, "%L %L", iPlayerID, "PLAYER_RESPAWNED", iPlayerID, "PLAYER_SP_ON", floatround( g_fSPTime ) );
	} else {
		// client_print( iPlayerID, print_center, "You have been respawned." );
		client_print( iPlayerID, print_center, "%L", iPlayerID, "PLAYER_RESPAWNED" );
	}
	
	return PLUGIN_HANDLED;
}

public Task_SpawnProtection( iTaskID ) {
	new iPlayerID = iTaskID - TASK_SP;
	
	if( CheckBit( g_bitIsConnected, iPlayerID ) ) {
		set_user_rendering( iPlayerID );
		ClearBit( g_bitHasNoDamage, iPlayerID );
		
		client_print( iPlayerID, print_center, "%L", iPlayerID, "PLAYER_SP_OFF" );
	}
}

public Task_Advertisement( ) {
	// client_print( 0, print_chat, "%s This server is running %s v%s%s by %s. Have Fun!", g_strPluginPrefix, g_strPluginName, g_strPluginVersion, g_bNeedToUpdate ? " (plugin needs to be updated)" : "", g_strPluginAuthor );
	client_print( 0, print_chat, "%s %L", g_strPluginPrefix, LANG_PLAYER, "VERSION_DISPLAY", g_strPluginName, g_strPluginVersion, g_bNeedToUpdate ? " (plugin needs to be updated)" : "", g_strPluginAuthor );
}

public Task_PlayerTrail( ) {
	if( CheckBit( g_bitCvarStatus, CVAR_TRAIL ) ) {
		static iColor[ 3 ]/*, iLastPosition[ MAX_PLAYERS + 1 ][ 3 ], iCurrentPosition[ MAX_PLAYERS + 1 ][ 3 ]*/;
		
		static iPlayers[ 32 ], iNum, iTempID, iLoop;
		get_players( iPlayers, iNum, "ah" );
		
		for( iLoop = 0; iLoop < iNum; iLoop++ ) {
			iTempID = iPlayers[ iLoop ];
			
			switch( cs_get_user_team( iTempID ) ) {
				case CS_TEAM_CT: {
					iColor[ 0 ]	= 0;
					iColor[ 1 ]	= 0;
					iColor[ 2 ]	= 255;
				}
				case CS_TEAM_T: {
					iColor[ 0 ]	= 255;
					iColor[ 1 ]	= 0;
					iColor[ 2 ]	= 0;
				}
			}
			
			if( CheckBit( g_bitDisplayTrail, iTempID ) ) {
				CreateBeam( iTempID, BEAM_LIFE, iColor );
			}
		}
	}
}

public Task_GetAnswer( ) {
	if( socket_change( g_iSocket ) ) {
		socket_recv( g_iSocket, g_strData, 1023 );
		
		new iPosition = containi( g_strData, "UltimateSurf v" );
		
		if( iPosition >= 0 ) {
			iPosition += strlen( "UltimateSurf v" );
			
			new iLength = 0;
			
			for( new iLoop = 0; iLoop < 16; iLoop++ ) {
				if( iLength < 5 && ('0' <= g_strData[ iPosition + iLoop ] <= '9' || g_strData[ iPosition + iLoop ] == '.'  ) ) {
					g_strSocketVersion[ iLength ] = g_strData[ iPosition + iLoop ];
					iLength++;
				}
			}
			
			CompareVersions( iLength );
			
			log_amx( "Versions has been compared. %s!", g_bNeedToUpdate ? "Plugin is outdated" : "Plugin is up to date" );
			
			socket_close( g_iSocket );
			
			remove_task( TASK_GETANSWER );
			remove_task( TASK_CLOSECONNECTION );
		}
	}
}

public Task_CloseConnection( ) {
	socket_close( g_iSocket );
}

public Task_RemoveSemiclip( ) {
	client_print( 0, print_chat, "TASK REMOVE SECMICLIP TRIGGERED" );
	
	g_bSemiclip = false;
}

/* Other Functions */
ReloadCvars( ) {
	/*
		In my opinion, its better to refresh all the cvars on demand and
		caching them instead of getting its value everytime we want it.
		And that way we do not waste useful CPU power.
	*/
	get_pcvar_num( g_pcvarRespawn )				? SetBit( g_bitCvarStatus, CVAR_RESPAWN ) 		: ClearBit( g_bitCvarStatus, CVAR_RESPAWN );
	get_pcvar_num( g_pcvarSP )				? SetBit( g_bitCvarStatus, CVAR_SP )			: ClearBit( g_bitCvarStatus, CVAR_SP );
	get_pcvar_num( g_pcvarRespawnWeapons )			? SetBit( g_bitCvarStatus, CVAR_RESPAWNWEAPONS )	: ClearBit( g_bitCvarStatus, CVAR_RESPAWNWEAPONS );
	get_pcvar_num( g_pcvarDeleteWeapons )			? SetBit( g_bitCvarStatus, CVAR_DELETEWEAPONS )		: ClearBit( g_bitCvarStatus, CVAR_DELETEWEAPONS );
	get_pcvar_num( g_pcvarAmmo )				? SetBit( g_bitCvarStatus, CVAR_AMMO )			: ClearBit( g_bitCvarStatus, CVAR_AMMO );
	get_pcvar_num( g_pcvarSemiclip )			? SetBit( g_bitCvarStatus, CVAR_SEMICLIP )		: ClearBit( g_bitCvarStatus, CVAR_SEMICLIP );
	get_pcvar_num( g_pcvarSemiclipTrans )			? SetBit( g_bitCvarStatus, CVAR_SEMICLIP_TRANS )	: ClearBit( g_bitCvarStatus, CVAR_SEMICLIP_TRANS );
	get_pcvar_num( g_pcvarAim )				? SetBit( g_bitCvarStatus, CVAR_AIM )			: ClearBit( g_bitCvarStatus, CVAR_AIM );
	get_pcvar_num( g_pcvarTrail )				? SetBit( g_bitCvarStatus, CVAR_TRAIL )			: ClearBit( g_bitCvarStatus, CVAR_TRAIL );	
	get_pcvar_num( g_pcvarFallDamage )			? SetBit( g_bitCvarStatus, CVAR_FALL_DAMAGE )		: ClearBit( g_bitCvarStatus, CVAR_FALL_DAMAGE );
	
	g_fRespawnDelay		= floatclamp( get_pcvar_float( g_pcvarRespawnDelay ),		1.0,	15.0 );
	g_fSPTime		= floatclamp( get_pcvar_float( g_pcvarSPTime ),			1.0,	15.0 );
	g_fRespawnWeaponDelay	= floatclamp( get_pcvar_float( g_pcvarRespawnWeaponsDelay ),	0.0,	60.0 );
	g_fDeleteWeaponDelay	= floatclamp( get_pcvar_float( g_pcvarDeleteWeaponsDelay ),	0.0,	60.0 );
	g_fSemiclipTime		= floatclamp( get_pcvar_float( g_pcvarSemiclipTime ),		0.0, 	60.0 );
	
	g_iSPGlow		= clamp( get_pcvar_num( g_pcvarSPGlow ),		0,	2 );
	g_iAdvertisement	= clamp( get_pcvar_num( g_pcvarPluginAdvertisement ),	0, 	30 );
	
	get_pcvar_string( g_pcvarPluginPrefix,			g_strPluginPrefix, 	31 );
}

ExecConfig( ) {
	/* Config File Execution */
	new strConfigDir[ 128 ];
	get_localinfo( "amxx_configsdir", strConfigDir, 127 );
	format( strConfigDir, 127, "%s/%s", strConfigDir, g_strPluginConfig );
	
	if( file_exists( strConfigDir ) ) {
		server_cmd( "exec %s", strConfigDir );
		log_amx( "%s configuration file successfully loaded!", g_strPluginName );
	} else {
		log_amx( "%s configuration file not found.", g_strPluginName );
	}
	
	server_exec( );
}

CheckMap( ) {
	new strMapName[ 32 ];
	get_mapname( strMapName, 31 );
	
	if( containi( strMapName, "surf" ) == -1 ) {
		set_fail_state( "UltimateSurf will only run on surf maps." );
	}
}

StripPlayerWeapons( iPlayerID ) {
	strip_user_weapons( iPlayerID );
	set_pdata_int( iPlayerID, 116, 0 );
	
	give_item( iPlayerID, "weapon_knife" );
}

FirstThink( ) {
	static iLoop;
	
	for( iLoop = 1; iLoop <= MAX_PLAYERS; iLoop++ ){
		if( !CheckBit( g_bitIsAlive, iLoop ) ) {
			ClearBit( g_bitIsSolid, iLoop );
			continue;
		}
		
		g_iPlayerTeam[ iLoop ] = get_user_team( iLoop );
		if( pev( iLoop, pev_solid ) == SOLID_SLIDEBOX ) {
			SetBit( g_bitIsSolid, iLoop );
		} else {
			ClearBit( g_bitIsSolid, iLoop );
		}
	}
}

GetUserAim( iPlayerID, Float:fSource[ 3 ], Float:fRet[ 3 ] ) {
	static Float:fAngleV[ 3 ], Float:fAngleP[ 3 ], Float:fDir[ 3 ], Float:fTemp[ 3 ];
	
	pev( iPlayerID, pev_v_angle, 	fAngleV );
	pev( iPlayerID, pev_punchangle, fAngleP );
	
	xs_vec_add( fAngleV, fAngleP, fTemp );
	
	engfunc( EngFunc_MakeVectors, fTemp );
	global_get( glb_v_forward, fDir );
	
	xs_vec_mul_scalar( fDir, 8192.0, fTemp );
	xs_vec_add( fSource, fTemp, fRet );
}

CreateBeam( iPlayerID, iLife, iColor[ 3 ] ) {	
	message_begin( MSG_BROADCAST, SVC_TEMPENTITY );
	write_byte( 22 );
	write_short( iPlayerID );
	write_short( g_iBeamSprite );
	write_byte( iLife * 10 );
	write_byte( 10 );
	write_byte( iColor[ 0 ] );
	write_byte( iColor[ 1 ] );
	write_byte( iColor[ 2 ] );
	write_byte( 100 );
	message_end( );
}

SetSpeedometer( ) {
	g_iTaskEntity = engfunc( EngFunc_CreateNamedEntity, engfunc( EngFunc_AllocString, "info_target" ) );
	set_pev( g_iTaskEntity, pev_classname, "Think_Speedometer" );
	set_pev( g_iTaskEntity, pev_nextthink, get_gametime( ) + 1.01 );
}

PrintInfo( ) {
	static iPlayers[ 32 ], iNum, iTempID, iLoop;
	get_players( iPlayers, iNum );
	
	static iTarget, Float:fVelocity[ 3 ], Float:fSpeed, Float:fSpeedRoot;
	
	for( iLoop = 0; iLoop < iNum; iLoop++ ) {
		iTempID = iPlayers[ iLoop ];
		
		if( !CheckBit( g_bitDisplaySpeed, iTempID ) ) {
			continue;
		}
		
		iTarget = ( pev( iTempID, pev_iuser1 ) == 4 ) ? pev( iTempID, pev_iuser2 ) : iTempID;
		pev( iTarget, pev_velocity, fVelocity );
		
		fSpeed = vector_length( fVelocity );
		fSpeedRoot = floatsqroot( floatpower( fVelocity[ 0 ], 2.0 ) + floatpower( fVelocity[ 1 ], 2.0 ) );
		
		if( fSpeed > 500.0 ) {
			SetBit( g_bitDisplayTrail, iTempID );
		} else {
			ClearBit( g_bitDisplayTrail, iTempID );
		}
		
		set_hudmessage( 255, 255, 255, -1.0, 0.7, 0, 0.0, 0.1, 0.01, 0.0 );
		ShowSyncHudMsg( iTempID, g_msgHudSync, "%Units/Second: %3.2f^nVelocity: %3.2f", fSpeed, fSpeedRoot );
	}
}

VersionCheckerSocket( ) {
	new iError, strBuffer[ 512 ];
	g_iSocket = socket_open( PLUGIN_HOST, 80, SOCKET_TCP, iError );
	
	switch( iError ) {
		case 1:	log_amx( "Unable to create socket." );
		case 2:	log_amx( "Unable to connect to hostname." );
		case 3:	log_amx( "Unable to connect to the HTTP port." );
		
		default: {
			formatex( strBuffer, 511, "GET %s HTTP/1.1^nHost:%s^r^n^r^n", PLUGIN_TOPIC, PLUGIN_HOST );
			socket_send( g_iSocket, strBuffer, 511 );
			
			set_task( 1.0, "Task_GetAnswer", TASK_GETANSWER, _, _, "a", 15 );
			set_task( 16.0, "Task_CloseConnection", TASK_CLOSECONNECTION );
		}
	}
}

CompareVersions( iSize ) {
	for( new iLoop = 0; iLoop < iSize; iLoop++ ) {
		if( g_strSocketVersion[ iLoop ] == '.' && g_strPluginVersion[ iLoop ] == '.' ) {
			continue;
		}
		
		if( str_to_num( g_strSocketVersion[ iLoop ] ) > str_to_num( g_strPluginVersion[ iLoop ] ) ) {
			g_bNeedToUpdate = true;
			return;
		}
	}
	
	g_bNeedToUpdate = false;
	return;
}

/*
	Notepad++ Allied Modders Edition v6.3.1
	Style Configuration:	Default
	Font:			Consolas
	Font size:		10
	Indent Tab:		8 spaces
*/