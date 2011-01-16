--[[--------------------------------------------------------------------------
--  TomTom by Cladhaire <cladhaire@gmail.com>
----------------------------------------------------------------------------]]

-- Simple localization table for messages
local L = TomTomLocals
local ldb = LibStub("LibDataBroker-1.1")
local astrolabe = DongleStub("Astrolabe-1.0")
local lmd = LibStub("LibMapData-1.0")

-- Create the addon object
TomTom = {
	events = {},
	eventFrame = CreateFrame("Frame"),
	RegisterEvent = function(self, event, method)
		self.eventFrame:RegisterEvent(event)
		self.events[event] = method or event
	end,
	UnregisterEvent = function(self, event)
		self.eventFrame:UnregisterEvent(event)
		self.events[event] = nil
	end,
	version = GetAddOnMetadata("TomTom", "Version")
}

if TomTom.version == "wowi:revision" then TomTom.version = "SVN" end
if TomTom.version == "@project-version@" then TomTom.version = "SCM" end

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
local Block_OnClick,Block_OnUpdate,Block_OnEnter,Block_OnLeave
local Block_OnDragStart,Block_OnDragStop
local callbackTbl
local RoundCoords

local waypoints = {}

function TomTom:ADDON_LOADED(event, addon)
	if addon == "TomTom" then
		self:UnregisterEvent("ADDON_LOADED")
		self.defaults = {
			profile = {
				general = {
					confirmremoveall = true,
					announce = false,
					corpse_arrow = true,
				},
				block = {
					enable = true,
					accuracy = 2,
					bordercolor = {1, 0.8, 0, 0.8},
					bgcolor = {0, 0, 0, 0.4},
					lock = false,
					height = 30,
					width = 100,
					fontsize = 12,
                    throttle = 0.2,
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
					noclick = false,
					showtta = true,
					autoqueue = true,
					menu = true,
					scale = 1.0,
					alpha = 1.0,
					title_width = 0,
					title_height = 0,
					title_scale = 1,
					title_alpha = 1,
					setclosest = true,
                    enablePing = false,
				},
				minimap = {
					enable = true,
					otherzone = true,
					tooltip = true,
					menu = true,
				},
				worldmap = {
					enable = true,
					tooltip = true,
					otherzone = true,
					clickcreate = true,
					menu = true,
					create_modifier = "C",
				},
				comm = {
					enable = true,
					prompt = false,
				},
				persistence = {
					cleardistance = 10,
					savewaypoints = true,
				},
				feeds = {
					coords = false,
					coords_throttle = 0.3,
					coords_accuracy = 2,
					arrow = false,
					arrow_throttle = 0.1,
				},
                poi = {
                    enable = false,
                    modifier = "C",
                    setClosest = false,
                },
			},
		}

		self.waydefaults = {
            global = {
                converted = {
                    ["*"] = {},
                },
            },
			profile = {
				["*"] = {},
			},
		}

		self.db = LibStub("AceDB-3.0"):New("TomTomDB", self.defaults, "Default")
		self.waydb = LibStub("AceDB-3.0"):New("TomTomWaypointsMF", self.waydefaults)

		self.db.RegisterCallback(self, "OnProfileChanged", "ReloadOptions")
		self.db.RegisterCallback(self, "OnProfileCopied", "ReloadOptions")
		self.db.RegisterCallback(self, "OnProfileReset", "ReloadOptions")
		self.waydb.RegisterCallback(self, "OnProfileChanged", "ReloadWaypoints")
		self.waydb.RegisterCallback(self, "OnProfileCopied", "ReloadWaypoints")
		self.waydb.RegisterCallback(self, "OnProfileReset", "ReloadWaypoints")

		self.tooltip = CreateFrame("GameTooltip", "TomTomTooltip", nil, "GameTooltipTemplate")
        self.tooltip:SetFrameStrata("DIALOG")

		self.dropdown = CreateFrame("Frame", "TomTomDropdown", nil, "UIDropDownMenuTemplate")

        -- Both the waypoints and waypointprofile tables are going to contain subtables for each
        -- of the mapids that might exist. Under these will be a hash of key/waypoint pairs consisting
        -- of the waypoints for the given map file.
		self.waypoints = waypoints
		self.waypointprofile = self.waydb.profile

		self:RegisterEvent("PLAYER_LEAVING_WORLD")
		self:RegisterEvent("CHAT_MSG_ADDON")

		self:ReloadOptions()
		self:ReloadWaypoints()

		if self.db.profile.feeds.coords then
			-- Create a data feed for coordinates
			local feed_coords = ldb:NewDataObject("TomTom_Coords", {
				type = "data source",
				icon = "Interface\\Icons\\INV_Misc_Map_01",
				text = "",
			})

			local coordFeedFrame = CreateFrame("Frame")
			local throttle, counter = self.db.profile.feeds.coords_throttle, 0
            function TomTom:_privateupdatecoordthrottle(x)
                throttle = x
            end

			coordFeedFrame:SetScript("OnUpdate", function(self, elapsed)
				counter = counter + elapsed
				if counter < throttle then
					return
				end

				counter = 0
                local m, f, x, y = TomTom:GetCurrentPlayerPosition()

				if x and y then
                    local opt = TomTom.db.profile.feeds
					feed_coords.text = string.format("%s", RoundCoords(x, y, opt.coords_accuracy))
				end
			end)
		end
	end
