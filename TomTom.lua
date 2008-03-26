--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
----------------------------------------------------------------------------]]

-- Simple localization table for messages
local L = TomTomLocals
local Astrolabe = DongleStub("Astrolabe-0.4")

-- Create the addon object
TomTom = {
	events = {},
	eventFrame = CreateFrame("Frame"),
	RegisterEvent = function(self, event, method)
		self.eventFrame:RegisterEvent(event)
		self.events[event] = event or method
	end,
	UnregisterEvent = function(self, event)
		self.eventFrame:UnregisterEvent(event)
		self.events[event] = nil
	end,
	version = GetAddOnMetadata("TomTom", "Version")
}

if TomTom.version == "wowi:revision" then TomTom.version = "SVN" end

TomTom.eventFrame:SetScript("OnEvent", function(self, event, ...)
	local method = TomTom.events[event]
	if method and TomTom[method] then
		TomTom[method](TomTom, event, ...)
	end
end)

TomTom:RegisterEvent("ADDON_LOADED")

-- Local definitions
local GetCurrentCursorPosition
local WorldMap_OnUpdate
local Block_OnClick,Block_OnUpdate,BlockOnEnter,BlockOnLeave
local Block_OnDragStart,Block_OnDragStop
local callbackTbl
local RoundCoords

local waypoints = {}

function TomTom:ADDON_LOADED(event, addon)
	if addon == "TomTom" then
		self:UnregisterEvent("ADDON_LOADED")
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
					autoqueue = true,
				},
				minimap = {
					enable = true,
					otherzone = true,
					tooltip = true,
				},
				worldmap = {
					enable = true,
					tooltip = true,
					otherzone = true,
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

		self.waydefaults = {
			profile = {
				["*"] = {},
			},
		}

		self.db = LibStub("AceDB-3.0"):New("TomTomDB", self.defaults, "Default")
		self.waydb = LibStub("AceDB-3.0"):New("TomTomWaypoints", self.waydefaults)

		self.db.RegisterCallback(self, "OnProfileChanged", "ReloadOptions")
		self.db.RegisterCallback(self, "OnProfileCopied", "ReloadOptions")
		self.db.RegisterCallback(self, "OnProfileReset", "ReloadOptions")
		self.waydb.RegisterCallback(self, "OnProfileChanged", "ReloadWaypoints")
		self.waydb.RegisterCallback(self, "OnProfileCopied", "ReloadWaypoints")
		self.waydb.RegisterCallback(self, "OnProfileReset", "ReloadWaypoints")

		self.tooltip = CreateFrame("GameTooltip", "TomTomTooltip", nil, "GameTooltipTemplate")
		self.dropdown = CreateFrame("Frame", "TomTomDropdown", nil, "UIDropDownMenuTemplate")

		self.waypoints = waypoints

		self:RegisterEvent("PLAYER_LEAVING_WORLD")
		self:RegisterEvent("PLAYER_ENTERING_WORLD", "ReloadWaypoints")
		self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "ReloadWaypoints")
		self:RegisterEvent("WORLD_MAP_UPDATE", "ReloadWaypoints")
		self:RegisterEvent("CHAT_MSG_ADDON")

		self:ReloadOptions()
		self:ReloadWaypoints()
	end
end

function TomTom:ReloadOptions()
	-- This handles the reloading of all options
	self.profile = self.db.profile

	self:ShowHideWorldCoords()
	self:ShowHideCoordBlock()
	self:ShowHideCrazyArrow()

end

function TomTom:ReloadWaypoints()
	-- Hide any waypoints that might be currently set
	for uid,point in pairs(waypoints) do
		self:ClearWaypoint(uid)
	end

	waypoints = {}
	self.waypoints = waypoints
	self.waypointprofile = self.waydb.profile

	local pc,pz = self:GetCurrentCZ()

	for zone,data in pairs(self.waypointprofile) do
		local c,z = self:GetCZ(zone)
		local same = (c == pc) and (z == pz)
		local minimap = self.profile.minimap.otherzone or same
		local world = self.profile.worldmap.otherzone or same
		for idx,waypoint in ipairs(data) do
			local coord,title = waypoint:match("^(%d+):(.*)$")
			if not title:match("%S") then title = nil end
			local x,y = self:GetXY(coord)
			self:AddZWaypoint(c, z, x*100, y*100, title, false, minimap, world)
		end
	end
