--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local PageFiles = {}

PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.cc.basic)@", script = "esc_basic.lua", image = "basic.png"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.cc.advanced)@", script = "esc_advanced.lua", image = "advanced.png"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.cc.other)@", script = "esc_other.lua", image = "other.png"}

return PageFiles
