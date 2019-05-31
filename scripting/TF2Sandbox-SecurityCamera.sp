 #pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "BattlefieldDuck"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <build>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Sandbox - Security Camera",
	author = PLUGIN_AUTHOR,
	description = "The security camera will be moving around to ensure safety",
	version = PLUGIN_VERSION,
	url = "https://github.com/tf2-sandbox-studio/Module-SecurityCamera"
};

ConVar cvfRotateSpeed;
ConVar cvfMaxTraceClient;

int g_iClientCameraList[MAXPLAYERS + 1][10][2];

bool g_bIN_SCORE[MAXPLAYERS + 1];
bool g_bIN_ATTACK[MAXPLAYERS + 1];
bool g_bIN_ATTACK2[MAXPLAYERS + 1];

bool g_bInConsole[MAXPLAYERS + 1];

int g_iInConsoleNum[MAXPLAYERS + 1];
int g_iInConsoleClient[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegAdminCmd("sm_sca", Command_SecurityCameraActivate, 0, "Activate the security camera");
	
	cvfRotateSpeed = CreateConVar("sm_tf2sb_sca_rotatespeed", "4.00", "(1.00 - 10.00) Security Camera rotate speed", 0, true, 1.00, true, 10.00);
	cvfMaxTraceClient = CreateConVar("sm_tf2sb_sca_maxtrace", "300.0", "(100.0 - 1000.0) Security Camera max trace client distance", 0, true, 100.0, true, 1000.0);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
}

public void OnMapStart()
{
	for (int i = 0; i <= MaxClients; i++)
	{
		for (int j = 0; j < 10; j++)
		{
			g_iClientCameraList[i][j][0] = INVALID_ENT_REFERENCE;
			g_iClientCameraList[i][j][1] = INVALID_ENT_REFERENCE;
		}
	}
}

