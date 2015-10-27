Script.Load("lua/Class.lua")

local function GetHud()
	return ClientUI.GetScript("GUITeamInfoHUD")
end

local green = Color(0,1,0)
kTeamInfoHudPlayerData = {}
local ConfigFileName = "TeamInfoHUD.json"

Shared.Message("Team Info HUD is installed. Use \"teaminfohud\" to configure.")

AddClientUIScriptForClass("Marine","GUITeamInfoHUD")
AddClientUIScriptForClass("Exo","GUITeamInfoHUD")
AddClientUIScriptForClass("MarineCommander","GUITeamInfoHUD")
AddClientUIScriptForClass("Alien","GUITeamInfoHUD")
AddClientUIScriptForClass("AlienCommander","GUITeamInfoHUD")

local base_MinimapUpdate
local function HighlightSelectedPlayers(self,deltaTime)
	base_MinimapUpdate(self,deltaTime)
	
	local localTeam = Client.GetLocalPlayer():GetTeamNumber()
	for i, blipEnt in ientitylist(Shared.GetEntitiesWithClassname("MapBlip")) do
		local owner = Shared.GetEntity(blipEnt.ownerEntityId)
		if owner and (not owner.GetIsInCombat or not owner:GetIsInCombat()) and owner.GetIsSelected and owner:GetIsSelected(localTeam) then
			self.staticBlips[i]:SetColor(green)
		end
	end
end

local base_CommanderOnInitLocalClient = Commander.OnInitLocalClient
function Commander:OnInitLocalClient()
	base_CommanderOnInitLocalClient(self)
	self.managerScript:AddChildScript(GetHud()) -- no proper way of doing this :(
	
	local minimapScript = ClientUI.GetScript("GUIMinimapFrame")
	base_MinimapUpdate = GUIMinimapFrame.Update
	minimapScript.Update = HighlightSelectedPlayers
	minimapScript.spawnQueueText:SetIsVisible(false)
	
	GetGUIManager():DestroyGUIScriptSingle("GUIHotkeyIcons") -- we are replacing this
end
Class_Reload("Commander")

local function OnCommandPoints(pointsString, resString)
	if GetHud() then
		local new_points = tonumber(pointsString)
		local gi = GetGameInfoEntity()
		if new_points > 0 and gi.accumulatedMarineScore ~= nil then
			if Client.GetLocalPlayer():GetTeamNumber() == kMarineTeamType then
				gi.accumulatedMarineScore = gi.accumulatedMarineScore + new_points
			else
				gi.accumulatedAlienScore = gi.accumulatedAlienScore + new_points
			end
			GetHud():UpdateScoreBarLayout(true,false)
		end
	end
end
Event.Hook("Console_points", OnCommandPoints)

local function OnUpdateClient()
	PROFILE("TeamInfoHUD:OnUpdateClient")
	
	for _, playerInfo in ientitylist(Shared.GetEntitiesWithClassname("PlayerInfoEntity")) do
		hudData = kTeamInfoHudPlayerData[playerInfo.clientId]
		if hudData == nil then
			hudData = {}
			kTeamInfoHudPlayerData[playerInfo.clientId] = hudData
		end
		hudData.team = playerInfo.teamNumber
		hudData.status = playerInfo.status
		hudData.entityId = playerInfo.playerId
		hudData.playerName = playerInfo.playerName
					
		if not GetHud() or not GetHud().icons then return end
		
		if hudData.team ~= Client.GetLocalPlayer():GetTeamNumber() or hudData.team == kNeutralTeamType then
			if GetHud().icons[playerInfo.clientId] then
				GetHud():DeleteIcon(playerInfo.clientId)
			end
		else
			local playerIcon = GetHud().icons[playerInfo.clientId]
			
			if playerIcon == nil then
				playerIcon = GetHud():CreatePlayerIcon(playerInfo.clientId,playerInfo.teamNumber)
				GetHud():UpdateIconLayout()
			end
			
			GetHud():UpdateIconTexture(playerInfo.clientId,hudData.status)
		end
	end
end
Event.Hook("UpdateClient", OnUpdateClient)

local function OnCommandOnClientDisconnect(clientIndexString)
	id = tonumber(clientIndexString)
	if GetHud() and GetHud().icons[id] then
		GetHud():DeleteIcon(id)
	end
	kTeamInfoHudPlayerData[id] = nil
end
Event.Hook("Console_clientdisconnect", OnCommandOnClientDisconnect)

local config = LoadConfigFile(ConfigFileName)
kDisplayTeamInfoHud = config and config.display or 2

function ShouldDisplayTeamInfoHud()
	return kDisplayTeamInfoHud == 1 or kDisplayTeamInfoHud == 2 or (kDisplayTeamInfoHud == 3 and Client.GetLocalPlayer().commandStationId)
end

function ShouldDisplayTeamInfoHudScoreBar()
	return kDisplayTeamInfoHud > 1 and not Client.GetLocalPlayer():isa("Exo") and not Client.GetLocalPlayer().commandStationId
end

function TeamInfoHudUpdateVisibility()
	if GetHud() then
			GetHud().root:SetIsVisible(ShouldDisplayTeamInfoHud() or false)
			GetHud().scoreBarBg:SetIsVisible(ShouldDisplayTeamInfoHudScoreBar() or false)
		end
end

function OnCommandTeamInfoHud(arg)
	if arg == nil then
		Shared.Message("teaminfohud = " .. tostring(kDisplayTeamInfoHud) .. "\n  0 = Off\n  1 = Score bar disabled\n  2 = Full\n  3 = Commander only")
		return
	end	
	
	arg = tonumber(arg)
	kDisplayTeamInfoHud = arg
	SaveConfigFile(ConfigFileName, { display=arg })

	TeamInfoHudUpdateVisibility()
end
Event.Hook("Console_teaminfohud", OnCommandTeamInfoHud)