end

function TomTom:ShowHideWorldCoords()
	-- Bail out if we're not supposed to be showing this frame
	if self.profile.mapcoords.playerenable or self.db.profile.mapcoords.cursorenable then
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

		if self.profile.mapcoords.playerenable then
			TomTomWorldFrame.Player:Show()
		end

		if self.profile.mapcoords.cursorenable then
			TomTomWorldFrame.Cursor:Show()
		end

		-- Show the frame
		TomTomWorldFrame:Show()
	elseif TomTomWorldFrame then
		TomTomWorldFrame:Hide()
	end
end

function TomTom:ShowHideCoordBlock()
	-- Bail out if we're not supposed to be showing this frame
	if self.profile.block.enable then
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

		local opt = self.profile.block

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

		local uid = TomTom:AddZWaypoint(c,z,x*100,y*100)
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

--[[-------------------------------------------------------------------
--  Dropdown menu code
-------------------------------------------------------------------]]--

StaticPopupDialogs["TOMTOM_REMOVE_ALL_CONFIRM"] = {
	text = L["Are you sure you would like to remove ALL TomTom waypoints?"],
	button1 = L["Yes"],
	button2 = L["No"],
	OnAccept = function()
		for uid,point in pairs(waypoints) do
			TomTom.waydb:ResetProfile()
		end
		TomTom:ReloadWaypoints()
	end,
	timeout = 30,
	whileDead = 1,
	hideOnEscape = 1,
}

local dropdown_info = {
	-- Define level one elements here
	[1] = {
		{ -- Title
			text = L["Waypoint Options"],
			isTitle = 1,
		},
		{
			-- set as crazy arrow
			text = L["Set as waypoint arrow"],
			func = function()
				local uid = TomTom.dropdown.uid
				local data = waypoints[uid]
				TomTom:SetCrazyArrow(uid, TomTom.profile.arrow.arrival, data.title or "TomTom waypoint")
			end,
		},
		{ -- Remove waypoint
			text = L["Remove waypoint"],
			func = function()
				local uid = TomTom.dropdown.uid
				local data = waypoints[uid]
				TomTom:RemoveWaypoint(uid)
				--TomTom:PrintF("Removing waypoint %0.2f, %0.2f in %s", data.x, data.y, data.zone) 
			end,
		},
		{ -- Remove all waypoints from this zone
			text = L["Remove all waypoints from this zone"],
			func = function()
				local uid = TomTom.dropdown.uid
				local data = waypoints[uid]
				for uid in pairs(waypoints[data.zone]) do
					TomTom:RemoveWaypoint(uid)
				end
			end,
		},
		{ -- Remove ALL waypoints
			text = L["Remove all waypoints"],
			func = function()
				StaticPopup_Show("TOMTOM_REMOVE_ALL_CONFIRM")
			end,
		},
		{ -- Save this waypoint
			text = L["Save this waypoint between sessions"],
			checked = function()
				return TomTom:UIDIsSaved(TomTom.dropdown.uid)
			end,
			func = function()
				-- Check to see if it's already saved
				local uid = TomTom.dropdown.uid
				if TomTom:UIDIsSaved(uid) then
					local data = waypoints[uid]
					if data then
						local key = string.format("%d:%s", data.coord, data.title or "")
						local zone = data.zone
						local sv = TomTom.waypointprofile[zone]

						-- Find the entry in the saved variable
						for idx,entry in ipairs(sv) do
							if entry == key then
								table.remove(sv, idx)
								return
							end
						end
					end
				else
					local data = waypoints[uid]
					if data then
						local key = string.format("%d:%s", data.coord, data.title or "")
						local zone = data.zone
						local sv = TomTom.waypointprofile[zone]
						table.insert(sv, key)
					end
				end
			end,
		},
	}
}

