--[[--------------------------------------------------------------------------
--  TomTom - A navigational assistant for World of Warcraft
-- 
--  CrazyTaxi: A crazy-taxi style arrow used for waypoint navigation.
--    concept taken from MapNotes2 (Thanks to Mery for the idea, along
--    with the artwork.)
----------------------------------------------------------------------------]]

local Astrolabe = DongleStub("Astrolabe-0.4")
local sformat = string.format
local L = TomTomLocals

local GetPlayerBearing
function GetPlayerBearing()
	local obj; -- Remains an upvalue
	do
		local t = {Minimap:GetChildren()}; -- Becomes garbage
		for k, v in pairs(t) do
			if v:IsObjectType("Model") and not v:GetName() then
				local model = v:GetModel():lower()
				if model:match("interface\\minimap\\minimaparrow") then 
					obj = v; break;
				end
			end
		end
	end
	if not obj then return; end

	-- If we've found what we were looking for, rewrite function to skip the search next time.
	GetPlayerBearing = function() 
		if GetCVar("rotateMinimap") ~= "0" then
			return (MiniMapCompassRing:GetFacing() * -1)
		else
			return obj:GetFacing(); 
		end
	end
	return GetPlayerBearing();
end

local function ColorGradient(perc, ...)
	local num = select("#", ...)
	local hexes = type(select(1, ...)) == "string"

	if perc == 1 then
		return select(num-2, ...), select(num-1, ...), select(num, ...)
	end

	num = num / 3

	local segment, relperc = math.modf(perc*(num-1))
	local r1, g1, b1, r2, g2, b2
	r1, g1, b1 = select((segment*3)+1, ...), select((segment*3)+2, ...), select((segment*3)+3, ...)
	r2, g2, b2 = select((segment*3)+4, ...), select((segment*3)+5, ...), select((segment*3)+6, ...)

	if not r2 or not g2 or not b2 then
		return r1, g1, b1
	else
		return r1 + (r2-r1)*relperc,
		g1 + (g2-g1)*relperc,
		b1 + (b2-b1)*relperc
	end
end

local twopi = math.pi * 2

local wayframe = CreateFrame("Button", "TomTomCrazyArrow", UIParent)
wayframe:SetHeight(42)
wayframe:SetWidth(56)
wayframe:SetPoint("CENTER", 0, 0)
wayframe:EnableMouse(true)
wayframe:SetMovable(true)
wayframe:Hide()

wayframe.title = wayframe:CreateFontString("OVERLAY", nil, "GameFontHighlightSmall")
wayframe.status = wayframe:CreateFontString("OVERLAY", nil, "GameFontNormalSmall")
wayframe.tta	= wayframe:CreateFontString("OVERLAY", nil, "GameFontNormalSmall")
wayframe.title:SetPoint("TOP", wayframe, "BOTTOM", 0, 0)
wayframe.status:SetPoint("TOP", wayframe.title, "BOTTOM", 0, 0)
wayframe.tta:SetPoint("TOP", wayframe.status, "BOTTOM", 0, 0)

local function OnDragStart(self, button)
	if not TomTom.db.profile.arrow.lock then
		self:StartMoving()
	end
end

local function OnDragStop(self, button)
	self:StopMovingOrSizing()
end

local function OnEvent(self, event, ...)
	if event == "ZONE_CHANGED_NEW_AREA" and TomTom.profile.arrow.enable then
		self:Show()
	end
end

wayframe:SetScript("OnDragStart", OnDragStart)
wayframe:SetScript("OnDragStop", OnDragStop)
wayframe:RegisterForDrag("LeftButton")
wayframe:RegisterEvent("ZONE_CHANGED_NEW_AREA")
wayframe:SetScript("OnEvent", OnEvent)

wayframe.arrow = wayframe:CreateTexture("OVERLAY")
wayframe.arrow:SetTexture("Interface\\Addons\\TomTom\\Images\\Arrow")
wayframe.arrow:SetAllPoints()

local active_point, arrive_distance, showDownArrow, point_title

function TomTom:SetCrazyArrow(uid, dist, title)
	if self.profile.arrow.enable then
		active_point = uid
		arrive_distance = dist
		point_title = title 

		wayframe.title:SetText(title or "Unknown waypoint")
		wayframe:Show()
	end
end

