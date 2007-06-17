local L = setmetatable({
	TOOLTIP_TITLE = "TomTom";
	TOOLTIP_SUBTITLE = "Zone Coordinates";
	TOOLTIP_LOCKED = "This window is locked in place.";
	TOOLTIP_LEFTCLICK = "Left-click and drag to move this window.";
	TOOLTIP_RIGHTCLICK = "Right-click to toggle the options panel.";
}, {__index=function(t,k) return k end})

TomTom = {}
local DongleFrames = DongleStub("DongleFrames-1.0")
local Astrolabe = DongleStub("Astrolabe-0.4")
local profile

function TomTom:Initialize()
	self.defaults = {
		profile = {
			clearwaypoints = true,
			show = true,
			lock = false,
			worldmap = true,
			cursor = true,
			tooltip = true,
			alpha = 1,
			notes = {
			},
		}
	}
	
	self.db = self:InitializeDB("TomTomDB", self.defaults)
	profile = self.db.profile
	self:CreateSlashCommands()
	self:CreateCoordWindows()
	self:RegisterEvent("PLAYER_LEAVING_WORLD")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("WORLD_MAP_UPDATE")
end

function TomTom:CreateCoordWindows()
	-- Create the draggable frame, as well as the world map coords
	local function OnMouseDown(self,button)
		if button == "LeftButton" and not profile.lock then
			self:StartMoving()
			self.isMoving = true
		end
	end

	local function OnMouseUp(self,button)
		if self.isMoving then
			self:StopMovingOrSizing()
			self.isMoving = false
		end
	end

	local function OnEnter(self)
		if profile.tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
			GameTooltip:SetText(L["TOOLTIP_TITLE"])
			GameTooltip:AddLine(L["TOOLTIP_SUBTITLE"])
			if profile.lock then
				GameTooltip:AddLine(L["TOOLTIP_LOCKED"])
			else
				GameTooltip:AddLine(L["TOOLTIP_LEFTCLICK"])
			end
			GameTooltipTextLeft1:SetTextColor(1,1,1);
			GameTooltipTextLeft2:SetTextColor(1,1,1);
			GameTooltip:Show()
		end
	end

	local function OnLeave(self)
		GameTooltip:Hide();
	end
	
	local function CoordFrame_OnUpdate(self, elapsed)		
		local c,z,x,y = Astrolabe:GetCurrentPlayerPosition()
		local text
		if not x or not y then
			self:Hide()
		else
			self.Text:SetText(string.format("%.2f, %.2f", x*100, y*100))
		end
	end

	local function WorldMap_OnUpdate(self, elapsed)
		local c,z,x,y = Astrolabe:GetCurrentPlayerPosition()

		-- Coordinate calculation code taken from CT_MapMod
		local cX, cY = GetCursorPosition()
		local ceX, ceY = WorldMapFrame:GetCenter();
		local wmfw, wmfh = WorldMapButton:GetWidth(), WorldMapButton:GetHeight();
		
		cX = ( ( ( cX / WorldMapFrame:GetScale() ) - ( ceX - wmfw / 2 ) ) / wmfw + 22/10000 );
		cY = ( ( ( ( ceY + wmfh / 2 ) - ( cY / WorldMapFrame:GetScale() ) ) / wmfh ) - 262/10000 );
		
		if not x or not y then
			self.Player:SetText("Player: ---")
		else
			self.Player:SetText(string.format("Player: %.2f, %.2f", x*100, y*100))
		end
		
		if not cX or not cY then
			self.Cursor:SetText("Cursor: ---")
		else
			self.Cursor:SetText(string.format("Cursor: %.2f, %.2f", cX*100, cY*100))
		end
	end  
	
	-- Create TomTomFrame, which is the coordinate display
	DongleFrames:Create("n=TomTomFrame#p=UIParent#size=100,32#toplevel#strata=HIGH#mouse#movable#clamp", "CENTER", 0, 0)
	TomTomFrame.Text = DongleFrames:Create("p=TomTomFrame#t=FontString#inh=GameFontNormal", "CENTER", 0, 0)
	TomTomFrame:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 16,
		insets = {left = 4, right = 4, top = 4, bottom = 4},
	})
	TomTomFrame:SetBackdropColor(0,0,0,0.4)
	TomTomFrame:SetBackdropBorderColor(1,0.8,0,0.8)
	TomTomFrame:SetScript("OnMouseDown", OnMouseDown)
	TomTomFrame:SetScript("OnMouseUp", OnMouseUp)
	TomTomFrame:SetScript("OnHide", OnMouseUp)
	TomTomFrame:SetScript("OnEnter", OnEnter)
	TomTomFrame:SetScript("OnLeave", OnLeave)
	TomTomFrame:SetScript("OnUpdate", CoordFrame_OnUpdate)

	if not profile.show then
		TomTomFrame:Hide()
	end
		
	-- Create TomTomWorldFrame, which is anchored to the center of the WorldMap
	DongleFrames:Create("n=TomTomWorldFrame#p=WorldMapFrame")
	TomTomWorldFrame.Player = DongleFrames:Create("p=TomTomWorldFrame#t=FontString#inh=GameFontHighlightSmall", "BOTTOM", WorldMapPositioningGuide, "BOTTOM", -100, 11)
	TomTomWorldFrame.Cursor = DongleFrames:Create("p=TomTomWorldFrame#t=FontString#inh=GameFontHighlightSmall", "BOTTOM", WorldMapPositioningGuide, "BOTTOM", 100, 11)		
	TomTomWorldFrame:SetScript("OnUpdate", WorldMap_OnUpdate)

	if not profile.worldmap then TomTomWorldFrame:Hide() end	
	
	self.frame = CreateFrame("Frame")