end

-- Some utility functions that can pack/unpack data from a waypoint

-- Returns a hashable 'key' for a given waypoint consisting of the
-- map, floor, x, y and the waypoints title. This isn't truly
-- unique, but should be close enough to determine duplicates, etc.
function TomTom:GetKey(waypoint)
    local m,f,x,y = unpack(waypoint)
    return self:GetKeyArgs(m, f, x, y, waypoint.title)
end

function TomTom:GetKeyArgs(m, f, x, y, title)
    if not f then
        local floors = astrolabe:GetNumFloors(m)
        f = floors == 0 and 0 or 1
    end

    return string.format("%d:%d:%d:%d:%s", m, f, x, y, tostring(title))
end

local flipFixFrame = CreateFrame("Frame", "TomTomMapFlipFixFrame", UIParent)
do
    local throttle = 0.25
    local counter = 0
    flipFixFrame:SetScript("OnUpdate", function(self, elapsed)
        counter = counter + elapsed
        if counter >= throttle then
            counter = counter - throttle
            if not WorldMapFrame:IsVisible() and not WorldMapFrame:IsShown() then
                local x, y = GetPlayerMapPosition("player")
                if x <= 0 or y <= 0 then
                    -- Flip the map, do not flip it back
                    SetMapToCurrentZone()
                end
            end
        end
    end)
end

function TomTom:GetCurrentPlayerPosition()
    -- Try to get the position without 'flipping' the map
    local m, f, x, y = astrolabe:GetUnitPosition("player", false)
    if m and x and y and not (x <= 0 or y <= 0) then
        local floors = astrolabe:GetNumFloors(m)
        local floor = floors == 0 and 0 or 1
        return m, floor, x, y
    end
end

function TomTom:ReloadOptions()
	-- This handles the reloading of all options
	self.profile = self.db.profile

	self:ShowHideWorldCoords()
	self:ShowHideCoordBlock()
	self:ShowHideCrazyArrow()
    self:EnableDisablePOIIntegration()
end

function TomTom:ClearAllWaypoints()
    for mapId, entries in pairs(waypoints) do
        for key, waypoint in pairs(entries) do
            -- The waypoint IS the UID now
            self:ClearWaypoint(waypoint)
        end
    end
end

function TomTom:ReloadWaypoints()
    self:ClearAllWaypoints()

	waypoints = {}
	self.waypoints = waypoints
	self.waypointprofile = self.waydb.profile

    local cm, cf, cx, cy = astrolabe:GetCurrentPlayerPosition()

	for mapId,data in pairs(self.waypointprofile) do
		local same = mapId == cm
		local minimap = self.profile.minimap.enable and (self.profile.minimap.otherzone or same)
		local world = self.profile.worldmap.enable and (self.profile.worldmap.otherzone or same)
		for key,waypoint in pairs(data) do
            local m,f,x,y = unpack(waypoint)
            local title = waypoint.title

            self:AddMFWaypoint(m, f, x, y, {
                desc = title,
                title = title,
                persistent = waypoint.persistent,
                minimap = minimap,
                world = world,
                custom_callbacks = nil,
                silent = true,
            })
		end
	end
