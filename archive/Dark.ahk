#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

/**
 * DarkMode.ahk - Unified Dark Mode GUI Framework for AutoHotkey v2
 *
 * A comprehensive, bulletproof dark mode implementation using Win32 APIs,
 * DWM attributes, and custom drawing techniques.
 *
 * Features:
 * - Automatic dark title bar (Windows 10 1809+)
 * - Dark system menus via undocumented uxtheme APIs
 * - Custom-drawn controls with hover/pressed states
 * - GDI+ anti-aliased slider thumbs
 * - Proper GDI resource management with cleanup
 * - Arrow-less dark scrollbars for ListView
 * - Complete WM_CTLCOLOR* handling for all controls
 *
 * Usage:
 *   myGui := DarkGui("+Resize", "My Dark App")
 *   myGui.Add("Button", "+Accent", "OK")
 *   myGui.Add("Edit", "w200", "Sample text")
 *   myGui.Show()
 *
 * @version 2.0
 * @author Based on DarkModeModular.ahk, unified and hardened
 */

; ═══════════════════════════════════════════════════════════════════════════════
; Win32 Structure Definitions (AHK v2.1 alpha struct syntax)
; ═══════════════════════════════════════════════════════════════════════════════

/** Win32 RECT structure for control dimensions */
class RECT {
    left: i32, top: i32, right: i32, bottom: i32
}

/** Win32 NMHDR notification header structure */
class NMHDR {
    hwndFrom: uptr
    idFrom  : uptr
    code    : i32
}

/** Win32 NMCUSTOMDRAW structure for custom drawing notifications */
class NMCUSTOMDRAW {
    hdr        : NMHDR
    dwDrawStage: u32
    hdc        : uptr
    rc         : RECT
    dwItemSpec : uptr
    uItemState : u32
    lItemlParam: iptr
}

; ═══════════════════════════════════════════════════════════════════════════════
; DarkTheme - Central Theme Manager
; ═══════════════════════════════════════════════════════════════════════════════

/**
 * Central theme manager for dark mode colors and GDI brushes.
 * Provides color constants, brush caching, and utility functions.
 * All brushes are automatically created on startup and cleaned up on exit.
 */
class DarkTheme {
    /** Color palette for dark theme (0xRRGGBB format) */
    static Colors := Map(
        "Background",     0x1A1A1A,   ; Main window background
        "Controls",       0x252525,   ; Control backgrounds (edit, listview)
        "ControlsHover",  0x333333,   ; Button hover state
        "ControlsActive", 0x404040,   ; Button pressed state
        "Font",           0xE8E8E8,   ; Primary text color
        "FontDim",        0xA0A0A0,   ; Secondary/disabled text
        "Accent",         0x0078D7,   ; Windows accent blue
        "AccentHover",    0x1A8CFF,   ; Accent hover state
        "AccentPressed",  0x005A9E,   ; Accent pressed state
        "Border",         0x404040,   ; Control borders
        "Selection",      0x264F78,   ; Selected item background
        "GridLine",       0x2A2A2A,   ; ListView grid lines
        "Header",         0x2D2D2D,   ; ListView header background
        "ScrollTrack",    0x191919,   ; Scrollbar track
        "ScrollThumb",    0x4D4D4D    ; Scrollbar thumb
    )

    /** Cached GDI brush handles keyed by color name */
    static Brushes := Map()

    /** GDI+ startup token for anti-aliased drawing */
    static GdipToken := 0

    /** Whether theme has been initialized */
    static _initialized := false

    /**
     * Initialize theme resources (called automatically on first use)
     */
    static Initialize() {
        if this._initialized
            return

        ; Create GDI brushes for all colors
        for name, color in this.Colors {
            try {
                this.Brushes[name] := DllCall("gdi32\CreateSolidBrush",
                    "UInt", this.RGBtoBGR(color), "Ptr")
            } catch as err {
                ; Log error but continue - brush will be created on demand
            }
        }

        ; Initialize GDI+ for anti-aliased drawing
        try {
            si := Buffer(24, 0)
            NumPut("UInt", 1, si, 0)
            token := 0
            if DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si, "Ptr", 0) = 0
                this.GdipToken := token
        }

        ; Register cleanup on exit
        OnExit((*) => DarkTheme.Cleanup())

