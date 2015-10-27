class 'GUITeamInfoHUD' (GUIAnimatedScript)

local scoreBarWidth = 512
local iconsPerRow = 12
local iconSize = math.floor(scoreBarWidth / iconsPerRow)
local scoreBarHeight = 32
local scoreBarYOffset = 15
local scoreBarPadding = 6
local scoreBarInnerHeight = scoreBarHeight - (scoreBarPadding*2)
local scoreBarInnerWidth = scoreBarWidth + 32 - (scoreBarPadding*2)
local scoreBarMidpoint = 60
local scoreBarAnimTime = 0.25
local white = Color(1,1,1)

local marineIcons = PrecacheAsset("ui/TeamInfo/marine_status.dds")
local alienIcons = PrecacheAsset("ui/TeamInfo/alien_status.dds")
local scoreBarMid = PrecacheAsset("ui/TeamInfo/scorebar_mid_marine.dds")
local scoreBarCap = PrecacheAsset("ui/TeamInfo/scorebar_cap_marine.dds")
local scoreBarInner = PrecacheAsset("ui/TeamInfo/scorebar_inner.dds")
local selectMarine = PrecacheAsset("ui/TeamInfo/select_marine.dds")
local selectAlien = PrecacheAsset("ui/TeamInfo/select_alien.dds")
local toolTipCap = PrecacheAsset("ui/TeamInfo/tooltip_cap.dds")

local function GetInCommandStructure(player)
	return player.commandStationId and player.commandStationId ~= -1
end

local chatUpdate_base = nil
local function ChatOffset(self, deltaTime)
	chatUpdate_base(self, deltaTime)
	if GetInCommandStructure(Client.GetLocalPlayer()) then
		for i, message in ipairs(self.messages) do
			message["Background"]:SetPosition( Vector(message["Background"]:GetPosition() - Vector(0,iconSize * 2,0)) )
		end
	end
end

function GUITeamInfoHUD:Initialize()
	GUIAnimatedScript.Initialize(self)
	
	self.icons = {}
	self.lastTeamScores = { 0, 0 }
	self.teamNumber = Client.GetLocalPlayer():GetTeamNumber()
	
	if GetGameInfoEntity().accumulatedMarineScore == nil then
		Shared.Message("Team Info HUD not running on server, score bars disabled. Updates to player icons will take longer to arrive.")
	else
		iconsPerRow = math.max(12,math.min(18,GetGameInfoEntity().maxPlayers / 2)) -- between 12 and 18 icons per row
		iconSize = math.floor(scoreBarWidth / iconsPerRow)
	end
	self.root = GUI.CreateItem()
	self.root:SetColor(Color(1,1,1,0))
	self.root:SetSize(Vector(scoreBarWidth,iconSize * math.ceil(GetGameInfoEntity().maxPlayers / 2 / iconsPerRow),0))
	self.root:SetAnchor(GUIItem.Middle, GUIItem.Top)
	self.root:SetLayer(kGUILayerCommanderHUD)
	
	local score_bg = GUIManager:CreateGraphicItem()
	score_bg:SetSize(Vector(scoreBarWidth,scoreBarHeight,0))
	score_bg:SetAnchor(GUIItem.Middle, GUIItem.Top)
	score_bg:SetPosition(Vector(-scoreBarWidth/2,scoreBarYOffset,0))
	score_bg:SetTexture(scoreBarMid)
	local setvis = score_bg.SetIsVisible
	score_bg.SetIsVisible = function(self_,visible)
			setvis(self_,visible)
			self:UpdateIconLayout()
		end
	self.root:AddChild(score_bg)
	self.scoreBarBg = score_bg
	
	local score_l = GUIManager:CreateGraphicItem()
	score_l:SetSize(Vector(16,scoreBarHeight,0))
	score_l:SetPosition(Vector(-16,0,0))
	score_l:SetTexture(scoreBarCap)
	score_bg:AddChild(score_l)
	
	local score_r = GUIManager:CreateGraphicItem()
	score_r:SetSize(Vector(16,scoreBarHeight,0))
	score_r:SetAnchor(GUIItem.Right, GUIItem.Top)
	score_r:SetTexture(scoreBarCap)
	score_r:SetTextureCoordinates(1,0,0,1)
	score_bg:AddChild(score_r)
	
	local label = GUIManager:CreateTextItem()
	label:SetTextAlignmentX(GUIItem.Align_Center)
	label:SetAnchor(GUIItem.Center, GUIItem.Top)
	label:SetPosition(Vector(0,-17,0))
	label:SetColor(Color(1,1,1,0.5))
	label:SetFontName("fonts/AgencyFB_tiny.fnt")
	label:SetText("TEAM SCORES")
	score_bg:AddChild(label)
	
	local score_marines = self:CreateAnimatedGraphicItem()
	score_marines:SetIsScaling(false)
	score_marines:SetSize(Vector(1,scoreBarInnerHeight,0))
	score_marines:SetPosition(Vector(-16 + scoreBarPadding,scoreBarPadding,0))
	score_marines:SetColor(kMarineTeamColorFloat)
	score_marines:SetTexture(scoreBarInner)
	score_marines:AddAsChildTo(score_bg)
	self.marineScore = score_marines
		
	local score_aliens = self:CreateAnimatedGraphicItem()
	score_marines:SetIsScaling(false)
	score_aliens:SetSize(Vector(1,scoreBarInnerHeight,0))
	score_aliens:SetAnchor(GUIItem.Middle, GUIItem.Top)
	score_aliens:SetPosition(Vector((scoreBarWidth/2) + 16 - scoreBarPadding - score_aliens:GetSize().x,scoreBarPadding,0))
	score_aliens:SetColor(kAlienTeamColorFloat)
	score_aliens:SetTexture(scoreBarInner)
	score_aliens:AddAsChildTo(score_bg)
	self.alienScore = score_aliens
	
	for clientIndex,playerInfo in pairs(kTeamInfoHudPlayerData) do
		self:CreatePlayerIcon(clientIndex,playerInfo.team)
		self:UpdateIconTexture(clientIndex,playerInfo.status)
	end
	
	self:UpdateIconLayout()
	self.scoreBarsHaveMet = false
	self:UpdateScoreBarLayout(false,true)
	
	TeamInfoHudUpdateVisibility()
	
	local chat = ClientUI.GetScript("GUIChat")
	if chat and chat.Update ~= ChatOffset then
		chatUpdate_base = chat.Update
		chat.Update = ChatOffset
	end
