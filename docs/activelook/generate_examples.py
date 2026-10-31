#!/usr/bin/env python3
"""Generate ActiveLook layout example PNGs.

The slot positions mirror src/rfsuite/widgets/activelook/activelook.lua.
Rendering uses Windows GDI+ through ctypes so the examples can use smooth
TrueType text without adding a Python imaging dependency.
"""

from __future__ import annotations

import ctypes
import os
import sys
from ctypes import wintypes


if os.name != "nt":
    raise SystemExit("This generator uses Windows GDI+ and must be run on Windows.")


WIDTH = 304
HEIGHT = 256
OUTER_PADDING = 8
ICON_GAP = 8

BG = 0xFF04090A
PANEL = 0xFF091416
GRID = 0xFF4C370E
AMBER = 0xFFFFBE30
DIM = 0xFF5C4212

FONT_PX = {
    1: 24,
    2: 38,
    3: 64,
}

LAYOUT_ACTIVE = {
    "two_top_one_bottom": (True, True, True, False),
    "two_top_two_bottom": (True, True, True, True),
    "one_centered": (True, False, False, False),
    "one_top_two_bottom": (True, False, True, True),
    "stacked_three": (True, True, True, False),
}

LAYOUT_NAMES = (
    "two_top_one_bottom",
    "two_top_two_bottom",
    "one_centered",
    "one_top_two_bottom",
    "stacked_three",
)

SCENARIOS = (
    {"key": "preflight", "values": ("ACTIVE", "DISARMED", "PRE", "")},
    # current, voltage, fuel, timer
    {"key": "inflight", "values": ("58.4A", "22.6V", "73%", "04:18")},
    # current_max, voltage_min, temp_esc_max, headspeed_max
    {"key": "postflight", "values": ("96A", "21.4V", "87C", "2140")},
)


class GdiplusStartupInput(ctypes.Structure):
    _fields_ = (
        ("GdiplusVersion", wintypes.UINT),
        ("DebugEventCallback", ctypes.c_void_p),
        ("SuppressBackgroundThread", wintypes.BOOL),
        ("SuppressExternalCodecs", wintypes.BOOL),
    )


class RectF(ctypes.Structure):
    _fields_ = (
        ("X", ctypes.c_float),
        ("Y", ctypes.c_float),
        ("Width", ctypes.c_float),
        ("Height", ctypes.c_float),
    )


class GUID(ctypes.Structure):
    _fields_ = (
        ("Data1", wintypes.DWORD),
        ("Data2", wintypes.WORD),
        ("Data3", wintypes.WORD),
        ("Data4", ctypes.c_ubyte * 8),
    )


PNG_ENCODER = GUID(
    0x557CF406,
    0x1A04,
    0x11D3,
    (ctypes.c_ubyte * 8)(0x9A, 0x73, 0x00, 0x00, 0xF8, 0x1E, 0xF3, 0x2E),
)


def check(status: int, action: str) -> None:
    if status != 0:
        raise RuntimeError(f"GDI+ {action} failed with status {status}")


