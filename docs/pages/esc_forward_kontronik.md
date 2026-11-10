---
title: KONTRONIK
sidebar_label: KONTRONIK
---

# KONTRONIK

Local preview of the Kontronik ESC setup design, adapted from branch `ESC_kontronik` to the current Suite page layout. Source: `src/rfsuite/app/pages/esc_forward_kontronik.lua`.

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *ESC Tools* → *KONTRONIK*.

The tile has no ESC protocol requirement. Like the other ESC tools, it requires an active flight-controller connection and declares `lockedWhileArmed = true`: entry is blocked while armed. Parent menu availability still applies. The connection requirement only controls menu availability; the preview itself never communicates with the flight controller.

The menu tile uses the original black K logo from the draft branch, normalized to the Suite's 70×70 RGB mask format.

## Settings

All values are local examples. Cell cutoff limits and examples follow the 2026-04-01 KONTRONIK PDF; other ranges remain provisional draft values, not validated firmware parameters. Save and Reload are disabled. Leaving the page discards all edits.

| Setting | Preview control |
| --- | --- |
| Default parameter set | Select Glider (2), Powered aircraft (3), Helicopter (4), F5A (5) or Car (6). These values are commands for loading complete default sets, not a readable current model type. |
| Load preset | Opens a confirmation warning that loading the selected set replaces all ESC parameters. The dialog provides OK and Cancel. In this UI preview, confirmation only records the requested set on screen; no ESC command or local parameter reset is performed. |
| Battery Type | Battery chemistry selection. |
| Low voltage action | Choose slow-down or shutdown at low voltage. |
| Cell cutoff | Chemistry-specific threshold: NiMH 700–1200 mV, LiPo 2700–3500 mV, LiFePo 1800–2600 mV. Separate local examples (800/3000/2300 mV) are retained when switching chemistry. |
| Discharge Limit | Discharge limiter threshold, 0.0–100.0 Ah in steps of 0.1 Ah. Zero means off; positive input enables the local limiter example. |
| Reverse Rotation | Reverse motor rotation. |
| Forward/Backward | Enable forward/reverse operation. |
| Pole Count | Choose 2–20 motor poles in steps of two. |
| Main Gear Ratio 1: | Motor-to-rotor gearing, draft raw range 100–2000. |
| Brake | Enable motor braking. |
| Proportional brake | Enable proportional braking; editable only while Brake is enabled. |
| RPM Control | Enable ESC speed regulation. |
| Max RPM source | Choose idle-up or governor-store speed reference. |
| Max RPM | Speed ceiling, 0–100000 RPM. |
| Startup Time | Spool-up duration, 0–60 s. |
| P-Gain | Governor proportional gain, 0–15. |
| Motor resistance | Motor resistance compensation, 0–15 mOhm. |
| PWM minimum | Minimum motor duty cycle, 0–100%. |
| Slew Rate Up | Upward ramp duration, 0–65535 ms. |
| Slew Rate Down | Downward ramp duration, 0–65535 ms. |
| Smooth idle up | Enable smooth idle-up. |
| Alternate Startup | Enable alternative startup behaviour. |
| Startup current limit | Startup current ceiling, 0–255 A. |
| RC endpoint check | Diagnoses endpoint order and spacing, including reversed throttle direction and the additional 200 us brake condition. Invalid combinations remain editable for correction. |
| Actual Impulse Length | Current throttle pulse, read-only placeholder, 500–2100 us. |
| Off Position | Motor-off throttle endpoint, 500–2100 us. |
| Max Position | Full-throttle endpoint, 500–2100 us. |
| Brake Position | Brake throttle position, 500–2100 us. |
| BEC Voltage | BEC output voltage, 4800–8000 mV. |
| Bluetooth: Disable after first run | Disable the Bluetooth module after the first motor run; restore Bluetooth with the module button. Read-only in the preview. |
| Bluetooth: Disable while running | Disable the Bluetooth module while the motor runs; restore Bluetooth when the motor stops. Read-only in the preview. |
| Edit ESC alarms | Explicit local opt-in to unlock the six ESC alarm thresholds; off by default on every visit. |
| Alarm max discharge | Discharged-capacity alarm, 0–50 Ah. |
| Min. input voltage | Supply-voltage alarm, 1000–100000 mV. |
| Alarm max motor current | Motor-current alarm, 0–500 A. |
| Alarm max ESC temperature | ESC temperature alarm, 0–200 °C. |
| Alarm max BEC temperature | BEC temperature alarm, 0–255 °C. |
| Alarm max BEC current | BEC-current alarm, 0–50000 mA. |

## Field dependencies

The proportional brake field follows **Brake**. The maximum-speed source, maximum RPM, startup time, P gain and motor resistance follow **RPM control**. Maximum RPM also requires **Governor store** mode. Inactive fields stay visible and retain their values; their setters reject edits until the dependency is satisfied.