end

function TomTom:UpdateCoordFeedThrottle()
    self:_privateupdatecoordthrottle(self.db.profile.feeds.coords_throttle)
end

-- Hook some global functions so we know when the world map size changes
local mapSizedUp = not (WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE);
hooksecurefunc("WorldMap_ToggleSizeUp", function()
    mapSizedUp = true
    TomTom:ShowHideWorldCoords()
end)
hooksecurefunc("WorldMap_ToggleSizeDown", function()
    mapSizedUp = false
    TomTom:ShowHideWorldCoords()
end)

function TomTom:ShowHideWorldCoords()
	-- Bail out if we're not supposed to be showing this frame
	if self.profile.mapcoords.playerenable or self.db.profile.mapcoords.cursorenable then
		-- Create the frame if it doesn't exist
		if not TomTomWorldFrame then
			TomTomWorldFrame = CreateFrame("Frame", nil, WorldMapFrame)
			TomTomWorldFrame.Player = TomTomWorldFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			TomTomWorldFrame.Cursor = TomTomWorldFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			TomTomWorldFrame:SetScript("OnUpdate", WorldMap_OnUpdate)
		end

        if mapSizedUp then
            TomTomWorldFrame.Player:SetPoint("RIGHT", WorldMapPositioningGuide, "BOTTOM", -15, 15)
            TomTomWorldFrame.Cursor:SetPoint("LEFT", WorldMapPositioningGuide, "BOTTOM", 15, 15)
        else
            TomTomWorldFrame.Player:SetPoint("RIGHT", WorldMapPositioningGuide, "BOTTOM", -40, 2)
            TomTomWorldFrame.Cursor:SetPoint("LEFT", WorldMapPositioningGuide, "BOTTOM", -15, 2)
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

			TomTomBlock.Text = TomTomBlock:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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
local world_click_verify = {
	["A"] = function() return IsAltKeyDown() end,
	["C"] = function() return IsControlKeyDown() end,
	["S"] = function() return IsShiftKeyDown() end,
}

local origScript = WorldMapButton_OnClick
WorldMapButton_OnClick = function(self, ...)
	local mouseButton, button = ...
	if mouseButton == "RightButton" then
		-- Check for all the modifiers that are currently set
		for mod in TomTom.db.profile.worldmap.create_modifier:gmatch("[ACS]") do
			if not world_click_verify[mod] or not world_click_verify[mod]() then
                return origScript and origScript(self, ...) or true
			end
		end

        local m,f = GetCurrentMapAreaID()
		local x,y = GetCurrentCursorPosition()

		if not m then
			return origScript and origScript(self, ...) or true
		end

		local uid = TomTom:AddMFWaypoint(m,f,x,y)
	else
		return origScript and origScript(self, ...) or true
	end
end

if WorldMapButton:GetScript("OnMouseUp") == origScript then
    WorldMapButton:SetScript("OnMouseUp", WorldMapButton_OnClick)
end