class GdiRenderer:
    PixelFormat32bppARGB = 0x0026200A
    FontStyleBold = 1
    UnitPixel = 2

    def __init__(self) -> None:
        self.gdip = ctypes.windll.gdiplus
        self.token = ctypes.c_ulonglong()
        startup = GdiplusStartupInput(1, None, False, False)
        check(self.gdip.GdiplusStartup(ctypes.byref(self.token), ctypes.byref(startup), None), "startup")

    def shutdown(self) -> None:
        self.gdip.GdiplusShutdown(self.token)

    def create_image(self):
        bitmap = ctypes.c_void_p()
        check(
            self.gdip.GdipCreateBitmapFromScan0(
                WIDTH,
                HEIGHT,
                0,
                self.PixelFormat32bppARGB,
                None,
                ctypes.byref(bitmap),
            ),
            "create bitmap",
        )
        graphics = ctypes.c_void_p()
        check(self.gdip.GdipGetImageGraphicsContext(bitmap, ctypes.byref(graphics)), "create graphics")
        self.gdip.GdipSetSmoothingMode(graphics, 4)
        self.gdip.GdipSetTextRenderingHint(graphics, 4)
        check(self.gdip.GdipGraphicsClear(graphics, BG), "clear")
        return bitmap, graphics

    def brush(self, argb: int):
        brush = ctypes.c_void_p()
        check(self.gdip.GdipCreateSolidFill(argb, ctypes.byref(brush)), "create brush")
        return brush

    def pen(self, argb: int, width: float = 1.0):
        pen = ctypes.c_void_p()
        check(self.gdip.GdipCreatePen1(argb, ctypes.c_float(width), self.UnitPixel, ctypes.byref(pen)), "create pen")
        return pen

    def font(self, size: float):
        family = ctypes.c_void_p()
        font = ctypes.c_void_p()
        check(self.gdip.GdipCreateFontFamilyFromName("Arial", None, ctypes.byref(family)), "create font family")
        check(
            self.gdip.GdipCreateFont(
                family,
                ctypes.c_float(size),
                self.FontStyleBold,
                self.UnitPixel,
                ctypes.byref(font),
            ),
            "create font",
        )
        return family, font

    def string_format(self):
        fmt = ctypes.c_void_p()
        check(self.gdip.GdipCreateStringFormat(0, 0, ctypes.byref(fmt)), "create string format")
        return fmt

    def measure_text(self, graphics, text: str, font, fmt) -> tuple[float, float]:
        layout = RectF(0, 0, 500, 120)
        bounds = RectF()
        chars = ctypes.c_int()
        lines = ctypes.c_int()
        check(
            self.gdip.GdipMeasureString(
                graphics,
                ctypes.c_wchar_p(text),
                -1,
                font,
                ctypes.byref(layout),
                fmt,
                ctypes.byref(bounds),
                ctypes.byref(chars),
                ctypes.byref(lines),
            ),
            "measure text",
        )
        return bounds.Width, bounds.Height

    def draw_text(self, graphics, brush, text: str, x: int, y: int, width: int, font_id: int, centered: bool) -> None:
        px = FONT_PX.get(font_id, 24)
        size = max(8, int(px * 0.72))
        family, font = self.font(size)
        fmt = self.string_format()
        try:
            measured_w, measured_h = self.measure_text(graphics, text, font, fmt)
            draw_x = x
            if centered:
                draw_x = x + max(0, int((width - measured_w) * 0.5))
            rect = RectF(float(draw_x), float(y), max(float(width), measured_w + 4), measured_h + 8)
            check(
                self.gdip.GdipDrawString(
                    graphics,
                    ctypes.c_wchar_p(text),
                    -1,
                    font,
                    ctypes.byref(rect),
                    fmt,
                    brush,
                ),
                "draw text",
            )
        finally:
            self.gdip.GdipDeleteStringFormat(fmt)
            self.gdip.GdipDeleteFont(font)
            self.gdip.GdipDeleteFontFamily(family)

    def save(self, bitmap, path: str) -> None:
        check(self.gdip.GdipSaveImageToFile(bitmap, path, ctypes.byref(PNG_ENCODER), None), "save PNG")

    def dispose_image(self, bitmap, graphics) -> None:
        self.gdip.GdipDeleteGraphics(graphics)
        self.gdip.GdipDisposeImage(bitmap)


def add_slot(slots, index, enabled, x, y, size, font, text_y_offset, width, align=""):
    slots[index - 1] = {
        "enabled": enabled,
        "x": x,
        "y": y,
        "size": size,
        "font": font,
        "text_y_offset": text_y_offset,
        "width": width,
        "align": align,
    }