        this._initialized := true
    }

    /**
     * Cleanup all GDI resources on exit
     */
    static Cleanup() {
        ; Delete all brushes
        for name, brush in this.Brushes {
            if brush
                DllCall("DeleteObject", "Ptr", brush)
        }
        this.Brushes.Clear()

        ; Shutdown GDI+
        if this.GdipToken
            DllCall("gdiplus\GdiplusShutdown", "Ptr", this.GdipToken)
        this.GdipToken := 0
    }

    /**
     * Gets a cached GDI brush handle for the specified color.
     * Creates the brush on demand if not cached.
     * @param {String} name - Color name from Colors map
     * @returns {Ptr} GDI brush handle or 0 if not found
     */
    static GetBrush(name) {
        this.Initialize()

        if !this.Brushes.Has(name) {
            if this.Colors.Has(name) {
                this.Brushes[name] := DllCall("gdi32\CreateSolidBrush",
                    "UInt", this.RGBtoBGR(this.Colors[name]), "Ptr")
            } else {
                return 0
            }
        }
        return this.Brushes[name]
    }

    /**
     * Gets a color value, optionally creating a temporary brush
     * @param {String} name - Color name from Colors map
     * @returns {Integer} Color in RGB format (0xRRGGBB)
     */
    static GetColor(name) => this.Colors.Has(name) ? this.Colors[name] : 0

    /**
     * Updates a theme color and recreates its brush.
     * @param {String} name - Color name to update
     * @param {Integer} value - New RGB color value (0xRRGGBB)
     */
    static SetColor(name, value) {
        this.Initialize()

        ; Delete existing brush
        if this.Brushes.Has(name) && this.Brushes[name]
            DllCall("DeleteObject", "Ptr", this.Brushes[name])

        ; Update color and create new brush
        this.Colors[name] := value
        this.Brushes[name] := DllCall("gdi32\CreateSolidBrush",
            "UInt", this.RGBtoBGR(value), "Ptr")
    }

    /**
     * Converts RGB to BGR format for Win32 GDI functions.
     * @param {Integer} RGB - Color in 0xRRGGBB format
     * @returns {Integer} Color in 0xBBGGRR format
     */
    static RGBtoBGR(RGB) => ((RGB & 0xFF) << 16) | (RGB & 0xFF00) | ((RGB >> 16) & 0xFF)

    /** Alias for RGBtoBGR - same operation works both ways */
    static BGRtoRGB(BGR) => this.RGBtoBGR(BGR)

    /**
     * Removes all border styles from a control.
     * @param {Ptr} hwnd - Control window handle
     */
    static RemoveBorder(hwnd) {
        static GWL_STYLE := -16
        static GWL_EXSTYLE := -20
        static WS_BORDER := 0x800000
        static WS_EX_CLIENTEDGE := 0x200
        static WS_EX_STATICEDGE := 0x20000
        static SWP_FLAGS := 0x27  ; FRAMECHANGED | NOMOVE | NOSIZE | NOZORDER

        GetWindowLong := A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"
        SetWindowLong := A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"

        ; Remove WS_BORDER from style
        style := DllCall(GetWindowLong, "Ptr", hwnd, "Int", GWL_STYLE, "Ptr")
        DllCall(SetWindowLong, "Ptr", hwnd, "Int", GWL_STYLE, "Ptr", style & ~WS_BORDER)

        ; Remove extended border styles
        exStyle := DllCall(GetWindowLong, "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr")
        DllCall(SetWindowLong, "Ptr", hwnd, "Int", GWL_EXSTYLE,
            "Ptr", exStyle & ~(WS_EX_CLIENTEDGE | WS_EX_STATICEDGE))

        ; Force redraw with new frame
        DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0,
            "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", SWP_FLAGS)
    }

    /**
     * Creates a temporary solid brush (caller must delete)
     * @param {Integer} color - RGB color value
     * @returns {Ptr} Brush handle (MUST be deleted by caller)
     */
    static CreateTempBrush(color) {
        return DllCall("gdi32\CreateSolidBrush", "UInt", this.RGBtoBGR(color), "Ptr")
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; Subclass - Window Procedure Subclassing Utility
; ═══════════════════════════════════════════════════════════════════════════════

/**
 * Utility class for window subclassing. Provides common pattern for installing
 * and uninstalling window procedure callbacks with proper cleanup.
 */
class Subclass {
    static SetWindowLong := A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"

    /**
     * Installs a window procedure callback on a control.
     * @param {Ptr} hwnd - Window handle to subclass
     * @param {Func} procMethod - Bound method to use as window procedure
     * @param {Map} callbacks - Map to store callback handles
     * @param {Map} oldProcs - Map to store original window procedures
     * @returns {Boolean} true if installed, false if already subclassed
     */
    static Install(hwnd, procMethod, callbacks, oldProcs) {
        if oldProcs.Has(hwnd)
            return false

        try {
            callback := CallbackCreate(procMethod, , 4)
            callbacks[hwnd] := callback
            oldProcs[hwnd] := DllCall(this.SetWindowLong, "Ptr", hwnd, "Int", -4, "Ptr", callback, "Ptr")
            return true
        } catch as err {
            return false
        }
    }

    /**
     * Removes subclass and restores original window procedure.
     * @param {Ptr} hwnd - Window handle to unsubclass
     * @param {Map} callbacks - Map containing callback handles
     * @param {Map} oldProcs - Map containing original window procedures
     */
    static Uninstall(hwnd, callbacks, oldProcs) {
        if !oldProcs.Has(hwnd)
            return

        try {
            DllCall(this.SetWindowLong, "Ptr", hwnd, "Int", -4, "Ptr", oldProcs[hwnd], "Ptr")
            CallbackFree(callbacks[hwnd])
        }

        callbacks.Delete(hwnd)
        oldProcs.Delete(hwnd)
    }

    /**
     * Calls the original window procedure.
     * @param {Ptr} oldProc - Original window procedure
     * @param {Ptr} hwnd - Window handle
     * @param {Integer} msg - Message
     * @param {Ptr} wParam - wParam
     * @param {Ptr} lParam - lParam
     * @returns {Ptr} Result from CallWindowProc
     */
    static CallOriginal(oldProc, hwnd, msg, wParam, lParam) {
        return DllCall("CallWindowProc", "Ptr", oldProc, "Ptr", hwnd,
            "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; DarkTitleBar - Windows 10/11 Dark Title Bar Support
; ═══════════════════════════════════════════════════════════════════════════════

/**
 * Applies dark mode to window title bar using DWM attributes.
 * Requires Windows 10 version 1809 (build 17763) or later.
 */
class DarkTitleBar {
    /**
     * Enables dark title bar for a window.
     * @param {Ptr} hwnd - Window handle
     * @returns {Boolean} true if applied, false if OS too old
     */
    static Apply(hwnd) {
        ; Check Windows version (requires 10.0.17763+)
        if VerCompare(A_OSVersion, "10.0.17763") < 0
            return false

        ; Use DWMWA_USE_IMMERSIVE_DARK_MODE (20 for 10.0.18985+, 19 for older)
        attr := VerCompare(A_OSVersion, "10.0.18985") >= 0 ? 20 : 19

        try {
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd,
                "Int", attr, "Int*", true, "Int", 4)
            return true
        } catch {
            return false
        }
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; DarkMenu - Application Menu Dark Mode
; ═══════════════════════════════════════════════════════════════════════════════

/**
 * Enables dark mode for application menus using undocumented uxtheme APIs.
 * These APIs are stable since Windows 10 1809.
 */
class DarkMenu {
    static _applied := false

    /**
     * Applies dark theme to all menus in the application.
     * Only needs to be called once per process.
     */
    static Apply() {
        if this._applied
            return

        try {
            uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
            if !uxtheme
                return

            ; Ordinal 135: SetPreferredAppMode (2 = Dark)
            SetPreferredAppMode := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
            ; Ordinal 136: FlushMenuThemes
            FlushMenuThemes := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")

            if SetPreferredAppMode && FlushMenuThemes {
                DllCall(SetPreferredAppMode, "Int", 2)  ; 2 = ForceDark
                DllCall(FlushMenuThemes)
                this._applied := true
            }
        }
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; Prototype Extensions - Simple Controls
; ═══════════════════════════════════════════════════════════════════════════════

/** Apply dark mode to Edit control */
_SetEditDarkMode(this) {
    DllCall("uxtheme\SetWindowTheme", "Ptr", this.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
    this.SetFont("c" Format("{:X}", DarkTheme.GetColor("Font")))
    DarkTheme.RemoveBorder(this.Hwnd)
}
Gui.Edit.Prototype.DefineProp("SetDarkMode", { Call: _SetEditDarkMode })

/** Apply dark mode to CheckBox control */
_SetCheckBoxDarkMode(this) {
    DllCall("uxtheme\SetWindowTheme", "Ptr", this.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
}
Gui.CheckBox.Prototype.DefineProp("SetDarkMode", { Call: _SetCheckBoxDarkMode })

/** Apply dark mode to Radio control */
_SetRadioDarkMode(this) {
    DllCall("uxtheme\SetWindowTheme", "Ptr", this.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
}
Gui.Radio.Prototype.DefineProp("SetDarkMode", { Call: _SetRadioDarkMode })

/** Apply dark mode to TreeView control with persistent selection color */
_SetTreeViewDarkMode(this) {
    static TVM_SETBKCOLOR := 0x111D
    static TVM_SETTEXTCOLOR := 0x111E
    static TVM_SETLINECOLOR := 0x1128
    static NM_CUSTOMDRAW := -12
    static WM_NOTIFY := 0x4E

    ; Add SHOWSELALWAYS style to always show selection even when unfocused
    static TVS_SHOWSELALWAYS := 0x20
    static GWL_STYLE := -16
    currentStyle := DllCall("GetWindowLong", "Ptr", this.Hwnd, "Int", GWL_STYLE, "Int")
    DllCall("SetWindowLong", "Ptr", this.Hwnd, "Int", GWL_STYLE, "Int", currentStyle | TVS_SHOWSELALWAYS)

    DllCall("uxtheme\SetWindowTheme", "Ptr", this.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
    SendMessage(TVM_SETBKCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.GetColor("Controls")), this)
    SendMessage(TVM_SETTEXTCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.GetColor("Font")), this)
    SendMessage(TVM_SETLINECOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.GetColor("Border")), this)
    DarkTheme.RemoveBorder(this.Hwnd)

    ; Custom draw for persistent selection color
    tv := this
    this.OnMessage(WM_NOTIFY, (ctrl, wParam, lParam, Msg) {
        static CDDS_PREPAINT := 0x1
        static CDDS_ITEMPREPAINT := 0x10001
        static CDRF_NOTIFYITEMDRAW := 0x20
        static CDRF_NEWFONT := 0x2
        static CDRF_DODEFAULT := 0x0
        static TVIS_SELECTED := 0x2
        static TVM_GETITEMSTATE := 0x1127

        if (StructFromPtr(NMHDR, lParam).Code != NM_CUSTOMDRAW)
            return

        nmcd := StructFromPtr(NMCUSTOMDRAW, lParam)
        if (nmcd.hdr.hWndFrom != tv.Hwnd)
            return CDRF_DODEFAULT

        switch nmcd.dwDrawStage {
            case CDDS_PREPAINT:
                return CDRF_NOTIFYITEMDRAW
            case CDDS_ITEMPREPAINT:
                ; Check actual selection state
                itemState := SendMessage(TVM_GETITEMSTATE, nmcd.dwItemSpec, TVIS_SELECTED, tv)
                isSelected := itemState & TVIS_SELECTED

                if isSelected {
                    DllCall("SetTextColor", "Ptr", nmcd.hdc,
                        "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Font")))
                    DllCall("SetBkColor", "Ptr", nmcd.hdc,
                        "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Selection")))
                } else {
                    DllCall("SetTextColor", "Ptr", nmcd.hdc,
                        "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Font")))
                    DllCall("SetBkColor", "Ptr", nmcd.hdc,
                        "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Controls")))
                }
                return CDRF_NEWFONT
        }
        return CDRF_DODEFAULT
    })
}
Gui.TreeView.Prototype.DefineProp("SetDarkMode", { Call: _SetTreeViewDarkMode })