end

local count = 0
local tooltip_icon
local function Tooltip_OnUpdate(self, elapsed)
	count = count + elapsed
	if count >= 0.1 then
		local tooltip = TomTom.tooltip
		local dist,x,y = Astrolabe:GetDistanceToIcon(tooltip_icon)
		TomTomTooltipTextLeft3:SetText(("%s yards away"):format(math.floor(dist)), 1, 1 ,1)
	end
end

local function MinimapIcon_OnEnter(self)
	local tooltip = TomTom.tooltip
	tooltip:SetScale(UIParent:GetEffectiveScale())
	tooltip:SetOwner(self, "ANCHOR_CURSOR")
	tooltip_icon = self
	if self.label then
		tooltip:SetText("TomTom: " .. self.label .. "\n")
	else
		tooltip:SetText("TomTom Waypoint\n")
	end

	local dist,x,y = Astrolabe:GetDistanceToIcon(self)

	tooltip:AddLine(self.coord, 1, 1, 1)
	tooltip:AddLine(("%s yards away"):format(math.floor(dist)), 1, 1 ,1)
	tooltip:AddLine(self.zone, 0.7, 0.7, 0.7)
	tooltip:Show()
	tooltip:SetScript("OnUpdate", Tooltip_OnUpdate)
end

local function MinimapIcon_OnLeave(self)
	local tooltip = TomTom.tooltip
	tooltip_icon = nil
	tooltip:Hide()
	tooltip:SetScript("OnUpdate", nil)
end

local function DropDown_RemoveWaypoint()
	local icon = TomTomDropDown.icon

	Astrolabe:RemoveIconFromMinimap(icon)

	icon.pair:Hide()
	table.insert(TomTom.worldmapIcons, icon.pair)

	for idx,entry in ipairs(TomTom.w_points) do
		local w_icon = entry.icon
		if icon.pair == w_icon then
			table.remove(TomTom.w_points, idx)
			break
		end
	end
end

local function DropDown_Init()
	local dropdown = TomTomDropDown
	local label = dropdown.icon.label

	if not label:match("[^%s]") then
		label = "TomTom Waypoint"
	end

	UIDropDownMenu_AddButton{
		text = label,
		isTitle = 1,
	}

	UIDropDownMenu_AddButton{
		text = "Remove waypoint",
		value = "remove",
		func = DropDown_RemoveWaypoint,
	}
	UIDropDownMenu_AddButton{
		text = "Send to party",
		value = "sendparty",
		func = DropDown_SendWaypoint,
		textR = 0.6,
		textG = 0.6,
		textB = 0.6,
	}
	UIDropDownMenu_AddButton{
		text = "Send to raid",
		value = "sendraid",
		func = DropDown_SendWaypoint,
		textR = 0.6,
		textG = 0.6,
		textB = 0.6,
	}
end

