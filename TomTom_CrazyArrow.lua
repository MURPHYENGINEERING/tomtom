--[[--------------------------------------------------------------------------
--  TomTom - A navigational assistant for World of Warcraft
-- 
--  CrazyTaxi: A crazy-taxi style arrow used for waypoint navigation.
--    concept taken from MapNotes2 (Thanks to Mery for the idea, along
--    with the artwork.)
----------------------------------------------------------------------------]]

local twopi = math.pi * 2

local playerModel
local children = { Minimap:GetChildren() }
for idx,child in ipairs(children) do
	if child:IsObjectType("Model") and child:GetModel() == "Interface\\Minimap\\MinimapArrow" then
		playerModel = child
		break
	end
end

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

wayframe:SetScript("OnDragStart", OnDragStart)
wayframe:SetScript("OnDragStop", OnDragStop)
wayframe:RegisterForDrag("LeftButton")

wayframe.arrow = wayframe:CreateTexture("OVERLAY")
wayframe.arrow:SetTexture("Interface\\Addons\\TomTom\\Arrow")
wayframe.arrow:SetAllPoints()

local active_point
function TomTom:SetCrazyWaypoint(point)
	active_point = point
	wayframe:Show()
end

local status = wayframe.status
local arrow = wayframe.arrow

local function OnUpdate(self, elapsed)
	local dist,x,y = Astrolabe:GetDistanceToIcon(active_point)
	local angle = Astrolabe:GetDirectionToIcon(active_point)
	local player = playerModel:GetFacing()

	status:SetText(string.format("%d yards", dist))
	
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

wayframe:SetScript("OnUpdate", OnUpdate)