public void OnEntityDestroyed(int entity)
{
	if(IsSecurityCamera(entity))
	{
		for (int i = 0; i <= MaxClients; i++)
		{
			RemoveCameraActivated(i, entity);
		}
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		if (g_bInConsole[client])
		{
			SetClientViewEntity(client, client);
		}
		
		g_bInConsole[client] = false;
	}
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		if (g_bInConsole[client])
		{
			SetClientViewEntity(client, client);
		}
		
		g_bInConsole[client] = false;
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	//PrintCenterText(client, "g_bIN_SCORE[client]: %i g_bInConsole[client]: %i", g_bIN_SCORE[client], g_bInConsole[client]);
	
	if (buttons & IN_SCORE)
	{
		if (!g_bIN_SCORE[client])
		{
			g_bIN_SCORE[client] = true;
			
			int console = GetClientAimTarget(client, false);
			if (console > MaxClients && IsValidEntity(console))
			{
				char strModel[64];
				GetEntPropString(console, Prop_Data, "m_ModelName", strModel, sizeof(strModel));
				if (StrEqual(strModel, "models/props_spytech/computer_screen_bank.mdl") || StrEqual(strModel, "models/props_lab/securitybank.mdl"))
				{
					float fconpos[3], fclientpos[3];
					GetEntPropVector(console, Prop_Send, "m_vecOrigin", fconpos);
					GetClientEyePosition(client, fclientpos);
					
					if (GetVectorDistance(fconpos, fclientpos) < 150.0)
					{	
						int owner = Build_ReturnEntityOwner(console);
						g_iInConsoleClient[client] = GetClientUserId(owner);
						
						g_bInConsole[client] = !g_bInConsole[client];
					}
					else if (g_bInConsole[client])
					{
						g_bInConsole[client] = false;
						SetClientViewEntity(client, client);
					}
				}
				else if (g_bInConsole[client])
				{
					g_bInConsole[client] = false;
					SetClientViewEntity(client, client);
				}
				
				if (g_bInConsole[client])
				{
					if (g_iInConsoleNum[client] > 9) g_iInConsoleNum[client] = 0;

					int owner = GetClientOfUserId(g_iInConsoleClient[client]);
					if (owner != 0)
					{
						g_iInConsoleNum[client] = GetNextCamera(owner, g_iInConsoleNum[client]);
						int point = EntRefToEntIndex(g_iClientCameraList[owner][g_iInConsoleNum[client]][1]);
						if (point != INVALID_ENT_REFERENCE)
						{
							SetClientViewEntity(client, point);
							
							PrintCenterText(client, "%N's Security Camera: %i", owner, g_iInConsoleNum[client]+1);
						}
						else
						{
							g_bInConsole[client] = false;
							SetClientViewEntity(client, client);
							
							//Camera removed
						}
					}
					else
					{
						g_bInConsole[client] = false;
						SetClientViewEntity(client, client);
						
						//Camera owner left
					}
				}
				else
				{
					SetClientViewEntity(client, client);
				}
			}
			else if (g_bInConsole[client])
			{
				g_bInConsole[client] = false;
				SetClientViewEntity(client, client);
			}
		}
	}
	else
	{
		g_bIN_SCORE[client] = false;
	}
	
	if (g_bInConsole[client])
	{	
		TF2_RemoveCondition(client, TFCond_Zoomed);
		
		if (buttons & IN_ATTACK)
		{
			if (!g_bIN_ATTACK[client])
			{
				g_bIN_ATTACK[client] = true;
				
				if (g_iInConsoleNum[client] > 9) g_iInConsoleNum[client] = 0;
				
				int owner = GetClientOfUserId(g_iInConsoleClient[client]);
				if (owner != 0)
				{
					g_iInConsoleNum[client] = GetNextCamera(owner, g_iInConsoleNum[client]);
					
					int point = EntRefToEntIndex(g_iClientCameraList[owner][g_iInConsoleNum[client]][1]);
					if (point != INVALID_ENT_REFERENCE)
					{
						SetClientViewEntity(client, point);
						
						PrintCenterText(client, "%N's Security Camera: %i", owner, g_iInConsoleNum[client]+1);
					}
					else
					{
						g_bInConsole[client] = false;
						SetClientViewEntity(client, client);
						
						//Camera removed
					}
				}
				else
				{
					g_bInConsole[client] = false;
					SetClientViewEntity(client, client);
					
					//Camera owner left
				}
			}
		}
		else
		{
			g_bIN_ATTACK[client] = false;
		}
		
		if (buttons & IN_ATTACK2)
		{
			if (!g_bIN_ATTACK2[client])
			{
				g_bIN_ATTACK2[client] = true;
					
				if (g_iInConsoleNum[client] < 0) g_iInConsoleNum[client] = 9;
				
				int owner = GetClientOfUserId(g_iInConsoleClient[client]);
				if (owner != 0)
				{
					g_iInConsoleNum[client] = GetBackCamera(owner, g_iInConsoleNum[client]);
					
					int point = EntRefToEntIndex(g_iClientCameraList[owner][g_iInConsoleNum[client]][1]);
					if (point != INVALID_ENT_REFERENCE)
					{
						SetClientViewEntity(client, point);
						
						PrintCenterText(client, "%N's Security Camera: %i", owner, g_iInConsoleNum[client]+1);
					}
					else
					{
						g_bInConsole[client] = false;
						SetClientViewEntity(client, client);
						
						//Camera removed
					}
				}
				else
				{
					g_bInConsole[client] = false;
					SetClientViewEntity(client, client);
					
					//Camera owner left
				}
			}
		}
		else
		{
			g_bIN_ATTACK2[client] = false;
		}
	}
	
	return Plugin_Continue;
}

public Action Command_SecurityCameraActivate(int client, int args)
{
	if(client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}
	
	int camera = GetClientAimTarget(client, false);
	if (camera <= MaxClients || !IsValidEntity(camera))
	{
		Build_PrintToChat(client, "Invalid target! Please aim at the security camera!");
		return Plugin_Continue;
	}

	if(!IsSecurityCamera(camera))
	{
		Build_PrintToChat(client, "Invalid target! Please aim at the security camera!");
		return Plugin_Continue;
	}
	
	if (IsCameraActivated(client, camera))
	{
		Build_PrintToChat(client, "The Security Camera had already activated!");
		return Plugin_Continue;
	}
	
	int bracket = GetClosestBracketIndex(client, camera);
	if (bracket == -1 || !IsValidEntity(bracket))
	{
		Build_PrintToChat(client, "Fail to find Security Camera Bracket! Please spawn Security Camera Bracket near the Security Camera!");
		return Plugin_Continue;
	}
	
	float fbracketpos[3], fbracketang[3];
	GetEntPropVector(bracket, Prop_Send, "m_vecOrigin", fbracketpos);
	GetEntPropVector(bracket, Prop_Data, "m_angRotation", fbracketang);
	fbracketang[2] = 0.0;
	TeleportEntity(camera, fbracketpos, fbracketang, NULL_VECTOR);

	if (!SetCameraActivated(client, camera, CreateObserverPoint(camera)))
	{
		Build_PrintToChat(client, "You have reached 10 Security Camera limit!");
		return Plugin_Continue;
	}

	Handle dp;
	CreateDataTimer(0.0, Timer_ActivateCamera, dp);
	WritePackCell(dp, EntIndexToEntRef(camera));
	WritePackCell(dp, EntIndexToEntRef(bracket));
	WritePackCell(dp, false);
	
	return Plugin_Continue;
}