local function MinimapIcon_OnClick(self)
	local dropdown = TomTom.dropdown
	if not dropdown then
		TomTom.dropdown = CreateFrame("Frame", "TomTomDropDown", UIParent, "UIDropDownMenuTemplate")
		dropdown = TomTom.dropdown
		--UIDropDownMenu_SetButtonWidth(50, dropdown)
		--UIDropDownMenu_SetWidth(50, dropdown)
	end

	dropdown:SetParent(self)
	dropdown.icon = self
	UIDropDownMenu_Initialize(dropdown, DropDown_Init, "MENU")
	ToggleDropDownMenu(1, nil, dropdown, "cursor", 0, 0);
end

local halfpi = math.pi / 2
local function MinimapIcon_UpdateArrow(self, elapsed)
	local icon = self.parent
	local angle = Astrolabe:GetDirectionToIcon(icon)

	local x = .03875* math.cos(angle + halfpi) + 0.04875 
	local y = .03875* math.sin(angle + halfpi) + 0.04875 
	self:SetPosition(x,y,0)
	self:SetFacing(angle)	
end

local function MinimapIcon_OnUpdate(self, elapsed)
	local edge = Astrolabe:IsIconOnEdge(self)
	local dot = self.dot:IsShown()
	local arrow = self.arrow:IsShown()

	if edge and not arrow then
		self.arrow:Show()
		self.arrow.seqtime = 0
		self.dot:Hide()
		self.edge = true
	elseif not edge and not dot then
		self.dot:Show()
		self.arrow:Hide()
		self.edge = false
	end

	local dist,x,y = Astrolabe:GetDistanceToIcon(self)
	if dist and dist < 11 and profile.clearwaypoints then
		-- Clear this waypoint
		Astrolabe:RemoveIconFromMinimap(self)
		self.pair:Hide()
		table.insert(TomTom.worldmapIcons, self.pair)
		local msg = (self.label and self.label ~= "") and self.label or "your destination"

		TomTom:PrintF("You have arrived at %s (%s)", msg, self.coord)

		for idx,entry in ipairs(TomTom.w_points) do
			local w_icon = entry.icon
			if self.pair == w_icon then
				table.remove(TomTom.w_points, idx)
				break
			end
		end
	end
end

function TomTom:CreateMinimapIcon(label, x, y)
	if not self.minimapIcons then
		self.minimapIcons = {}
	end

	if not self.tooltip then
		self.tooltip = CreateFrame("GameTooltip", "TomTomTooltip", nil, "GameTooltipTemplate")
	end

	-- Return one from the frame pool, if possible
	local icon = table.remove(self.minimapIcons)
	if icon then
		icon.label = label
		icon.coord = string.format("%5.2f, %5.2f", x, y)
		return icon 
	end
	
	-- Create a new icon with arrow
	-- icon.dot is the minimap dot texture
	-- icon.arrow is the model used on the edge of the map
	-- icon.label will contain the mouseover label
	-- icon.coord will contain the text of the coordinates
	icon = CreateFrame("Button", nil, Minimap)
	icon:SetHeight(12)
	icon:SetWidth(12)
	icon:RegisterForClicks("RightButtonUp")

	icon.label = label
	icon.coord = string.format("%5.2f, %5.2f", x, y)

	local texture = icon:CreateTexture()
	texture:SetTexture("Interface\\Minimap\\ObjectIcons")
	texture:SetTexCoord(0.5, 0.75, 0, 0.25)
	texture:SetAllPoints()
	icon.dot = texture
	icon:SetScript("OnEnter", MinimapIcon_OnEnter)
	icon:SetScript("OnLeave", MinimapIcon_OnLeave)
	icon:SetScript("OnUpdate", MinimapIcon_OnUpdate)
	icon:SetScript("OnClick", MinimapIcon_OnClick)

	local model = CreateFrame("Model", nil, icon)
	model:SetHeight(140.8)
	model:SetWidth(140.8)
	model:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
	model:SetModel("Interface\\Minimap\\Rotating-MinimapArrow.mdx")
--	model:SetFogColor(0.9999977946281433,0.9999977946281433,0.9999977946281433,0.9999977946281433)
--	model:SetFogColor(math.random(), math.random(), math.random(), math.random())
--	model:SetFogFar(1)
--	model:SetFogNear(0)
--	model:SetLight(0,1,0,0,0,1,1,1,1,1,1,1,1)
--	model:SetLight(1, 0, 0, -0.707, -0.707, 0.7, 1.0, 1.0, 1.0, 0.8, 1.0, 1.0, 0.8)
	model:SetModelScale(.600000023841879)

	model.parent = icon
	icon.arrow = model
	model:SetScript("OnUpdate", MinimapIcon_UpdateArrow)
	model:Hide()

	return icon
