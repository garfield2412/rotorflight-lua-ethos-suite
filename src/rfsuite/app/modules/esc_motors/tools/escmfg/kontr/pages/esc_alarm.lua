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

return {apidata = apidata, eepromWrite = true, reboot = false, escinfo = escinfo, postLoad = postLoad, navButtons = {menu = true, save = true, reload = true, tool = false, help = false}, onNavMenu = onNavMenu, event = event, pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.kontr.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.kontr.alarm)@", headerLine = rfsuite.escHeaderLineText}
