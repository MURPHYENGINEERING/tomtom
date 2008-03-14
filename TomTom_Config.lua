local options = {}
local db = {}

local L = TomTomLocals

options.type = "group"
options.name = "TomTom"

local function get(info)
	local ns,opt = string.split(".", info.arg)
	local val = TomTom.db.profile[ns][opt]
	--TomTom:Print("get", ns, opt, val)
	if type(val) == "table" then
		return unpack(val)
	else
		return val
	end
end

local function set(info, arg1, arg2, arg3, arg4)
	local ns,opt = string.split(".", info.arg)
	--TomTom:Print("set", ns, opt, arg1, arg2, arg3, arg4)
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
   get = get,
   set = set,
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
		 width = "double",
         arg = "block.enable",
      },
	  lock = {
		  order = 3,
		  type = "toggle",
		  name = L["Lock coordinate block"],
		  desc = L["Locks the coordinate block so it can't be accidentally dragged to another location"],
		  width = "double",
		  arg = "block.lock",
	  },
	  accuracy = {
		  order = 4,
		  type = "range",
		  name = "Coordinate Accuracy",
		  desc = L["Coordinates can be displayed as simple XX, YY coordinate, or as more precise XX.XX, YY.YY.  This setting allows you to control that precision"],
		  min = 0, max = 2, step = 1,
		  arg = "block.accuracy",
	  },
	  display = {
         order = 4,
         type = "group",
		 inline = true,
         name = L["Display Settings"],
		 args = {
			 help = {
				 type = "description",
				 name = L["The display of the coordinate block can be customized by changing the options below."],
				 order = 1,
			 },
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

options.args.crazytaxi = {
   type = "group",
   name = L["Waypoint Arrow"],
   get = get,
   set = set,
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
	  lock = {
		  order = 3,
		  type = "toggle",
		  name = L["Lock waypoint arrow"],
		  desc = L["Locks the waypoint arrow, so it can't be moved accidentally"],
		  arg = "arrow.lock",
	  },
	  arrival = {
		  order = 4,
		  type = "toggle",
		  name = L["Show estimated time to arrival"],
		  desc = L["Shows an estimate of how long it will take you to reach the waypoint at your current speed"],
		  width = "double",
		  arg = "arrow.showtta",
	  },
	  heredistance = {
		  order = 5,
		  type = "range",
		  name = L["\"Arrival Distance\""],
		  desc = L["This setting will control the distance at which the waypoint arrow switches to a downwards arrow, indicating you have arrived at your destination"],
		  min = 0, max = 150, step = 5,
		  arg = "arrow.arrival",
	  },
      color = {
         type = "group",
         name = L["Arrow colors"],
		 inline = true,
         args = {
            help = {
               order = 1,
               type = "description",
               name = L["The floating waypoint arrow can change color depending on whether or nor you are facing your destination.  By default it will display green when you are facing it directly, and red when you are facing away from it.  These colors can be changed in this section.  Setting these options to the same color will cause the arrow to not change color at all"],
            },
            colorstart = {
				order = 2,
               type = "color",
               name = L["Good color"],
			   desc = L["The color to be displayed when you are moving in the direction of the active waypoint"],
			   arg = "arrow.goodcolor",
			   hasAlpha = false,
            },
			colormiddle = {
				order = 3,
				type = "color",
				name = L["Middle color"],
				desc = L["The color to be displayed when you are halfway between the direction of the active waypoint and the completely wrong direction"],
				arg = "arrow.middlecolor",
				hasAlpha = false,
			},
            colorend = {
				order = 4,
               type = "color",
               name = L["Bad color"],
			   desc = L["The color to be displayed when you are moving in the opposite direction of the active waypoint"],
			   arg = "arrow.badcolor",
			   hasAlpha = false,
            },
         },
      },
   },   
} -- End crazy taxi options

options.args.minimap = {
   type = "group",
   name = L["Minimap"],
   get = get,
   set = set,
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
		 width = "double",
		 arg = "minimap.tooltip",
      },
      
   },
} -- End minimap options

