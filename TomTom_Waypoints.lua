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
local pool = {}

-- Create a mapping from uniqueID to waypoint
local getuid,resolveuid
do
	local uidmap = {}
	local uid = 0
	function getuid(obj)
		-- Ensure the object doesn't already have a uid mapping
		for k,v in pairs(uidmap) do
			if obj == v then
				error("Attempt to re-use an object without clearing identifier")
			end
		end

		-- Establish the new mapping
		uid = uid + 1

		uidmap[uid] = obj

		return uid
	end

	function resolveuid(uid, remove)
		-- Return the object that corresponds to the UID
		local obj = uidmap[uid]
		assert(obj, "Attempt to use out-of-date identifier")
		if remove then
			uidmap[uid] = nil
		end

		return obj
	end
end

-- Local declarations
local Minimap_OnEnter,Minimap_OnLeave,Minimap_OnUpdate,Minimap_OnClick,Minimap_OnEvent
local Arrow_OnUpdate
local World_OnEnter,World_OnLeave,World_OnClick,World_OnEvent

function TomTom:SetWaypoint(c, z, x, y, callbacks)
	-- Try to acquire a waypoint from the frame pool
	local point = table.remove(pool)

	if not point then
		point = {}

		local minimap = CreateFrame("Button", nil, Minimap)
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

		local worldmap = CreateFrame("Button", nil, WorldMapDetailFrame)
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

		point.worldmap = worldmap
		point.minimap = minimap
	end

	point.c = c
	point.z = z
	point.x = x
	point.y = y
	point.callbacks = callbacks

	-- Link the actual frames back to the waypoint object
	point.minimap.point = point
	point.worldmap.point = point

	-- Place the waypoint
	local x,y = x/100,y/100
	Astrolabe:PlaceIconOnMinimap(point.minimap, c, z, x, y)
	Astrolabe:PlaceIconOnWorldMap(WorldMapDetailFrame, point.worldmap, c, z, x, y)

	point.uid = getuid(point)
	return point.uid
end

function TomTom:RemoveWaypoint(uid)
	local point = resolveuid(uid, true)
	Astrolabe:RemoveIconFromMinimap(point.minimap)
	point.minimap:Hide()
	point.worldmap:Hide()
	table.insert(pool, point)
end

function TomTom:GetDistanceToWaypoint(uid)
	local point = resolveuid(uid)
	return Astrolabe:GetDistanceToIcon(point.minimap)
end

function TomTom:GetDirectionToWaypoint(uid)
	local point = resolveuid(uid)
	return Astrolabe:GetDirectionToIcon(point.minimap)
end

do
	local tooltip_uid,tooltip_callbacks

	local function tooltip_onupdate(self, elapsed)
		if tooltip_callbacks and tooltip_callbacks.tooltip_update then
			local dist,x,y = TomTom:GetDistanceToWaypoint(tooltip_uid)
			tooltip_callbacks.tooltip_update("tooltip_update", tooltip, tooltip_uid, dist)
		end
	end

	function Minimap_OnEnter(self, motion)
		local data = self.point.callbacks

		if data and data.tooltip_show then
			local uid = self.point.uid
			local dist,x,y = TomTom:GetDistanceToWaypoint(uid)

			tooltip_uid = uid
			tooltip_callbacks = data

			tooltip:SetOwner(self, "ANCHOR_CURSOR")

			data.tooltip_show("tooltip_show", tooltip, uid, dist)
			tooltip:Show()

			-- Set the update script if there is one
			if data.tooltip_update then
				tooltip:SetScript("OnUpdate", tooltip_onupdate)
			else
				tooltip:SetScript("OnUpdate", nil)
			end
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
