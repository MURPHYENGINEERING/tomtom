--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
----------------------------------------------------------------------------]]

-- Simple localization table for messages
local L = setmetatable({}, {__index=function(t,k) return k end})

local Astrolabe = DongleStub("Astrolabe-0.4")

-- Create the addon object
TomTom = {}

-- Local definitions
local GetCurrentCursorPosition
local WorldMap_OnUpdate
local Block_OnClick,Block_OnUpdate,BlockOnEnter,BlockOnLeave
local Block_OnDragStart,Block_OnDragStop

function TomTom:Initialize()
	self.defaults = {
		profile = {
			cleardistance = 10,
			lock = false,
			coords_worldmap = true,
			coords_cursor = true,
			coords_block = true,
			clearzone = false,
			waypoints = {
			},
			positions = {
				["*"] = {},
			},
		},
	}

	self.db = self:InitializeDB("TomTomDB", self.defaults)

	self:RegisterEvent("PLAYER_LEAVING_WORLD")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("WORLD_MAP_UPDATE")
	self:RegisterEvent("CHAT_MSG_ADDON")

	self:ShowHideWorldCoords()
	self:ShowHideBlockCoords()
end

function TomTom:ShowHideWorldCoords()
	-- Bail out if we're not supposed to be showing this frame
	if self.db.profile.coords_worldmap then
		-- Create the frame if it doesn't exist
		if not TomTomWorldFrame then
			TomTomWorldFrame = CreateFrame("Frame", nil, WorldMapFrame)
			TomTomWorldFrame.Player = TomTomWorldFrame:CreateFontString("OVERLAY", nil, "GameFontHighlightSmall")
			TomTomWorldFrame.Player:SetPoint("BOTTOM", WorldMapPositioningGuide, "BOTTOM", -100, 11)
			
			TomTomWorldFrame.Cursor = TomTomWorldFrame:CreateFontString("OVERLAY", nil, "GameFontHighlightSmall")
			TomTomWorldFrame.Cursor:SetPoint("BOTTOM", WorldMapPositioningGuide, "BOTTOM", 100, 11)
			
			TomTomWorldFrame:SetScript("OnUpdate", WorldMap_OnUpdate)
		end
		-- Show the frame
		TomTomWorldFrame:Show()
	elseif TomTomWorldFrame then
		TomTomWorldFrame:Hide()
	end
end

function TomTom:ShowHideBlockCoords()
	-- Bail out if we're not supposed to be showing this frame
	if self.db.profile.coords_block then
		-- Create the frame if it doesn't exist
		if not TomTomBlock then
			-- Create the coordinate display
			TomTomBlock = CreateFrame("Button", "TomTomBlock", UIParent)
			TomTomBlock:SetWidth(120)
			TomTomBlock:SetHeight(32)
			TomTomBlock:SetToplevel(1)
			TomTomBlock:SetFrameStrata("LOW")
			TomTomBlock:SetMovable(true)
			TomTomBlock:EnableMouse(true)
			TomTomBlock:SetClampedToScreen()
			TomTomBlock:RegisterForDrag("LeftButton")
			TomTomBlock:RegisterForClicks("RightButtonUp")
			TomTomBlock:SetPoint("TOP", Minimap, "BOTTOM", 0, -10)

			TomTomBlock.Text = TomTomBlock:CreateFontString("OVERLAY", nil, "GameFontNormal")
			TomTomBlock.Text:SetJustifyH("CENTER")
			TomTomBlock.Text:SetPoint("CENTER", 0, 0)

			TomTomBlock:SetBackdrop({
										bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
										edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
										edgeSize = 16,
										insets = {left = 4, right = 4, top = 4, bottom = 4},
									})
			TomTomBlock:SetBackdropColor(0,0,0,0.4)
			TomTomBlock:SetBackdropBorderColor(1,0.8,0,0.8)

			-- Set behavior scripts
			TomTomBlock:SetScript("OnUpdate", Block_OnUpdate)
			TomTomBlock:SetScript("OnClick", Block_OnClick)
			TomTomBlock:SetScript("OnEnter", Block_OnEnter)
			TomTomBlock:SetScript("OnLeave", Block_OnLeave)
			TomTomBlock:SetScript("OnDragStop", Block_OnDragStop)
			TomTomBlock:SetScript("OnDragStart", Block_OnDragStart)
		end
		-- Show the frame
		TomTomBlock:Show()
	elseif TomTomBlock then
		TomTomBlock:Hide()
	end
end