; ═══════════════════════════════════════════════════════════════════════════════
; DarkButton - Owner-Draw Button with Hover Effects
; ═══════════════════════════════════════════════════════════════════════════════

/**
 * Owner-draw dark button with hover/pressed states and rounded corners.
 * Uses window subclassing for complete control rendering.
 */
class DarkButton extends Gui.Button {
    static __New() {
        super.Prototype.SetDarkMode := ObjBindMethod(this, "ApplyDarkMode")
    }

    static Instances := Map()
    static Callbacks := Map()
    static OldProcs := Map()
    static ButtonTexts := Map()
    static HoverStates := Map()
    static PressedStates := Map()

    /**
     * Applies owner-draw dark mode to button.
     * @param {Gui.Button} btn - Button control instance
     */
    static ApplyDarkMode(btn) {
        hwnd := btn.Hwnd
        this.ButtonTexts[hwnd] := btn.Text
        this.HoverStates[hwnd] := false
        this.PressedStates[hwnd] := false
        this.Instances[hwnd] := btn

        callback := CallbackCreate(ObjBindMethod(this, "ButtonProc", hwnd), , 4)
        this.Callbacks[hwnd] := callback
        this.OldProcs[hwnd] := DllCall(Subclass.SetWindowLong, "Ptr", hwnd, "Int", -4, "Ptr", callback, "Ptr")

        DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1)
    }

    static ButtonProc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_PAINT := 0x000F
        static WM_ERASEBKGND := 0x0014
        static WM_MOUSEMOVE := 0x0200
        static WM_MOUSELEAVE := 0x02A3
        static WM_LBUTTONDOWN := 0x0201
        static WM_LBUTTONUP := 0x0202

        if msg = WM_ERASEBKGND
            return 1

        if msg = WM_PAINT {
            this.PaintButton(targetHwnd, false)
            return 0
        }

        if msg = WM_MOUSEMOVE {
            if !this.HoverStates[targetHwnd] {
                this.HoverStates[targetHwnd] := true
                tme := Buffer(24, 0)
                NumPut("UInt", 24, tme, 0)
                NumPut("UInt", 2, tme, 4)  ; TME_LEAVE
                NumPut("Ptr", targetHwnd, tme, 8)
                DllCall("TrackMouseEvent", "Ptr", tme)
                DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1)
            }
            return 0
        }

        if msg = WM_MOUSELEAVE {
            this.HoverStates[targetHwnd] := false
            DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1)
            return 0
        }

        if msg = WM_LBUTTONDOWN {
            this.PressedStates[targetHwnd] := true
            DllCall("SetCapture", "Ptr", targetHwnd)
            DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1)
            return 0
        }

        if msg = WM_LBUTTONUP {
            wasPressed := this.PressedStates[targetHwnd]
            this.PressedStates[targetHwnd] := false
            DllCall("ReleaseCapture")
            DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1)

            if wasPressed {
                ; Check if mouse still over button
                rc := Buffer(16)
                DllCall("GetClientRect", "Ptr", targetHwnd, "Ptr", rc)
                pt := Buffer(8)
                DllCall("GetCursorPos", "Ptr", pt)
                DllCall("ScreenToClient", "Ptr", targetHwnd, "Ptr", pt)
                x := NumGet(pt, 0, "Int"), y := NumGet(pt, 4, "Int")
                w := NumGet(rc, 8, "Int"), h := NumGet(rc, 12, "Int")

                if (x >= 0 && x < w && y >= 0 && y < h) {
                    parent := DllCall("GetParent", "Ptr", targetHwnd, "Ptr")
                    ctrlId := DllCall("GetDlgCtrlID", "Ptr", targetHwnd, "Int")
                    DllCall("SendMessage", "Ptr", parent, "UInt", 0x0111,
                        "Ptr", ctrlId, "Ptr", targetHwnd)  ; WM_COMMAND with BN_CLICKED
                }
            }
            return 0
        }

        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }

    static PaintButton(hwnd, isAccent := false) {
        ps := Buffer(72, 0)
        hdc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", ps, "Ptr")

        rc := Buffer(16)
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
        w := NumGet(rc, 8, "Int")
        h := NumGet(rc, 12, "Int")

        isHover := this.HoverStates[hwnd]
        isPressed := this.PressedStates[hwnd]

        ; Determine colors based on state and accent mode
        if isAccent {
            if isPressed
                bgColor := DarkTheme.GetColor("AccentPressed")
            else if isHover
                bgColor := DarkTheme.GetColor("AccentHover")
            else
                bgColor := DarkTheme.GetColor("Accent")
            fontColor := 0xFFFFFF
        } else {
            if isPressed
                bgColor := DarkTheme.GetColor("ControlsActive")
            else if isHover
                bgColor := DarkTheme.GetColor("ControlsHover")
            else
                bgColor := DarkTheme.GetColor("Controls")
            fontColor := DarkTheme.GetColor("Font")
        }

        ; Fill background with parent color first (for rounded corners)
        parentBrush := DarkTheme.CreateTempBrush(DarkTheme.GetColor("Background"))
        DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", parentBrush)
        DllCall("DeleteObject", "Ptr", parentBrush)

        ; Draw rounded rectangle background
        brush := DarkTheme.CreateTempBrush(bgColor)
        pen := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", DarkTheme.RGBtoBGR(bgColor), "Ptr")
        oldBrush := DllCall("SelectObject", "Ptr", hdc, "Ptr", brush, "Ptr")
        oldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", pen, "Ptr")

        DllCall("RoundRect", "Ptr", hdc, "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", 8, "Int", 8)

        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldBrush)
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldPen)
        DllCall("DeleteObject", "Ptr", brush)
        DllCall("DeleteObject", "Ptr", pen)

        ; Draw text
        text := this.ButtonTexts[hwnd]
        DllCall("SetBkMode", "Ptr", hdc, "Int", 1)  ; TRANSPARENT
        DllCall("SetTextColor", "Ptr", hdc, "UInt", DarkTheme.RGBtoBGR(fontColor))

        hFont := DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
        oldFont := hFont ? DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr") : 0

        DllCall("DrawText", "Ptr", hdc, "Str", text, "Int", -1, "Ptr", rc,
            "UInt", 0x25)  ; DT_CENTER | DT_VCENTER | DT_SINGLELINE

        if oldFont
            DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont)

        DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps)
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; DarkAccentButton - Blue Accent Button
; ═══════════════════════════════════════════════════════════════════════════════