end

local function WorldMapIcon_OnEnter(self)
	local tooltip = TomTom.tooltip
	tooltip:SetScale(UIParent:GetEffectiveScale())
	tooltip:SetOwner(self, "ANCHOR_CURSOR")
	tooltip_icon = self
	if self.label then
		tooltip:SetText("TomTom: " .. self.label .. "\n")
	else
		tooltip:SetText("TomTom Waypoint\n")
	end

	tooltip:AddLine(self.coord, 1, 1, 1)
	tooltip:AddLine(self.zone, 0.7, 0.7, 0.7)
	tooltip:Show()
end

local function WorldMapIcon_OnLeave(self)
	local tooltip = TomTom.tooltip
	tooltip:Hide()
end

function TomTom:CreateWorldMapIcon(label, x, y)
	if not self.worldmapIcons then
		self.worldmapIcons = {}
	end

	-- Return one from the frame pool, if possible
	local icon = table.remove(self.worldmapIcons)
	if icon then
		icon.label = label
		icon.coord = string.format("%5.2f, %5.2f", x, y)
		return icon 
	end
	
	-- Create a new icon with arrow
	-- icon.dot is the minimap dot texture
	-- icon.label will contain the mouseover label
	-- icon.coord will contain the text of the coordinates
	icon = CreateFrame("Button", nil, WorldMapButton)
	icon:SetHeight(12)
	icon:SetWidth(12)

	icon.label = label
	icon.coord = string.format("%5.2f, %5.2f", x, y)

	local texture = icon:CreateTexture()
	texture:SetTexture("Interface\\Minimap\\ObjectIcons")
	texture:SetTexCoord(0.5, 0.75, 0, 0.25)
	texture:SetAllPoints()
	icon.dot = texture
	icon:SetScript("OnEnter", WorldMapIcon_OnEnter)
	icon:SetScript("OnLeave", WorldMapIcon_OnLeave)
	return icon
end

function TomTom:CreateSlashCommands()
	-- Options slash commands
	self.cmd = self:InitializeSlashCommand("TomTom Slash Command", "TOMTOM", "tomtom")
	
	local ToggleDisplay = function(origin)
		if origin == "coord" and TomTomFrame then
			profile.show = not profile.show
			TomTomFrame[profile.show and "Show" or "Hide"](TomTomFrame)
			self:PrintF("The coordinate display has been %s.", profile.show and "shown" or "hidden")
		elseif origin == "mapcoord" and TomTomWorldFrame then
			profile.worldmap = not profile.worldmap
			TomTomWorldFrame[profile.worldmap and "Show" or "Hide"](TomTomWorldFrame)
			self:PrintF("The world map coordinate display has been %s.", profile.worldmap and "shown" or "hidden")
		end
	end
	
	local LockDisplay = function()
		profile.lock = not profile.lock
		self:PrintF("The coordinate display has been %s.", profile.lock and "locked" or "unlocked")
	end
	
	self.cmd:RegisterSlashHandler("|cffffff00coord|r - Show/Hide the coordinate display", "^(coord)$", ToggleDisplay)
	self.cmd:RegisterSlashHandler("|cffffff00mapcoord|r - Show/Hide the world map coordinate display", "^(mapcoord)$", ToggleDisplay)
	self.cmd:RegisterSlashHandler("|cffffff00lock|r - Lock/Unlock the coordinate display", "^lock$", LockDisplay)

	-- Waypoint placement slash commands
	self.cmd_way = self:InitializeSlashCommand("TomTom - Waypoints", "TOMTOM_WAY", "way")
	
	local Way_Set = function(x,y,desc)
		self:AddWaypoint(x,y,desc)
	end
	
	local Way_Reset = function()
		if #self.w_points == 0 then
			self:Print("There are no waypoints to remove.")
			return
		end

		if self.m_points then
			for cont,ztbl in pairs(self.m_points) do
				for zone,ztbl in pairs(ztbl) do
					for idx,entry in pairs(ztbl) do
						Astrolabe:RemoveIconFromMinimap(entry.icon)
						table.insert(self.minimapIcons, entry.icon)
						ztbl[idx] = nil
					end
				end
			end
		end

		if self.w_points then
			for k,v in ipairs(self.w_points) do
				local icon = v.icon
				icon:Hide()
				self.w_points[k] = nil
				table.insert(self.worldmapIcons, icon)
			end
		end
		
		self:Print("All waypoints have been removed.")
	end
		
	self.cmd_way:RegisterSlashHandler("reset - Remove all current waypoints", "^reset$", Way_Reset)
	self.cmd_way:RegisterSlashHandler("<xx.xx> <yy.yy> [<desc>] - Add a new waypoint with optional note", "^(%d*%.?%d*)[%s]+(%d*%.?%d*)%s*(.*)", Way_Set)
