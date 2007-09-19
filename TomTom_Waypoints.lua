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
local Minimap_OnEnter,Minimap_OnLeave,Minimap_OnUpdate,Minimap_OnClick
local Arrow_OnUpdate
local Minimap_OnEvent
local World_OnEnter,World_OnLeave,World_OnClick

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
		point.minimap.icon:SetTexture("Interface\\Minimap\\ObjectIcons")
		point.minimap.icon:SetTexCoord(0.5, 0.75, 0, 0.25)
		point.minimap.icon:SetPoint("CENTER", 0, 0)
		point.minimap.icon:SetHeight(12)
		point.minimap.icon:SetWidth(12)

		point.minimap.arrowout = point.minimap:CreateTexture("ARTWORK")
		point.minimap.arrowout:SetTexture("Interface\\AddOns\\TomTom\\MinimapArrow-Outer")
		point.minimap.arrowout:SetPoint("CENTER", 0, 0)
		point.minimap.arrowout:SetHeight(40)
		point.minimap.arrowout:SetWidth(40)
		point.minimap.arrowout:SetVertexColor(1, 1, 1)
		point.minimap.arrowout:Hide()

		point.minimap.arrowin = point.minimap:CreateTexture("ARTWORK")
		point.minimap.arrowin:SetTexture("Interface\\AddOns\\TomTom\\MinimapArrow-Inner")
		point.minimap.arrowin:SetPoint("CENTER", 0, 0)
		point.minimap.arrowin:SetHeight(40)
		point.minimap.arrowin:SetWidth(40)
		point.minimap.arrowin:SetGradient("VERTICAL", 0.2, 1.0, 0.2, 0.5, 0.5, 0.5)
		point.minimap.arrowin:Hide()

		-- Create the world map point, and associated texture
		point.world = CreateFrame("Button", nil, WorldMapButton)
		point.world:SetHeight(12)
		point.world:SetWidth(12)
		point.world:RegisterForClicks("RightButtonUp")
		point.world.icon = point.world:CreateTexture()
		point.world.icon:SetAllPoints()
 		point.world.icon:SetTexture("Interface\\Minimap\\ObjectIcons")
		point.world.icon:SetTexCoord(0.5, 0.75, 0, 0.25)

		-- Add the behavior scripts 
		point.minimap:SetScript("OnEnter", Minimap_OnEnter)
		point.minimap:SetScript("OnLeave", Minimap_OnLeave)
		point.minimap:SetScript("OnUpdate", Minimap_OnUpdate)
		point.minimap:SetScript("OnClick", Minimap_OnClick)

		point.world:SetScript("OnEnter", World_OnEnter)
		point.world:SetScript("OnLeave", World_OnLeave)
		point.world:SetScript("OnClick", World_OnClick)

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
				self.arrowin:Show()
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
			self.arrowin:SetTexCoord(0.5-sin, 0.5+cos, 0.5+cos, 0.5+sin, 0.5-cos, 0.5-sin, 0.5+sin, 0.5-cos)
			self.arrowout:SetTexCoord(0.5-sin, 0.5+cos, 0.5+cos, 0.5+sin, 0.5-cos, 0.5-sin, 0.5+sin, 0.5-cos)

		elseif data.edge then
			self.icon:Show()
			self.arrowin:Hide()
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
			local dist,x,y = Astrolabe:GetDistanceToIcon(self)
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
				state = 4
			end
			
			if state ~= newstate then
				local event = states[newstate]
				if event then
					callback(event, data, dist, data.lastdist)
				end
				data.state = newstate
			end	
		end
			
		-- Update the last distance with the current distance
		data.lastdist = dist
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
end


function foo()
	local twopi = math.pi * 2

	-- Test for waypoints
	local c,z = TomTom:GetZoneNumber("Shattrath City")

	local OnDistanceArrive,OnDistanceNear
	local callback = function(...)
						 for i=1,select("#", ...) do
							 ChatFrame1:AddMessage(tostring(select(i, ...)))
						 end
						 local event = select(1, ...)
						 if event == "OnDistanceArrive" then
							 OnDistanceArrive()
						 elseif event == "OnDistanceNear" then
							 OnDistanceNear()
						 end
					 end

	local point = TomTom:SetWaypoint(c,z,51,44, 100, 50, 15, callback)
	local dist,x,y =  Astrolabe:GetDistanceToIcon(point.minimap)

	local playerModel
	local children = { Minimap:GetChildren() }
	for idx,child in ipairs(children) do
		if child:IsObjectType("Model") and child:GetModel() == "Interface\\Minimap\\MinimapArrow" then
			playerModel = child
			break
		end
	end

	local wayframe = CreateFrame("Frame", nil, UIParent)
	wayframe:SetHeight(56)
	wayframe:SetWidth(42)
	wayframe:SetPoint("CENTER", 0, 0)
	wayframe:EnableMouse(true)
	wayframe:SetMovable(true)

	local status = wayframe:CreateFontString("OVERLAY", nil, "GameFontNormal")
	status:SetPoint("TOP", wayframe, "BOTTOM", 0, 0)

	wayframe:SetScript("OnDragStart", function(self, button)
										  self:StartMoving()
									  end)
	wayframe:SetScript("OnDragStop", function(self, button)
										 self:StopMovingOrSizing()
									 end)
	wayframe:RegisterForDrag("LeftButton")
	local arrow = wayframe:CreateTexture("OVERLAY")
	arrow:SetTexture("Interface\\Addons\\TomTom\\Arrow")
	arrow:SetAllPoints()

	local function OnUpdate(self, elapsed)
		local dist,x,y = Astrolabe:GetDistanceToIcon(point.minimap)
		local angle = Astrolabe:GetDirectionToIcon(point.minimap)
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

	local count = 0
	local function ThereOnUpdate(self, elapsed)
		count = count + 1
		if count > 54 then count = 0 end

		local cell = count
		local column = cell % 9
		local row = floor(cell / 9)
		
		local xstart = (column * 53) / 512
		local ystart = (row * 70) / 512
		local xend = ((column + 1) * 53) / 512
		local yend = ((row + 1) * 70) / 512
		arrow:SetTexCoord(xstart,xend,ystart,yend)		
	end


	function OnDistanceArrive()
		arrow:SetHeight(53)
		arrow:SetWidth(70)
		arrow:SetTexture("Interface\\Addons\\TomTom\\Arrow-UP")
		wayframe:SetScript("OnUpdate", ThereOnUpdate)
	end

	function OnDistanceNear()
		arrow:SetHeight(56)
		arrow:SetWidth(42)
		arrow:SetTexture("Interface\\Addons\\TomTom\\Arrow")
		wayframe:SetScript("OnUpdate", OnUpdate)
	end

	wayframe:SetScript("OnUpdate", OnUpdate)
end
