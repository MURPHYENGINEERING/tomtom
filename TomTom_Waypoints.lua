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
function Waypoint:New(c,z,x,y,title,note,distance,callback)
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
		point.world:RegisterForClicks("RightButtonUp")
		point.world:SetNormalTexture("Interface\\Minimap\\ObjectIcons")
		point.world:GetNormalTexture():SetTexCoord(0.5, 0.75, 0, 0.25)

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

		point.world:SetScript("OnEnter", OnEnter)
		point.world:SetScript("OnLeave", OnLeave)
		point.world:SetScript("OnClick", OnClick)

		-- Copy all methods into the table
		for k,v in pairs(Waypoint) do
			point[k] = v
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

	-- Set the data for this waypoint
	point.world.c = c
	point.world.z = z
	point.world.x = x
	point.world.y = y
	point.world.title = title
	point.world.note = note
	point.world.distance = distance or DEFAULT_DISTANCE
	point.world.callback = callback
	
	-- Use Astrolabe to place the waypoint
	-- TODO: Place the waypoint via astrolabe

	x,y = x/100,y/100
	Astrolabe:PlaceIconOnMinimap(point, c, z, x, y)
	Astrolabe:PlaceIconOnWorldMap(WorldMapDetailFrame, point.world, c, z, x, y)

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

	self:Hide()
	Astrolabe:RemoveIconFromMinimap(self)
	
	-- Add the waypoint back into the frame pool
	table.insert(pool, self)
end

do
	-- Local variable declarations
	local tooltip_icon

	function OnEnter(self, motion)
		tooltip:SetOwner(self, "ANCHOR_CURSOR")

		-- Display the title, and add the note if it exists
		tooltip:SetText(title or "TomTom Waypoint")
		tooltip:AddLine(self.note or "No note for this waypoint", 1, 1, 1)

		local dist,x,y = Astrolabe:GetDistanceToIcon(self)

		tooltip:AddLine(format("\n%.2f, %.2f", self.x, self.y), 1, 1, 1)
		if dist then
			tooltip:AddLine(("%s yards away"):format(math.floor(dist)), 1, 1 ,1)
		end
		tooltip:AddLine(TomTom:GetZoneName(self.c, self.z), 0.7, 0.7, 0.7)
		tooltip:Show()
		tooltip:SetScript("OnUpdate", Tooltip_OnUpdate)
		tooltip_icon = self
	end

	function OnLeave(self, motion)
		tooltip:Hide()
	end

	function OnClick(self, button, down)
		--TODO: Implement dropdown
	end
	
	local halfpi = math.pi / 2
	
	-- The magic number which represents the ratio of model position pixels to
	-- logical screen pixels. I suspect this is really based on some property of the
	-- model itself, but I figured it out through interpolation given 3 ratios
	-- 4:3 5:4 16:10
	local MAGIC_ARROW_NUMBER  = 0.000723339
	
	-- Calculation to determine the actual offset factor for the screen ratio, I dont
	-- know where the 1/3 rationally comes from, but it works, there's probably some
	-- odd logic within the client somewhere.
	--
	-- 70.4 is half the width of the frame so we move to the center
	local ofs = MAGIC_ARROW_NUMBER * (GetScreenHeight()/GetScreenWidth() + 1/3) * 70.4;
	-- The divisor here puts the arrow where the original magic number pair had it
	local radius = ofs / 1.166666666666667;
	
	local function gomove(model,angle)
			model:SetFacing(angle);
		-- The 137/140 simply adjusts for the fact that the textured
		-- border around the minimap isn't exactly centered
		model:SetPosition(ofs * (137 / 140) - radius * math.sin(angle),
						  ofs + radius * math.cos(angle), 0);
	end

	function OnUpdate(self, elapsed)
		local edge = Astrolabe:IsIconOnEdge(self)

		if edge then
			if not self.arrow:IsShown() then
				self.arrow:Show()
				self.icon:Hide()
				self.edge = true
			end

			local angle = Astrolabe:GetDirectionToIcon(self)
			
			if GetCVar("rotateMinimap") == "1" then
				local cring = MiniMapCompassRing:GetFacing()
				angle = angle + cring
			end
			
			gomove(self.arrow, angle)
		else
			if not self.icon:IsShown() then					
				self.icon:Show()
				self.arrow:Hide()
				self.edge = false
			end
		end
	
		local dist,x,y = Astrolabe:GetDistanceToIcon(self)
		
		if dist <= self.distance then
			if self.callback then
				self.callback(self)
			end
			self:Clear()
		end
	end

	local count = 0
	function Tooltip_OnUpdate(self, elapsed)
		count = count + elapsed
		if count >= 0.2 then
			local dist,x,y = Astrolabe:GetDistanceToIcon(tooltip_icon)
			if dist then
				TomTomTooltipTextLeft4:SetText(("%s yards away"):format(math.floor(dist)), 1, 1, 1)
			end
		end
	end
end