Battery chemistry changes the cell-cutoff target, limits and default in place. Each chemistry retains its own local value; switching does not copy a threshold into another chemistry. The displayed defaults are documented preview examples, not received ESC data.

The RC check mirrors K-PROG's endpoint-order rules: off/max must differ by at least 100 us; brake ordering depends on throttle direction, and an enabled brake requires at least 200 us between brake and full throttle. It is a local diagnostic and does not execute or validate an actual programming-mode completion.

A preset request does not impose a model mask because no preset is actually loaded. EEPROM/model capability gates and controller programming permission require future firmware integration; the current preview does not invent them. No governor helper writes or transport requests are performed.

## Status fields

Events appear directly after Operating state, before live measurements and statistics. All fields are read-only. The unit is included in the label. Target speed is meaningful only with speed control active; until real data is available it also shows `--`.

| Group | Field | Meaning |
| --- | --- | --- |
| Controller | ESC model | Controller identification string. |
| Controller | EEPROM version | Version used to determine parameter capabilities. |
| Controller | Programming allowed | Controller programming-possible flag. |
| Controller | Operating state | State number decoded to its documented description when transport is implemented. |
| Latest event | Event time | Event timestamp in seconds. |
| Latest event | Event severity | Event type: Info, Warning, Error, Self-test, EEPROM or invalid set/reset number. |
| Latest event | Event code | Raw documented event number. |
| Latest event | Event description | Decoded event meaning when transport is implemented. |
| Live | Runtime | Controller run time in seconds. |
| Live | Battery voltage | Present supply voltage in volts. |
| Live | Battery current | Present battery current in amps. |
| Live | Used capacity | Consumed battery capacity in mAh. |
| Live | Output speed | Reported motor/output speed in RPM. |
| Live | Motor current | Averaged motor current in amps. |
| Live | Timing | Commutation angle in degrees. |
| Live | BEC voltage | Present BEC voltage in volts. |
| Live | BEC current | Present BEC current in amps. |
| Live | BEC temperature | Present BEC temperature in Celsius. |
| Live | Throttle command | Controller throttle demand in percent. |
| Live | Target speed | Governor target speed in RPM; transmitted only with speed control active. |
| Live | Actual PWM | Motor PWM duty cycle in percent. |
| Live | ESC temperature | Present power-stage temperature in Celsius. |
| Live | Throttle pulse | Current receiver pulse length in microseconds (`§G`). |
| Live | Average pulse | Averaged receiver pulse length in microseconds (text ID 19). |
| Statistics | Min. battery voltage | Lowest recorded battery voltage in volts. |
| Statistics | Max. motor current | Highest recorded averaged motor current in amps. |
| Statistics | Peak motor current | Highest recorded peak motor current in amps. |
| Statistics | Min. BEC voltage | Lowest recorded BEC voltage in volts. |
| Statistics | Max. BEC current | Highest recorded BEC current in amps. |
| Statistics | Max. BEC temperature | Highest recorded BEC temperature in Celsius. |
| Statistics | Max. ESC temperature | Highest recorded power-stage temperature in Celsius. |

## ESC alarm edit lock

Alarm is the last panel, directly after ESC Live Status. Its thresholds belong to the ESC; they do not configure Rotorflight or Suite alert thresholds. ESC-generated events can still appear in the status/event display.

The **Edit ESC alarms** switch starts off on every page visit. All six alarm inputs remain visible but disabled until it is explicitly switched on. Switching it off locks the inputs again without discarding local preview edits. This switch only permits editing; it does not enable or disable the ESC's alarms and is never stored or sent to the controller. All preview edits are discarded on leaving the page.

## Notes

Groups: Basic, Motor, Remote Control, Bluetooth interface, ESC Live Status and Alarm. The Bluetooth controls affect the Bluetooth interface, not motor enablement. Live status uses the fields described by the KONTRONIK Bluetooth Module Serial Protocol (2026-04-01), pages 2–9. Every value is shown as `--` until firmware integration supplies actual data; no fake telemetry is displayed. The hidden discharge-limiter activation control stays omitted, as in the draft.

This page does not read or write ESC parameters, persist settings, request EEPROM writes or reboot the flight controller. Firmware integration is a separate step.

## UI verification

The actual page was rendered in an isolated X20PRO Ethos 26.2.0-RC1 system-tool harness on 2026-11-10. The full Suite menu integration was checked by the Lua menu harnesses; the simulator model had no active flight-controller connection. X18 text budgets were checked with `check-fit.py`; no X18 simulator build was available locally.

*Documented against the current Suite branch `ESC_Koontronik_4.7`; firmware communication is not implemented.*