public Action Timer_ActivateCamera(Handle timer, Handle dp)
{
	ResetPack(dp);
	int camera = EntRefToEntIndex(ReadPackCell(dp));
	int bracket = EntRefToEntIndex(ReadPackCell(dp));
	bool rotateright = ReadPackCell(dp);
	
	if (camera == INVALID_ENT_REFERENCE || bracket == INVALID_ENT_REFERENCE)
	{
		for (int i = 0; i <= MaxClients; i++)
		{
			RemoveCameraActivated(i, camera);
		}
		return Plugin_Continue;
	}
	
	float fcamerapos[3], fbracketpos[3];
	GetEntPropVector(camera, Prop_Send, "m_vecOrigin", fcamerapos);
	GetEntPropVector(bracket, Prop_Send, "m_vecOrigin", fbracketpos);
	
	if (fcamerapos[0] != fbracketpos[0] && fcamerapos[1] != fbracketpos[1] && fcamerapos[2] != fbracketpos[2])
	{
		return Plugin_Continue;
	}
	
	int client = GetClosestClient(camera);
	if (client != -1)
	{
		float fclientpos[3];
		GetClientEyePosition(client, fclientpos);
		
		float vector[3];
		MakeVectorFromPoints(fcamerapos, fclientpos, vector);
		
		float faimangle[3];
		GetVectorAngles(vector, faimangle);

		faimangle[2] = faimangle[0]*-1;
		faimangle[1] -= 90.0;
		faimangle[0] = 0.0;
		
		TeleportEntity(camera, NULL_VECTOR, faimangle, NULL_VECTOR);
	}
	else
	{
		float fcamang[3];
		GetEntPropVector(camera, Prop_Data, "m_angRotation", fcamang);
		
		float fbracketang[3];
		GetEntPropVector(bracket, Prop_Data, "m_angRotation", fbracketang);
		
		if (fbracketang[1] - fcamang[1] > 45) rotateright = true;
		else if (fbracketang[1] - fcamang[1] < -45) rotateright = false;
	
		float rotateangle;
		rotateangle = (rotateright) ? cvfRotateSpeed.FloatValue : cvfRotateSpeed.FloatValue*-1;
		
		fcamang[1] += rotateangle;
		
		TeleportEntity(camera, NULL_VECTOR, fcamang, NULL_VECTOR);
	}

	CreateDataTimer(0.1, Timer_ActivateCamera, dp);
	WritePackCell(dp, EntIndexToEntRef(camera));
	WritePackCell(dp, EntIndexToEntRef(bracket));
	WritePackCell(dp, rotateright);
	
	return Plugin_Continue;
}

int GetClosestBracketIndex(int client, int camera)
{
	float fcampos[3];
	GetEntPropVector(camera, Prop_Send, "m_vecOrigin", fcampos);
	
	int bracket = -1;
	float shortestdistance = 30.0;
	char strModel[64];
	
	int entity = -1;
	while ((entity = FindEntityByClassname(entity, "prop_dynamic")) != -1) 
	{
		if (Build_ReturnEntityOwner(entity) != client)
		{
			continue;
		}
		
		GetEntPropString(entity, Prop_Data, "m_ModelName", strModel, sizeof(strModel));
		if(!StrEqual(strModel, "models/props_spytech/security_camera_bracket.mdl"))
		{
			continue;
		}
		
		float fbrapos[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", fbrapos);
		
		float distance = GetVectorDistance(fcampos, fbrapos);
		if (distance < shortestdistance)
		{
			bracket = entity;
			shortestdistance = distance;
		}
	}
	
	return bracket;
}

int GetClosestClient(int camera)
{
	float fcampos[3];
	GetEntPropVector(camera, Prop_Send, "m_vecOrigin", fcampos);
	
	int client = -1;
	float shortestdistance = cvfMaxTraceClient.FloatValue;
	
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			float fclientpos[3];
			GetClientEyePosition(i, fclientpos);
			
			float distance = GetVectorDistance(fcampos, fclientpos);
			if (distance < shortestdistance)
			{
				if (!CanSeeClient(i, camera))
				{
					continue;
				}
				
				client = i;
				shortestdistance = distance;
			}
		}
	}

	return client;
}