end

function TomTom:ZONE_CHANGED_NEW_AREA()
	-- This could clear the minimap, but I won't.. cause.. I don't like that
	-- Not sure what to do here

	if profile.show then
		local c,z,x,y = Astrolabe:GetCurrentPlayerPosition()
		if c and z and x and y then
			TomTomFrame:Show()
		end
	end

	if true then return end
end

function TomTom:PLAYER_ENTERING_WORLD()
	local oc,oz = Astrolabe:GetCurrentPlayerPosition()
	SetMapToCurrentZone()
	local c,z,x,y = Astrolabe:GetCurrentPlayerPosition()
	if oc and oz then
		SetMapZoom(oc,oz)
	end

	if self.m_points and self.m_points[c] then
		for zone,v in pairs(self.m_points[c]) do
			for idx,entry in pairs(v) do
				Astrolabe:PlaceIconOnMinimap(entry.icon, c, zone, entry.x, entry.y)
			end
		end
	end
end

function TomTom:WORLD_MAP_UPDATE()
	if not self.w_points then return end

	local c = GetCurrentMapContinent()

	for idx,entry in ipairs(self.w_points) do
		local icon = entry.icon
		local x,y = Astrolabe:PlaceIconOnWorldMap(WorldMapDetailFrame, icon, entry.c, entry.z, entry.x, entry.y)
		if (x and y and (0 < x and x <= 1) and (0 < y and y <= 1)) then 
			icon:Show()
		else
			icon:Hide()
		end
	end
end

local sortFunc = function(a,b) 
	if a.x == b.x then return a.y < b.y else return a.x < b.x end
end
	

function TomTom:AddZWaypoint(c,z,x,y,desc)
	if not self.m_points then self.m_points = {} end
	if not self.w_points then self.w_points = {} end

	local m_icon = self:CreateMinimapIcon(desc, x, y)
	local w_icon = self:CreateWorldMapIcon(desc, x, y)
	m_icon.pair = w_icon

	x = x / 100
	y = y / 100

	Astrolabe:PlaceIconOnMinimap(m_icon, c, z, x, y)
	Astrolabe:PlaceIconOnWorldMap(WorldMapDetailFrame, w_icon, c, z, x, y)
	
	w_icon:Show()

	local zone = select(z, GetMapZones(c))
	m_icon.zone = zone
	w_icon.zone = zone

	self:PrintF("Setting a waypoint at %.2f, %.2f in %s.", x * 100, y * 100, zone)

	self.m_points[c] = self.m_points[c] or {}
	self.m_points[c][z] = self.m_points[c][z] or {}
	self.m_points.current = self.m_points[c][z]
	
	table.insert(self.m_points[c][z], {["x"] = x, ["y"] = y, ["icon"] = m_icon})
	table.sort(self.m_points[c][z], sortFunc)

	table.insert(self.w_points, {["c"] = c, ["z"] = z, ["x"] = x, ["y"] = y, ["icon"] = w_icon})
end

function TomTom:AddWaypoint(x,y,desc)
	local oc,oz = Astrolabe:GetCurrentPlayerPosition()
	SetMapToCurrentZone()
	local c,z = Astrolabe:GetCurrentPlayerPosition()
	if oc and oz then
		SetMapZoom(oc,oz)
	end

	if not c or not z or c < 1 then
		self:Print("Cannot find a valid zone to place the coordinates")
		return 
	end

	self:AddZWaypoint(c,z,x,y,desc)
end

TomTom = DongleStub("Dongle-1.0"):New("TomTom", TomTom)