/**
 * Accent-colored (blue) owner-draw button for primary actions.
 */
class DarkAccentButton {
    static Instances := Map()
    static Callbacks := Map()
    static OldProcs := Map()
    static ButtonTexts := Map()
    static HoverStates := Map()
    static PressedStates := Map()

    static ApplyAccent(btn) {
        hwnd := btn.Hwnd
        this.ButtonTexts[hwnd] := btn.Text
        this.HoverStates[hwnd] := false
        this.PressedStates[hwnd] := false
        this.Instances[hwnd] := btn

        callback := CallbackCreate(ObjBindMethod(this, "ButtonProc", hwnd), , 4)
        this.Callbacks[hwnd] := callback
        this.OldProcs[hwnd] := DllCall(Subclass.SetWindowLong, "Ptr", hwnd, "Int", -4, "Ptr", callback, "Ptr")

        DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1)
    }

    static ButtonProc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_PAINT := 0x000F
        static WM_ERASEBKGND := 0x0014
        static WM_MOUSEMOVE := 0x0200
        static WM_MOUSELEAVE := 0x02A3
        static WM_LBUTTONDOWN := 0x0201
        static WM_LBUTTONUP := 0x0202

        if msg = WM_ERASEBKGND
            return 1

        if msg = WM_PAINT {
            this.PaintButton(targetHwnd)
            return 0
        }

        if msg = WM_MOUSEMOVE {
            if !this.HoverStates[targetHwnd] {
                this.HoverStates[targetHwnd] := true
                tme := Buffer(24, 0)
                NumPut("UInt", 24, tme, 0)
                NumPut("UInt", 2, tme, 4)
                NumPut("Ptr", targetHwnd, tme, 8)
                DllCall("TrackMouseEvent", "Ptr", tme)
                DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1)
            }
            return 0
        }

        if msg = WM_MOUSELEAVE {
            this.HoverStates[targetHwnd] := false
            DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1)
            return 0
        }

        if msg = WM_LBUTTONDOWN {
            this.PressedStates[targetHwnd] := true
            DllCall("SetCapture", "Ptr", targetHwnd)
            DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1)
            return 0
        }

        if msg = WM_LBUTTONUP {
            wasPressed := this.PressedStates[targetHwnd]
            this.PressedStates[targetHwnd] := false
            DllCall("ReleaseCapture")
            DllCall("InvalidateRect", "Ptr", targetHwnd, "Ptr", 0, "Int", 1)

            if wasPressed {
                rc := Buffer(16)
                DllCall("GetClientRect", "Ptr", targetHwnd, "Ptr", rc)
                pt := Buffer(8)
                DllCall("GetCursorPos", "Ptr", pt)
                DllCall("ScreenToClient", "Ptr", targetHwnd, "Ptr", pt)
                x := NumGet(pt, 0, "Int"), y := NumGet(pt, 4, "Int")
                w := NumGet(rc, 8, "Int"), h := NumGet(rc, 12, "Int")

                if (x >= 0 && x < w && y >= 0 && y < h) {
                    parent := DllCall("GetParent", "Ptr", targetHwnd, "Ptr")
                    ctrlId := DllCall("GetDlgCtrlID", "Ptr", targetHwnd, "Int")
                    DllCall("SendMessage", "Ptr", parent, "UInt", 0x0111,
                        "Ptr", ctrlId, "Ptr", targetHwnd)
                }
            }
            return 0
        }

        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }

    static PaintButton(hwnd) {
        ps := Buffer(72, 0)
        hdc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", ps, "Ptr")

        rc := Buffer(16)
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
        w := NumGet(rc, 8, "Int")
        h := NumGet(rc, 12, "Int")

        isHover := this.HoverStates[hwnd]
        isPressed := this.PressedStates[hwnd]

        if isPressed
            bgColor := DarkTheme.GetColor("AccentPressed")
        else if isHover
            bgColor := DarkTheme.GetColor("AccentHover")
        else
            bgColor := DarkTheme.GetColor("Accent")

        ; Fill with parent color for rounded corners
        parentBrush := DarkTheme.CreateTempBrush(DarkTheme.GetColor("Background"))
        DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", parentBrush)
        DllCall("DeleteObject", "Ptr", parentBrush)

        ; Draw rounded rectangle
        brush := DarkTheme.CreateTempBrush(bgColor)
        pen := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", DarkTheme.RGBtoBGR(bgColor), "Ptr")
        oldBrush := DllCall("SelectObject", "Ptr", hdc, "Ptr", brush, "Ptr")
        oldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", pen, "Ptr")

        DllCall("RoundRect", "Ptr", hdc, "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", 8, "Int", 8)

        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldBrush)
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldPen)
        DllCall("DeleteObject", "Ptr", brush)
        DllCall("DeleteObject", "Ptr", pen)

        ; Draw white text
        text := this.ButtonTexts[hwnd]
        DllCall("SetBkMode", "Ptr", hdc, "Int", 1)
        DllCall("SetTextColor", "Ptr", hdc, "UInt", 0xFFFFFF)

        hFont := DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
        oldFont := hFont ? DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr") : 0

        DllCall("DrawText", "Ptr", hdc, "Str", text, "Int", -1, "Ptr", rc, "UInt", 0x25)

        if oldFont
            DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont)

        DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps)
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; DarkListView - Custom-Drawn ListView with Dark Header
; ═══════════════════════════════════════════════════════════════════════════════

/**
 * Dark-themed ListView with custom-drawn header and items.
 * Features arrow-less scrollbar and persistent selection colors.
 */
class DarkListView extends Gui.ListView {
    static HeaderHandles := Map()

    static __New() {
        static LVM_GETHEADER := 0x101F
        super.Prototype.GetHeader := SendMessage.Bind(LVM_GETHEADER, 0, 0)
        super.Prototype.SetDarkMode := ObjBindMethod(this, "ApplyDarkMode")
    }