-- Hook the WorldMap OnClick
local Orig_WorldMapButton_OnClick = WorldMapButton_OnClick
function WorldMapButton_OnClick(...)
	local mouseButton, button = ...
    if IsControlKeyDown() and mouseButton == "RightButton" then
		local c,z = GetCurrentMapContinent(), GetCurrentMapZone()
		local x,y = GetCurrentCursorPosition()
		
		if z == 0 then
			return
		end

		TomTom:SetWaypoint(c,z,x*100,y*100)
    else
        return Orig_WorldMapButton_OnClick(...)
    end
end

-- TODO: Make this now suck
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

	local point = self:SetWaypoint(c,z,x,y)
	self:SetCrazyArrow(point, 15)
end
--[[

local Orig_WorldMapButton_OnClick = WorldMapButton_OnClick
function WorldMapButton_OnClick(mouseButton, button)
    if IsControlKeyDown() and mouseButton == "RightButton" then
		local c,z = GetCurrentMapContinent(), GetCurrentMapZone()
		local x,y = GetCurrentCursorPosition()

		if z == 0 then
			return
		end

        TomTom:AddZWaypoint(c,z,x*100, y*100)
    else
        Orig_WorldMapButton_OnClick(mouseButton, button)
    end
end

WorldMapMagnifyingGlassButton:SetText(ZOOM_OUT_BUTTON_TEXT .. "\nCtrl+Right Click To Add a Waypoint")

function TomTom:ZONE_CHANGED_NEW_AREA()
	if profile.coords_block then
		local c,z,x,y = Astrolabe:GetCurrentPlayerPosition()
		if c and z and x and y then
			TomTomBlock:Show()
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

function TomTom:AddZWaypoint(c,z,x,y,desc,silent)
	if not self.m_points then self.m_points = {} end
	if not self.w_points then self.w_points = {} end

    if desc == '' then desc = nil end

	local m_icon = self:CreateMinimapIcon(desc, x, y)
	local w_icon = self:CreateWorldMapIcon(desc, x, y)
	m_icon.pair = w_icon
	w_icon.mpair = m_icon

	x = x / 100
	y = y / 100

	Astrolabe:PlaceIconOnMinimap(m_icon, c, z, x, y)
	Astrolabe:PlaceIconOnWorldMap(WorldMapDetailFrame, w_icon, c, z, x, y)

	w_icon:Show()

	local zone = select(z, GetMapZones(c))
	m_icon.zone = zone
	w_icon.zone = zone

	if not silent then
		self:PrintF("Setting a waypoint at %.2f, %.2f in %s.", x * 100, y * 100, zone)
	end

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

--]]

TomTom = DongleStub("Dongle-1.0"):New("TomTom", TomTom)

do
	function GetCurrentCursorPosition()
		-- Coordinate calculation code taken from CT_MapMod
		local cX, cY = GetCursorPosition()
		local ceX, ceY = WorldMapFrame:GetCenter()
		local wmfw, wmfh = WorldMapButton:GetWidth(), WorldMapButton:GetHeight()

		cX = ( ( ( cX / WorldMapFrame:GetScale() ) - ( ceX - wmfw / 2 ) ) / wmfw + 22/10000 )
		cY = ( ( ( ( ceY + wmfh / 2 ) - ( cY / WorldMapFrame:GetScale() ) ) / wmfh ) - 262/10000 )

		return cX, cY
	end

	function WorldMap_OnUpdate(self, elapsed)
		local c,z,x,y = Astrolabe:GetCurrentPlayerPosition()

		if not x or not y then
			self.Player:SetText("Player: ---")
		else
			self.Player:SetText(string.format("Player: %.2f, %.2f", x*100, y*100))
		end

		local cX, cY = GetCurrentCursorPosition()

		if not cX or not cY then
			self.Cursor:SetText("Cursor: ---")
		else
			self.Cursor:SetText(string.format("Cursor: %.2f, %.2f", cX*100, cY*100))
		end
	end
end

do 
	function Block_OnUpdate(self, elapsed)
		local c,z,x,y = Astrolabe:GetCurrentPlayerPosition()
		if not x or not y then
			-- Hide the frame when we have no coordinates
			self:Hide()
		else
			self.Text:SetText(string.format("%.2f, %.2f", x*100, y*100))
		end
	end

	function Block_OnDragStart(self, button, down)
		if not TomTom.db.profile.lock then
			self:StartMoving()
		end
	end

	function Block_OnDragStop(self, button, down)
		self:StopMovingOrSizing()
	end
end
