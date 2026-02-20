--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()
local folder = "kontr"

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_KONTRONIK"
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.max_discharge)@", type = 2,  mspapi = 1, apikey = "max_discharge"},    
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.min_input_voltage)@", type = 2,  mspapi = 1, apikey = "min_input_voltage"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.max_motor_current)@", type = 2,  mspapi = 1, apikey = "max_motor_current"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.max_esc_temp)@", type = 2,  mspapi = 1, apikey = "max_esc_temp"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.max_bec_temp)@", type = 2,  mspapi = 1, apikey = "max_bec_temp"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.max_bec_current)@", type = 2,  mspapi = 1, apikey = "max_bec_current"}
        }
    }
}

local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

return {
    apidata = apidata,
    eepromWrite = true,
    reboot = false,
    escinfo = escinfo,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.kontr.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.kontr.alarm)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}