    static ApplyDarkMode(lv) {
        static LVS_EX_DOUBLEBUFFER := 0x10000
        static LVM_SETBKCOLOR := 0x1001
        static LVM_SETTEXTBKCOLOR := 0x1026
        static LVM_SETTEXTCOLOR := 0x1024
        static LVM_SETOUTLINECOLOR := 0x1047
        static NM_CUSTOMDRAW := -12
        static WM_NOTIFY := 0x4E
        static WM_THEMECHANGED := 0x031A

        lv.Header := lv.GetHeader()

        ; Add SHOWSELALWAYS style to always show selection even when unfocused
        static LVS_SHOWSELALWAYS := 0x8
        static GWL_STYLE := -16
        currentStyle := DllCall("GetWindowLong", "Ptr", lv.Hwnd, "Int", GWL_STYLE, "Int")
        DllCall("SetWindowLong", "Ptr", lv.Hwnd, "Int", GWL_STYLE, "Int", currentStyle | LVS_SHOWSELALWAYS)

        ; Set colors
        SendMessage(LVM_SETBKCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.GetColor("Controls")), lv)
        SendMessage(LVM_SETTEXTBKCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.GetColor("Controls")), lv)
        SendMessage(LVM_SETTEXTCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.GetColor("Font")), lv)
        SendMessage(LVM_SETOUTLINECOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.GetColor("GridLine")), lv)

        ; Block theme changes
        lv.OnMessage(WM_THEMECHANGED, (*) => 0)

        ; Custom draw handler for header and items
        lv.OnMessage(WM_NOTIFY, (lv, wParam, lParam, Msg) {
            static CDDS_PREPAINT := 0x1
            static CDDS_ITEMPREPAINT := 0x10001
            static CDRF_NOTIFYITEMDRAW := 0x20
            static CDRF_SKIPDEFAULT := 0x4
            static CDRF_NEWFONT := 0x2
            static CDRF_DODEFAULT := 0x0
            static HDM_GETITEMRECT := 0x1207
            static HDM_GETITEM := 0x120B
            static HDI_TEXT := 0x2
            static CDIS_SELECTED := 0x1

            if (StructFromPtr(NMHDR, lParam).Code != NM_CUSTOMDRAW)
                return

            nmcd := StructFromPtr(NMCUSTOMDRAW, lParam)

            ; Header custom draw
            if (nmcd.hdr.hWndFrom = lv.Header) {
                switch nmcd.dwDrawStage {
                    case CDDS_PREPAINT:
                        return CDRF_NOTIFYITEMDRAW
                    case CDDS_ITEMPREPAINT:
                        hdc := nmcd.hdc
                        itemIndex := nmcd.dwItemSpec

                        rc := Buffer(16, 0)
                        SendMessage(HDM_GETITEMRECT, itemIndex, rc.Ptr, lv.Header)

                        hBrush := DarkTheme.CreateTempBrush(DarkTheme.GetColor("Background"))
                        DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", hBrush)
                        DllCall("DeleteObject", "Ptr", hBrush)

                        textBuf := Buffer(256, 0)
                        hdItem := Buffer(A_PtrSize = 8 ? 72 : 48, 0)
                        NumPut("UInt", HDI_TEXT, hdItem, 0)
                        NumPut("Ptr", textBuf.Ptr, hdItem, 8)
                        NumPut("Int", 128, hdItem, A_PtrSize = 8 ? 24 : 16)
                        SendMessage(HDM_GETITEM, itemIndex, hdItem.Ptr, lv.Header)

                        DllCall("SetTextColor", "Ptr", hdc, "UInt", 0xFFFFFF)
                        DllCall("SetBkMode", "Ptr", hdc, "Int", 1)

                        left := NumGet(rc, 0, "Int") + 8
                        top := NumGet(rc, 4, "Int")
                        right := NumGet(rc, 8, "Int") - 4
                        bottom := NumGet(rc, 12, "Int")
                        rcText := Buffer(16, 0)
                        NumPut("Int", left, "Int", top, "Int", right, "Int", bottom, rcText)

                        DllCall("DrawTextW", "Ptr", hdc, "Ptr", textBuf.Ptr, "Int", -1,
                            "Ptr", rcText, "UInt", 0x24)  ; DT_VCENTER | DT_SINGLELINE

                        return CDRF_SKIPDEFAULT
                }
                return CDRF_DODEFAULT
            }

            ; ListView item custom draw
            if (nmcd.hdr.hWndFrom = lv.Hwnd) {
                switch nmcd.dwDrawStage {
                    case CDDS_PREPAINT:
                        return CDRF_NOTIFYITEMDRAW
                    case CDDS_ITEMPREPAINT:
                        ; Check actual selection state (not CDIS_SELECTED which changes on focus loss)
                        static LVM_GETITEMSTATE := 0x102C
                        static LVIS_SELECTED := 0x2
                        itemState := SendMessage(LVM_GETITEMSTATE, nmcd.dwItemSpec, LVIS_SELECTED, lv)
                        isSelected := itemState & LVIS_SELECTED

                        if isSelected {
                            DllCall("SetTextColor", "Ptr", nmcd.hdc,
                                "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Font")))
                            DllCall("SetBkColor", "Ptr", nmcd.hdc,
                                "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Selection")))
                        } else {
                            DllCall("SetTextColor", "Ptr", nmcd.hdc,
                                "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Font")))
                            DllCall("SetBkColor", "Ptr", nmcd.hdc,
                                "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Controls")))
                        }
                        return CDRF_NEWFONT
                }
                return CDRF_DODEFAULT
            }

            return CDRF_DODEFAULT
        })

        lv.Opt("+LV" LVS_EX_DOUBLEBUFFER)

        ; Hide focus rect
        static UIS_SET := 1
        static UISF_HIDEFOCUS := 0x1
        static WM_CHANGEUISTATE := 0x0127
        SendMessage(WM_CHANGEUISTATE, (UIS_SET << 8) | UISF_HIDEFOCUS, 0, lv)

        ; Apply themes
        DllCall("uxtheme\SetWindowTheme", "Ptr", lv.Header, "Str", "DarkMode_ItemsView", "Ptr", 0)
        DllCall("uxtheme\SetWindowTheme", "Ptr", lv.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        DarkTheme.RemoveBorder(lv.Hwnd)

        this.HeaderHandles[lv.Hwnd] := lv.Header
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; DarkComboBox - Owner-Draw ComboBox
; ═══════════════════════════════════════════════════════════════════════════════

/**
 * Owner-draw ComboBox with custom-drawn main control and styled dropdown.
 */
class DarkComboBox extends Gui.ComboBox {
    static __New() {
        super.Prototype.SetDarkMode := ObjBindMethod(this, "ApplyDarkMode")
    }

    static Callbacks := Map()
    static OldProcs := Map()
    static ComboDropdowns := Map()

    static ApplyDarkMode(combo) {
        DllCall("uxtheme\SetWindowTheme", "Ptr", combo.Hwnd, "Str", "DarkMode_CFD", "Ptr", 0)
        combo.SetFont("c" Format("{:X}", DarkTheme.GetColor("Font")))
        DarkTheme.RemoveBorder(combo.Hwnd)

        ; Style dropdown list
        static CB_GETCOMBOBOXINFO := 0x0164
        cbi := Buffer(A_PtrSize = 8 ? 64 : 52, 0)
        NumPut("UInt", cbi.Size, cbi, 0)

        if DllCall("SendMessage", "Ptr", combo.Hwnd, "UInt", CB_GETCOMBOBOXINFO, "Ptr", 0, "Ptr", cbi) {
            listHwnd := NumGet(cbi, A_PtrSize = 8 ? 56 : 44, "Ptr")
            if listHwnd {
                DllCall("uxtheme\SetWindowTheme", "Ptr", listHwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                this.ComboDropdowns[listHwnd] := true
            }
        }

        this.SubclassCombo(combo.Hwnd)
    }

    static SubclassCombo(hwnd) {
        if this.OldProcs.Has(hwnd)
            return

        callback := CallbackCreate(ObjBindMethod(this, "ComboProc", hwnd), , 4)
        this.Callbacks[hwnd] := callback
        this.OldProcs[hwnd] := DllCall(Subclass.SetWindowLong, "Ptr", hwnd, "Int", -4, "Ptr", callback, "Ptr")
    }

    static ComboProc(targetHwnd, hwnd, msg, wParam, lParam) {
        if hwnd != targetHwnd
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)

        if msg = 0x000F {  ; WM_PAINT
            this.DrawComboBox(hwnd)
            return 0
        }

        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }

    static DrawComboBox(hwnd) {
        ps := Buffer(72, 0)
        hdc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", ps, "Ptr")
        if !hdc
            return

        rc := Buffer(16)
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
        w := NumGet(rc, 8, "Int")
        h := NumGet(rc, 12, "Int")

        bgColor := DarkTheme.RGBtoBGR(DarkTheme.GetColor("Background"))
        ctrlColor := DarkTheme.RGBtoBGR(DarkTheme.GetColor("Controls"))
        fontColor := DarkTheme.RGBtoBGR(DarkTheme.GetColor("Font"))

        bgBrush := DllCall("CreateSolidBrush", "UInt", bgColor, "Ptr")
        ctrlBrush := DllCall("CreateSolidBrush", "UInt", ctrlColor, "Ptr")

        ; Fill with parent color
        fillRect := Buffer(16)
        NumPut("Int", 0, "Int", 0, "Int", w, "Int", h, fillRect)
        DllCall("FillRect", "Ptr", hdc, "Ptr", fillRect, "Ptr", bgBrush)

        ; Draw rounded control background
        hOldBrush := DllCall("SelectObject", "Ptr", hdc, "Ptr", ctrlBrush, "Ptr")
        nullPen := DllCall("GetStockObject", "Int", 8, "Ptr")
        hOldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", nullPen, "Ptr")
        DllCall("RoundRect", "Ptr", hdc, "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", 6, "Int", 6)

        ; Draw dropdown arrow
        arrowPen := DllCall("CreatePen", "Int", 0, "Int", 2, "UInt", fontColor, "Ptr")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", arrowPen, "Ptr")

        arrowCenterX := w - 12
        arrowCenterY := h // 2

        DllCall("MoveToEx", "Ptr", hdc, "Int", arrowCenterX - 4, "Int", arrowCenterY - 3, "Ptr", 0)
        DllCall("LineTo", "Ptr", hdc, "Int", arrowCenterX, "Int", arrowCenterY + 1)
        DllCall("MoveToEx", "Ptr", hdc, "Int", arrowCenterX, "Int", arrowCenterY + 1, "Ptr", 0)
        DllCall("LineTo", "Ptr", hdc, "Int", arrowCenterX + 4, "Int", arrowCenterY - 3)

        ; Draw text
        textLen := DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x000E, "Ptr", 0, "Ptr", 0, "Int")
        if textLen > 0 {
            textBuf := Buffer((textLen + 1) * 2, 0)
            DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x000D, "Ptr", textLen + 1, "Ptr", textBuf)

            DllCall("SetTextColor", "Ptr", hdc, "UInt", fontColor)
            DllCall("SetBkMode", "Ptr", hdc, "Int", 1)

            hFont := DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
            hOldFont := hFont ? DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr") : 0

            rcText := Buffer(16)
            NumPut("Int", 6, "Int", 0, "Int", w - 24, "Int", h, rcText)
            DllCall("DrawTextW", "Ptr", hdc, "Ptr", textBuf, "Int", -1, "Ptr", rcText, "UInt", 0x824)

            if hOldFont
                DllCall("SelectObject", "Ptr", hdc, "Ptr", hOldFont, "Ptr")
        }

        DllCall("SelectObject", "Ptr", hdc, "Ptr", hOldPen)
        DllCall("SelectObject", "Ptr", hdc, "Ptr", hOldBrush)
        DllCall("DeleteObject", "Ptr", bgBrush)
        DllCall("DeleteObject", "Ptr", ctrlBrush)
        DllCall("DeleteObject", "Ptr", arrowPen)
        DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps)
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; DarkSlider - Custom Slider with GDI+ Anti-Aliased Thumb
; ═══════════════════════════════════════════════════════════════════════════════

