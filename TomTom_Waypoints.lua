--[[--------------------------------------------------------------------------
--  TomTom - A navigational assistant for World of Warcraft
----------------------------------------------------------------------------]]

-- Import Astrolabe for locations
local Astrolabe = DongleStub("Astrolabe-0.4")

-- Create a tooltip to be used when mousing over waypoints
local tooltip = CreateFrame("GameTooltip", "TomTomTooltip", nil, "GameTooltipTemplate")
do
	-- Set the the tooltip's lines
	local i = 1
	tooltip.lines = {}
	repeat
		local line = getglobal("TomTomTooltipTextLeft"..i)
		if line then
			tooltip.lines[i] = line
		end
		i = i + 1
	until not line
end

-- Create a local table used as a frame pool
local pool = {
	minimap = {},
	worldmap = {},
}

-- Local declarations
local Minimap_OnEnter,Minimap_OnLeave,Minimap_OnUpdate,Minimap_OnClick,Minimap_OnEvent
local Arrow_OnUpdate
local World_OnEnter,World_OnLeave,World_OnClick,World_OnEvent

local WaypointClass = {}

function WaypointClass:Show(minimap, worldmap)
	local x = self.x / 100
	local y = self.y / 100

	if minimap then
		Astrolabe:PlaceIconOnMinimap(self.minimap, self.c, self.z, x, y) 
	end

	if worldmap then
		local x, y = Astrolabe:PlaceIconOnWorldMap(WorldMapDetailFrame, self.worldmap, self.c, self.z, x, y)
		self.worldmap:Show()
	end
end

function WaypointClass:Hide(minimap, worldmap)
	if minimap then
		Astrolabe:RemoveIconFromMinimap(self.minimap)
	end

	if worldmap then
		Astrolabe:Hide()
	end
end

function WaypointClass:GetDistanceToWaypoint()
	return Astrolabe:GetDistanceToIcon(self.minimap)
end

function WaypointClass:GetDirectionToWaypoint()
	return Astrolabe:GetDirectionToIcon(self.minimap)
end


function TomTom:SetWaypoint(c, z, x, y, distances)
	-- Try to acquire a waypoint from the frame pool
	local minimap = table.remove(pool.minimap)
	local worldmap = table.remove(pool.worldmap)

	if not minimap then
		minimap = CreateFrame("Button", nil, Minimap)
		minimap:SetHeight(20)
		minimap:SetWidth(20)
		minimap:RegisterForClicks("RightButtonUp")

		minimap.icon = minimap:CreateTexture("BACKGROUND")
		minimap.icon:SetTexture("Interface\\AddOns\\TomTom\\Images\\GoldGreenDot")
		minimap.icon:SetPoint("CENTER", 0, 0)
		minimap.icon:SetHeight(12)
		minimap.icon:SetWidth(12)

		minimap.arrow = minimap:CreateTexture("BACKGROUND")
		minimap.arrow:SetTexture("Interface\\AddOns\\TomTom\\Images\\MinimapArrow-Green")
		minimap.arrow:SetPoint("CENTER", 0 ,0)
		minimap.arrow:SetHeight(40)
		minimap.arrow:SetWidth(40)
		minimap.arrow:Hide()

		-- Add the behavior scripts 
		minimap:SetScript("OnEnter", Minimap_OnEnter)
		minimap:SetScript("OnLeave", Minimap_OnLeave)
		minimap:SetScript("OnUpdate", Minimap_OnUpdate)
		minimap:SetScript("OnClick", Minimap_OnClick)
		minimap:RegisterEvent("PLAYER_ENTERING_WORLD")
		minimap:SetScript("OnEvent", Minimap_OnEvent)
	end

	if not worldmap then
		worldmap = CreateFrame("Button", nil, WorldMapDetailFrame)
		worldmap:SetHeight(12)
		worldmap:SetWidth(12)
		worldmap:RegisterForClicks("RightButtonUp")
		worldmap.icon = worldmap:CreateTexture("ARTWORK")
		worldmap.icon:SetAllPoints()
		worldmap.icon:SetTexture("Interface\\AddOns\\TomTom\\Images\\GoldGreenDot")

		worldmap:RegisterEvent("WORLD_MAP_UPDATE")
		worldmap:SetScript("OnEnter", World_OnEnter)
		worldmap:SetScript("OnLeave", World_OnLeave)
		worldmap:SetScript("OnClick", World_OnClick)
		worldmap:SetScript("OnEvent", World_OnEvent)
	end

	-- Create a new waypoint object which wraps 	
	local point = setmetatable({}, {__index=WaypointClass})
	point.c = c
	point.z = z
	point.x = x
	point.y = y
	point.distances = distances
	point.minimap = minimap
	point.worldmap = worldmap

	-- Link the actual frames back to the waypoint object
	minimap.point = point
	worldmap.point = point

	-- Place the waypoints
	point:Show(true, true)

	return point
end

function TomTom:ClearWaypoint(point)
	if point then
		point:Hide(true, true)
		table.insert(pool.minimap, point.minimap)
		table.insert(pool.worldmap, point.worldmap)
		point.minimap = nil
		point.worldmap = nil
	end
end

do
	local tooltip_icon,tooltip_callback

	function Minimap_OnEnter(self, motion)
		local data = self

		tooltip_icon = self
		tooltip_callback = data.callback

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
		local data = self.point
		local callback = data.callback

		if edge then
			-- Check to see if this is a transition
			if not data.edge then
				self.icon:Hide()
				self.arrow:Show()
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
			self.arrow:SetTexCoord(0.5-sin, 0.5+cos, 0.5+cos, 0.5+sin, 0.5-cos, 0.5-sin, 0.5+sin, 0.5-cos)

		elseif data.edge then
			self.icon:Show()
			self.arrow:Hide()
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
		if tooltip_count >= 0.2 then
			if tooltip_callback then
				local dist,x,y = Astrolabe:GetDistanceToIcon(tooltip_icon)

				-- Callback: OnTooltipShown
				-- arg1: The tooltip object
				-- arg2: The distance to the icon in yards
				-- arg3: Boolean value indicating the tooltip was just shown
				tooltip_callback("OnTooltipShown", tooltip, dist, false)
				tooltip_count = 0
			end
		end
	end
	tooltip:SetScript("OnUpdate", Tooltip_OnUpdate)

	function World_OnEvent(self, event, ...)
		if event == "WORLD_MAP_UPDATE" then
			local data = self.point
			-- It seems that data.x and data.y are occasionally not valid
			-- perhaps when the waypoint is removed.  Guard this for now
			-- TODO: Fix permanently
			if not data.x or not data.y then
				self:Hide()
				return
			end

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
