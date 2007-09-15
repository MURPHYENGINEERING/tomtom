--[[---------------------------------------------------------------------------------
  TomTom by Cladhaire <cladhaire@gmail.com>
----------------------------------------------------------------------------------]]

local Waypoint = {}
TomTom.Waypoint = Waypoint

-- Import Astrolabe for locations
local Astrolabe = DongleStub("Astrolabe-0.4")

-- Create a tooltip for use throughout this section
local tooltip = CreateFrame("GameTooltip", "TomTomTooltip", nil, "GameTooltipTemplate")

-- Create a local table used as a pool
local pool = {}

-- Local declarations
local OnEnter,OnLeave,OnClick,OnUpdate,Tooltip_OnUpdate

-- Local default distance in yards
local DEFAULT_DISTANCE = 10

-- Waypoint:New(c,z,x,y,title,note,distance,callback)
-- c (number) - The continent on which to place the waypoint
-- z (number) - The zone on which to place the waypoint
-- x (number) - The x coordinate
-- y (number) - The y coordinate
-- title (string) - A title for the waypoint
-- note (string) - A description or note for this waypoint
-- distance (number) - Arrival distance (in yards)
-- callback (function) - A function to be called when the player is distance
--   yards from the waypoint.
--
-- Creates a new waypoint object at the given coordinate, with the supplied
-- title and note.  Returns a waypoint object.  When 
function Waypoint:New(c,z,x,y,distance,title,note)
	if not self.pool then self.pool = {} end

	-- Try to acquire a waypoint from the frame pool
	local point = table.remove(self.pool)

	if not point then
		point = CreateFrame("Button", nil, Minimap)
		point:SetHeight(12)
		point:SetWidth(12)
		point:RegisterForClicks("RightButtonUp")

		-- Create the actual texture attached for the minimap icon
		point.icon = point:CreateTexture()
		point.icon:SetTexture("Interface\\Minimap\\ObjectIcons")
		point.icon:SetTexCoord(0.5, 0.75, 0, 0.25)
		point.icon:SetAllPoints()

		-- Create the world map point, and associated texture
		point.world = CreateFrame("Button", nil, WorldMapButton)
		point.world:SetHeight(12)
		point.world:SetWidth(12)
		point:RegisterForClicks("RightButtonUp")
		point:SetNormalTexture("Interface\\Minimap\\ObjectIcons")
		point:GetNormalTexture():SetTExCoords(0.5, 0.75, 0, 0.25)

		-- Create the minimap model
		point.arrow = CreateFrame("Model", nil, point)
		point.arrow:SetHeight(140.8)
		point.arrow:SetWidth(140.8)
		point.arrow:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
		point.arrow:SetModel("Interface\\Minimap\\Rotating-MinimapArrow.mdx")
		point.arrow:SetModelScale(.600000023841879)
		point.arrow:Hide()

		-- Add the behavior scripts 
		point:SetScript("OnEnter", OnEnter)
		point:SetScript("OnLeave", OnLeave)
		point:SetScript("OnUpdate", OnUpdate)
		point:SetScript("OnClick", OnClick)

		-- Copy all methods into the table
		for k,v in pairs(Waypoint) do
			Waypoint[k] = v
		end
	end

	-- Set the data for this waypoint
	point.c = c
	point.z = z
	point.x = x
	point.y = y
	point.title = title
	point.note = note
	point.distance = distance or DEFAULT_DISTANCE
	point.callback = callback
	
	-- Use Astrolabe to place the waypoint
	-- TODO: Place the waypoint via astrolabe

	return point
end

-- Waypoint:Clear()
-- 
-- Clears and releases a waypoint without notification.
function Waypoint:Clear()
	self.c = nil
	self.z = nil
	self.x = nil
	self.y = nil
	self.title = nil
	self.note = nil
	self.distance = nil
	self.callback = nil

	self.icon:Hide()
	self.arrow:Hide()
	self.world:Hide()
	
	-- Add the waypoint back into the frame pool
	table.insert(pool, self)

	-- TODO: Remove from Astrolabe	
end

do
	function OnEnter(self, motion)
		tooltip:SetParent(self)
		tooltip:SetOwner(self, "ANCHOR_CURSOR")

		-- Display the title, and add the note if it exists
		tooltip:SetTitle(title or "TomTom Waypoint")
		tooltip:AddLine(self.note or "No note for this waypoint")

		local dist,x,y = Astrolabe:GetDistanceToIcon(self)

		tooltip:AddLine(format("%.2f, %.2f", self.x, self.y), 1, 1, 1)
		tooltip:AddLine(("%s yards away"):format(math.floor(dist)), 1, 1 ,1)
		tooltip:AddLine(TomTom:GetZoneText(self.zone), 0.7, 0.7, 0.7)
		tooltip:Show()
		tooltip:SetScript("OnUpdate", Tooltip_OnUpdate)
	end

	function OnLeave(self, motion)
		tooltip:Hide()
	end

	function OnClick(self, button, down)
		--TODO: Implement dropdown
	end

	function OnUpdate(self, elapsed)
		local edge = Astrolabe:IsIconOnEdge(self)

		if edge and not self.arrow:IsShown() then
			self.arrow:Show()
			self.icon:Hide()
			self.edge = true
		elseif not edge and not self.icon:IsShown() then
			self.icon:Show()
			self.arrow:Hide()
			self.edge = false
		end

		local dist,x,y = Astrolabe:GetDistanceToIcon(self)
		local cleardist = TomTom.profile.options.cleardist

		if dist <= self.distance then
			if self.callback then
				self.callback(self)
				self:Clear()
			end
		end
	end

	local count = 0
	function Tooltip_OnUpdate(self, elapsed)
		count = count + elapsed
		if count >= 0.1 then
			local dist,x,y = Astrolabe:GetDistanceToIcon(self:GetParent())
			TomTomTooltipTextLeft4:SetText(("%s yards away"):format(math.floor(dist)), 1, 1, 1)
		end
	end
end
