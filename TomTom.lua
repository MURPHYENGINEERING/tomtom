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
local callbackTbl

function TomTom:Initialize()
	self.defaults = {
		profile = {
			block = {
				enable = true,
				accuracy = 2,
				bordercolor = {1, 0.8, 0, 0.8},
				bgcolor = {0, 0, 0, 0.4},
				lock = false,
				height = 30,
				width = 100,
				fontsize = 12,
			},
			mapcoords = {
				playerenable = true,
				playeraccuracy = 2,
				cursorenable = true,
				cursoraccuracy = 2,
			},
			arrow = {
				enable = true,
				goodcolor = {0, 1, 0},
				badcolor = {1, 0, 0},
				middlecolor = {1, 1, 0},
				arrival = 15,
				lock = false,
				showtta = true,
			},
			minimap = {
				enable = true,
				otherzone = true,
				tooltip = true,
			},
			worldmap = {
				enable = true,
				otherzone = true,
				tooltip = true,
				clickcreate = true,
			},
			comm = {
				enable = true,
				prompt = false,
			},
			persistence = {
				cleardistance = 10,
				savewaypoints = true,
			},
		},
	}

	self.db = self:InitializeDB("TomTomDB", self.defaults)

	self.tooltip = CreateFrame("GameTooltip", "TomTomTooltip", nil, "GameTooltipTemplate")

	self:RegisterEvent("PLAYER_LEAVING_WORLD")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("WORLD_MAP_UPDATE")
	self:RegisterEvent("CHAT_MSG_ADDON")

	-- Push the arrival distance into the callback table
	local cleardistance = self.db.profile.persistence.cleardistance
	if cleardistance > 0 then
		callbackTbl.distance[cleardistance] = function(event, uid)
			TomTom:RemoveWaypoint(uid)
		end
		callbackTbl.distance[cleardistance+1] = function() end
	end

	self:ShowHideWorldCoords()
	self:ShowHideBlockCoords()
end

function TomTom:ShowHideWorldCoords()
	-- Bail out if we're not supposed to be showing this frame
	if self.db.profile.mapcoords.playerenable or self.db.profile.mapcoords.cursorenable then
		-- Create the frame if it doesn't exist
		if not TomTomWorldFrame then
			TomTomWorldFrame = CreateFrame("Frame", nil, WorldMapFrame)
			TomTomWorldFrame.Player = TomTomWorldFrame:CreateFontString("OVERLAY", nil, "GameFontHighlightSmall")
			TomTomWorldFrame.Player:SetPoint("BOTTOM", WorldMapPositioningGuide, "BOTTOM", -100, 11)
			
			TomTomWorldFrame.Cursor = TomTomWorldFrame:CreateFontString("OVERLAY", nil, "GameFontHighlightSmall")
			TomTomWorldFrame.Cursor:SetPoint("BOTTOM", WorldMapPositioningGuide, "BOTTOM", 100, 11)
			
			TomTomWorldFrame:SetScript("OnUpdate", WorldMap_OnUpdate)
		end

		TomTomWorldFrame.Player:Hide()
		TomTomWorldFrame.Cursor:Hide()

		if self.db.profile.mapcoords.playerenable then
			TomTomWorldFrame.Player:Show()
		end

		if self.db.profile.mapcoords.cursorenable then
			TomTomWorldFrame.Cursor:Show()
		end

		-- Show the frame
		TomTomWorldFrame:Show()
	elseif TomTomWorldFrame then
		TomTomWorldFrame:Hide()
	end
end

function TomTom:ShowHideBlockCoords()
	-- Bail out if we're not supposed to be showing this frame
	if self.db.profile.block.enable then
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
			TomTomBlock:SetPoint("TOP", Minimap, "BOTTOM", -20, -10)

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

		local opt = self.db.profile.block

		-- Update the backdrop color, and border color
		TomTomBlock:SetBackdropColor(unpack(opt.bgcolor))
		TomTomBlock:SetBackdropBorderColor(unpack(opt.bordercolor))

		-- Update the height and width
		TomTomBlock:SetHeight(opt.height)
		TomTomBlock:SetWidth(opt.width)

		-- Update the font size
		local font,height = TomTomBlock.Text:GetFont()
		TomTomBlock.Text:SetFont(font, opt.fontsize, select(3, TomTomBlock.Text:GetFont()))

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

		local uid = TomTom:AddWaypoint(c,z,x*100,y*100)
    else
        return Orig_WorldMapButton_OnClick(...)
    end