bool CanSeeClient(int client, int camera)
{
	float fcampos[3];
	GetEntPropVector(camera, Prop_Send, "m_vecOrigin", fcampos);
	
	float fclientpos[3];
	GetClientEyePosition(client, fclientpos);
	
	Handle trace = TR_TraceRayFilterEx(fcampos, fclientpos, MASK_SHOT, RayType_EndPoint, TraceEntityFilter, client);
	if (TR_DidHit(trace))
	{
		int entity = TR_GetEntityIndex(trace);
		if (entity > 0 && entity <= MaxClients)
		{
			return true;
		}
	}
	
	return false;
}

float[] GetPointAimPosition(float pos[3], float angles[3], float maxtracedistance, int camera)
{
	Handle trace = TR_TraceRayFilterEx(pos, angles, MASK_SOLID, RayType_Infinite, TraceEntityFilter, camera);

	if(TR_DidHit(trace))
	{
		float endpos[3];
		TR_GetEndPosition(endpos, trace);
		
		if((GetVectorDistance(pos, endpos) <= maxtracedistance) || maxtracedistance <= 0)
		{
			CloseHandle(trace);
			return endpos;
		}
		else
		{
			float eyeanglevector[3];
			GetAngleVectors(angles, eyeanglevector, NULL_VECTOR, NULL_VECTOR);
			NormalizeVector(eyeanglevector, eyeanglevector);
			ScaleVector(eyeanglevector, maxtracedistance);
			AddVectors(pos, eyeanglevector, endpos);
			CloseHandle(trace);
			return endpos;
		}
	}
	
	CloseHandle(trace);
	return pos;
}

public bool TraceEntityFilter(int entity, int mask, int client)
{
	char strModel[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", strModel, sizeof(strModel));
	if(StrContains(strModel, "security_camera") == -1)
	{
		return true;
	}
	
	return false;
}

bool IsSecurityCamera(int entity)
{
	char strModel[64];
	GetEntPropString(entity, Prop_Data, "m_ModelName", strModel, sizeof(strModel));
	return StrEqual(strModel, "models/props_spytech/security_camera.mdl");
}

int CreateObserverPoint(int camera)
{
	float fcampos[3], fcamang[3];
	GetEntPropVector(camera, Prop_Send, "m_vecOrigin", fcampos);
	GetEntPropVector(camera, Prop_Data, "m_angRotation", fcamang);
	
	int point = CreateEntityByName("info_observer_point");
	fcamang[1] += 90.0;
	fcamang[2] = 0.0;
	fcampos = GetPointAimPosition(fcampos, fcamang, 30.0, camera);
	TeleportEntity(point, fcampos, fcamang, NULL_VECTOR);
	
	DispatchSpawn(point);
	
	SetVariantString("!activator");
	AcceptEntityInput(point, "SetParent", camera);
	
	return point;
}

bool IsCameraActivated(int client, int camera)
{
	for (int i = 0; i < 10; i++)
	{
		if (g_iClientCameraList[client][i][0] == EntIndexToEntRef(camera))
		{
			return true;
		}
	}
	return false;
}

bool SetCameraActivated(int client, int camera, int point)
{
	for (int i = 0; i < 10; i++)
	{
		if (g_iClientCameraList[client][i][0] == INVALID_ENT_REFERENCE)
		{
			g_iClientCameraList[client][i][0] = EntIndexToEntRef(camera);
			g_iClientCameraList[client][i][1] = EntIndexToEntRef(point);
			
			return true;
		}
	}
	return false;
}

void RemoveCameraActivated(int client, int camera)
{
	for (int i = 0; i < 10; i++)
	{
		if (g_iClientCameraList[client][i][0] == EntIndexToEntRef(camera))
		{
			g_iClientCameraList[client][i][0] = INVALID_ENT_REFERENCE;
			g_iClientCameraList[client][i][1] = INVALID_ENT_REFERENCE;
			
			break;
		}
	}
}

int GetNextCamera(int client, int id)
{
	for (int i = id+1; i < 10; i++)
	{
		if (g_iClientCameraList[client][i][0] != INVALID_ENT_REFERENCE)
		{
			return i;
		}
	}
	
	for (int i = 0; i < id; i++)
	{
		if (g_iClientCameraList[client][i][0] != INVALID_ENT_REFERENCE)
		{
			return i;
		}
	}
	
	return id;
}

int GetBackCamera(int client, int id)
{
	for (int i = id-1; i >= 0; i--)
	{
		if (g_iClientCameraList[client][i][0] != INVALID_ENT_REFERENCE)
		{
			return i;
		}
	}
	
	for (int i = 9; i > id; i--)
	{
		if (g_iClientCameraList[client][i][0] != INVALID_ENT_REFERENCE)
		{
			return i;
		}
	}
	
	return id;
}