local function init_dropdown(level)
	-- Make sure level is set to 1, if not supplied
	level = level or 1

	-- Get the current level from the info table
	local info = dropdown_info[level]

	-- If a value has been set, try to find it at the current level
	if level > 1 and UIDROPDOWNMENU_MENU_VALUE then
		if info[UIDROPDOWNMENU_MENU_VALUE] then
			info = info[UIDROPDOWNMENU_MENU_VALUE]
		end
	end

	-- Add the buttons to the menu
	for idx,entry in ipairs(info) do
		if type(entry.checked) == "function" then
			-- Make this button dynamic
			local new = {}
			for k,v in pairs(entry) do new[k] = v end
			new.checked = new.checked()
			entry = new
		end
		UIDropDownMenu_AddButton(entry, level)
	end
end

function TomTom:UIDIsSaved(uid)
	local data = waypoints[uid]
	if data then
		local key = string.format("%d:%s", data.coord, data.title or "")
		local zone = data.zone
		local sv = TomTom.waypointprofile[zone]

		-- Find the entry in the saved variable
		for idx,entry in ipairs(sv) do
			if entry == key then
				return true
			end
		end
	end
	return false
end


--[[-------------------------------------------------------------------
--  Define callback functions 
-------------------------------------------------------------------]]--
local function _both_onclick(event, uid, self, button)
	TomTom.dropdown.uid = uid
	UIDropDownMenu_Initialize(TomTom.dropdown, init_dropdown)
	ToggleDropDownMenu(1, nil, TomTom.dropdown, "cursor", 0, 0)
end

local function _both_tooltip_show(event, tooltip, uid, dist)
	local data = waypoints[uid]

	tooltip:SetText(data.title or "TomTom waypoint")
	tooltip:AddLine(string.format("%s yards away", math.floor(dist)), 1, 1, 1)
	tooltip:AddLine(string.format("%s (%.2f, %.2f)", data.zone, data.x, data.y), 0.7, 0.7, 0.7)
	tooltip:Show()
end

local function _minimap_tooltip_show(event, tooltip, uid, dist)
	if not TomTom.db.profile.minimap.tooltip then 
		tooltip:Hide()
		return
	end
	return _both_tooltip_show(event, tooltip, uid, dist)
end

local function _world_tooltip_show(event, tooltip, uid, dist)
	if not TomTom.db.profile.worldmap.tooltip then
		tooltip:Hide()
		return
	end
	return _both_tooltip_show(event, tooltip, uid, dist)
end

local function _both_tooltip_update(event, tooltip, uid, dist)
	tooltip.lines[2]:SetFormattedText("%s yards away", math.floor(dist), 1, 1, 1)
end

local function _both_clear_distance(event, uid, range, distance, lastdistance)
	TomTom:RemoveWaypoint(uid)
end

local function _remove(event, uid)
	local data = waypoints[uid]
	local key = string.format("%d:%s", data.coord, data.title or "")
	local zone = data.zone
	local sv = TomTom.waypointprofile[zone]

	-- Find the entry in the saved variable
	for idx,entry in ipairs(sv) do
		if entry == key then
			table.remove(sv, idx)
			break
		end
	end

	-- Remove this entry from the waypoints table
	waypoints[uid] = nil
	if waypoints[zone] then
		waypoints[zone][uid] = nil
	end
end

local function noop() end

function TomTom:GetCurrentCZ()
	local oc,oz = Astrolabe:GetCurrentPlayerPosition()
	SetMapToCurrentZone()
	local c,z = Astrolabe:GetCurrentPlayerPosition()
	if oc and oz then
		SetMapZoom(oc,oz)
	end
	return c,z
end