end

WorldMapMagnifyingGlassButton:SetText(ZOOM_OUT_BUTTON_TEXT .. "\nCtrl+Right Click To Add a Waypoint")

local function WaypointCallback(event, arg1, arg2, arg3)
	if event == "OnDistanceArrive" then
		TomTom:ClearWaypoint(arg1)
	elseif event == "OnTooltipShown" then
		local tooltip = arg1
		if arg3 then
			tooltip:SetText("TomTom waypoint")
			tooltip:AddLine(string.format("%s yards away", math.floor(arg2)), 1, 1 ,1)
			tooltip:Show()
		else
			tooltip.lines[2]:SetFormattedText("%s yards away", math.floor(arg2), 1, 1, 1)
		end
	end
end

callbackTbl = {
	tooltip_show = function(event, tooltip, uid, dist)
		tooltip:SetText("TomTom waypoint")
		tooltip:AddLine(string.format("%s yards away", math.floor(dist)), 1, 1, 1)
		tooltip:Show()
	end,
	tooltip_update = function(event, tooltip, uid, dist)
		tooltip.lines[2]:SetFormattedText("%s yards away", math.floor(dist), 1, 1, 1)
	end,
	distance = {
	},
}

-- TODO: Make this not suck
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

	local point = self:SetWaypoint(c, z, x, y, callbackTbl)
	self:SetCrazyArrow(point, self.db.profile.arrow.arrival)
end

function TomTom:AddZWaypoint(c,z,x,y,desc)
	local point = self:SetWaypoint(c,z,x,y, callbackTbl)
	self:SetCrazyArrow(point, self.db.profile.arrow.arrival)
end

TomTom = DongleStub("Dongle-1.1"):New("TomTom", TomTom)

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

	local coord_fmt = "%%.%df, %%.%df"
	function RoundCoords(x,y,prec)
		local fmt = coord_fmt:format(prec, prec)
		return fmt:format(x*100, y*100)
	end

	function WorldMap_OnUpdate(self, elapsed)
		local c,z,x,y = Astrolabe:GetCurrentPlayerPosition()
		local opt = TomTom.db.profile

		if not x or not y then
			self.Player:SetText("Player: ---")
		else
			self.Player:SetFormattedText("Player: %s", RoundCoords(x, y, opt.mapcoords.playeraccuracy))
		end

		local cX, cY = GetCurrentCursorPosition()

		if not cX or not cY then
			self.Cursor:SetText("Cursor: ---")
		else
			self.Cursor:SetFormattedText("Cursor: %s", RoundCoords(cX, cY, opt.mapcoords.cursoraccuracy))
		end
	end
end

do 
	function Block_OnUpdate(self, elapsed)
		local c,z,x,y = Astrolabe:GetCurrentPlayerPosition()
		local opt = TomTom.db.profile

		if not x or not y then
			-- Hide the frame when we have no coordinates
			self:Hide()
		else
			self.Text:SetFormattedText("%s", RoundCoords(x, y, opt.block.accuracy))
		end
	end

	function Block_OnDragStart(self, button, down)
		if not TomTom.db.profile.block.lock then
			self:StartMoving()
		end
	end

	function Block_OnDragStop(self, button, down)
		self:StopMovingOrSizing()
	end
end

SLASH_WAY1 = "/way"
SlashCmdList["WAY"] = function(msg)
	local x,y,desc = msg:match("(%d+%.?%d*)%s+(%d+%.?%d*)%s*(.*)")
	x,y = tonumber(x), tonumber(y)
	TomTom:PrintF("Adding waypoint %d %d", x, y)
	TomTom:AddWaypoint(x, y, desc)
end