local function WaypointCallback(event, arg1, arg2, arg3)
	if event == "OnDistanceArrive" then
		TomTom:ClearWaypoint(arg1)
	elseif event == "OnTooltipShown" then
		local tooltip = arg1
		if arg3 then
			tooltip:SetText(L["TomTom waypoint"])
			tooltip:AddLine(string.format(L["%s yards away"], math.floor(arg2)), 1, 1 ,1)
			tooltip:Show()
		else
			tooltip.lines[2]:SetFormattedText(L["%s yards away"], math.floor(arg2), 1, 1, 1)
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
		TomTom.waydb:ResetProfile()
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
                local data = uid
				TomTom:SetCrazyArrow(uid, TomTom.profile.arrow.arrival, data.title or L["TomTom waypoint"])
			end,
		},
		{
			-- Send waypoint
			text = L["Send waypoint to"],
			hasArrow = true,
			value = "send",
		},
		{ -- Remove waypoint
			text = L["Remove waypoint"],
			func = function()
				local uid = TomTom.dropdown.uid
				local data = uid
                TomTom:RemoveWaypoint(uid)
				--TomTom:PrintF("Removing waypoint %0.2f, %0.2f in %s", data.x, data.y, data.zone)
			end,
		},
		{ -- Remove all waypoints from this zone
			text = L["Remove all waypoints from this zone"],
			func = function()
				local uid = TomTom.dropdown.uid
				local data = uid
                local mapId = data[1]
				for key, waypoint in pairs(waypoints[mapId]) do
					TomTom:RemoveWaypoint(waypoint)
				end
			end,
		},
		{ -- Remove ALL waypoints
			text = L["Remove all waypoints"],
			func = function()
				if TomTom.db.profile.general.confirmremoveall then
					StaticPopup_Show("TOMTOM_REMOVE_ALL_CONFIRM")
				else
					StaticPopupDialogs["TOMTOM_REMOVE_ALL_CONFIRM"].OnAccept()
					return
				end
			end,
		},
		{ -- Save this waypoint
			text = L["Save this waypoint between sessions"],
			checked = function()
				return TomTom:UIDIsSaved(TomTom.dropdown.uid)
			end,
			func = function()
                -- Add/remove it from the SV file
                local uid = TomTom.dropdown.uid
                local data = waypoints[uid]
                if data then
                    local key = TomTom:GetKey(data)
                    local mapId = data[1]

                    if mapId then
                        if UIDIsSavedTomTom.waypointprofile[mapId][key] then
                            TomTom.waypointprofile[mapId][key] = nil
                        else
                            TomTom.waypointprofile[mapId][key] = data
                        end
                    end
                end
			end,
		},
	},
	[2] = {
		send = {
			{
				-- Title
				text = L["Waypoint communication"],
				isTitle = true,
			},
			{
				-- Party
				text = L["Send to party"],
				func = function()
					TomTom:SendWaypoint(TomTom.dropdown.uid, "PARTY")
				end
			},
			{
				-- Raid
				text = L["Send to raid"],
				func = function()
					TomTom:SendWaypoint(TomTom.dropdown.uid, "RAID")
				end
			},
			{
				-- Battleground
				text = L["Send to battleground"],
				func = function()
					TomTom:SendWaypoint(TomTom.dropdown.uid, "BATTLEGROUND")
				end
			},
			{
				-- Guild
				text = L["Send to guild"],
				func = function()
					TomTom:SendWaypoint(TomTom.dropdown.uid, "GUILD")
				end
			},
		},
	},
}

local function init_dropdown(self, level)
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
		else
			entry.checked = nil
		end

		UIDropDownMenu_AddButton(entry, level)
	end
end

function TomTom:InitializeDropdown(uid)
	self.dropdown.uid = uid
	UIDropDownMenu_Initialize(self.dropdown, init_dropdown)
end

function TomTom:UIDIsSaved(uid)
	local data = uid
	if data then
        local key = TomTom:GetKey(data)
        local mapId = data[1]

        if data then
            return not not TomTom.waypointprofile[mapId][key]
        end
	end
	return false
end

function TomTom:SendWaypoint(uid, channel)
	local data = uid
    local m, f, x, y = unpack(data)
	local msg = string.format("%d:%d:%f:%f:%s", m, f, x, y, data.title or "")
	SendAddonMessage("TOMTOM3", msg, channel)
end

function TomTom:CHAT_MSG_ADDON(event, prefix, data, channel, sender)
	if prefix ~= "TOMTOM3" then return end
	if sender == UnitName("player") then return end

	local m,f,x,y,title = string.split(":", data)
	if not title:match("%S") then
		title = string.format(L["Waypoint from %s"], sender)
	end

    local zoneName = lmd:MapLocalize(m)
	self:AddMFWaypoint(m, f, x, y, title)
	local msg = string.format(L["|cffffff78TomTom|r: Added '%s' (sent from %s) to zone %s"], title, sender, zoneName)
	ChatFrame1:AddMessage(msg)