options.args.worldmap = {
	type = "group",
	name = L["World Map"],
	get = get,
	set = set,
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
			order = 3,
			type = "toggle",
			name = L["Display waypoints from other zones"],
			desc = L["TomTom can hide waypoints in other zones, this setting toggles that functionality"],   
			width = "double",
			arg = "worldmap.otherzone",
		},
		tooltip = {
			order = 4,
			type = "toggle",
			name = L["Enable mouseover tooltips"],
			desc = L["TomTom can display a tooltip containing information abouto waypoints, when they are moused over.  This setting toggles that functionality"],
			width = "double",
			arg = "worldmap.tooltip",
		},
		createclick = {
			order = 5,
			type = "toggle",
			name = L["Allow control-right clicking on map to create new waypoint"],
			width = "double",
			arg = "worldmap.clickcreate",
		},
		player = {
			order = 6,
			type = "group",
			inline = true,
			name = L["Player Coordinates"],
			args = {
				enableplayer = {
					order = 1,
					type = "toggle",
					name = L["Enable showing player coordinates"],
					width = "double",
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
			order = 7,
			type = "group",
			inline = true,
			name = L["Cursor Coordinates"],
			args = {
				enablecursor = {
					order = 3,
					type = "toggle",
					name = L["Enable showing cursor coordinates"],
					width = "double",
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
} -- End world map options

options.args.general = {
   type = "group",
   name = L["General Options"],
   get = get,
   set = set,
   args = {
      comm = {
         type = "toggle",
		 order = 1,
         name = L["Accept waypoints from guild and party members"],
         width = "double",
		 arg = "comm.enable",
      },
      promptcomm = {
         type = "toggle",
		 order = 2,
         name = L["Prompt before accepting sent waypoints"],
         width = "double",
		 arg = "comm.prompt",
      },
      persistence = {
         type = "toggle",
		 order = 3,
         name = L["Save waypoints in between sessions"],
         width = "double",
		 arg = "persistence.savewaypoints",
      },
	  cleardistance = {
		  type = "range",
		  order = 4,
		  name = L["Clear waypoint distance"],
		  desc = L["Waypoints can be automatically cleared when you reach them.  This slider allows you to customize the distance in yards that signals your \"arrival\" at the waypoint.  A setting of 0 turns off the auto-clearing feature\n\nChanging this setting only takes effect after reloading your interface."],  
		  min = 0, max = 150, step = 1,
		  arg = "persistence.cleardistance",
	  },
   },
}

local config = LibStub("AceConfig-3.0")
local dialog = LibStub("AceConfigDialog-3.0")
local registered = false;

function GetBuildInfo() return "0.3.0" end

SLASH_TOMTOM1 = "/tomtom"
SlashCmdList["TOMTOM"] = function(msg)
	local build = GetBuildInfo()
	
	if not registered then
		if build == "0.4.0" then
			config:RegisterOptionsTable("TomTom", {
				name = L["TomTom"],
				type = "group",
				args = {
					help = {
						type = "description",
						name = "TomTom is a simple navigation assistant",
					},
				},
			})
			dialog:SetDefaultSize("TomTom", 600, 400)
			dialog:AddToBlizOptions("TomTom", "TomTom")

			-- Add the options in reverse order of how we want them to be shown
			-- World Map Options
			config:RegisterOptionsTable("TomTom-Worldmap", options.args.worldmap)
			dialog:AddToBlizOptions("TomTom-Worldmap", options.args.worldmap.name, "TomTom")
			-- Minimap Options
			config:RegisterOptionsTable("TomTom-Minimap", options.args.minimap)
			dialog:AddToBlizOptions("TomTom-Minimap", options.args.minimap.name, "TomTom")
			-- Crazy Taxi Options
			config:RegisterOptionsTable("TomTom-CrazyTaxi", options.args.crazytaxi)
			dialog:AddToBlizOptions("TomTom-CrazyTaxi", options.args.crazytaxi.name, "TomTom")
			-- Coordinate Block Options
			config:RegisterOptionsTable("TomTom-CoordBlock", options.args.coordblock)
			dialog:AddToBlizOptions("TomTom-CoordBlock", options.args.coordblock.name, "TomTom")
			-- General Options
			config:RegisterOptionsTable("TomTom-General", options.args.general)
			dialog:AddToBlizOptions("TomTom-General", options.args.general.name, "TomTom")
		else
			config:RegisterOptionsTable("TomTom", options)
			dialog:SetDefaultSize("TomTom", 600, 400)
		end

		registered = true
	end

	if build == "0.4.0" then
		InterfaceOptionsFrame_OpenToFrame(options.args.general.name, "TomTom")
	else
		dialog:Open("TomTom")
	end
end