end

function GUITeamInfoHUD:Uninitialize()
	GUIAnimatedScript.Uninitialize(self)
	GUI.DestroyItem(self.root)
end

local GUIResourceDisplay_kBackgroundHeight = GUIScale(63) -- from /lua/GUIResourceDisplay.lua

local function MakeToolTip(fontSize)
	label = GUIManager:CreateTextItem()
	label:SetFontName("fonts/AgencyFB_".. fontSize .. ".fnt")
	return label
end

local toolTipColour = Color(0,0,0,0.5)

local function MakeCap(right)
	cap = GUIManager:CreateGraphicItem()
	cap:SetSize(Vector(6,44,0))
	cap:SetTexture(toolTipCap)
	cap:SetColor(toolTipColour)
	if right then
		cap:SetAnchor(GUIItem.Right, GUIItem.Top)
		cap:SetTextureCoordinates(1,0,0,1)
	else
		cap:SetPosition(Vector(-6,0,0))
	end
	return cap
end

function GUITeamInfoHUD:OnLocalPlayerChanged(newPlayer)
	TeamInfoHudUpdateVisibility()
	
	if newPlayer:isa("Commander") then
		if not self.toolTip then
			tip = GUIManager:CreateGraphicItem()
			tip:SetColor(toolTipColour)
			tip:SetIsVisible(false)
			tip:SetLayer(kGUILayerLocationText)
			self.root:AddChild(tip)
			
			tip:AddChild(MakeCap(false))
			tip:AddChild(MakeCap(true))
			
			tip.line1 = MakeToolTip("small")
			label:SetPosition(Vector(-1,2,0))
			tip:AddChild(tip.line1)
			
			tip.line2 = MakeToolTip("tiny")
			tip.line2:SetPosition(Vector(-1,24,0))
			tip:AddChild(tip.line2)
			
			self.toolTip = tip
			self.locations = {}
		end
		self.root:SetAnchor(GUIItem.Left, GUIItem.Bottom)
		self.root:SetPosition(Vector(0,0,0)) 
	else
		for clientId,playerIcon in pairs(self.icons) do
			playerIcon:SetColor(white)
		end
		self.root:SetAnchor(GUIItem.Middle, GUIItem.Top)
		self.root:SetPosition(Vector(-(scoreBarWidth/2),0,0)) 
	end
	self:UpdateIconLayout()