end

--[[-------------------------------------------------------------------
--  Define callback functions
-------------------------------------------------------------------]]--
local function _minimap_onclick(event, uid, self, button)
	if TomTom.db.profile.minimap.menu then
		TomTom:InitializeDropdown(uid)
		ToggleDropDownMenu(1, nil, TomTom.dropdown, "cursor", 0, 0)
	end
end

local function _world_onclick(event, uid, self, button)
	if TomTom.db.profile.worldmap.menu then
		TomTom:InitializeDropdown(uid)
		ToggleDropDownMenu(1, nil, TomTom.dropdown, "cursor", 0, 0)
	end
end

local function _both_tooltip_show(event, tooltip, uid, dist)
	local data = uid

	tooltip:SetText(data.title or L["TomTom waypoint"])
	if dist and tonumber(dist) then
		tooltip:AddLine(string.format(L["%s yards away"], math.floor(dist)), 1, 1, 1)
	else
		tooltip:AddLine(L["Unknown distance"])
	end
    local m,f,x,y = unpack(data)
    local zoneName = lmd:MapLocalize(m)

	tooltip:AddLine(string.format(L["%s (%.2f, %.2f)"], zoneName, x*100, y*100), 0.7, 0.7, 0.7)
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
	if dist and tonumber(dist) then
		tooltip.lines[2]:SetFormattedText(L["%s yards away"], math.floor(dist), 1, 1, 1)
	else
		tooltip.lines[2]:SetText(L["Unknown distance"])
	end
end

local function _both_clear_distance(event, uid, range, distance, lastdistance)
	if not UnitOnTaxi("player") then
		TomTom:RemoveWaypoint(uid)
	end
end

local function _both_ping_arrival(event, uid, range, distance, lastdistance)
    if TomTom.profile.arrow.enablePing then
        PlaySoundFile("Interface\\AddOns\\TomTom\\Media\\ping.mp3")
    end
end

local function _remove(event, uid)
	local data = uid
    local key = TomTom:GetKey(data)
    local mapId = data[1]
	local sv = TomTom.waypointprofile[mapId]

    if sv and sv[key] then
        sv[key] = nil
    end

	-- Remove this entry from the waypoints table
	if waypoints[mapId] then
		waypoints[mapId][key] = nil
	end
end

local function noop() end

function TomTom:RemoveWaypoint(uid)
	local data = uid
	self:ClearWaypoint(uid)

    local key = TomTom:GetKey(data)
    local mapId = data[1]
	local sv = TomTom.waypointprofile[mapId]

    if sv and sv[key] then
        sv[key] = nil
    end

	-- Remove this entry from the waypoints table
	if waypoints[mapId] then
		waypoints[mapId][key] = nil
	end
end

-- TODO: Make this not suck
function TomTom:AddWaypoint(x, y, desc, persistent, minimap, world, silent)
	local c,z = GetCurrentMapContinent(), GetCurrentMapZone()

	if not c or not z or c < 1 then
		--self:Print("Cannot find a valid zone to place the coordinates")
		return
	end

	return self:AddZWaypoint(c, z, x/100, y/100, desc, persistent, minimap, world, nil, silent)
end

function TomTom:AddZWaypoint(c, z, x, y, desc, persistent, minimap, world, custom_callbacks, silent, crazy)
    -- Convert the c,z,x,y tuple to m,f,x,y and pass the work off to AddMFWaypoint()
    local mapId, floor = astrolabe:GetMapID(c, z)
    if not mapId then
        return
    end

    return self:AddMFWaypoint(mapId, floor, x/100, y/100, {
        title = desc,
        persistent = persistent,
        minimap = minimap,
        world = world,
        custom_callbacks = custom_callbacks,
        silent = silent,
        crazy = crazy,
    })
end

