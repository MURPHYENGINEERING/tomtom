local options = {}
local db = {}

local L = setmetatable({}, {__index = function(t,k) return k end})

options.type = "group"
options.name = "TomTom"

function options.get(info)
	local ns,opt = string.split(".", info.arg)
	local val = TomTom.db.profile[ns][opt]
	if type(val) == "table" then
		return unpack(val)
	else
		return val
	end
end

function options.set(info, arg1, arg2, arg3, arg4)
	local ns,opt = string.split(".", info.arg)
	--TomTom:Print(ns, opt, arg1, arg2, arg3, arg4)
	if arg2 then
		local entry = TomTom.db.profile[ns][opt]
		entry[1] = arg1
		entry[2] = arg2
		entry[3] = arg3
		entry[4] = arg4
	else
		TomTom.db.profile[ns][opt] = arg1
	end

	if ns == "block" then
		TomTom:ShowHideBlockCoords()
	elseif ns == "mapcoords" then
		TomTom:ShowHideWorldCoords()
	end
end

options.args = {}

options.args.coordblock = {
   type = "group",
   name = L["Coordinate Block"],
   desc = L["Options that alter the coordinate block"],
   args = {
      desc = {
         order = 1,
         type = "description",
         name = L["TomTom provides you with a floating coordinate display that can be used to determine your current position.  These options can be used to enable or disable this display, or customize the block's display."],
      },      
      enable = {
         order = 2,
         type = "toggle",
         name = L["Enable coordinate block"],
         desc = L["Enables a floating block that displays your current position in the current zone"],
         arg = "block.enable",
      },
      accuracy = {
         order = 3,
         type = "range",
         name = "Accuracy",
         desc = L["Coordinates can be displayed as simple XX, YY coordinate, or as more precise XX.XX, YY.YY.  This setting allows you to control that precision"],
         min = 0, max = 2, step = 1,
         arg = "block.accuracy",
      },
	  lock = {
		  order = 4,
		  type = "toggle",
		  name = L["Lock coordinate block"],
		  arg = "block.lock",
	  },
      display = {
         order = 4,
         type = "group",
         name = L["Display Settings"],
		 args = {
			 bordercolor = {
				 type = "color",
				 name = L["Border color"],
				 arg = "block.bordercolor",
			 },
			 bgcolor = {
				 type = "color",
				 name = L["Background color"],
				 arg = "block.bgcolor",
			 },
			 height = {
				 type = "range",
				 name = L["Block height"],
				 arg = "block.height",
				 min = 5, max = 50, step = 1,
			 },
			 width = {
				 type = "range",
				 name = L["Block width"],
				 arg = "block.width",
				 min = 50, max = 250, step = 5,
			 },
			 fontsize = {
				 type = "range",
				 name = L["Font size"],
				 arg = "block.fontsize",
				 min = 1, max = 24, step = 1,
			 },
		 },
	 },
   },
} -- End coordinate block settings

options.args.mapcoord = {
   type = "group",
   name = L["Map Coordinates"],
   desc = L["Options that customize the map coordinate display"],
   args = {
      help = {
         order = 1,
         type = "description",
         name = L["TomTom is capable of displaying the player's coordinates on the world map, as well as the current coordinate position of the cursor.  These options can be used to enable or disable these displays"],
      },
      player = {
         type = "group",
         name = L["Player Coordinates"],
         args = {
            enableplayer = {
               order = 1,
               type = "toggle",
               name = L["Enable player coordinates"],
			   arg = "mapcoords.playerenable",
            },
            playeraccuracy = {
               order = 4,
               type = "range",
               name = L["Player coordinate accuracy"],
               desc = L["Coordinates can be displayed as simple XX, YY coordinate, or as more precise XX.XX, YY.YY.  This setting allows you to control that precision"],
               min = 0, max = 2, step = 1,
			   arg = "mapcoords.playeraccuracy",
            },
         },
      },
      cursor = {
         type = "group",
         name = L["Cursor Coordinates"],
         args = {
            enablecursor = {
               order = 3,
               type = "toggle",
               name = L["Enable cursor coordinates"],
			   arg = "mapcoords.cursorenable",
            },
            
            cursoraccuracy = {
               order = 5,
               type = "range",
               name = L["Cursor coordinate accuracy"],
               desc = L["Coordinates can be displayed as simple XX, YY coordinate, or as more precise XX.XX, YY.YY.  This setting allows you to control that precision"],
               min = 0, max = 2, step = 1,
			   arg = "mapcoords.cursoraccuracy",
            },
         },
      },
   },
} -- end map coord options

