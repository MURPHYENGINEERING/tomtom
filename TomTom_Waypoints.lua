--[[--------------------------------------------------------------------------
--  TomTom - A navigational assistant for World of Warcraft
----------------------------------------------------------------------------]]

-- Import Astrolabe for locations
local Astrolabe = DongleStub("Astrolabe-0.4")

-- Create a tooltip to be used when mousing over waypoints
local tooltip = CreateFrame("GameTooltip", "TomTomTooltip", nil, "GameTooltipTemplate")

-- Create a local table used as a frame pool
local pool = {}

-- Local declarations
local Minimap_OnEnter,Minimap_OnLeave,Minimap_OnUpdate,Minimap_OnClick,Minimap_OnEvent
local Arrow_OnUpdate
local Minimap_OnEvent
local World_OnEnter,World_OnLeave,World_OnClick,World_OnEvent

-- pointObject = TomTom:SetWaypoint(c,z,x,y,far,near,arrive,callback)
-- c (number) - The continent number
-- z (number) - The zone number
-- x (number) - The x coordinate
-- y (number) - The y coordinate
-- far (number) - A distance in yards to trigger the OnFar callback
-- near (number) - A distance in yards to trigger the OnNear callback
-- arrive (number) - A distance in yards to trigger the OnArrive callback
-- callback (function) - A function to be called on state changes.  This function
--   will be passed the frame itself, an event string, the distance to the point
--   in yards, and any addition arguments that are necessary.
--
-- Creates a waypoint at the given coordinates and registers a callback to handle
-- the following state changes:

-- OnEdgeChanged - Called when the icon's edge state changes.  Passes a boolean
--   value onEdge that indicates if the icon is currently on the edge, or not.
-- OnTooltipShown - Called every 0.2 seconds when the tooltip is visible for the
--   given icon. Passes the tooltip, the distance to the icon in yards,
--   and a boolean flag indicating if this is the first frame showing the tooltip
--   as opposed to an update
-- OnDistanceFar
-- OnDistanceNear
-- OnDistanceArrive
function TomTom:SetWaypoint(c,z,x,y,far,near,arrive,callback)
	-- Try to acquire a waypoint from the frame pool
	local point = table.remove(pool)
	
	if not point then
		point = {}

		point.minimap = CreateFrame("Button", nil, Minimap)
		point.minimap:SetHeight(20)
		point.minimap:SetWidth(20)
		point.minimap:SetFrameLevel(4)
		point.minimap:RegisterForClicks("RightButtonUp")

		-- Create the actual texture attached for the minimap icon
		point.minimap.icon = point.minimap:CreateTexture("BACKGROUND")
		point.minimap.icon:SetTexture("Interface\\AddOns\\TomTom\\Images\\GoldGreenDot")
		point.minimap.icon:SetPoint("CENTER", 0, 0)
		point.minimap.icon:SetHeight(12)
		point.minimap.icon:SetWidth(12)

		point.minimap.arrowout = point.minimap:CreateTexture("BACKGROUND")
		point.minimap.arrowout:SetTexture("Interface\\AddOns\\TomTom\\Images\\MinimapArrow-Green")
		point.minimap.arrowout:SetPoint("CENTER", 0, 0)
		point.minimap.arrowout:SetHeight(40)
		point.minimap.arrowout:SetWidth(40)
		point.minimap.arrowout:SetVertexColor(1, 1, 1)
		point.minimap.arrowout:Hide()

		-- Create the world map point, and associated texture
		point.world = CreateFrame("Button", nil, WorldMapDetailFrame)
		point.world:SetHeight(12)
		point.world:SetWidth(12)
		point.world:RegisterForClicks("RightButtonUp")
		point.world.icon = point.world:CreateTexture()
		point.world.icon:SetAllPoints()
 		point.world.icon:SetTexture("Interface\\AddOns\\TomTom\\Images\\GoldGreenDot")

		-- Add the behavior scripts 
		point.minimap:SetScript("OnEnter", Minimap_OnEnter)
		point.minimap:SetScript("OnLeave", Minimap_OnLeave)
		point.minimap:SetScript("OnUpdate", Minimap_OnUpdate)
		point.minimap:SetScript("OnClick", Minimap_OnClick)
		point.minimap:RegisterEvent("PLAYER_ENTERING_WORLD")
		point.minimap:SetScript("OnEvent", Minimap_OnEvent)
		
		point.world:RegisterEvent("WORLD_MAP_UPDATE")
		point.world:SetScript("OnEnter", World_OnEnter)
		point.world:SetScript("OnLeave", World_OnLeave)
		point.world:SetScript("OnClick", World_OnClick)
		point.world:SetScript("OnEvent", World_OnEvent)

		-- Point from the icons/arrow into the data
		point.minimap.data = point
		point.world.data = point
	end

	-- Set the relevant data in the point object
	point.c = c
	point.z = z
	point.x = x
	point.y = y
	point.far = far
	point.near = near
	point.arrive = arrive
	point.callback = callback

	-- Use Astrolabe to place the waypoint
	local x = x/100
	local y = y/100
	Astrolabe:PlaceIconOnMinimap(point.minimap, c, z, x, y)
	Astrolabe:PlaceIconOnWorldMap(WorldMapDetailFrame, point.world, c, z, x, y)

	return point
end