function TomTom:RemoveWaypoint(uid)
	local data = waypoints[uid]
	self:ClearWaypoint(uid)

	if data then
		local key = string.format("%d:%s", data.coord, data.title or "")
		local zone = data.zone
		local sv = TomTom.waypointprofile[zone]

		-- Find the entry in the saved variable
		for idx,entry in ipairs(sv) do
			if entry == key then
				table.remove(sv, idx)
				break
			end
		end
	end
	-- Remove this entry from the waypoints table
	waypoints[uid] = nil
	if waypoints[zone] then
		waypoints[zone][uid] = nil
	end
end

-- TODO: Make this not suck
function TomTom:AddWaypoint(x, y, desc, persistent, minimap, world)
	local c,z = self:GetCurrentCZ()

	if not c or not z or c < 1 then
		--self:Print("Cannot find a valid zone to place the coordinates")
		return
	end

	return self:AddZWaypoint(c, z, x, y, desc, persistent, minimap, world)
end

function TomTom:AddZWaypoint(c, z, x, y, desc, persistent, minimap, world)
	local callbacks = {
		minimap = {
			onclick = _both_onclick,
			tooltip_show = _minimap_tooltip_show,
			tooltip_update = _both_tooltip_update,
		},
		world = {
			onclick = _both_onclick,
			tooltip_show = _world_tooltip_show,
			tooltip_update = _both_tooltip_show,
		},
		remove = _remove,
		distance = {},
	}

	-- Default values
	if persistent == nil then persistent = self.profile.persistence.savewaypoints end
	if minimap == nil then minimap = true end
	if world == nil then world = true end
	
	if not persistent then
		local cleardistance = self.profile.persistence.cleardistance
		callbacks.distance[cleardistance] = _both_clear_distance
		callbacks.distance[cleardistance+1] = noop
	end

	local uid = self:SetWaypoint(c,z,x/100,y/100, callbacks, minimap, world)
	if self.profile.arrow.autoqueue then
		self:SetCrazyArrow(uid, self.profile.arrow.arrival, desc)
	end

	local coord = self:GetCoord(x / 100, y / 100)
	local zone = self:GetMapFile(c, z)

	waypoints[uid] = {
		title = desc,
		coord = coord,
		x = x,
		y = y,
		zone = zone,
	}

	if not waypoints[zone] then
		waypoints[zone] = {}
	end

	waypoints[zone][uid] = true

	-- If this is a persistent waypoint, then add it to the waypoints table
	if persistent then
		local data = string.format("%d:%s", coord, desc or "")
		table.insert(self.waypointprofile[zone], data)
	end

	return uid
end

-- Code taken from HandyNotes, thanks Xinhuan

---------------------------------------------------------
-- Public functions for plugins to convert between MapFile <-> C,Z
--
local continentMapFile = {
	[WORLDMAP_COSMIC_ID] = "Cosmic", -- That constant is -1
	[0] = "World",
	[1] = "Kalimdor",
	[2] = "Azeroth",
	[3] = "Expansion01",
}
local reverseMapFileC = {}
local reverseMapFileZ = {}
for C = 1, #Astrolabe.ContinentList do
	for Z = 1, #Astrolabe.ContinentList[C] do
		local mapFile = Astrolabe.ContinentList[C][Z]
		reverseMapFileC[mapFile] = C
		reverseMapFileZ[mapFile] = Z
	end
end
for C = -1, 3 do
	local mapFile = continentMapFile[C]
	reverseMapFileC[mapFile] = C
	reverseMapFileZ[mapFile] = 0
end

function TomTom:GetMapFile(C, Z)
	if not C or not Z then return end
	if Z == 0 then
		return continentMapFile[C]
	elseif C > 0 then
		return Astrolabe.ContinentList[C][Z]
	end
end
function TomTom:GetCZ(mapFile)
	return reverseMapFileC[mapFile], reverseMapFileZ[mapFile]
end

-- Public functions for plugins to convert between coords <--> x,y
function TomTom:GetCoord(x, y)
	return floor(x * 10000 + 0.5) * 10000 + floor(y * 10000 + 0.5)