function TomTom:AddMFWaypoint(m, f, x, y, opts)
    opts = opts or {}

    print("AddMFWaypoint", m, f, x, y, opts and opts.title)
    if opts then
        for k,v in pairs(opts) do
            print("option:", k, v)
        end
    end
	local callbacks
	if opts.custom_callbacks then
		callbacks = opts.custom_callbacks
	else
		callbacks = {
			minimap = {
				onclick = _minimap_onclick,
				tooltip_show = _minimap_tooltip_show,
				tooltip_update = _both_tooltip_update,
			},
			world = {
				onclick = _world_onclick,
				tooltip_show = _world_tooltip_show,
				tooltip_update = _both_tooltip_show,
			},
			distance = {
			},
		}
	end

	local cleardistance = self.profile.persistence.cleardistance
    local arrivaldistance = self.profile.arrow.arrival

    if cleardistance == arrivaldistance then
        callbacks.distance[cleardistance] = function(...)
            _both_clear_distance(...);
            _both_ping_arrival(...);
        end
    else
        if cleardistance > 0 then
            callbacks.distance[cleardistance] = _both_clear_distance
        end
        if arrivaldistance > 0 then
            callbacks.distance[arrivaldistance] = _both_ping_arrival
        end
	end

	-- Default values
	if opts.persistent == nil then opts.persistent = self.profile.persistence.savewaypoints end
	if opts.minimap == nil then opts.minimap = self.profile.minimap.enable end
	if opts.world == nil then opts.world = self.profile.worldmap.enable end
	if opts.crazy == nil then opts.crazy = self.profile.arrow.autoqueue end

    local zoneName = lmd:MapLocalize(m)

    if not astrolabe:GetMapInfo(m) then
		return
	end

    -- Get the default map floor, if necessary
    if not f then
        local floors = astrolabe:GetNumFloors(m)
        f = floors == 0 and 0 or 1
    end

	-- Ensure there isn't already a waypoint at this location
    local key = self:GetKey({m, f, x, y, title = opts.title})
    if waypoints[m] and waypoints[m][key] then
        return waypoints[m][key]
    end

    -- uid is the 'new waypoint' called this for historical reasons
    local uid = {m, f, x, y, title = opts.title}

    -- Copy over any options, so we have em
    for k,v in pairs(opts) do
        if not uid[k] then
            uid[k] = v
        end
    end

    -- No need to convert x and y because they're already 0-1 instead of 0-100
	self:SetWaypoint(uid, callbacks, opts.minimap, opts.world)
	if opts.crazy then
		self:SetCrazyArrow(uid, self.profile.arrow.arrival, opts.title)
	end

    waypoints[m] = waypoints[m] or {}
    waypoints[m][key] = uid

	-- If this is a persistent waypoint, then add it to the waypoints table
	if opts.persistent then
        self.waypointprofile[m][key] = uid
	end

	if not opts.silent and self.profile.general.announce then
		local ctxt = RoundCoords(x, y, 2)
        local desc = opts.desc and opts.desc or ""
        local sep = opts.desc and " - " or ""
        local msg = string.format(L["|cffffff78TomTom:|r Added a waypoint (%s%s%s) in %s"], desc, sep, ctxt, zoneName)
		ChatFrame1:AddMessage(msg)
	end

	return uid
end

-- Check to see if a given uid/waypoint is actually set somewhere
function TomTom:IsValidWaypoint(waypoint)
    local m = waypoint[1]
    local key = self:GetKey(waypoint)
    if waypoints[m] and waypoints[m][key] then
        return true
    else
        return false
    end
end

function TomTom:WaypointMFExists(m, f, x, y, desc)
    local key = self:GetKeyArgs(m, f, x, y, desc)
    if waypoints[m] and waypoints[m][key] then
        return true
    else
        return false
    end
end

function TomTom:WaypointExists(c, z, x, y, desc)
    local m, f = astrolabe:GetMapID(c, z)
    return self:WaypointMFExists(m, f, x, y, desc)
end

function TomTom:SetCustomWaypoint(c,z,x,y,callback,minimap,world,silent)
	return self:AddZWaypoint(c, z, x, y, nil, false, minimap, world, callback, silent)
end