end

local function CanSelect(clientId)
	if clientId == Client.GetLocalClientIndex() then return true end
	local unit = Shared.GetEntity(kTeamInfoHudPlayerData[clientId].entityId)
	return (unit and unit:GetPlayerStatusDesc() ~= kPlayerStatus.Dead) and kTeamInfoHudPlayerData[clientId].status ~= kPlayerStatus.Dead
end

local toolTipOffset = Vector(0,-20-22,0) + Vector(4,-5,0)

function GUITeamInfoHUD:Update(deltaTime)
	PROFILE("GUITeamInfoHUD:Update")
	
	GUIAnimatedScript.Update(self, deltaTime)
	
	self:UpdateScoreBarLayout(false,false)
	
	if self.toolTip then
		self.toolTip:SetIsVisible(false)
		self.toolTip.line2:SetIsVisible(false)
	end
	
	local localPlayer = Client.GetLocalPlayer()
	
	for clientId,playerIcon in pairs(self.icons) do
		local playerData = kTeamInfoHudPlayerData[clientId]
		local player = Shared.GetEntity(playerData.entityId)
		local frameAlpha = 0
		
		if player and player:isa("Player") and (player == localPlayer or player:GetPlayerStatusDesc() ~= kPlayerStatus.Void) then -- in commander mode off-screen players always have void status
			playerData.status = player:GetPlayerStatusDesc()
			self:UpdateIconTexture(clientId,playerData.status)
		end
		
		if GetInCommandStructure(localPlayer) then
			local mouseX, mouseY = Client.GetCursorPosScreen()
			local selectable = player
			if player and GetInCommandStructure(player) then
				selectable = Shared.GetEntity(player.commandStationId)
			end
			local selected = false
			
			if selectable then
				local healthFrac = selectable:GetHealth() / selectable:GetMaxHealth()
				playerIcon:SetColor(Color(1.0,healthFrac,healthFrac))
				selected = selectable:GetIsSelected(self.teamNumber) and CanSelect(clientId) -- dead players remain selected!
				frameAlpha = selected and 0.8 or 0
			end
			
			if GUIItemContainsPoint(playerIcon:GetParent(), mouseX, mouseY) then
				local framePos = playerIcon:GetParent():GetPosition()
				self.toolTip:SetPosition(framePos + toolTipOffset)
				
				self.toolTip:SetIsVisible(true)
				self.toolTip.line1:SetText(player and player:GetName() or playerData.playerName)
				
				if selectable and selectable:GetLocationName() then
					self.locations[clientId] = selectable:GetLocationName()
				end
				
				if self.locations[clientId] then
					self.toolTip.line2:SetIsVisible(true)
					if (player and player:GetPlayerStatusDesc() == kPlayerStatus.Dead) or (playerData and playerData.status == kPlayerStatus.Dead) then
						self.toolTip.line2:SetText("(" .. self.locations[clientId] .. ")")
					else
						self.toolTip.line2:SetText(self.locations[clientId])
					end
				end
				
				local width = math.max(self.toolTip.line1:GetTextWidth(self.toolTip.line1:GetText()),self.toolTip.line2:GetTextWidth(self.toolTip.line2:GetText())) - 2
				local height = 42 + 2
				
				self.toolTip:SetSize(Vector(width,height,0))
				
				if CanSelect(clientId) then
					if self.lmbDown then
						frameAlpha = 1
					else
						frameAlpha = selected and 0.8 or 0.6
					end
				end
			end
		end
		
		playerIcon:GetParent():SetColor(Color(1,1,1,frameAlpha))
	end
end

function GUITeamInfoHUD:ContainsPoint(mouseX, mouseY)
	for clientId,playerIcon in pairs(self.icons) do
		if GUIItemContainsPoint(playerIcon, mouseX, mouseY) then
			return true
		end
	end
	return false
end

