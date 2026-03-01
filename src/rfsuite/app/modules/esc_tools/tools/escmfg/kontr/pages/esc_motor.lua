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
            { t = "@i18n(app.modules.esc_tools.mfg.kontr.general)@", label = "general"},
            { t = "@i18n(app.modules.esc_tools.mfg.kontr.rpm_ctl)@", label = "rpm", inline_size = 40.6 },
            { t = "@i18n(app.modules.esc_tools.mfg.kontr.expert)@", label = "expert"},
        },
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.rotation)@", type = 4, mspapi = 1, apikey = "rotation", label = "general"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.fwd_bckwd)@", type = 4, mspapi = 1, apikey = "fwd_bckwd", label = "general"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.pole_number)@", type = 1, mspapi = 1, apikey = "pole_number", label = "general"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.gear_ratio)@", type = 2, mspapi = 1, apikey = "gear_ratio", label = "general"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.brake)@", type = 4, mspapi = 1, apikey = "brake"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.prop_brake)@", type = 4, mspapi = 1, apikey = "prop_brake", label = "general"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.rpm_ctl)@", type = 4, mspapi = 1, apikey = "rpm_ctl"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.how_adj_max_rpm)@", type = 1,  mspapi = 1, apikey = "how_adj_max_rpm", label = "rpm"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.max_rpm)@", type = 2, mspapi = 1, apikey = "max_rpm", label = "rpm"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.startuptime)@", type = 2, mspapi = 1, apikey = "startuptime", label = "rpm"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.p-gain)@", type = 2, mspapi = 1, apikey = "p-gain", label = "rpm"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.motor_resist)@", type = 2, mspapi = 1, apikey = "motor_resist", label = "rpm"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.PWM_min)@", type = 2, mspapi = 1, apikey = "PWM_min"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.slewrate_up)@", type = 2, mspapi = 1, apikey = "slewrate_up", label = "expert"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.slewrate_down)@", type = 2, mspapi = 1, apikey = "slewrate_down", label = "expert"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.extra_smooth_IU)@", type = 4, mspapi = 1, apikey = "extra_smooth_IU", label = "expert"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.alternate_startup)@", type = 4, mspapi = 1, apikey = "alternate_startup", label = "expert"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.startup_curr_limit)@", type = 2, mspapi = 1, apikey = "startup_curr_limit", label = "expert"}
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
    navButtons = {menu = true, save = true,
    reload = true,
    tool = false,
    help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.kontr.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.kontr.motor)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}