function TomTom:SetCustomMFWaypoint(m, f, x, y, opts)
    opts.persistent = false

    return self:AddMFWaypoint(m, f, x, y, opts)
end

do
	-- Code courtesy ckknight
	function GetCurrentCursorPosition()
		local x, y = GetCursorPosition()
		local left, top = WorldMapDetailFrame:GetLeft(), WorldMapDetailFrame:GetTop()
		local width = WorldMapDetailFrame:GetWidth()
		local height = WorldMapDetailFrame:GetHeight()
		local scale = WorldMapDetailFrame:GetEffectiveScale()
		local cx = (x/scale - left) / width
		local cy = (top - y/scale) / height

		if cx < 0 or cx > 1 or cy < 0 or cy > 1 then
			return nil, nil
		end

		return cx, cy
	end

	local coord_fmt = "%%.%df, %%.%df"
	function RoundCoords(x,y,prec)
		local fmt = coord_fmt:format(prec, prec)
		return fmt:format(x*100, y*100)
	end

	function WorldMap_OnUpdate(self, elapsed)
		local m,f,x,y = TomTom:GetCurrentPlayerPosition()
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
    local bcounter = 0
	function Block_OnUpdate(self, elapsed)
        bcounter = bcounter + elapsed
        if bcounter > TomTom.profile.block.throttle then
            bcounter = bcounter - TomTom.profile.block.throttle

            local m,f,x,y = astrolabe:GetCurrentPlayerPosition()

            local opt = TomTom.db.profile
            if not x or not y then
                local blank = ("-"):rep(8)
                self.Text:SetText(blank)
            else
                self.Text:SetFormattedText("%s", RoundCoords(x, y, opt.block.accuracy))
            end
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

    function Block_OnClick(self, button, down)
        local m,f,x,y = TomTom:GetCurrentPlayerPosition()
        local zoneName = lmd:MapLocalize(m,f)
        local desc = format("%s: %.2f, %.2f", zoneName, x*100, y*100)
        TomTom:AddZWaypoint(m, f, x, y, desc)
    end
end

local function usage()
	ChatFrame1:AddMessage(L["|cffffff78TomTom |r/way |cffffff78Usage:|r"])
	ChatFrame1:AddMessage(L["|cffffff78/way <x> <y> [desc]|r - Adds a waypoint at x,y with descrtiption desc"])
	ChatFrame1:AddMessage(L["|cffffff78/way <zone> <x> <y> [desc]|r - Adds a waypoint at x,y in zone with description desc"])
	ChatFrame1:AddMessage(L["|cffffff78/way reset all|r - Resets all waypoints"])
	ChatFrame1:AddMessage(L["|cffffff78/way reset <zone>|r - Resets all waypoints in zone"])
end

function TomTom:GetClosestWaypoint()
    local m,f,x,y = self:GetCurrentPlayerPosition()
	local closest_waypoint = nil
	local closest_dist = nil
	if waypoints[m] then
		for key, waypoint in pairs(waypoints[m]) do
            local dist, x, y = TomTom:GetDistanceToWaypoint(waypoint) 
			if (dist and closest_dist == nil) or (dist and dist < closest_dist) then
				closest_dist = dist
				closest_waypoint = waypoint
			end
		end
	end
	if closest_dist then
		return closest_waypoint
	end
end

function TomTom:SetClosestWaypoint()
	local uid = self:GetClosestWaypoint()
	if uid then
		local data = uid
		TomTom:SetCrazyArrow(uid, TomTom.profile.arrow.arrival, data.title)
	end
end

SLASH_TOMTOM_CLOSEST_WAYPOINT1 = "/cway"
SLASH_TOMTOM_CLOSEST_WAYPOINT2 = "/closestway"
SlashCmdList["TOMTOM_CLOSEST_WAYPOINT"] = function(msg)
	TomTom:SetClosestWaypoint()
end

SLASH_TOMTOM_WAYBACK1 = "/wayb"
SLASH_TOMTOM_WAYBACK2 = "/wayback"
SlashCmdList["TOMTOM_WAYBACK"] = function(msg)
	local backc,backz,backx,backy = TomTom:GetCurrentPlayerPosition()
	TomTom:AddZWaypoint(backc, backz, backx, backy, L["Wayback"])
