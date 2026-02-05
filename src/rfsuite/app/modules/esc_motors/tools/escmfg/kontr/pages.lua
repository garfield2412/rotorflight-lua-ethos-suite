--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local PageFiles = {}

PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.kontr.basic)@", script = "esc_basic.lua", image = "basic.png"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.kontr.motor)@", script = "esc_motor.lua", image = "motor.png"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.kontr.alarm)@", script = "esc_alarm.lua", image = "limits.png"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.kontr.esc_status)@", script = "esc_status.lua", image = "other.png"}

return PageFiles