def get_slots(layout_key: str, mode_key: str):
    area_w = WIDTH - OUTER_PADDING * 2
    area_h = HEIGHT - OUTER_PADDING * 2
    scale = area_h / 256
    y1 = int(8 * scale)
    y2 = int(88 * scale)
    y3 = int(186 * scale)
    gap = max(4, int(ICON_GAP * scale))
    large_offset = int(8 * scale)
    small_offset = int(6 * scale)
    box_w = int((area_w - gap) * 0.5)
    right_x = box_w + gap
    center_x = int((area_w - box_w) * 0.5)
    active = LAYOUT_ACTIVE[layout_key]
    slots = [None, None, None, None]
    is_preflight = mode_key == "preflight"
    top_font = 3
    bottom_font = 1 if is_preflight else 2
    top_offset = large_offset + int(6 * scale) if is_preflight else large_offset
    bottom_offset = int(2 * scale) if is_preflight else small_offset

    if layout_key == "two_top_one_bottom":
        add_slot(slots, 1, active[0], 0, y1, "large", top_font, top_offset, box_w, "center" if is_preflight else "")
        add_slot(slots, 2, active[1], right_x, y1, "large", top_font, top_offset, box_w, "center" if is_preflight else "")
        add_slot(slots, 3, active[2], center_x, y3, "small", bottom_font, bottom_offset, box_w, "center")
        add_slot(slots, 4, active[3], right_x, y3, "small", bottom_font, bottom_offset, box_w, "center" if is_preflight else "")
    elif layout_key == "stacked_three":
        add_slot(slots, 1, active[0], 0, y1, "large", top_font, top_offset, area_w, "center")
        add_slot(slots, 2, active[1], 0, y2, "large", top_font, top_offset, area_w, "center")
        add_slot(slots, 3, active[2], 0, y3, "small", bottom_font, bottom_offset, area_w, "center")
        add_slot(slots, 4, active[3], right_x, y3, "small", bottom_font, bottom_offset, box_w, "center" if is_preflight else "")
    elif layout_key == "one_centered":
        add_slot(slots, 1, active[0], 0, y2, "large", top_font, top_offset, area_w, "center")
        add_slot(slots, 2, active[1], right_x, y2, "large", top_font, top_offset, box_w, "center" if is_preflight else "")
        add_slot(slots, 3, active[2], 0, y3, "small", bottom_font, bottom_offset, box_w, "center" if is_preflight else "")
        add_slot(slots, 4, active[3], right_x, y3, "small", bottom_font, bottom_offset, box_w, "center" if is_preflight else "")
    elif layout_key == "one_top_two_bottom":
        add_slot(slots, 1, active[0], 0, y1, "large", top_font, top_offset, area_w, "center")
        add_slot(slots, 2, active[1], right_x, y1, "large", top_font, top_offset, box_w, "center" if is_preflight else "")
        add_slot(slots, 3, active[2], 0, y3, "small", bottom_font, bottom_offset, box_w, "center" if is_preflight else "")
        add_slot(slots, 4, active[3], right_x, y3, "small", bottom_font, bottom_offset, box_w, "center" if is_preflight else "")
    else:
        add_slot(slots, 1, active[0], 0, y1, "large", top_font, top_offset, box_w, "center" if is_preflight else "")
        add_slot(slots, 2, active[1], right_x, y1, "large", top_font, top_offset, box_w, "center" if is_preflight else "")
        add_slot(slots, 3, active[2], 0, y3, "small", bottom_font, bottom_offset, box_w, "center" if is_preflight else "")
        add_slot(slots, 4, active[3], right_x, y3, "small", bottom_font, bottom_offset, box_w, "center" if is_preflight else "")

    return slots


def draw_example(renderer: GdiRenderer, out_dir: str, layout_key: str, scenario: dict) -> None:
    bitmap, graphics = renderer.create_image()
    panel_brush = renderer.brush(PANEL)
    amber_brush = renderer.brush(AMBER)
    grid_pen = renderer.pen(GRID)
    dim_pen = renderer.pen(DIM)
    try:
        area_w = WIDTH - OUTER_PADDING * 2
        area_h = HEIGHT - OUTER_PADDING * 2
        check(renderer.gdip.GdipFillRectangleI(graphics, panel_brush, OUTER_PADDING, OUTER_PADDING, area_w, area_h), "fill panel")
        check(renderer.gdip.GdipDrawRectangleI(graphics, grid_pen, OUTER_PADDING, OUTER_PADDING, area_w, area_h), "draw border")

        slots = get_slots(layout_key, scenario["key"])
        for index, slot in enumerate(slots):
            if not slot or not slot["enabled"]:
                continue
            text = scenario["values"][index]
            if not text:
                continue

            text_x = OUTER_PADDING + int(slot["x"])
            text_y = OUTER_PADDING + int(slot["y"] + slot["text_y_offset"])
            renderer.draw_text(
                graphics,
                amber_brush,
                text,
                text_x,
                text_y,
                int(slot["width"]),
                slot["font"],
                slot["align"] == "center",
            )

            underline_y = OUTER_PADDING + int(slot["y"] + (72 if slot["size"] == "large" else 44))
            line_x = OUTER_PADDING + int(slot["x"])
            check(
                renderer.gdip.GdipDrawLineI(graphics, dim_pen, line_x, underline_y, line_x + int(slot["width"]), underline_y),
                "draw line",
            )

        path = os.path.join(out_dir, f"{layout_key}_{scenario['key']}.png")
        renderer.save(bitmap, path)
    finally:
        renderer.gdip.GdipDeletePen(dim_pen)
        renderer.gdip.GdipDeletePen(grid_pen)
        renderer.gdip.GdipDeleteBrush(amber_brush)
        renderer.gdip.GdipDeleteBrush(panel_brush)
        renderer.dispose_image(bitmap, graphics)


def main() -> None:
    out_dir = os.path.dirname(os.path.abspath(__file__))
    renderer = GdiRenderer()
    try:
        for layout_key in LAYOUT_NAMES:
            for scenario in SCENARIOS:
                draw_example(renderer, out_dir, layout_key, scenario)
    finally:
        renderer.shutdown()
    print(f"Generated {len(LAYOUT_NAMES) * len(SCENARIOS)} PNG files in {out_dir}")


if __name__ == "__main__":
    main()
