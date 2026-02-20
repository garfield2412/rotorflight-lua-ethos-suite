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
            { t = "@i18n(app.modules.esc_tools.mfg.kontr.pgm_bt)@", label = "bluetooth"},
            },
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.act_impulse_length)@", type = 2, mspapi = 1, apikey = "act_impulse_length", disable = true},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.off_position)@", type = 2, mspapi = 1, apikey = "off_position"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.max_position)@", type = 2, mspapi = 1, apikey = "max_position"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.brake_position)@", type = 2, mspapi = 1, apikey = "brake_position"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.bec_voltage)@", type = 2, mspapi = 1, apikey = "bec_voltage"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.bt_disable_motor_renable_button)@", type = 4, mspapi = 1, apikey = "bt_disable_motor_renable_button", label = "bluetooth"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.bt_disable_motor_renable_motor_stop)@", type = 4, mspapi = 1, apikey = "bt_disable_motor_renable_motor_stop", label = "bluetooth"}
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
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.kontr.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.kontr.rc)@",
    headerLine = rfsuite.escHeaderLineText, progressCounter = 0.5
}
