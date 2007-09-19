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
	["Desolace"] = "DESO",
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

-- token -> number
-- number -> name
-- name -> token
local zones = {}
for c in pairs{GetMapContinents()} do
	zones[c] = {GetMapZones(c)}
	for idx,zone in ipairs(zones[c]) do
		local token = tokens[zone]
		assert(token, tostring(zone))

		local key = c * 100 + idx
		zones[token] = key
		zones[key] = zone
	end
	zones[c] = nil
end

-- TomTom:GetZoneToken(name or continent [, zone])
-- name (string) - The name of a map zone as returned by GetMapZones()
-- continent (number) - The continent number
-- zone (number) - The zone number
--
-- Converts a zone name or continent/zone pair to a locale-independent token
function TomTom:GetZoneToken(arg1, arg2)
	local targ1,targ2 = type(arg1), type(arg2)

	if targ1 == "number" and targ2 == "number" then
		-- c,z pair as arguments
		local key = arg1 * 100 + arg2
		local name = zones[key]
		return name and tokens[name]
	elseif targ1 == "string" and targ2 == "nil" then
		-- zone name as argument
		local token = tokens[arg1]
		return tokens[arg1]
	end
end

-- TomTom:GetZoneName(token or continent [, zone])
-- token (string) - The locale independent token for the zone
-- continent (number) - The continent number
-- zone (number) - The zone number
--
-- Converts a zone token or continent/zone pair into a zone name
function TomTom:GetZoneName(arg1, arg2)
	local targ1,targ2 = type(arg1), type(arg2)

	if targ1 == "number" and targ2 == "number" then
		-- c,z pair as arguments
		local key = arg1 * 100 + arg2
		return zones[key]
	elseif targ1 == "string" and targ2 == "nil" then
		-- token as argument
		local num = zones[arg1]
		return num and zones[num]
	end
end

-- TomTom:GetZoneNumber(token or name)
-- token (string) - The locale independent token for the zone
-- name (string) - The name of the zone
--
-- Converts a zone token or name into a continent/zone pair
function TomTom:GetZoneNumber(arg1)
	-- convert from name to token first, if possible
	local token = tokens[arg1] or arg1
	local key = token and zones[token]

	if key then
		return math.floor(key / 100), key % 100
	end
end
