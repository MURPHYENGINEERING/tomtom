--[[--------------------------------------------------------------------------
--  TomTom - A navigational assistant for World of Warcraft
-- 
--  CrazyTaxi: A crazy-taxi style arrow used for waypoint navigation.
--    concept taken from MapNotes2 (Thanks to Mery for the idea, along
--    with the artwork.)
----------------------------------------------------------------------------]]

local Astrolabe = DongleStub("Astrolabe-0.4")

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
	GetPlayerBearing = function() return (obj:GetFacing()); end
	return GetPlayerBearing();
end

local twopi = math.pi * 2

local wayframe = CreateFrame("Frame", "TomTomCrazyArrow", UIParent)
wayframe:SetHeight(56)
wayframe:SetWidth(42)
wayframe:SetPoint("CENTER", 0, 0)
wayframe:EnableMouse(true)
wayframe:SetMovable(true)
wayframe:Hide()

wayframe.status = wayframe:CreateFontString("OVERLAY", nil, "GameFontNormalSmall")
wayframe.status:SetPoint("TOP", wayframe, "BOTTOM", 0, 0)

local function OnDragStart(self, button)
	self:StartMoving()
end

local function OnDragStop(self, button)
	self:StopMovingOrSizing()
end

local function OnEvent(self, event, ...)
	if event == "ZONE_CHANGED_NEW_AREA" then
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

local active_point, arrive_distance, showDownArrow

function TomTom:SetCrazyArrow(point, dist)
	active_point = point.minimap
	arrive_distance = dist
	wayframe:Show()
end

local status = wayframe.status
local arrow = wayframe.arrow
local count = 0
local function OnUpdate(self, elapsed)
	local dist,x,y = Astrolabe:GetDistanceToIcon(active_point)
	if not dist then
		self:Hide()
		return
	end

	status:SetText(string.format("%d yards", dist))

	-- Showing the arrival arrow?
	if dist <= arrive_distance then
		if not showDownArrow then
			arrow:SetHeight(70)
			arrow:SetWidth(53)
			arrow:SetTexture("Interface\\AddOns\\TomTom\\Images\\Arrow-UP")
			showDownArrow = true
		end

		count = count + 1
		if count >= 55 then
			count = 0
		end

		local cell = count
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
			
		local angle = Astrolabe:GetDirectionToIcon(active_point)
		local player = GetPlayerBearing()
		
		angle = angle - player
		
		local cell = floor(angle / twopi * 108 + 0.5) % 108
		local column = cell % 9
		local row = floor(cell / 9)
		
		local xstart = (column * 56) / 512
		local ystart = (row * 42) / 512
		local xend = ((column + 1) * 56) / 512
		local yend = ((row + 1) * 42) / 512
		arrow:SetTexCoord(xstart,xend,ystart,yend)
	end
end

wayframe:SetScript("OnUpdate", OnUpdate)