function GUITeamInfoHUD:SendKeyEvent(key, down, amount)
	if not GetInCommandStructure(Client.GetLocalPlayer()) then
		return false
	end
	
	if key == InputKey.LeftControl or key == InputKey.RightControl then
		self.ctrlDown = down
		return false
	end
	if key == InputKey.LeftShift or key == InputKey.RightShift then
		self.shiftDown = down
		return false
	end
	
	if key == InputKey.MouseButton0 then
		local mouseX, mouseY = Client.GetCursorPosScreen()
		if down then
			for clientId,playerIcon in pairs(self.icons) do
				if CanSelect(clientId) and GUIItemContainsPoint(playerIcon, mouseX, mouseY) then
					local unit = Shared.GetEntity(clientId == Client.GetLocalClientIndex() and Client.GetLocalPlayer().commandStationId or kTeamInfoHudPlayerData[clientId].entityId)
					if unit then
						if not self.ctrlDown then
							if unit:GetIsSelected(self.teamNumber) then
								Client.GetLocalPlayer():SetWorldScrollPosition(unit:GetOrigin().x-5, unit:GetOrigin().z)
							end
							if not self.shiftDown then
								DeselectAllUnits(self.teamNumber,false,true)
							end
						end
						unit:SetSelected(self.teamNumber,not self.ctrlDown,true,true)
					end
					return true
				end
			end
		end
	end
	return false
end

function GUITeamInfoHUD:UpdateScoreBarLayout(flash,instant)
	local animTime = instant == false and scoreBarAnimTime or 0
		
	local gi = GetGameInfoEntity()
	local marineScore = gi.accumulatedMarineScore
	local alienScore = gi.accumulatedAlienScore
	
	if marineScore == nil or alienScore == nil then -- mod not running on server?
		return
	end
	
	if not instant and marineScore == lastTeamScores[kMarineTeamType] and alienScore == lastTeamScores[kAlienTeamType] then
		return
	end
	lastTeamScores = { marineScore, alienScore }
		
	local totalScore = marineScore + alienScore
	if not self.scoreBarsHaveMet and totalScore >= scoreBarMidpoint * 2 then
		self.scoreBarsHaveMet = true
	end
	
	local marineWidth
	local alienWidth
	
	if marineScore == 0 then
		marineWidth = 1
	elseif self.scoreBarsHaveMet then
		marineWidth = (marineScore / totalScore) * scoreBarInnerWidth
	else
		marineWidth = (marineScore / scoreBarMidpoint) * (scoreBarInnerWidth/2)
	end
	marineWidth = math.min(scoreBarInnerWidth - 1,marineWidth)
	self.marineScore:SetSize(Vector(marineWidth,scoreBarInnerHeight,0), animTime, nil, AnimateSin)
	self.marineScore:SetTextureCoordinates(0,0,marineWidth/48,1)
	if flash and self.teamNumber == kMarineTeamType then
		self:FlashScoreBar(self.marineScore)
	end
	
	if alienScore == 0 then
		alienWidth = 1
	elseif self.scoreBarsHaveMet then
		alienWidth = (alienScore / totalScore) * scoreBarInnerWidth
	else
		alienWidth = (alienScore / scoreBarMidpoint) * (scoreBarInnerWidth/2)
	end
	alienWidth = math.min(scoreBarInnerWidth - 1,alienWidth)
	self.alienScore:SetSize(Vector(alienWidth,scoreBarInnerHeight,0), animTime, nil, AnimateSin)
	self.alienScore:SetPosition(Vector((scoreBarWidth/2) + 16 - scoreBarPadding - alienWidth,scoreBarPadding,0), animTime, nil, AnimateSin)
	self.alienScore:SetTextureCoordinates((alienWidth/48),0,0,1)
	if flash and self.teamNumber == kAlienTeamType then
		self:FlashScoreBar(self.alienScore)
	end
end

function GUITeamInfoHUD:FlashScoreBar(bar)
	bar:SetColor(white,scoreBarAnimTime*0.2,nil, AnimLinear, // to white
		function(script,item)
			item:SetColor(white,scoreBarAnimTime*4,nil,AnimateLinear, // hold...
			function(script,item)
				item:SetColor(self.teamNumber == kMarineTeamType and kMarineTeamColorFloat or kAlienTeamColorFloat,scoreBarAnimTime*1,nil,AnimateSin) // ...return
			end)
		end)
end

local MinimapHeight = GUIScale(360) -- GUIMinimapFrame.lua -> kFrameTextureSize

