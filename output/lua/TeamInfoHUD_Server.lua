Script.Load("lua/Class.lua")

Server.AddTag("teaminfohud")

local base_OnCreate = GameInfo.OnCreate
function GameInfo:OnCreate()
	base_OnCreate(self)
	self.maxPlayers = Server.GetMaxPlayers()
end

local base_ResetGame = NS2Gamerules.ResetGame
function NS2Gamerules:ResetGame()
	base_ResetGame(self)
	local gi = GetGameInfoEntity()
	gi.accumulatedMarineScore = 0
	gi.accumulatedAlienScore = 0
end

local base_AddScore = ScoringMixin.AddScore
function ScoringMixin:AddScore(points, res)
	base_AddScore(self,points,res)
	local gi = GetGameInfoEntity()
	if self:GetTeamNumber() == kAlienTeamType then
		gi.accumulatedAlienScore = gi.accumulatedAlienScore + points
	end
	if self:GetTeamNumber() == kMarineTeamType then
		gi.accumulatedMarineScore = gi.accumulatedMarineScore + points
	end
end

function SelectableMixin:UpdateIncludeRelevancyMask()
	SetAlwaysRelevantToCommander(self,true)
end

base_CommandStructureOnInitialized = CommandStructure.OnInitialized
function CommandStructure:OnInitialized()
	base_CommandStructureOnInitialized(self)
	self:UpdateIncludeRelevancyMask()
end