end

SLASH_TOMTOM_WAY1 = "/way"
SLASH_TOMTOM_WAY2 = "/tway"
SLASH_TOMTOM_WAY3 = "/tomtomway"

local nameToMapId = {}
local mapIds = lmd:GetAllMapIDs()

for idx, mapId in ipairs(mapIds) do
    local mapName = lmd:MapLocalize(mapId)
    nameToMapId[mapName] = mapId
end

local wrongseparator = "(%d)" .. (tonumber("1.1") and "," or ".") .. "(%d)"
local rightseparator =   "%1" .. (tonumber("1.1") and "." or ",") .. "%2"

SlashCmdList["TOMTOM_WAY"] = function(msg)
	msg = msg:gsub("(%d)[%.,] (%d)", "%1 %2"):gsub(wrongseparator, rightseparator)
	local tokens = {}
	for token in msg:gmatch("%S+") do table.insert(tokens, token) end

	-- Lower the first token
	if tokens[1] then
		tokens[1] = tokens[1]:lower()
	end

	if tokens[1] == "reset" then
		if tokens[2] == "all" then
			if TomTom.db.profile.general.confirmremoveall then
				StaticPopup_Show("TOMTOM_REMOVE_ALL_CONFIRM")
			else
				StaticPopupDialogs["TOMTOM_REMOVE_ALL_CONFIRM"].OnAccept()
				return
			end

		elseif tokens[2] then
			-- Reset the named zone
			local zone = table.concat(tokens, " ", 2)

			-- Find a fuzzy match for the zone
			local matches = {}
			zone = zone:lower():gsub("[%L]", "")

			for name,mapId in pairs(nameToMapId) do
                local lname = name:lower()
				if lname:match(zone) then
					table.insert(matches, lname)
				end
			end

			if #matches > 5 then
				local msg = string.format(L["Found %d possible matches for zone %s.  Please be more specific"], #matches, tokens[2])
				ChatFrame1:AddMessage(msg)
				return
			elseif #matches > 1 then
				table.sort(matches)

				ChatFrame1:AddMessage(string.format(L["Found multiple matches for zone '%s'.  Did you mean: %s"], tokens[2], table.concat(matches, ", ")))
				return
			end

            local zoneName = matches[1]
            local mapId = nameToMapId[zoneName]

			if waypoints[mapId] then
				for key, uid in pairs(waypoints[mapId]) do
					TomTom:RemoveWaypoint(uid)
				end
			else
				ChatFrame1:AddMessage(L["There were no waypoints to remove in %s"]:format(zoneName))
			end
		end
	elseif tokens[1] and not tonumber(tokens[1]) then
		-- Find the first numeric token
		local zoneEnd = 1
		for idx,token in ipairs(tokens) do
			if tonumber(token) then
				zoneEnd = idx - 1
				break
			end
		end

		-- This is a waypoint set, with a zone before the coords
		local zone = table.concat(tokens, " ", 1, zoneEnd)
		local x,y,desc = select(zoneEnd + 1, unpack(tokens))

		if desc then desc = table.concat(tokens, " ", zoneEnd + 3) end

        -- Find a fuzzy match for the zone
        local matches = {}
        zone = zone:lower():gsub("[%L]", "")

        for name,mapId in pairs(nameToMapId) do
            local lname = name:lower()
            if lname:match(zone) then
                table.insert(matches, lname)
            end
        end

		if #matches ~= 1 then
				local msg = string.format(L["Found %d possible matches for zone %s.  Please be more specific"], #matches, tokens[1])
				ChatFrame1:AddMessage(msg)
			return
		end

		local zoneName = matches[1]
        local mapId = nameToMapId[zoneName]

		if not x or not tonumber(x) then
			return usage()
		elseif not y or not tonumber(y) then
			return usage()
		end

		x = tonumber(x)
		y = tonumber(y)
		TomTom:AddMFWaypoint(mapId, nil, x, y, desc)
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