local status = wayframe.status
local tta = wayframe.tta
local arrow = wayframe.arrow
local count = 0
local last_distance = 0
local tta_throttle = 0
local speed = 0
local speed_count = 0
local function OnUpdate(self, elapsed)
	if not active_point then
		self:Hide()
		return
	end

	local dist,x,y = TomTom:GetDistanceToWaypoint(active_point)
	if not dist or IsInInstance() then
		self:Hide()
		return
	end

	status:SetText(sformat("%d yards", dist))

	local cell

	-- Showing the arrival arrow?
	if dist <= arrive_distance then
		if not showDownArrow then
			arrow:SetHeight(70)
			arrow:SetWidth(53)
			arrow:SetTexture("Interface\\AddOns\\TomTom\\Images\\Arrow-UP")
			arrow:SetVertexColor(unpack(TomTom.db.profile.arrow.goodcolor))
			showDownArrow = true
		end

		count = count + 1
		if count >= 55 then
			count = 0
		end

		cell = count
		local column = cell % 9
		local row = floor(cell / 9)

		local xstart = (column * 53) / 512
		local ystart = (row * 70) / 512
		local xend = ((column + 1) * 53) / 512
		local yend = ((row + 1) * 70) / 512
		arrow:SetTexCoord(xstart,xend,ystart,yend)
	else
		if showDownArrow then
			arrow:SetHeight(56)
			arrow:SetWidth(42)
			arrow:SetTexture("Interface\\AddOns\\TomTom\\Images\\Arrow")
			showDownArrow = false
		end

		local angle = TomTom:GetDirectionToWaypoint(active_point)
		local player = GetPlayerBearing()

		angle = angle - player

		local perc = math.abs((math.pi - math.abs(angle)) / math.pi)

		local gr,gg,gb = unpack(TomTom.db.profile.arrow.goodcolor)
		local mr,mg,mb = unpack(TomTom.db.profile.arrow.middlecolor)
		local br,bg,bb = unpack(TomTom.db.profile.arrow.badcolor)
		local r,g,b = ColorGradient(perc, br, bg, bb, mr, mg, mb, gr, gg, gb)		
		arrow:SetVertexColor(r,g,b)

		cell = floor(angle / twopi * 108 + 0.5) % 108
		local column = cell % 9
		local row = floor(cell / 9)

		local xstart = (column * 56) / 512
		local ystart = (row * 42) / 512
		local xend = ((column + 1) * 56) / 512
		local yend = ((row + 1) * 42) / 512
		arrow:SetTexCoord(xstart,xend,ystart,yend)
	end

	-- Calculate the TTA every second  (%01d:%02d)

	tta_throttle = tta_throttle + elapsed

	if tta_throttle >= 1.0 then
		-- Calculate the speed in yards per sec at which we're moving
		local current_speed = (last_distance - dist) / tta_throttle

		if last_distance == 0 then
			current_speed = 0
		end

		if speed_count < 2 then
			speed = (speed + current_speed) / 2
			speed_count = speed_count + 1
		else
			speed_count = 0
			speed = current_speed
		end

		if speed > 0 then
			local eta = math.abs(dist / speed)
			tta:SetFormattedText("%01d:%02d", eta / 60, eta % 60) 
		else
			tta:SetText("***")
		end
		
		last_distance = dist
		tta_throttle = 0
	end
end

function TomTom:ShowHideCrazyArrow()
	if self.profile.arrow.enable then
		wayframe:Show()

		-- Set the scale and alpha
		wayframe:SetScale(TomTom.db.profile.arrow.scale)
		wayframe:SetAlpha(TomTom.db.profile.arrow.alpha)
		local width = TomTom.db.profile.arrow.title_width
		local height = TomTom.db.profile.arrow.title_height

		wayframe.title:SetWidth(width)
		wayframe.title:SetHeight(height)

		if self.profile.arrow.showtta then
			tta:Show()
		else
			tta:Hide()
		end
	else
		wayframe:Hide()
	end
end

wayframe:SetScript("OnUpdate", OnUpdate)


--[[-------------------------------------------------------------------------
--  Dropdown
-------------------------------------------------------------------------]]--

local dropdown_info = {
	-- Define level one elements here
	[1] = {
		{
			-- Title
			text = L["TomTom Waypoint Arrow"],
			isTitle = 1,
		},
		{
			-- Clear waypoint from crazy arrow
			text = L["Clear waypoint from crazy arrow"],
			func = function()
				active_point = nil
			end,
		},
		{
			-- Remove a waypoint
			text = L["Remove waypoint"],
			func = function()
				local uid = active_point
				TomTom:RemoveWaypoint(uid)
			end,
		},
		{
			-- Remove all waypoints from this zone
			text = L["Remove all waypoints from this zone"],
			func = function()
				local uid = active_point
				local waypoints = TomTom.waypoints
				local data = waypoints[uid]
				for uid in pairs(waypoints[data.zone]) do
					TomTom:RemoveWaypoint(uid)
				end
			end,
		},
		{
			-- Remove all waypoints
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
	}
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
		end
		UIDropDownMenu_AddButton(entry, level)
	end
end

wayframe:RegisterForClicks("RightButtonUp")
wayframe:SetScript("OnClick", function(self, button)
	if TomTom.db.profile.arrow.menu then
		UIDropDownMenu_Initialize(TomTom.dropdown, init_dropdown)
		ToggleDropDownMenu(1, nil, TomTom.dropdown, "cursor", 0, 0)
	end
end)
