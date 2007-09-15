--[[--------------------------------------------------------------------------
  TomTom by Cladhaire <cladhaire@gmail.com>
----------------------------------------------------------------------------]]

local tokens = {
	-- Kalimdor
	["Ashenvale"] = "ASHE",
	["Azshara"] = "AZSH",
	["Azuremyst Isle"] = "AZUR",
	["Bloodmyst Isle"] = "BLOO",
	["Darkshore"] = "DARK",
	["Darnassus"] = "DARN",
	["Durotar"] = "DURO",
	["Dustwallow Marsh"] = "DUST",
	["Felwood"] = "FELW",
	["Feralas"] = "FERA",
	["Moonglade"] = "MOON",
	["Mulgore"] = "MULG",
	["Orgrimmar"] = "ORGR",
	["Silithus"] = "SILI",
	["Stonetalon Mountains"] = "STON",
	["Tanaris"] = "TANA",
	["Teldrassil"] = "TELD",
	["The Barrens"] = "BARR",
	["The Exodar"] = "EXOD",
	["Thousand Needles"] = "1KNE",
	["Thunder Bluff"] = "THUN",
	["Un'Goro Crater"] = "UNGO",
	["Winterspring"] = "WINT",
	-- Eastern Kingdoms
	["Alterac Mountains"] = "ALTE",
	["Arathi Highlands"] = "ARAT",
	["Badlands"] = "BADL",
	["Blasted Lands"] = "BLAS",
	["Burning Steppes"] = "BURN",
	["Deadwind Pass"] = "DWPA",
	["Dun Morogh"] = "DUNM",
	["Duskwood"] = "DUSK",
	["Eastern Plaguelands"] = "EPLA",
	["Elwynn Forest"] = "ELWY",
	["Eversong Woods"] = "EVSO",
	["Ghostlands"] = "GHOL",
	["Hillsbrad Foothills"] = "HILLF",
	["Ironforge"] = "IFGE",
	["Loch Modan"] = "LCHM",
	["Redridge Mountains"] = "REMT",
	["Searing Gorge"] = "SGOR",
	["Silvermoon City"] = "SILC",
	["Silverpine Forest"] = "SILF",
	["Stormwind City"] = "STOC",
	["Stranglethorn Vale"] = "STVA",
	["Swamp of Sorrows"] = "SWOS",
	["The Hinterlands"] = "HINT",
	["Tirisfal Glades"] = "TGLAD",
	["Undercity"] = "UCIT",
	["Western Plaguelands"] = "WPLA",
	["Westfall"] = "WFAL",
	["Wetlands"] = "WETL",
	-- Outlands
	["Blade's Edge Mountains"] = "BLEM",
	["Hellfire Peninsula"] = "HFPE",
	["Nagrand"] = "NAGR",
	["Netherstorm"] = "NETH",
	["Shadowmoon Valley"] = "SHVA",
	["Shattrath City"] = "SHAT",
	["Terokkar Forest"] = "TERF",
	["Zangarmarsh"] = "ZANG",
}

-- Generate a lookup table from token to continent zone
local zones = {}
for c in pairs{GetMapContinents()} do
	zones[c] = {GetMapZones(c)}
	for idx,zone in ipairs(zones[c]) do
		local token = tokens[zone]
		zones[token] = format("%d,%d", c, zone)
	end
	zones[c] = nil
end

-- TomTom:GetZoneToken(name)
-- name (string) - The name of a zone as returned from GetMapZones()
-- 
-- Converts a zone name into a locale-independent token.  Inspiration from 
-- Gatherer_ZoneTokens.
function TomTom:GetZoneToken(name)
	local token = tokens[name]
	if not token then
		error(format("Could not find token for zone name '%s'.", name))
	end

	return tokens[name]
end

-- c,z = TomTom:GetZoneNumbers(name)
-- name (string) - The name of an in-game zone
--
-- Converts a zone name into a continent,zone pair usable by Astrolabe
function TomTom:GetZoneNumber(name)
	local token = self:GetZoneToken(name)
	return strsplit(",", zones[token])
end
