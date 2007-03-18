local L = {
	TOOLTIP_TITLE = "TomTom";
	TOOLTIP_SUBTITLE = "Zone Coordinates";
	TOOLTIP_LOCKED = "This window is locked in place.";
	TOOLTIP_LEFTCLICK = "Left-click and drag to move this window.";
	TOOLTIP_RIGHTCLICK = "Right-click to toggle the options panel.";
}

TomTom = DongleStub("Dongle-Beta0"):New("TomTom")
local DongleFrames = DongleStub("DongleFrames-1.0")
local Astrolabe = DongleStub("Astrolabe-0.3")
local profile

function TomTom:Enable()
	self.defaults = {
		profile = {
			show = true,
			lock = false,
			worldmap = true,
			cursor = true,
			alpha = 1,
			notes = {
			},
		}
	}
	
	self.db = self:InitializeDB("TomTomDB", self.defaults)
	profile = self.db.profile
	
	self:CreateSlashCommands()
end

local OnMouseDown = function(self,button)
	if button == "LeftButton" and not profile.lock then
		self:StartMoving()
		self.isMoving = true
	end
end

local OnMouseUp = function(self,button)
	if self.isMoving then
		self:StopMovingOrSizing()
		self.isMoving = false
	end
end

local OnEnter = function(self)
	if profile.tooltip then
		GameTooltip:SetDefaultAnchor(GameTooltip, self)
		GameTooltip:SetText(L["TOOLTIP_TITLE"])
		GameTooltip:AddLine(L["TOOLTIP_SUBTITLE"])
		if profile.lock then
			GameTooltip:AddLine(L["TOOLTIP_LOCKED"])
		else
			GameTooltip:AddLine(L["TOOLTIP_LEFTCLICK"])
		end
		GameTooltipTextLeft1:SetTextColor(1,1,1);
		GameTooltipTextLeft2:SetTextColor(1,1,1);
		GameTooltip:Show()
	end
end

local OnLeave = function(self)
	GameTooltip:Hide();
end

local OnUpdate = function(self, elapsed)
	local c,z,x,y = Astrolabe:GetCurrentPlayerPosition()
	
	if not x or not y then
		text = "---"
	else
		text = string.format("%.2f, %.2f", x*100, y*100)
	end
	
	self.Text:SetText(text)
end  

local MinimapSize = {
	indoor = {
		[0] = 300, -- scale
		[1] = 240, -- 1.25
		[2] = 180, -- 5/3
		[3] = 120, -- 2.5
		[4] = 80,  -- 3.75
		[5] = 50,  -- 6
	},
	outdoor = {
		[0] = 466 + 2/3, -- scale
		[1] = 400,       -- 7/6
		[2] = 333 + 1/3, -- 1.4
		[3] = 266 + 2/6, -- 1.75
		[4] = 200,       -- 7/3
		[5] = 133 + 1/3, -- 3.5
	},
}

local halfpi = math.pi / 2

local function updateAngle(icon)
	local angle = Astrolabe:GetDirectionToIcon(icon)

	local x = .03875* math.cos(angle + halfpi) + 0.04875 
	local y = .03875* math.sin(angle + halfpi) + 0.04875 
	icon.arrow:SetPosition(x,y,0)
	icon.arrow:SetFacing(angle)	
end

local function iconOnUpdate(icon, elapsed)
	if not icon.arrow then return end

	local edge = Astrolabe:IsIconOnEdge(icon)

	if edge then
		icon.arrow:Show()
		icon.icon:Hide()
	elseif icon.arrow:IsVisible() then
		icon.arrow:Hide()
		icon.icon:Show()
	end
end

function TomTom:GetMinimapIcon(desc)
	self.mmicons = self.mmicons or {}

	local icon = table.remove(self.mmicons)
	if not icon then
		icon = CreateFrame("Button", nil, Minimap)
		icon:SetHeight(12)
		icon:SetWidth(12)

		local texture = icon:CreateTexture()
		texture:SetTexture("Interface\\Minimap\\ObjectIcons")
		texture:SetTexCoord(0.5, 0.75, 0, 0.25)
		texture:SetAllPoints()
		icon.icon = texture
		icon:SetScript("OnUpdate", iconOnUpdate)

		local frame = CreateFrame("Model", nil, Minimap)
		frame:SetHeight(140.8)
		frame:SetWidth(140.8)
		frame:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
		frame:SetModel("Interface\\Minimap\\Rotating-MinimapArrow.mdx")
		frame:SetFogColor(0.9999977946281433,0.9999977946281433,0.9999977946281433,0.9999977946281433)
		frame:SetFogFar(1)
		frame:SetFogNear(0)
		frame:SetLight(0,1,0,0,0,1,1,1,1,1,1,1,1)
		frame:SetModelScale(.600000023841879)
		icon.arrow = frame
		local total = 0
		frame:SetScript("OnEnter", function() TomTom:Print("enter") end)
		frame:SetScript("OnUpdate", function(self, elapsed)
			-- Update arrow direction here
			updateAngle(icon)
		end)
    
		table.insert(self.points, icon)
		return icon
	else
		return icon
	end
end

function TomTom:GetWorldMapIcon()
	self.wmicons = self.wmicons or {}

	local icon = table.remove(self.wmicons)
	if not icon then
		icon = CreateFrame("Button", nil, WorldMapFrame)
		icon:SetHeight(12)
		icon:SetWidth(12)
		local texture = icon:CreateTexture()
		texture:SetTexture("Interface\\Minimap\\ObjectIcons")
		texture:SetTexCoord(0.5, 0.75, 0, 0.25)
		texture:SetAllPoints()
		icon.icon = texture
		icon:SetScript("OnUpdate", iconOnUpdate)

		--table.insert(self.points, icon)
		return icon
	else
		return icon
	end