end
function TomTom:GetXY(id)
	return floor(id / 10000) / 10000, (id % 10000) / 10000
end

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

local function usage()
	ChatFrame1:AddMessage("|cffffff78TomTom |r/way |cffffff78Usage:|r")
	ChatFrame1:AddMessage("|cffffff78/way <x> <y> [desc]|r - Adds a waypoint at x,y with descrtiption desc")
	ChatFrame1:AddMessage("|cffffff78/way <zone> <x> <y> [desc]|r - Adds a waypoint at x,y in zone with description desc")
	ChatFrame1:AddMessage("|cffffff78/way reset all|r - Resets all waypoints")
	ChatFrame1:AddMessage("|cffffff78/way reset <zone>|r - Resets all waypoints in zone")
end

local zlist = {}
for cidx,c in ipairs{GetMapContinents()} do
	for zidx,z in ipairs{GetMapZones(cidx)} do
		zlist[z:lower():gsub("[%L]", "")] = {cidx, zidx, z}
	end
end

SLASH_WAY1 = "/way"
SlashCmdList["WAY"] = function(msg)
	local tokens = {}
	for token in msg:gmatch("%S+") do table.insert(tokens, token) end

	-- Lower the first token
	tokens[1] = tokens[1]:lower()

	if tokens[1] == "reset" then
		if tokens[2] == "all" then
			StaticPopup_Show("TOMTOM_REMOVE_ALL_CONFIRM")

		elseif tokens[2] then
			-- Reset the named zone
			local _,zone = unpack(tokens)

			-- Find a fuzzy match for the zone
			local matches = {}
			zone = zone:lower():gsub("[%L]", "")

			for z,entry in pairs(zlist) do
				if z:match(zone) then
					table.insert(matches, entry)
				end
			end

			if #matches > 5 then
				ChatFrame1:AddMessage("Found " .. #matches .. " possible matches for zone '" .. tokens[2] .. "'.  Please be more specific.")
				return
			elseif #matches > 1 then
				local poss = {}
				for k,v in pairs(matches) do
					table.insert(poss, v[3])
				end
				table.sort(poss)

				ChatFrame1:AddMessage("Found multiple matches for zone '" .. tokens[2] .. "'.  Did you mean: " .. table.concat(poss, ", "))
				return
			end


			local c,z,name = unpack(matches[1])
			local zone = TomTom:GetMapFile(c, z)
			if waypoints[zone] then
				for uid in pairs(waypoints[zone]) do
					TomTom:RemoveWaypoint(uid)
				end
			else
				ChatFrame1:AddMessage("There were no waypoints to remove in " .. name)
			end
		end
	elseif tokens[1] and not tonumber(tokens[1]) then
		-- This is a waypoint set, with a zone before the coords
		local zone,x,y,desc = unpack(tokens)
		if desc then desc = table.concat(tokens, " ", 4) end

		-- Find a fuzzy match for the zone
		local matches = {}
		zone = zone:lower():gsub("[%L]", "")

		for z,entry in pairs(zlist) do
			if z:match(zone) then
				table.insert(matches, entry)
			end
		end

		if #matches ~= 1 then
			ChatFrame1:AddMessage("Found " .. #matches .. " possible matches for zone '" .. tokens[1] .. "'.  Please be more specific.")
			return
		end

		local c,z,name = unpack(matches[1])

		if not x or not tonumber(x) then
			return usage()
		elseif not y or not tonumber(y) then
			return usage()
		end

		x = tonumber(x)
		y = tonumber(y)
		TomTom:AddZWaypoint(c, z, x, y, desc)
	elseif tonumber(tokens[1]) then
		-- A vanilla set command
		local x,y,desc = unpack(tokens)
		if not x or not tonumber(x) then
			return usage()
		elseif not y or not tonumber(y) then
			return usage()
		end
		if desc then
			desc = table.concat(tokens, " ", 3)
		end

		x = tonumber(x)
		y = tonumber(y)
		TomTom:AddWaypoint(x, y, desc)
	else
		return usage()
	end
end