function GUITeamInfoHUD:UpdateIconLayout()
	local i = 0
	local rowOffset = 0
	
	if Client.GetLocalPlayer():GetIsCommander() then
		rowOffset = rowOffset - iconSize
		for id,playerIcon in pairs(self.icons) do
			if i >= iconsPerRow/2 then
				i = 0
				rowOffset = rowOffset - iconSize
			end
			
			local offset = (i * iconSize) + 30
			
			playerIcon:GetParent():SetPosition(Vector(
				offset,
				-MinimapHeight + rowOffset,
				0))
			i = i + 1
		end
	else
		for id,playerIcon in pairs(self.icons) do
			if i >= iconsPerRow then
				i = 0
				rowOffset = rowOffset + iconSize
			end
			
			local offset = i * iconSize
			if self.teamNumber == kAlienTeamType then
				offset = scoreBarWidth - iconSize - offset
			end
			
			playerIcon:GetParent():SetPosition(Vector(
				offset,
				(self.scoreBarBg:GetIsVisible() and scoreBarHeight + scoreBarYOffset or 2) + rowOffset,
				0))
			i = i + 1
		end
	end
end

function GUITeamInfoHUD:DeleteIcon(id)
	GUI.DestroyItem(self.icons[id]:GetParent())
	self.icons[id] = nil
	self:UpdateIconLayout()
end

function GUITeamInfoHUD:CreatePlayerIcon(clientIndex,team)
	frame = GUIManager:CreateGraphicItem()
	frame:SetSize(Vector(iconSize,iconSize,0))
	frame:SetColor(Color(1,1,1,0))
	frame:SetTexture(team == kMarineTeamType and selectMarine or selectAlien)
	frame:SetLayer(kGUILayerCommanderHUD)
	
	icon = GUIManager:CreateGraphicItem()
	icon:SetSize(Vector(iconSize,iconSize,0))
	icon:SetTexture(team == kMarineTeamType and marineIcons or alienIcons)
	icon:SetLayer(kGUILayerCommanderHUD)
	
	frame:AddChild(icon)
	self.root:AddChild(frame)
	
	self.icons[clientIndex] = icon
	return stateIcon
end

function GUITeamInfoHUD:UpdateIconTexture(clientIndex,status)
	if status == kPlayerStatus.Hidden then
		self.icons[clientIndex]:SetIsVisible(false)
	else
		self.icons[clientIndex]:SetIsVisible(true)
		
		local xOffset = 0
		local yOffset = 0
		
		if status == kPlayerStatus.Void then
			xOffset = 1
			yOffset = 1
		elseif status == kPlayerStatus.Dead then
			xOffset = 3
			yOffset = 1
		elseif status == kPlayerStatus.Commander then
			xOffset = 2
			yOffset = 1
		
		elseif status == kPlayerStatus.Rifle then
			// 0,0
		elseif status == kPlayerStatus.Shotgun then
			xOffset = 1
		elseif status == kPlayerStatus.GrenadeLauncher then
			xOffset = 2
		elseif status == kPlayerStatus.Flamethrower then
			xOffset = 3
		elseif status == kPlayerStatus.Exo then
			xOffset = 0
			yOffset = 1
			
		elseif status == kPlayerStatus.Skulk then
			// 0,0
		elseif status == kPlayerStatus.Gorge then
			xOffset = 1
		elseif status == kPlayerStatus.Lerk then
			xOffset = 2
		elseif status == kPlayerStatus.Fade then
			xOffset = 3
		elseif status == kPlayerStatus.Onos then
			xOffset = 0
			yOffset = 1
		elseif status == kPlayerStatus.SkulkEgg then
			xOffset = 0
			yOffset = 2
		elseif status == kPlayerStatus.GorgeEgg then
			xOffset = 1
			yOffset = 2
		elseif status == kPlayerStatus.LerkEgg then
			xOffset = 2
			yOffset = 2
		elseif status == kPlayerStatus.FadeEgg then
			xOffset = 3
			yOffset = 2
		elseif status == kPlayerStatus.OnosEgg then
			xOffset = 0
			yOffset = 3
		end
		
		xOffset = xOffset * 64
		yOffset = yOffset * 64
		self.icons[clientIndex]:SetTexturePixelCoordinates(xOffset, yOffset, xOffset + 64, yOffset + 64)
	end
end
