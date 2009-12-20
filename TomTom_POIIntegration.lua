local function POIAnchorToCoord(poiframe)
    local point, relto, relpoint, x, y = poiframe:GetPoint()
    local frame = WorldMapDetailFrame
    local width = frame:GetWidth()
    local height = frame:GetHeight()
    local scale = frame:GetScale() / poiframe:GetScale()
    local cx = (x / scale) / width
    local cy = (-y / scale) / height

    if cx < 0 or cx > 1 or cy < 0 or cy > 1 then
        return nil, nil
    end

    return cx * 100, cy * 100
end

local modTbl = {
    C = IsControlKeyDown,
    A = IsAltKeyDown,
    S = IsShiftKeyDown,
}

local hookEnabled = true;
local modifier;

-- desc, persistent, minimap, world, custom_callbacks, silent, crazy)
local function poi_OnClick(self, button)
    -- Are we enabled?
    if not hookEnabled then
        return
    end

    -- Is this the right button/modifier?
    if button == "RightButton" then
        for i = 1, #modifier do
            local mod = modifier:sub(i, i)
            local func = modTbl[mod]
            if not func() then
                return
            end
        end
    else
        return
    end

    if self.parentName == "WatchFrameLines" then
        local questFrame = _G["WorldMapQuestFrame"..self.questLogIndex];
        local selected = WorldMapQuestScrollChildFrame.selected
        local poiIcon = selected.poiIcon;
        self = poiIcon
    end
    
    local c, z = GetCurrentMapContinent(), GetCurrentMapZone();
    local x, y = POIAnchorToCoord(self)

    local qid = self.questId

    local title;
    if self.quest.questLogIndex then
        title = GetQuestLogTitle(self.quest.questLogIndex)
    else
        title = "Quest #" .. qid .. " POI"
    end

    local uid = TomTom:AddZWaypoint(c, z, x, y, title)
end

local hooked = {}
hooksecurefunc("QuestPOI_DisplayButton", function(parentName, buttonType, buttonIndex, questId)
      local buttonName = "poi"..tostring(parentName)..tostring(buttonType).."_"..tostring(buttonIndex);
      local poiButton = _G[buttonName];
      
      if not hooked[buttonName] then
         poiButton:HookScript("OnClick", poi_OnClick)
         poiButton:RegisterForClicks("AnyUp")
         hooked[buttonName] = true
      end
end)

function TomTom:EnableDisablePOIIntegration()
    hookEnabled = TomTom.profile.poi.enable
    modifier = TomTom.profile.poi.modifier
end
