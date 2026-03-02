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
            { t = "", label = "undervoltage1", inline_size = 40.6 },
            { t = "", label = "discharge", inline_size = 40.6 },
        },
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.flight_mode)@", type = 1, mspapi = 1, apikey = "flight_Mode", disable = true},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.battery_type)@", type = 1,  mspapi = 1, apikey = "battery_type"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.undervoltage_behavior)@", type = 1,  mspapi = 1, apikey = "undervoltage_behavior"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.undervoltage_cell)@", label = "undervoltage1", inline = 1, type = 2,  mspapi = 1, apikey = "undervoltage_cell"},
            --{t = "@i18n(app.modules.esc_tools.mfg.kontr.discharge_limiter_act)@", type = 4,  mspapi = 1, apikey = "discharge_limiter_act"}, -- this field is for later purpose (inactivating and deactivating the discharge limiter), so not adding it to the form for now
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.discharge_limit)@", label = "discharge", inline = 1, type = 2,  mspapi = 1, apikey = "discharge_limit"}
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
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.kontr.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.kontr.basic)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}