/**
 * Custom-drawn Slider with GDI+ anti-aliased thumb.
 * Features circular knob with blue accent border.
 */
class DarkSlider extends Gui.Slider {
    static Callbacks := Map()
    static OldProcs := Map()

    static __New() {
        super.Prototype.SetDarkMode := ObjBindMethod(this, "ApplyDarkMode")
    }

    static ApplyDarkMode(slider) {
        DllCall("uxtheme\SetWindowTheme", "Ptr", slider.Hwnd, "WStr", "", "WStr", "")
        this.SubclassSlider(slider.Hwnd)
        DllCall("InvalidateRect", "Ptr", slider.Hwnd, "Ptr", 0, "Int", true)
    }

    static SubclassSlider(hwnd) {
        if this.OldProcs.Has(hwnd)
            return

        callback := CallbackCreate(ObjBindMethod(this, "SliderProc", hwnd), , 4)
        this.Callbacks[hwnd] := callback
        this.OldProcs[hwnd] := DllCall(Subclass.SetWindowLong, "Ptr", hwnd, "Int", -4, "Ptr", callback, "Ptr")
    }

    static SliderProc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_PAINT := 0x000F
        static WM_ERASEBKGND := 0x0014
        static WM_LBUTTONDOWN := 0x0201
        static WM_MOUSEMOVE := 0x0200
        static WM_LBUTTONUP := 0x0202
        static TBM_GETCHANNELRECT := 0x41A
        static TBM_GETTHUMBRECT := 0x0419