options.args.crazytaxi = {
   type = "group",
   name = L["Waypoint Arrow"],
   args = {
      help = {
         order = 1,
         type = "description",
         name = L["TomTom provides an arrow that can be placed anywhere on the screen.  Similar to the arrow in \"Crazy Taxi\" it will point you towards your next waypoint"],
      },   
      enable = {
         order = 2,
         type = "toggle",
         name = L["Enable floating waypoint arrow"],
         width = "double",
		 arg = "arrow.enable",
      },
      color = {
         type = "group",
         name = L["Arrow colors"],
         args = {
            help = {
               order = 1,
               type = "description",
               name = L["The floating waypoint arrow can change color depending on whether or nor you are facing your destination.  By default it will display green when you are facing it directly, and red when you are facing away from it.  These colors can be changed in this section.  Setting these options to the same color will cause the arrow to not change color at all"],
            },
            colorstart = {
               type = "color",
               name = L["Good color"],
			   arg = "arrow.goodcolor",
            },
            colorend = {
               type = "color",
               name = L["Bad color"],
			   arg = "arrow.badcolor",
            },
         },
      },
   },   
} -- End crazy taxi options

options.args.minimap = {
   type = "group",
   name = L["Minimap"],
   args = {
      help = {
         order = 1,
         type = "description",
         name = L["TomTom can display multiple waypoint arrows on the minimap.  These options control the display of these waypoints"],
      },
      enable = {
         order = 2,
         type = "toggle",
         name = L["Enable minimap waypoints"],
         width = "double",
		 arg = "minimap.enable",
      },
      otherzone = {
         type = "toggle",
         name = L["Display waypoints from other zones"],
         desc = L["TomTom can hide waypoints in other zones, this setting toggles that functionality"],   
         width = "double",
		 arg = "minimap.otherzone",
      },
      tooltip = {
         type = "toggle",
         name = L["Enable mouseover tooltips"],
         desc = L["TomTom can display a tooltip containing information abouto waypoints, when they are moused over.  This setting toggles that functionality"],
		 arg = "minimap.tooltip",
      },
      
   },
} -- End minimap options

options.args.worldmap = {
   type = "group",
   name = L["World Map"],
   args = {
      help = {
         order = 1,
         type = "description",
         name = L["TomTom can display multiple waypoints on the world map.  These options control the display of these waypoints"],
      },
      enable = {
         order = 2,
         type = "toggle",
         name = L["Enable world map waypoints"],
         width = "double",
		 arg = "worldmap.enable",
      },
      otherzone = {
         type = "toggle",
         name = L["Display waypoints from other zones"],
         desc = L["TomTom can hide waypoints in other zones, this setting toggles that functionality"],   
         width = "double",
		 arg = "worldmap.otherzone",
      },
      tooltip = {
         type = "toggle",
         name = L["Enable mouseover tooltips"],
         desc = L["TomTom can display a tooltip containing information abouto waypoints, when they are moused over.  This setting toggles that functionality"],
		 arg = "worldmap.tooltip",
      },
	  createclick = {
		  type = "toggle",
		  name = L["Allow control-clicking on map to create new waypoint"],
		  width = "double",
		  arg = "worldmap.clickcreate",
	  },
   },
} -- End world map options

options.args.general = {
   type = "group",
   name = L["General Options"],
   args = {
      help = {
         order = 1,
         type = "description",
         name = L["TomTom is able to accept and send waypoints to guild and party members who are also running TomTom.  In addition, waypoints may be stored between sessions."],
      },
      comm = {
         type = "toggle",
         name = L["Accept waypoints from guild and party members"],
         width = "double",
		 arg = "comm.enable",
      },
      promptcomm = {
         type = "toggle",
         name = L["Prompt before accepting sent waypoints"],
         width = "double",
		 arg = "comm.prompt",
      },
      persistence = {
         type = "toggle",
         name = L["Save waypoints in between sessions"],
         width = "double",
		 arg = "persistence.savewaypoints",
      },
   },
}

LibStub("AceConfig-3.0"):RegisterOptionsTable("TomTom", options)

SLASH_TOMTOM1 = "/tomtom"
SlashCmdList["TOMTOM"] = function(msg)
	LibStub("AceConfigDialog-3.0"):Open("TomTom")
end