function TomTom:ClearWaypoint(point)
	point.c = nil
	point.z = nil
	point.x = nil
	point.y = nil
	point.far = nil
	point.near = nil
	point.arrive = nil
	point.callback = nil
	
	Astrolabe:RemoveIconFromMinimap(point.minimap)
	point.world:Hide()
	table.insert(pool, point)
end

do
	local tooltip_icon,tooltip_callback

	function Minimap_OnEnter(self, motion)
		tooltip_icon = self
		tooltip_callback = self.data.callback

		if tooltip_callback then
			local dist,x,y = Astrolabe:GetDistanceToIcon(self)
			tooltip:SetOwner(self, "ANCHOR_CURSOR")
		
			-- Callback: OnTooltipShown
			-- arg1: The tooltip object
			-- arg2: The distance to the icon in yards
			-- arg3: Boolean value indicating the tooltip was just shown
			tooltip_callback("OnTooltipShown", tooltip, dist, true)
			tooltip:Show()
		end
	end

	function Minimap_OnLeave(self, motion)
		tooltip_icon,tooltip_callback = nil,nil
		tooltip:Hide()
	end

	local states = {
		[1] = "OnDistanceArrive",
		[2] = "OnDistanceNear",
		[3] = "OnDistanceFar",
	}

	local square_half = math.sqrt(0.5)
	local rad_135 = math.rad(135)
	local minimap_count = 0
	function Minimap_OnUpdate(self, elapsed)
		local dist,x,y = Astrolabe:GetDistanceToIcon(self)
		if not dist then
			self:Hide()
			return
		end

		minimap_count = minimap_count + elapsed
		
		-- Only take action every 0.2 seconds
		if minimap_count < 0.2 then return end

		-- Reset the counter
		minimap_count = 0

		local edge = Astrolabe:IsIconOnEdge(self)
		local data = self.data
		local callback = data.callback

		if edge then
			-- Check to see if this is a transition
			if not data.edge then
				self.icon:Hide()
				self.arrowout:Show()
				data.edge = true
				
				if callback then
					-- Callback: OnEdgeChanged
					-- arg1: The point object of the icon crossing the edge
					-- arg2: Boolean value indicating if the icon is on the edge
					callback("OnEdgeChanged", data, true)
				end
			end

			-- Rotate the icon, as required
			local angle = Astrolabe:GetDirectionToIcon(self)
			angle = angle + rad_135

			if GetCVar("rotateMinimap") == "1" then
				local cring = MiniMapCompassRing:GetFacing()
				angle = angle + cring
			end

			local sin,cos = math.sin(angle) * square_half, math.cos(angle) * square_half
			self.arrowout:SetTexCoord(0.5-sin, 0.5+cos, 0.5+cos, 0.5+sin, 0.5-cos, 0.5-sin, 0.5+sin, 0.5-cos)

		elseif data.edge then
			self.icon:Show()
			self.arrowout:Hide()
			data.edge = nil

			if callback then
				-- Callback: OnEdgeChanged
				-- arg1: The point object of the icon crossing the edge
				-- arg2: Boolean value indicating if the icon is on the edge
				callback("OnEdgeChanged", data, true)
			end
		end

		if callback then
			-- Handle the logic/callbacks for arrival
			local near,far,arrive = data.near,data.far,data.arrive
			local state = data.state
			
			if not state then
				if arrive and dist <= arrive then
					state = 1
				elseif near and dist <= near then
					state = 2
				elseif far and dist <= far then
					state = 3
				else
					state = 4
				end
				
				data.state = state
			end
			
			local newstate
			if arrive and dist <= arrive then
				newstate = 1
			elseif near and dist <= near then
				newstate = 2
			elseif far and dist <= far then
				newstate = 3
			else
				newstate = 4
			end
			
			if state ~= newstate then
				local event = states[newstate]
				if event then
					callback(event, data, dist, data.lastdist)
				end
				data.state = newstate
			end	
			
			-- Update the last distance with the current distance
			data.lastdist = dist
		end
	end

	local tooltip_count = 0
	function Tooltip_OnUpdate(self, elapsed)
		tooltip_count = tooltip_count + elapsed
		if count >= 0.2 then
			if tooltip_callback then
				local dist,x,y = Astrolabe:GetDistanceToIcon(tooltip_icon)

				-- Callback: OnTooltipShown
				-- arg1: The tooltip object
				-- arg2: The distance to the icon in yards
				-- arg3: Boolean value indicating the tooltip was just shown
				tooltip_callback("OnTooltipShown", tooltip, dist, true)
			end
		end
	end
	tooltip:SetScript("OnUpdate", Tooltip_OnUpdate)

	function World_OnEvent(self, event, ...)
		if event == "WORLD_MAP_UPDATE" then
			local data = self.data
			local x,y = Astrolabe:PlaceIconOnWorldMap(WorldMapDetailFrame, self, data.c, data.z, data.x/100, data.y/100)
			if (x and y and (0 < x and x <= 1) and (0 < y and y <= 1)) then
				self:Show()
			else
				self:Hide()
			end
		end
	end

	function Minimap_OnEvent(self, event, ...)
		if event == "PLAYER_ENTERING_WORLD" then
			local data = self.data
			Astrolabe:PlaceIconOnMinimap(self, data.c, data.z, data.x/100, data.y/100)
		end
	end
end