        if hwnd != targetHwnd
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)

        if msg = WM_LBUTTONDOWN || msg = WM_MOUSEMOVE || msg = WM_LBUTTONUP {
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", true)
            return result
        }

        if msg = WM_ERASEBKGND {
            rc := Buffer(16)
            DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
            hBrush := DarkTheme.CreateTempBrush(DarkTheme.GetColor("Background"))
            DllCall("FillRect", "Ptr", wParam, "Ptr", rc, "Ptr", hBrush)
            DllCall("DeleteObject", "Ptr", hBrush)
            return 1
        }

        if msg = WM_PAINT {
            ps := Buffer(72, 0)
            hdc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", ps, "Ptr")

            rcClient := Buffer(16)
            DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rcClient)
            clientW := NumGet(rcClient, 8, "Int")
            clientH := NumGet(rcClient, 12, "Int")

            ; Double buffering
            hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
            hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", clientW, "Int", clientH, "Ptr")
            hOldBitmap := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap, "Ptr")

            ; Background
            hBrush := DarkTheme.CreateTempBrush(DarkTheme.GetColor("Background"))
            DllCall("FillRect", "Ptr", hdcMem, "Ptr", rcClient, "Ptr", hBrush)
            DllCall("DeleteObject", "Ptr", hBrush)

            ; Track
            rcChannel := Buffer(16, 0)
            SendMessage(TBM_GETCHANNELRECT, 0, rcChannel.Ptr, hwnd)
            hBrush := DarkTheme.CreateTempBrush(DarkTheme.GetColor("Controls"))
            DllCall("FillRect", "Ptr", hdcMem, "Ptr", rcChannel, "Ptr", hBrush)
            DllCall("DeleteObject", "Ptr", hBrush)

            ; Get thumb position
            rcThumb := Buffer(16, 0)
            SendMessage(TBM_GETTHUMBRECT, 0, rcThumb.Ptr, hwnd)
            thumbLeft := NumGet(rcThumb, 0, "Int")
            thumbTop := NumGet(rcThumb, 4, "Int")
            thumbRight := NumGet(rcThumb, 8, "Int")
            thumbBottom := NumGet(rcThumb, 12, "Int")

            thumbW := thumbRight - thumbLeft
            thumbH := thumbBottom - thumbTop
            diameter := Min(thumbW, thumbH) + 6

            centerX := thumbLeft + (thumbW // 2)
            centerY := thumbTop + (thumbH // 2) - 2
            circleLeft := centerX - (diameter // 2)
            circleTop := centerY - (diameter // 2)

            ; Draw anti-aliased thumb with GDI+
            if DarkTheme.GdipToken {
                pGraphics := 0
                DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdcMem, "Ptr*", &pGraphics)
                DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", 4)

                pBrush := 0
                DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFFFFFFFF, "Ptr*", &pBrush)

                pPen := 0
                DllCall("gdiplus\GdipCreatePen1", "UInt", 0xFF0078D7, "Float", 4.0, "Int", 2, "Ptr*", &pPen)

                halfPen := 2.0
                DllCall("gdiplus\GdipFillEllipse", "Ptr", pGraphics, "Ptr", pBrush,
                    "Float", circleLeft + halfPen, "Float", circleTop + halfPen,
                    "Float", diameter - 4, "Float", diameter - 4)
                DllCall("gdiplus\GdipDrawEllipse", "Ptr", pGraphics, "Ptr", pPen,
                    "Float", circleLeft + halfPen, "Float", circleTop + halfPen,
                    "Float", diameter - 4, "Float", diameter - 4)

                DllCall("gdiplus\GdipDeletePen", "Ptr", pPen)
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", pBrush)
                DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)
            }

            ; Blit to screen
            DllCall("BitBlt", "Ptr", hdc, "Int", 0, "Int", 0, "Int", clientW, "Int", clientH,
                "Ptr", hdcMem, "Int", 0, "Int", 0, "UInt", 0x00CC0020)

            DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOldBitmap, "Ptr")
            DllCall("DeleteObject", "Ptr", hBitmap)
            DllCall("DeleteDC", "Ptr", hdcMem)

            DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps)
            return 0
        }

        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; DarkProgress - Dark Progress Bar
; ═══════════════════════════════════════════════════════════════════════════════

class DarkProgress extends Gui.Progress {
    static __New() {
        super.Prototype.SetDarkMode := ObjBindMethod(this, "ApplyDarkMode")
    }

    static ApplyDarkMode(prog) {
        static PBM_SETBKCOLOR := 0x2001
        DllCall("uxtheme\SetWindowTheme", "Ptr", prog.Hwnd, "Str", "", "Ptr", 0)
        SendMessage(PBM_SETBKCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.GetColor("Controls")), prog)
        prog.Opt("c" Format("{:X}", DarkTheme.GetColor("Accent")))
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; DarkListBox - Dark ListBox
; ═══════════════════════════════════════════════════════════════════════════════

class DarkListBox extends Gui.ListBox {
    static __New() {
        super.Prototype.SetDarkMode := ObjBindMethod(this, "ApplyDarkMode")
    }

    static ApplyDarkMode(lb) {
        DllCall("uxtheme\SetWindowTheme", "Ptr", lb.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        lb.SetFont("c" Format("{:X}", DarkTheme.GetColor("Font")))
        DarkTheme.RemoveBorder(lb.Hwnd)
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; DarkWindowProc - WM_CTLCOLOR* Message Handler
; ═══════════════════════════════════════════════════════════════════════════════

/**
 * Window procedure subclass for handling WM_CTLCOLOR* messages.
 * Provides dark background brushes for Edit, ListBox, Button, and Static controls.
 */
class DarkWindowProc {
    static Callbacks := Map()
    static OldProcs := Map()
    static RadioTextControls := Map()
    static ComboDropdowns := Map()

    static Install(hwnd) {
        Subclass.Install(hwnd, ObjBindMethod(this, "Proc", hwnd), this.Callbacks, this.OldProcs)
    }

    static Uninstall(hwnd) {
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
    }

    static Proc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_CTLCOLOREDIT := 0x0133
        static WM_CTLCOLORLISTBOX := 0x0134
        static WM_CTLCOLORBTN := 0x0135
        static WM_CTLCOLORSTATIC := 0x0138

        if hwnd != targetHwnd
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)

        switch msg {
            case WM_CTLCOLOREDIT:
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Font")))
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Controls")))
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
                return DarkTheme.GetBrush("Controls")

            case WM_CTLCOLORLISTBOX:
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Font")))
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", 1)

                if DarkComboBox.ComboDropdowns.Has(lParam) {
                    DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Background")))
                    return DarkTheme.GetBrush("Background")
                } else {
                    DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Controls")))
                    return DarkTheme.GetBrush("Controls")
                }

            case WM_CTLCOLORBTN:
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Font")))
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Background")))
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
                return DarkTheme.GetBrush("Background")

            case WM_CTLCOLORSTATIC:
                if this.RadioTextControls.Has(lParam) {
                    DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", 0xFFFFFF)
                } else {
                    DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Font")))
                }
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.GetColor("Background")))
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", 1)
                return DarkTheme.GetBrush("Background")
        }

        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; DarkGui - Main Dark-Themed GUI Class
; ═══════════════════════════════════════════════════════════════════════════════

/**
 * Dark-themed Gui class. All controls added via Add() are automatically styled.
 * Use "+Accent" option for accent-colored buttons.
 *
 * @example
 *   myGui := DarkGui("+Resize", "My App")
 *   myGui.Add("Text", , "Hello World")
 *   myGui.Add("Button", "+Accent", "OK")
 *   myGui.Show()
 */
class DarkGui extends Gui {
    /**
     * Creates a new dark-themed GUI window.
     * @param {String} options - Gui options
     * @param {String} title - Window title
     */
    __New(options := "", title := A_ScriptName) {
        super.__New(options, title)

        ; Initialize theme resources
        DarkTheme.Initialize()

        ; Apply dark theme
        this.BackColor := DarkTheme.GetColor("Background")
        this.SetFont("s9", "Segoe UI")

        ; Apply title bar and menu theming
        DarkTitleBar.Apply(this.Hwnd)
        DarkMenu.Apply()

        ; Install WM_CTLCOLOR handler
        DarkWindowProc.Install(this.Hwnd)

        ; Cleanup on close
        this.OnEvent("Close", (*) => (DarkWindowProc.Uninstall(this.Hwnd), 0))
    }

