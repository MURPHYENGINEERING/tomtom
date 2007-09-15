local MinimapPoint = {}

-- Import Astrolabe
local Astrolabe = DongleStub("Astrolabe-0.4")

-- Create tooltip
if not self.tooltip then
	self.tooltip = CreateFrame("GameTooltip", "TomTomTooltip", nil, "GameTooltipTemplate")
end

local OnEnter,OnLeave,OnClick,OnUpdate
local Tooltip_OnUpdate

function MinimapPoint:New(c,z,x,y,title,note)
	if not self.pool then self.pool = {} end

	-- Try to acquire an icon from the frame pool
	local point = table.remove(self.pool)
	
	if not point then
		point = CreateFrame("Button", nil, Minimap)
		point:SetHeight(12)
		point:SetWidth(12)
		point:RegisterForClicks("RightButtonUp")
		
		point.icon = point:CreateTexture()
		point.icon:SetTexture("Interface\\Minimap\\ObjectIcons")
		point.icon:SetTexCoord(0.5, 0.75, 0, 0.25)
		point.icon:SetAllPoints()

		-- Add the behavior scripts 
		point:SetScript("OnEnter", OnEnter)
		point:SetScript("OnLeave", OnLeave)
		point:SetScript("OnUpdate", OnUpdate)
		point:SetScript("OnClick", OnClick)

		point.arrow = CreateFrame("Model", nil, point)
		point.arrow:SetHeight(140.8)
		point.arrow:SetWidth(140.8)
		point.arrow:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
		point.arrow:SetModel("Interface\\Minimap\\Rotating-MinimapArrow.mdx")
		point.arrow:SetModelScale(.600000023841879)
		point.arrow:Hide()

		-- Copy all methods into the table
		for k,v in pairs(self) do
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
	
	-- Use Astrolabe to place the waypoint
	-- TODO: Place the waypoint via astrolabe

	return point
end

function MinimapPoint:Arrive()
end

function MinimapPoint:Clear()
end

do
	function OnEnter(self, motion)
		local tooltip = TomTomTooltip
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
		TomTomTooltip:Hide()
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

		if dist <= cleardist then
			self:Arrive()
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
