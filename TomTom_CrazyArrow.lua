--[[--------------------------------------------------------------------------
--  TomTom - A navigational assistant for World of Warcraft
-- 
--  CrazyTaxi: A crazy-taxi style arrow used for waypoint navigation.
--    concept taken from MapNotes2 (Thanks to Mery for the idea, along
--    with the artwork.)
----------------------------------------------------------------------------]]

local DongleUtils = {}

do
	function DongleUtils.RGBToHex(r, g, b)
		return string.format("%02x%02x%02x", r, g, b)
	end


	function DongleUtils.RGBPercToHex(r, g, b)
		return string.format("%02x%02x%02x", r*255, g*255, b*255)
	end


	function DongleUtils.HexToRGB(hex)
		local rhex, ghex, bhex = string.sub(hex, 1, 2), string.sub(hex, 3, 4), string.sub(hex, 5, 6)
		return tonumber(rhex, 16), tonumber(ghex, 16), tonumber(bhex, 16)
	end


	function DongleUtils.HexToRGBPerc(hex)
		local rhex, ghex, bhex = string.sub(hex, 1, 2), string.sub(hex, 3, 4), string.sub(hex, 5, 6)
		return tonumber(rhex, 16)/255, tonumber(ghex, 16)/255, tonumber(bhex, 16)/255
	end


	function DongleUtils.ColorGradient(perc, ...)
		local num = select("#", ...)
		local hexes = type(select(1, ...)) == "string"

		if perc == 1 then
			if hexes then return select(num, ...)
			else return select(num-2, ...), select(num-1, ...), select(num, ...) end
		end

		if not hexes then num = num / 3 end

		local segment, relperc = math.modf(perc*(num-1))
		local r1, g1, b1, r2, g2, b2
		if hexes then
			r1, g1, b1 = DongleUtils.HexToRGBPerc(select(segment+1, ...))
			r2, g2, b2 = DongleUtils.HexToRGBPerc(select(segment+2, ...))
		else
			r1, g1, b1 = select((segment*3)+1, ...), select((segment*3)+2, ...), select((segment*3)+3, ...)
			r2, g2, b2 = select((segment*3)+4, ...), select((segment*3)+5, ...), select((segment*3)+6, ...)
		end

		if hexes then
			return DongleUtils.RGBToHex(r1 + (r2-r1)*relperc,
										g1 + (g2-g1)*relperc,
										b1 + (b2-b1)*relperc)
		else
			return r1 + (r2-r1)*relperc,
			g1 + (g2-g1)*relperc,
			b1 + (b2-b1)*relperc
		end
	end


	function DongleUtils.GetHPSeverity(perc, class)
		if not class then return DongleUtils.ColorGradient(perc, 1,0,0, 1,1,0, 0,1,0)
		else
			local c = RAID_CLASS_COLORS[class]
			return DongleUtils.ColorGradient(perc, 1,0,0, 1,1,0, c.r,c.g,c.b)
		end
	end

end

local Astrolabe = DongleStub("Astrolabe-0.4")
local sformat = string.format
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
wayframe.tta	= wayframe:CreateFontString("OVERLAY", nil, "GameFontNormalSmall")
wayframe.status:SetPoint("TOP", wayframe, "BOTTOM", 0, 0)
wayframe.tta:SetPoint("TOP", wayframe.status, "BOTTOM", 0, 0)


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
local tta = wayframe.tta
local arrow = wayframe.arrow
local count = 0
local time = 0
local distance = 0
local delta = 0
local function OnUpdate(self, elapsed)
	local dist,x,y = Astrolabe:GetDistanceToIcon(active_point)
	if not dist then
		self:Hide()
		return
	end

	status:SetText(sformat("%d yards", dist))
	
	local cell

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

		cell = count
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
		
		local perc = math.abs((math.pi - math.abs(angle)) / math.pi)

		local r,g,b = DongleUtils.ColorGradient(perc, 1,0,0, 1,1,0, 0,1,0)		
		arrow:SetVertexColor(r,g,b)
		
		cell = floor(angle / twopi * 108 + 0.5) % 108
		local column = cell % 9
		local row = floor(cell / 9)
		
		local xstart = (column * 56) / 512
		local ystart = (row * 42) / 512
		local xend = ((column + 1) * 56) / 512
		local yend = ((row + 1) * 42) / 512
		arrow:SetTexCoord(xstart,xend,ystart,yend)
		end
		
		-- Give time til arrival only if facing towards destination
		time = time + elapsed
		
		if time >= 1 then
			if cell <= 27 or cell >= 81 or showDownArrow then

				delta = distance - dist 
				
				if delta > 0 then
					local eta = dist/(delta/time)
					tta:SetText(sformat("%01d:%02d", eta / 60, eta % 60))
				else
					tta:SetText("***")
				end 
				time = 0
				distance = dist
			else
				tta:SetText("***")
				distance = dist
				time = 0
			end
		end
end

wayframe:SetScript("OnUpdate", OnUpdate)
