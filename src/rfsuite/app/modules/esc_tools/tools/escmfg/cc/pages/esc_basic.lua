--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "cc"

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_CASTLE"
    },
    formdata = {
        labels = {}
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.cc.motor_timing)@",    type = 1, mspapi = 1, apikey = "motor_timing"},
            {t = "@i18n(app.modules.esc_tools.mfg.cc.cutoff_voltage)@",       type = 1, mspapi = 1, apikey = "cutoff_voltage"},
            {t = "@i18n(app.modules.esc_tools.mfg.cc.current_limiting)@",    type = 1, mspapi = 1, apikey = "current_limiting"},
            {t = "@i18n(app.modules.esc_tools.mfg.cc.brake_strength)@", type = 1, mspapi = 1, apikey = "brake_strength"},
            {t = "@i18n(app.modules.esc_tools.mfg.cc.voltage_cutoff_type)@",type = 1, mspapi = 1, apikey = "voltage_cutoff_type"},
            {t = "@i18n(app.modules.esc_tools.mfg.cc.pwm_rate)@",  type = 1, mspapi = 1, apikey = "pwm_rate"},
            {t = "@i18n(app.modules.esc_tools.mfg.cc.direction)@",  type = 1, mspapi = 1, apikey = "direction"}
        }
    }
}

local function postLoad()
    rfsuite.app.triggers.closeProgressLoader = true
end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

return {apidata = apidata, eepromWrite = true, reboot = false, escinfo = escinfo, postLoad = postLoad, navButtons = navHandlers.navButtons, onNavMenu = navHandlers.onNavMenu, event = navHandlers.event, pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.cc.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.cc.basic)@", headerLine = rfsuite.escHeaderLineText}