    /**
     * Adds a control with automatic dark mode styling.
     * @param {String} controlType - Control type (Button, Edit, ListView, etc.)
     * @param {String} options - Control options. Use "+Accent" for accent buttons.
     * @param {Any} content - Control content (text, items array, etc.)
     * @returns {Gui.Control} The created control
     */
    Add(controlType, options := "", content?) {
        isAccent := InStr(options, "+Accent")
        if isAccent
            options := StrReplace(options, "+Accent", "")

        switch controlType, false {
            case "Text":
                if !RegExMatch(options, "i)\bc[0-9A-Fa-f]+\b")
                    options .= " c" Format("{:X}", DarkTheme.GetColor("Font"))
                return super.Add(controlType, options, content?)

            case "ListView":
                if !RegExMatch(options, "i)\bc[0-9A-Fa-f]+\b|\bcWhite\b|\bcBlack\b")
                    options .= " cWhite"
                ctrl := super.Add(controlType, options, content?)
                ctrl.SetDarkMode()
                return ctrl

            case "Radio":
                return this._AddRadio(options, content?)

            case "Button":
                ctrl := super.Add(controlType, options, content?)
                if isAccent
                    DarkAccentButton.ApplyAccent(ctrl)
                else
                    ctrl.SetDarkMode()
                return ctrl

            case "CheckBox":
                ctrl := super.Add(controlType, options, content?)
                DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                ctrl.SetFont("c" Format("{:X}", DarkTheme.GetColor("Font")))
                return ctrl

            case "Edit", "ComboBox", "Slider", "Progress", "ListBox", "TreeView":
                ctrl := super.Add(controlType, options, content?)
                ctrl.SetDarkMode()
                return ctrl

            default:
                return super.Add(controlType, options, content?)
        }
    }

    /** Internal: Adds Radio with separate text control for proper dark styling */
    _AddRadio(options, text?) {
        static SM_CXMENUCHECK := 71
        static radioW := DllCall("GetSystemMetrics", "Int", SM_CXMENUCHECK)

        radio := super.Add("Radio", options " +0x4000000", "")

        if !InStr(options, "right")
            txt := super.Add("Text", "xp+" (radioW + 8) " yp+2 HP-4 +0x4000200 cFFFFFF", text?)
        else
            txt := super.Add("Text", "xp+8 yp+2 HP-4 +0x4000200 cFFFFFF", text?)

        DarkWindowProc.RadioTextControls[txt.Hwnd] := true

        DllCall("SetWindowPos", "Ptr", txt.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0,
            "UInt", 0x53)  ; SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE | 0x40

        DllCall("uxtheme\SetWindowTheme", "Ptr", radio.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)

        radio.TextCtrl := txt
        radio.DefineProp("Text", {
            Get: (this) => this.TextCtrl.Text,
            Set: (this, value) => this.TextCtrl.Text := value
        })

        return radio
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; Demo - Showcase All Controls
; ═══════════════════════════════════════════════════════════════════════════════

; Only run demo if this is the main script
if A_ScriptName = "DarkMode.ahk" || A_ScriptName = "DarkMode"
    DarkModeDemo()

class DarkModeDemo {
    controls := Map()

    __New() {
        this.gui := DarkGui("+Resize", "DarkMode.ahk - Unified Dark Mode Framework")
        this.BuildLayout()
        this.BindEvents()
        this.gui.Show("w620 h520")
    }

    BuildLayout() {
        ; Text Input Section
        this.gui.Add("Text", "x20 y15 w200", "Text Input")
        this.controls["edit1"] := this.gui.Add("Edit", "x20 y40 w200 h25", "Single-line edit")
        this.controls["edit2"] := this.gui.Add("Edit", "x20 y75 w200 h68 +Multi", "Multi-line`nedit control`nLine 3")

        ; Selection Section
        this.gui.Add("Text", "x240 y15 w180", "Selection")
        this.controls["chk1"] := this.gui.Add("CheckBox", "x240 y40 w160 +Checked", "Feature enabled")
        this.controls["chk2"] := this.gui.Add("CheckBox", "x240 y65 w160", "Auto-save")
        this.controls["rad1"] := this.gui.Add("Radio", "x240 y95 w160 +Checked", "Option A")
        this.controls["rad2"] := this.gui.Add("Radio", "x240 y120 w160", "Option B")

        ; Actions Section
        this.gui.Add("Text", "x420 y15 w180", "Actions")
        this.controls["btn1"] := this.gui.Add("Button", "x420 y40 w80 h28", "Apply")
        this.controls["btn2"] := this.gui.Add("Button", "+Accent x510 y40 w80 h28", "OK")
        this.controls["btn3"] := this.gui.Add("Button", "x420 y75 w170 h28", "Reset All")

        ; Dropdowns & Progress Section
        this.gui.Add("Text", "x20 y200 w200", "Dropdowns & Progress")
        this.controls["combo"] := this.gui.Add("ComboBox", "x20 y225 w200", ["Option 1", "Option 2", "Option 3"])
        this.controls["slider"] := this.gui.Add("Slider", "x20 y265 w200 Range0-100", 50)
        this.controls["sliderLabel"] := this.gui.Add("Text", "x20 y295 w200", "Value: 50")
        this.controls["progress"] := this.gui.Add("Progress", "x20 y320 w200 h20", 50)

        ; ListView Section
        this.gui.Add("Text", "x240 y200 w350", "ListView")
        this.controls["lv"] := this.gui.Add("ListView", "x240 y225 w350 h115", ["Name", "Type", "Size"])
        this.controls["lv"].Add("", "Document.pdf", "PDF", "1.2 MB")
        this.controls["lv"].Add("", "Script.ahk", "AHK", "5 KB")
        this.controls["lv"].Add("", "Image.png", "PNG", "234 KB")
        this.controls["lv"].Add("", "Archive.zip", "ZIP", "12 MB")
        this.controls["lv"].Add("", "Video.mp4", "MP4", "156 MB")
        this.controls["lv"].Add("", "Music.mp3", "MP3", "8.4 MB")
        this.controls["lv"].Add("", "Database.db", "DB", "45 MB")
        this.controls["lv"].ModifyCol(1, 150)
        this.controls["lv"].ModifyCol(2, 90)
        this.controls["lv"].ModifyCol(3, 85)

        ; ListBox Section
        this.gui.Add("Text", "x20 y355 w200", "ListBox")
        this.controls["listbox"] := this.gui.Add("ListBox", "x20 y380 w200 h90",
            ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"])

        ; TreeView Section
        this.gui.Add("Text", "x240 y355 w350", "TreeView")
        this.controls["tv"] := this.gui.Add("TreeView", "x240 y380 w350 h83")
        p1 := this.controls["tv"].Add("Documents")
        this.controls["tv"].Add("Report.pdf", p1)
        this.controls["tv"].Add("Notes.txt", p1)
        p2 := this.controls["tv"].Add("Images")
        this.controls["tv"].Add("Photo.jpg", p2)

        ; Status
        this.controls["status"] := this.gui.Add("Text", "x20 y480 w580", "Status: Ready")
    }

    BindEvents() {
        this.controls["btn1"].OnEvent("Click", (*) => this.OnApply())
        this.controls["btn2"].OnEvent("Click", (*) => this.gui.Hide())
        this.controls["btn3"].OnEvent("Click", (*) => this.OnReset())
        this.controls["slider"].OnEvent("Change", (*) => this.OnSliderChange())
        this.gui.OnEvent("Close", (*) => ExitApp())
    }

    OnApply() {
        this.controls["status"].Text := "Status: Applied at " FormatTime(, "HH:mm:ss")
    }

    OnReset() {
        this.controls["edit1"].Value := "Single-line edit"
        this.controls["edit2"].Value := "Multi-line`nedit control`nLine 3"
        this.controls["chk1"].Value := 1
        this.controls["chk2"].Value := 0
        this.controls["rad1"].Value := 1
        this.controls["slider"].Value := 50
        this.controls["progress"].Value := 50
        this.controls["sliderLabel"].Text := "Value: 50"
        this.controls["status"].Text := "Status: Reset complete"
    }

    OnSliderChange() {
        val := this.controls["slider"].Value
        this.controls["progress"].Value := val
        this.controls["sliderLabel"].Text := "Value: " val
    }
}
