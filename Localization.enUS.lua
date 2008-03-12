--Localization.enUS.lua

TomTolmLocals = {
}

setmetatable(TomTomLocals, {__index=function(t,k) rawset(t, k, k) end})
