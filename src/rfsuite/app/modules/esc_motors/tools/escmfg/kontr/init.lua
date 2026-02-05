--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local MSP_API = "ESC_PARAMETERS_KONTRONIK"
local toolName = "@i18n(app.modules.esc_tools.mfg.kontr.name)@"
local moduleName = "kontr"
local mspHeaderBytes = 2

local function getText(buffer, st, en)

    local tt = {}
    for i = st, en do
        local v = buffer[i]
        if v == 0 then break end
        table.insert(tt, string.char(v))
    end
    return table.concat(tt)
end

local function getEscModel(buffer) return getText(buffer, 3, 18) end
local function getEscVersion(buffer) return getText(buffer, 19, 34) end
local function getEscFirmware(buffer) return getText(buffer, 35, 50) end


return {mspapi = MSP_API, toolName = toolName, image = "kontronik.png", powerCycle = false, getEscModel = getEscModel, getEscVersion = getEscVersion, getEscFirmware = getEscFirmware, mspHeaderBytes = mspHeaderBytes}