end

function TomTom:CreateSlashCommands()
	-- Options slash commands
	self.cmd = self:InitializeSlashCommand("TomTom Slash Command", "TOMTOM", "tomtom")
	
	local ToggleDisplay = function(origin)
		if origin == "coord" and TomTomFrame then
			profile.show = not profile.show
			TomTomFrame[profile.show and "Show" or "Hide"](TomTomFrame)
			self:PrintF("The coordinate display has been %s.", profile.show and "shown" or "hidden")
		elseif origin == "mapcoord" and TomTomWorldFrame then
			profile.worldmap = not profile.worldmap
			TomTomWorldFrame[profile.worldmap and "Show" or "Hide"](TomTomWorldFrame)
			self:PrintF("The world map coordinate display has been %s.", profile.worldmap and "shown" or "hidden")
		end
	end
	
	local LockDisplay = function()
		profile.lock = not profile.lock
		self:PrintF("The coordinate display has been %s.", profile.lock and "locked" or "unlocked")
	end
	
	self.cmd:RegisterSlashHandler("Show/Hide the coordinate display", "^(coord)$", ToggleDisplay)
	self.cmd:RegisterSlashHandler("Show/Hide the world map coordinate display", "^(mapcoord)$", ToggleDisplay)
	self.cmd:RegisterSlashHandler("Lock/Unlock the coordinate display", "^lock$", LockDisplay)

	-- Waypoint placement slash commands
	self.cmd_way = self:InitializeSlashCommand("TomTom - Waypoints", "TOMTOM_WAY", "way")
	
	local total = 0
	local Way_Update = function(frame,elapsed)
		if total >= 0.2 then
			total = total + elapsed
			return
		else
			total = 0
			local c,z,x,y = Astrolabe:GetCurrentPlayerPosition()
			local zone = self.points and self.points[c] and self.points[c][z]
			if not zone then return end

			for idx,entry in ipairs(zone) do
				-- Bail out if we're too high
				local range = .001
				local xeq = x <= entry.x + range and x >= entry.x - range
				local yeq = y <= entry.y + range and y >= entry.y - range
				if xeq and yeq then
					self:PrintF("You have reached your destination at %.2f, %.2f.", x * 100 , y * 100)
					Astrolabe:RemoveIconFromMinimap(entry.icon)
					table.insert(self.mmicons, icon)
					table.remove(zone, idx)
					frame:SetScript("OnUpdate", nil)
				end
			end
		end
	end
	
	local sortFunc = function(a,b) 
		if a.x == b.x then return a.y < b.y else return a.x < b.x end
	end
	
	local Way_Set = function(x,y,desc)
		if not self.points then self.points = {} end

		x = x / 100
		y = y / 100
						
		local icon = self:GetMinimapIcon(desc)
		local c,z = Astrolabe:GetCurrentPlayerPosition()		
		Astrolabe:PlaceIconOnMinimap(icon, c, z, x, y)
		local icon = self:GetWorldMapIcon(desc)
		Astrolabe:PlaceIconOnWorldMap(WorldMapFrame, icon, c, z, x, y)

		self:PrintF("Setting a waypoint at %.2f, %.2f.", x * 100, y * 100)

		self.points[c] = self.points[c] or {}
		self.points[c][z] = self.points[c][z] or {}
		
		table.insert(self.points[c][z], {["x"] = x, ["y"] = y, ["icon"] = icon})
		table.sort(self.points[c][z], sortFunc)
		self.frame:SetScript("OnUpdate", Way_Update)
	end
	
	local Way_Reset = function()
		if #self.points == 0 then
			self:Print("There are no waypoints to remove.")
			return
		end
		
		for idx,icon in ipairs(self.points) do
			Astrolabe:RemoveIconFromMinimap(icon)
			icon:Hide()
		end
		self:Print("All waypoints have been removed.")
	end
		
	self.cmd_way:RegisterSlashHandler("Remove all current waypoints", "^reset$", Way_Reset)
	self.cmd_way:RegisterSlashHandler("Add a new waypoint with optional note", "^(%d*%.?%d*)[%s]+(%d*%.?%d*)[%s]*(.*)", Way_Set)
end

function TomTom:CreateFrames()
	DongleFrames:Create("n=TomTomFrame#p=UIParent#size=100,32#toplevel#strata=HIGH#mouse#movable#clamp", "CENTER", 0, 0)
	TomTomFrame.Text = DongleFrames:Create("p=TomTomFrame#t=FontString#inh=GameFontNormal", "CENTER", 0, 0)
	TomTomFrame:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 16,
		insets = {left = 4, right = 4, top = 4, bottom = 4},
	})
	TomTomFrame:SetBackdropColor(0,0,0,0.4)
	TomTomFrame:SetBackdropBorderColor(1,0.8,0,0.8)
	TomTomFrame:SetScript("OnMouseDown", OnMouseDown)
	TomTomFrame:SetScript("OnMouseUp", OnMouseUp)
	TomTomFrame:SetScript("OnHide", OnMouseUp)
	TomTomFrame:SetScript("OnEnter", OnEnter)
	TomTomFrame:SetScript("OnLeave", OnLeave)
	TomTomFrame:SetScript("OnUpdate", OnUpdate)
		
	DongleFrames:Create("n=TomTomWorldFrame#p=WorldMapFrame")
	TomTomWorldFrame.Text = DongleFrames:Create("p=TomTomWorldFrame#t=FontString#inh=GameFontHighlightSmall", "BOTTOM", WorldMapPositioningGuide, "BOTTOM", 0, 11)		
	TomTomWorldFrame:SetScript("OnUpdate", OnUpdate)
	
	self.frame = CreateFrame("Frame")
end

TomTom:CreateFrames()
