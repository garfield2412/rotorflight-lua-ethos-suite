--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local folder = "kontr"

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_KONTRONIK"
    },
    formdata = {
        labels = {
            { t = "", label = "maxrpm", inline_size = 40.6 },
        },
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.rotation)@", type = 4, mspapi = 1, apikey = "rotation"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.fwd_bckwd)@", type = 4, mspapi = 1, apikey = "fwd_bckwd"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.pole_number)@", type = 1, mspapi = 1, apikey = "pole_number"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.gear_ratio)@", type = 2, mspapi = 1, apikey = "gear_ratio"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.brake)@", type = 4, mspapi = 1, apikey = "brake"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.rpm_ctl)@", type = 4, mspapi = 1, apikey = "rpm_ctl"},
            {t = "@i18n(app.modules.esc_tools.mfg.kontr.how_adj_max_rpm)@", label = "maxrpm", inline = 1, type = 1,  mspapi = 1, apikey = "how_adj_max_rpm"}
        }
    }
}

local function postLoad()

    if rfsuite.app.Page.apidata and rfsuite.tasks.msp.api.apidata.other and rfsuite.tasks.msp.api.apidata.other['ESC_PARAMETERS_KONTRONIK'] then
        local version
        if rfsuite.session.escDetails and rfsuite.session.escDetails.version then
            version = rfsuite.session.escDetails.version
        else
            version = "default"
        end

        if rfsuite.tasks.msp.api.apidata.other['ESC_PARAMETERS_KONTRONIK'][version] then
            local newVoltage = rfsuite.tasks.msp.api.apidata.other['ESC_PARAMETERS_KONTRONIK'][version]
            local voltageTable = rfsuite.app.utils.convertPageValueTable(newVoltage, -1)

            rfsuite.app.formFields[3]:values(voltageTable)
        end

    end

    rfsuite.app.triggers.closeProgressLoader = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder, "esc_motors/tools/esc_tool.lua")
end

local function event(widget, category, value, x, y)

    if category == EVT_CLOSE and value == 0 or value == 35 then
        if powercycleLoader then powercycleLoader:close() end
        rfsuite.app.ui.openPage(pidx, folder, "esc_motors/tools/esc_tool.lua")
        return true
    end

end

return {apidata = apidata, eepromWrite = true, reboot = false, escinfo = escinfo, postLoad = postLoad, navButtons = {menu = true, save = true, reload = true, tool = false, help = false}, onNavMenu = onNavMenu, event = event, pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.kontr.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.kontr.motor)@", headerLine = rfsuite.escHeaderLineText}
