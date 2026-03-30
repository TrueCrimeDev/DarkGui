/*
DarkModeModular.ahk — Dark mode GUI framework for AutoHotkey v2

Usage:
  #Include DarkModeModular.ahk
  myGui := DarkGui("+Resize", "My App")
  myGui.Add("Button", "+Accent", "OK")
  myGui.Add("Edit", "w300", "text")
  myGui.Show()

Public API: DarkGui, DarkTheme, DarkTitleBar, DarkMenu, DarkMenuBar, DarkScrollbar
All controls added via DarkGui.Add() are automatically dark-styled.
Use "+Accent" on buttons for blue accent color.
*/
#Requires AutoHotkey v2.1-alpha.23

/** Win32 RECT structure for control dimensions */
Struct RECT {
    left: i32, top: i32, right: i32, bottom: i32
}

/** Win32 NMHDR notification header structure */
Struct NMHDR {
    hwndFrom: uptr
    idFrom  : uptr
    code    : i32
}

/** Win32 NMCUSTOMDRAW structure for custom drawing notifications */
Struct NMCUSTOMDRAW {
    hdr        : NMHDR
    dwDrawStage: u32
    hdc        : uptr
    rc         : RECT
    dwItemSpec : uptr
    uItemState : u32
    lItemlParam: iptr
}

/**
 * Central theme manager for dark mode colors and GDI brushes.
 * Provides color constants, brush caching, and utility functions.
 */
class DarkTheme {
    /** @type {Map} Color palette: Background, Controls, ControlsHover, ControlsActive, Font, FontDim, Accent, Border, Selection, GridLine, Header */
    static Colors := Map(
        "Background", 0x1A1A1A,
        "Controls", 0x252525,
        "ControlsHover", 0x333333,
        "ControlsActive", 0x404040,
        "Font", 0xE8E8E8,
        "FontDim", 0xA0A0A0,
        "Accent", 0x0078D7,
        "Border", 0x404040,
        "Selection", 0x264F78,
        "GridLine", 0x2A2A2A,
        "Header", 0x2D2D2D,
        "ScrollTrack", 0x3C3C3C,
        "ScrollThumb", 0x5A5A5A,
        "ScrollThumbHover", 0x787878
    )

    /** @type {Map} Cached GDI brush handles keyed by color name */
    static Brushes := Map()
    /** @type {Integer} Active DarkGui instance count */
    static _refCount := 0
    /** @type {Boolean} Whether OnExit safety net is registered */
    static _exitRegistered := false

    static __New() {
        for name, color in this.Colors
            this.Brushes[name] := DllCall("gdi32\CreateSolidBrush", "UInt", this.RGBtoBGR(color), "Ptr")
        if !this._exitRegistered {
            OnExit((*) => (DarkTheme.Cleanup(), _DarkSlider.Shutdown()))
            this._exitRegistered := true
        }
    }

    /**
     * Increments reference count. Called by {@link DarkGui#__New}.
     */
    static AddRef() => ++this._refCount

    /**
     * Decrements reference count. Cleans up brushes and GDI+ when
     * the last {@link DarkGui} instance is destroyed.
     */
    static Release() {
        if --this._refCount <= 0 {
            this._refCount := 0
            this.Cleanup()
            _DarkSlider.Shutdown()
        }
    }

    /**
     * Gets a cached GDI brush handle for the specified color.
     * @param {String} name - Color name from Colors map
     * @returns {Ptr} GDI brush handle or 0 if not found
     */
    static GetBrush(name) => this.Brushes.Has(name) ? this.Brushes[name] : 0

    /**
     * Updates a theme color and recreates its brush.
     * @param {String} name - Color name to update
     * @param {Integer} value - New RGB color value (0xRRGGBB)
     */
    static SetColor(name, value) {
        if this.Brushes.Has(name)
            DllCall("DeleteObject", "Ptr", this.Brushes[name])
        this.Colors[name] := value
        this.Brushes[name] := DllCall("gdi32\CreateSolidBrush", "UInt", this.RGBtoBGR(value), "Ptr")
    }

    /**
     * Scales a pixel value by the system DPI factor.
     * @param {Integer} px - Pixel value at 96 DPI
     * @returns {Integer} Scaled pixel value for current DPI
     */
    static Scale(px) => Round(px * (A_ScreenDPI / 96))

    /**
     * Converts RGB to BGR format for Win32 GDI functions.
     * @param {Integer} RGB - Color in 0xRRGGBB format
     * @returns {Integer} Color in 0xBBGGRR format
     */
    static RGBtoBGR(RGB) => ((RGB & 0xFF) << 16) | (RGB & 0xFF00) | ((RGB >> 16) & 0xFF)
    /**
     * Converts BGR to RGB format. Same operation as {@link DarkTheme.RGBtoBGR}.
     *
     * @param {Integer} BGR - Color in `0xBBGGRR` format.
     * @returns {Integer} Color in `0xRRGGBB` format.
     */
    static BGRtoRGB(BGR) => this.RGBtoBGR(BGR)

    /**
     * Removes all border styles from a control (WS_BORDER, WS_EX_CLIENTEDGE, WS_EX_STATICEDGE).
     * @param {Ptr} hwnd - Control window handle
     */
    static RemoveBorder(hwnd) {
        static GWL_STYLE := -16
        static GWL_EXSTYLE := -20
        static WS_BORDER := 0x800000
        static WS_EX_CLIENTEDGE := 0x200
        static WS_EX_STATICEDGE := 0x20000
        static SWP_FRAMECHANGED := 0x20
        static SWP_NOMOVE := 0x2
        static SWP_NOSIZE := 0x1
        static SWP_NOZORDER := 0x4

        GetWindowLong := A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"
        SetWindowLong := A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"

        ; Remove WS_BORDER from style
        style := DllCall(GetWindowLong, "Ptr", hwnd, "Int", GWL_STYLE, "Ptr")
        DllCall(SetWindowLong, "Ptr", hwnd, "Int", GWL_STYLE, "Ptr", style & ~WS_BORDER)

        ; Remove WS_EX_CLIENTEDGE and WS_EX_STATICEDGE from extended style
        exStyle := DllCall(GetWindowLong, "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr")
        DllCall(SetWindowLong, "Ptr", hwnd, "Int", GWL_EXSTYLE, "Ptr", exStyle & ~(WS_EX_CLIENTEDGE | WS_EX_STATICEDGE))

        ; Force redraw with new frame
        DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0,
            "UInt", SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER)
    }

    /**
     * Frees all cached GDI brush handles.
     * Called automatically by {@link DarkTheme.Release} or on application exit.
     */
    static Cleanup() {
        for name, brush in this.Brushes
            DllCall("DeleteObject", "Ptr", brush)
        this.Brushes.Clear()
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; Prototype Extensions - Scoped inside DarkPrototypes to avoid global pollution
; ═══════════════════════════════════════════════════════════════════════════════

/**
 * Installs SetDarkMode() on Gui control prototypes using local function scope.
 * No global function names are introduced.
 */
class DarkPrototypes {
    static __New() {
        _editDark(ctrl) {
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
            ctrl.SetFont("c" Format("{:X}", DarkTheme.Colors["Font"]))
            DarkTheme.RemoveBorder(ctrl.Hwnd)
        }
        Gui.Edit.Prototype.DefineProp("SetDarkMode", { Call: _editDark })

        _checkBoxDark(ctrl) {
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        }
        Gui.CheckBox.Prototype.DefineProp("SetDarkMode", { Call: _checkBoxDark })

        _radioDark(ctrl) {
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        }
        Gui.Radio.Prototype.DefineProp("SetDarkMode", { Call: _radioDark })

        _treeViewDark(ctrl) {
            static TVM_SETBKCOLOR := 0x111D
            static TVM_SETTEXTCOLOR := 0x111E
            static TVM_SETLINECOLOR := 0x1128
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
            SendMessage(TVM_SETBKCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]), ctrl)
            SendMessage(TVM_SETTEXTCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]), ctrl)
            SendMessage(TVM_SETLINECOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["Border"]), ctrl)
            DarkTheme.RemoveBorder(ctrl.Hwnd)
        }
        Gui.TreeView.Prototype.DefineProp("SetDarkMode", { Call: _treeViewDark })
    }
}

/**
 * Applies dark mode to window title bar using DWM attributes (Win10 1809+).
 * Uses `DwmSetWindowAttribute` with the immersive dark mode flag.
 */
class DarkTitleBar {
    /**
     * Enables dark title bar for a window.
     *
     * @param {Ptr} hwnd - Window handle.
     * @returns {Boolean} `true` if applied, `false` if OS too old.
     */
    static Apply(hwnd) {
        if VerCompare(A_OSVersion, "10.0.17763") < 0
            return false
        attr := VerCompare(A_OSVersion, "10.0.18985") >= 0 ? 20 : 19
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", attr, "Int*", true, "Int", 4)
        return true
    }
}

/**
 * Enables dark mode for application menus using undocumented uxtheme APIs
 * (ordinals 135 `SetPreferredAppMode` and 136 `FlushMenuThemes`).
 */
class DarkMenu {
    /**
     * Applies dark theme to all menus in the application.
     * Call once during GUI initialization; {@link DarkGui#__New} calls this automatically.
     */
    static Apply() {
        uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
        SetPreferredAppMode := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
        FlushMenuThemes := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")
        DllCall(SetPreferredAppMode, "Int", 2)
        DllCall(FlushMenuThemes)
    }
}

/**
 * Utility class for window subclassing. Provides common pattern for installing
 * and uninstalling window procedure callbacks.
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
        callback := CallbackCreate(procMethod, , 4)
        callbacks[hwnd] := callback
        oldProcs[hwnd] := DllCall(this.SetWindowLong, "Ptr", hwnd, "Int", -4, "Ptr", callback, "Ptr")
        return true
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
        DllCall(this.SetWindowLong, "Ptr", hwnd, "Int", -4, "Ptr", oldProcs[hwnd], "Ptr")
        CallbackFree(callbacks[hwnd])
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
        return DllCall("CallWindowProc", "Ptr", oldProc, "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }
}

/**
 * Custom dark scrollbar control for ListView. Creates an owner-draw scrollbar
 * that syncs with ListView scroll position via a 100ms timer.
 *
 * Rendering uses GDI `FillRect` with rounded thumb, hover/drag states,
 * and page-up/page-down on track clicks.
 */
class DarkScrollbar {
    /** @type {Map} Active instances keyed by scrollbar hwnd */
    static Instances := Map()
    /** @type {Map} Window procedure callbacks keyed by hwnd */
    static Callbacks := Map()
    /** @type {Map} Original window procedures for restoration */
    static OldProcs := Map()
    /** @type {Integer} Scrollbar width in DPI-scaled pixels */
    static ScrollbarWidth := DarkTheme.Scale(14)

    /**
     * Creates a dark scrollbar alongside a target ListView.
     *
     * @param {DarkGui} gui - Parent GUI instance.
     * @param {Gui.ListView} targetCtrl - ListView to sync scroll position with.
     * @param {Integer} x - X position.
     * @param {Integer} y - Y position.
     * @param {Integer} h - Height.
     */
    __New(gui, targetCtrl, x, y, h) {
        this.gui := gui
        this.target := targetCtrl
        this.x := x
        this.y := y
        this.h := h
        this.w := DarkScrollbar.ScrollbarWidth

        this.trackColor := DarkTheme.Colors["Header"]
        this.thumbColor := DarkTheme.Colors["ScrollThumb"]
        this.thumbHoverColor := DarkTheme.Colors["ScrollThumbHover"]

        this.isDragging := false
        this.dragStartY := 0
        this.dragStartPos := 0
        this.isHovering := false

        ; Create the scrollbar as a Text control (we'll custom draw it)
        this.ctrl := gui.Add("Text", "x" x " y" y " w" this.w " h" h " +0x4000000")  ; WS_CLIPSIBLINGS
        this.ctrl.Opt("+Background" Format("{:X}", this.trackColor))

        ; Store instance reference
        DarkScrollbar.Instances[this.ctrl.Hwnd] := this

        ; Subclass for custom drawing and mouse handling
        this.SubclassScrollbar()

        ; Set up scroll sync timer
        this.syncTimer := ObjBindMethod(this, "SyncFromTarget")
        SetTimer(this.syncTimer, 100)
    }

    SubclassScrollbar() {
        Subclass.Install(this.ctrl.Hwnd, ObjBindMethod(this, "ScrollbarProc"), DarkScrollbar.Callbacks, DarkScrollbar.OldProcs)
    }

    ScrollbarProc(hwnd, msg, wParam, lParam) {
        static WM_PAINT := 0x000F
        static WM_ERASEBKGND := 0x0014
        static WM_LBUTTONDOWN := 0x0201
        static WM_LBUTTONUP := 0x0202
        static WM_MOUSEMOVE := 0x0200
        static WM_MOUSELEAVE := 0x02A3
        static WM_CAPTURECHANGED := 0x0215

        if msg = WM_ERASEBKGND
            return 1

        if msg = WM_PAINT {
            this.Paint()
            return 0
        }

        if msg = WM_LBUTTONDOWN {
            this.OnMouseDown(lParam)
            return 0
        }

        if msg = WM_LBUTTONUP {
            this.OnMouseUp()
            return 0
        }

        if msg = WM_MOUSEMOVE {
            this.OnMouseMove(lParam)
            return 0
        }

        if msg = WM_MOUSELEAVE {
            this.isHovering := false
            DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1)
            return 0
        }

        if msg = WM_CAPTURECHANGED {
            this.isDragging := false
            return 0
        }

        return Subclass.CallOriginal(DarkScrollbar.OldProcs[this.ctrl.Hwnd], hwnd, msg, wParam, lParam)
    }

    GetScrollInfo() {
        static LVM_GETITEMCOUNT := 0x1004
        static LVM_GETCOUNTPERPAGE := 0x1028
        static LVM_GETTOPINDEX := 0x1027

        ; Get ListView scroll info from item counts
        itemCount := SendMessage(LVM_GETITEMCOUNT, 0, 0, this.target.Hwnd)
        visibleCount := SendMessage(LVM_GETCOUNTPERPAGE, 0, 0, this.target.Hwnd)
        topIndex := SendMessage(LVM_GETTOPINDEX, 0, 0, this.target.Hwnd)

        return {
            min: 0,
            max: Max(0, itemCount - 1),
            page: visibleCount,
            pos: topIndex
        }
    }

    GetThumbRect() {
        info := this.GetScrollInfo()
        range := info.max - info.min + 1

        if range <= info.page || range <= 0
            return {top: 0, bottom: this.h, height: this.h}

        thumbHeight := Max(DarkTheme.Scale(30), (info.page * this.h) // range)
        trackSpace := this.h - thumbHeight

        scrollRange := info.max - info.min - info.page + 1
        if scrollRange <= 0
            thumbTop := 0
        else
            thumbTop := (info.pos * trackSpace) // scrollRange

        return {
            top: thumbTop,
            bottom: thumbTop + thumbHeight,
            height: thumbHeight
        }
    }

    Paint() {
        static PAINTSTRUCT_SIZE := A_PtrSize = 8 ? 72 : 64
        ps := Buffer(PAINTSTRUCT_SIZE, 0)
        hdc := DllCall("BeginPaint", "Ptr", this.ctrl.Hwnd, "Ptr", ps, "Ptr")

        ; Get client rect
        rc := Buffer(16)
        DllCall("GetClientRect", "Ptr", this.ctrl.Hwnd, "Ptr", rc)
        w := NumGet(rc, 8, "Int")
        h := NumGet(rc, 12, "Int")

        ; Draw track
        trackBrush := DllCall("CreateSolidBrush", "UInt", DarkTheme.RGBtoBGR(this.trackColor), "Ptr")
        DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", trackBrush)
        DllCall("DeleteObject", "Ptr", trackBrush)

        ; Draw thumb
        thumb := this.GetThumbRect()
        thumbColor := this.isHovering || this.isDragging ? this.thumbHoverColor : this.thumbColor

        thumbBrush := DllCall("CreateSolidBrush", "UInt", DarkTheme.RGBtoBGR(thumbColor), "Ptr")
        rcThumb := Buffer(16)
        pad := DarkTheme.Scale(2)
        NumPut("Int", pad, "Int", thumb.top + pad, "Int", w - pad, "Int", thumb.bottom - pad, rcThumb)
        DllCall("FillRect", "Ptr", hdc, "Ptr", rcThumb, "Ptr", thumbBrush)
        DllCall("DeleteObject", "Ptr", thumbBrush)

        DllCall("EndPaint", "Ptr", this.ctrl.Hwnd, "Ptr", ps)
    }

    OnMouseDown(lParam) {
        mouseY := (lParam >> 16) & 0xFFFF
        if mouseY > 0x7FFF
            mouseY -= 0x10000

        thumb := this.GetThumbRect()

        if mouseY < thumb.top {
            ; Click above thumb - page up
            this.PageUp()
        } else if mouseY > thumb.bottom {
            ; Click below thumb - page down
            this.PageDown()
        } else {
            ; Start dragging thumb
            this.isDragging := true
            this.dragStartY := mouseY
            this.dragStartPos := this.GetScrollInfo().pos
            DllCall("SetCapture", "Ptr", this.ctrl.Hwnd)
        }

        DllCall("InvalidateRect", "Ptr", this.ctrl.Hwnd, "Ptr", 0, "Int", 1)

        ; Track mouse for hover effects
        tme := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", A_PtrSize = 8 ? 24 : 16, tme, 0)
        NumPut("UInt", 2, tme, 4)  ; TME_LEAVE
        NumPut("Ptr", this.ctrl.Hwnd, tme, 8)
        DllCall("TrackMouseEvent", "Ptr", tme)
    }

    OnMouseUp() {
        if this.isDragging {
            this.isDragging := false
            DllCall("ReleaseCapture")
            DllCall("InvalidateRect", "Ptr", this.ctrl.Hwnd, "Ptr", 0, "Int", 1)
        }
    }

    OnMouseMove(lParam) {
        mouseY := (lParam >> 16) & 0xFFFF
        if mouseY > 0x7FFF
            mouseY -= 0x10000

        ; Track mouse for hover effects
        if !this.isHovering {
            this.isHovering := true
            tme := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
            NumPut("UInt", A_PtrSize = 8 ? 24 : 16, tme, 0)
            NumPut("UInt", 2, tme, 4)  ; TME_LEAVE
            NumPut("Ptr", this.ctrl.Hwnd, tme, 8)
            DllCall("TrackMouseEvent", "Ptr", tme)
            DllCall("InvalidateRect", "Ptr", this.ctrl.Hwnd, "Ptr", 0, "Int", 1)
        }

        if this.isDragging {
            info := this.GetScrollInfo()
            deltaY := mouseY - this.dragStartY

            thumb := this.GetThumbRect()
            trackSpace := this.h - thumb.height

            if trackSpace <= 0
                return

            scrollRange := info.max - info.min - info.page + 1
            if scrollRange <= 0
                return

            deltaPosFloat := (deltaY * scrollRange) / trackSpace
            newPos := this.dragStartPos + Round(deltaPosFloat)
            newPos := Max(info.min, Min(newPos, info.max - info.page + 1))

            this.SetScrollPos(newPos)
        }
    }

    PageUp() {
        info := this.GetScrollInfo()
        newPos := Max(info.min, info.pos - info.page)
        this.SetScrollPos(newPos)
    }

    PageDown() {
        info := this.GetScrollInfo()
        newPos := Min(info.max - info.page + 1, info.pos + info.page)
        this.SetScrollPos(newPos)
    }

    SetScrollPos(pos) {
        static LVM_ENSUREVISIBLE := 0x1013
        static LVM_GETITEMCOUNT := 0x1004

        ; Clamp position to valid range
        itemCount := SendMessage(LVM_GETITEMCOUNT, 0, 0, this.target.Hwnd)
        pos := Max(0, Min(pos, itemCount - 1))

        ; Scroll to make the item at position visible at the top
        SendMessage(LVM_ENSUREVISIBLE, pos, 0, this.target.Hwnd)

        DllCall("InvalidateRect", "Ptr", this.ctrl.Hwnd, "Ptr", 0, "Int", 1)
    }

    SyncFromTarget() {
        ; Update our display to match target's scroll position
        if !this.isDragging
            DllCall("InvalidateRect", "Ptr", this.ctrl.Hwnd, "Ptr", 0, "Int", 1)
    }

    /**
     * Moves and resizes the scrollbar control.
     *
     * @param {Integer} x - New X position.
     * @param {Integer} y - New Y position.
     * @param {Integer} h - New height.
     */
    UpdatePosition(x, y, h) {
        this.x := x
        this.y := y
        this.h := h
        this.ctrl.Move(x, y, this.w, h)
    }

    /**
     * Stops the sync timer and frees the subclass callback.
     */
    Destroy() {
        if this.syncTimer
            SetTimer(this.syncTimer, 0)
        Subclass.Uninstall(this.ctrl.Hwnd, DarkScrollbar.Callbacks, DarkScrollbar.OldProcs)
        DarkScrollbar.Instances.Delete(this.ctrl.Hwnd)
    }
}

/**
 * Dark-themed ListView with custom-drawn header, items, and arrow-less scrollbar.
 * Uses NM_CUSTOMDRAW for item/header colors and hides scrollbar arrows.
 */
class _DarkListView extends Gui.ListView {
    /** @type {Map} Window procedure callbacks keyed by hwnd */
    static Callbacks := Map()
    /** @type {Map} Original window procedures for restoration */
    static OldProcs := Map()
    /** @type {Map} Header control handles for scroll alignment */
    static HeaderHandles := Map()
    /** @type {Map} Active hover timer states */
    static HoverTimers := Map()
    /** @type {Map} Bound timer functions for hover effects */
    static HoverTimerFuncs := Map()

    static __New() {
        static LVM_GETHEADER := 0x101F
        super.Prototype.GetHeader := SendMessage.Bind(LVM_GETHEADER, 0, 0)
        super.Prototype.SetDarkMode := this.SetDarkMode.Bind(this)
    }

    static SubclassListView(hwnd) {
        Subclass.Install(hwnd, ObjBindMethod(this, "ListViewProc", hwnd), this.Callbacks, this.OldProcs)
    }

    static StopHoverTimer(hwnd) {
        if this.HoverTimers.Has(hwnd) {
            SetTimer(this.HoverTimerFuncs[hwnd], 0)
            this.HoverTimerFuncs.Delete(hwnd)
            this.HoverTimers.Delete(hwnd)
        }
    }

    /**
     * Removes subclass and frees resources for a ListView.
     * @param {Ptr} hwnd - ListView window handle
     */
    static Remove(hwnd) {
        this.StopHoverTimer(hwnd)
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
        this.HeaderHandles.Delete(hwnd)
    }

    static CreateArrowHideTimerFunc(hwnd, headerHwnd) {
        ; Create a bound function for arrow hiding timer
        return () => (_DarkListView.HideScrollbarArrows(hwnd, headerHwnd), 0)
    }

    /**
     * Temporarily sets a window region that excludes scrollbar arrow areas.
     * Used to prevent Windows from painting arrows during drag operations.
     * Call ClearArrowClipRegion() after the default proc returns.
     * @param {Ptr} hwnd - Window handle
     * @returns {Boolean} True if region was set, false if scrollbar not visible
     */
    static SetArrowClipRegion(hwnd) {
        static OBJID_VSCROLL := -5
        sbi := Buffer(60, 0)
        NumPut("UInt", 60, sbi, 0)
        if !DllCall("GetScrollBarInfo", "Ptr", hwnd, "Int", OBJID_VSCROLL, "Ptr", sbi)
            return false
        if NumGet(sbi, 36, "UInt") & 0x8000
            return false

        sbL := NumGet(sbi, 4, "Int"), sbT := NumGet(sbi, 8, "Int")
        sbR := NumGet(sbi, 12, "Int"), sbB := NumGet(sbi, 16, "Int")
        arrowH := DllCall("GetSystemMetrics", "Int", 20)

        rcWin := Buffer(16)
        DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rcWin)
        winL := NumGet(rcWin, 0, "Int"), winT := NumGet(rcWin, 4, "Int")
        w := NumGet(rcWin, 8, "Int") - winL, h := NumGet(rcWin, 12, "Int") - winT

        ; Window-relative arrow coords
        aL := sbL - winL, aR := sbR - winL
        aTopT := sbT - winT, aTopB := sbT + arrowH - winT
        aBotT := sbB - arrowH - winT, aBotB := sbB - winT

        ; Full window region minus arrow rects
        fullRgn := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr")
        topRgn := DllCall("CreateRectRgn", "Int", aL, "Int", aTopT, "Int", aR, "Int", aTopB, "Ptr")
        DllCall("CombineRgn", "Ptr", fullRgn, "Ptr", fullRgn, "Ptr", topRgn, "Int", 4)  ; RGN_DIFF
        DllCall("DeleteObject", "Ptr", topRgn)
        botRgn := DllCall("CreateRectRgn", "Int", aL, "Int", aBotT, "Int", aR, "Int", aBotB, "Ptr")
        DllCall("CombineRgn", "Ptr", fullRgn, "Ptr", fullRgn, "Ptr", botRgn, "Int", 4)  ; RGN_DIFF
        DllCall("DeleteObject", "Ptr", botRgn)

        ; System takes ownership of fullRgn - don't delete it
        DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", fullRgn, "Int", 0)
        return true
    }

    /**
     * Removes the arrow clip region, restoring full window painting.
     *
     * @param {Ptr} hwnd - Window handle.
     */
    static ClearArrowClipRegion(hwnd) {
        DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", 0, "Int", 0)
    }

    /**
     * Creates a WM_NCPAINT region with scrollbar arrow areas excluded.
     * Prevents Windows from painting arrows by clipping them from the paint region.
     * @param {Ptr} hwnd - Window handle
     * @param {Ptr|Integer} wParam - WM_NCPAINT wParam (1=full repaint, or HRGN)
     * @returns {Ptr} New HRGN with arrows excluded, or 0 if scrollbar hidden. Caller must DeleteObject if non-zero.
     */
    static ClipArrowRegion(hwnd, wParam) {
        static OBJID_VSCROLL := -5
        sbi := Buffer(60, 0)
        NumPut("UInt", 60, sbi, 0)
        if !DllCall("GetScrollBarInfo", "Ptr", hwnd, "Int", OBJID_VSCROLL, "Ptr", sbi)
            return 0
        if NumGet(sbi, 36, "UInt") & 0x8000  ; STATE_SYSTEM_INVISIBLE
            return 0

        ; Scrollbar rect in screen coords
        sbL := NumGet(sbi, 4, "Int"), sbT := NumGet(sbi, 8, "Int")
        sbR := NumGet(sbi, 12, "Int"), sbB := NumGet(sbi, 16, "Int")
        arrowH := DllCall("GetSystemMetrics", "Int", 20)  ; SM_CYVSCROLL

        ; Build base region from wParam
        if wParam = 1 {
            rcWin := Buffer(16)
            DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rcWin)
            hrgn := DllCall("CreateRectRgn",
                "Int", NumGet(rcWin, 0, "Int"), "Int", NumGet(rcWin, 4, "Int"),
                "Int", NumGet(rcWin, 8, "Int"), "Int", NumGet(rcWin, 12, "Int"), "Ptr")
        } else {
            ; Copy - must not modify the original region
            hrgn := DllCall("CreateRectRgn", "Int", 0, "Int", 0, "Int", 0, "Int", 0, "Ptr")
            DllCall("CombineRgn", "Ptr", hrgn, "Ptr", wParam, "Ptr", hrgn, "Int", 5)  ; RGN_COPY
        }

        ; Subtract top arrow region (screen coords)
        topRgn := DllCall("CreateRectRgn", "Int", sbL, "Int", sbT, "Int", sbR, "Int", sbT + arrowH, "Ptr")
        DllCall("CombineRgn", "Ptr", hrgn, "Ptr", hrgn, "Ptr", topRgn, "Int", 4)  ; RGN_DIFF
        DllCall("DeleteObject", "Ptr", topRgn)

        ; Subtract bottom arrow region (screen coords)
        botRgn := DllCall("CreateRectRgn", "Int", sbL, "Int", sbB - arrowH, "Int", sbR, "Int", sbB, "Ptr")
        DllCall("CombineRgn", "Ptr", hrgn, "Ptr", hrgn, "Ptr", botRgn, "Int", 4)  ; RGN_DIFF
        DllCall("DeleteObject", "Ptr", botRgn)

        return hrgn
    }

    /**
     * Paints over scrollbar arrow areas with track color.
     * Used as fallback for non-WM_NCPAINT repaints (hover effects, scroll events).
     * @param {Ptr} hwnd - Window handle
     */
    static HideScrollbarArrows(hwnd, headerHwnd := 0) {
        static OBJID_VSCROLL := -5
        sbi := Buffer(60, 0)
        NumPut("UInt", 60, sbi, 0)
        if !DllCall("GetScrollBarInfo", "Ptr", hwnd, "Int", OBJID_VSCROLL, "Ptr", sbi)
            return
        if NumGet(sbi, 36, "UInt") & 0x8000
            return

        sbLeft := NumGet(sbi, 4, "Int"), sbTop := NumGet(sbi, 8, "Int")
        sbRight := NumGet(sbi, 12, "Int"), sbBottom := NumGet(sbi, 16, "Int")
        arrowHeight := DllCall("GetSystemMetrics", "Int", 20)

        rcWin := Buffer(16)
        DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rcWin)
        winLeft := NumGet(rcWin, 0, "Int"), winTop := NumGet(rcWin, 4, "Int")

        ; Convert to window-relative coords
        sbLeftW := sbLeft - winLeft, sbTopW := sbTop - winTop
        sbRightW := sbRight - winLeft, sbBottomW := sbBottom - winTop

        hdc := DllCall("GetWindowDC", "Ptr", hwnd, "Ptr")
        if !hdc
            return

        trackBrush := DllCall("CreateSolidBrush", "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["ScrollTrack"]), "Ptr")
        rc := Buffer(16)

        NumPut("Int", sbLeftW, "Int", sbTopW, "Int", sbRightW, "Int", sbTopW + arrowHeight, rc)
        DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", trackBrush)

        NumPut("Int", sbLeftW, "Int", sbBottomW - arrowHeight, "Int", sbRightW, "Int", sbBottomW, rc)
        DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", trackBrush)

        DllCall("DeleteObject", "Ptr", trackBrush)
        DllCall("ReleaseDC", "Ptr", hwnd, "Ptr", hdc)
    }

    static ListViewProc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_NCPAINT := 0x0085
        static WM_NCMOUSEMOVE := 0x00A0
        static WM_NCLBUTTONDOWN := 0x00A1
        static WM_NCLBUTTONUP := 0x00A2
        static WM_NCMOUSELEAVE := 0x02A2
        static WM_MOUSEWHEEL := 0x020A
        static WM_VSCROLL := 0x0115
        static WM_MOUSEMOVE := 0x0200
        static WM_LBUTTONUP := 0x0202
        static WM_CAPTURECHANGED := 0x0215
        static WM_TIMER := 0x0113
        static HTVSCROLL := 7
        static HTHSCROLL := 6

        if hwnd != targetHwnd
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)

        ; Get header handle for proper alignment
        headerHwnd := this.HeaderHandles.Has(hwnd) ? this.HeaderHandles[hwnd] : 0

        ; Handle NC paint - clip arrow regions BEFORE default paint
        if msg = WM_NCPAINT {
            clippedRgn := _DarkListView.ClipArrowRegion(hwnd, wParam)
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, clippedRgn ? clippedRgn : wParam, lParam)
            ; Fill excluded arrow areas with track color
            _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
            if clippedRgn
                DllCall("DeleteObject", "Ptr", clippedRgn)
            return result
        }

        ; Handle scrollbar mouse interactions - let default handle, then hide arrows
        if msg = WM_NCMOUSEMOVE {
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)

            ; Check if over scrollbar - start continuous redraw timer
            if wParam = HTVSCROLL || wParam = HTHSCROLL {
                ; Start high-frequency timer if not already running
                if !this.HoverTimers.Has(hwnd) {
                    timerFn := _DarkListView.CreateArrowHideTimerFunc(hwnd, headerHwnd)
                    this.HoverTimerFuncs[hwnd] := timerFn
                    this.HoverTimers[hwnd] := true
                    SetTimer(timerFn, 16)  ; ~60fps to cover scrollbar arrow repaints
                }
                _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
            } else {
                ; Mouse moved to non-scrollbar NC area - stop timer
                this.StopHoverTimer(hwnd)
            }
            return result
        }

        ; Handle scrollbar click - clip arrows via SetWindowRgn before default proc
        if msg = WM_NCLBUTTONDOWN && (wParam = HTVSCROLL || wParam = HTHSCROLL) {
            _DarkListView.SetArrowClipRegion(hwnd)
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            _DarkListView.ClearArrowClipRegion(hwnd)
            _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
            return result
        }

        if msg = WM_NCLBUTTONUP {
            _DarkListView.SetArrowClipRegion(hwnd)
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            _DarkListView.ClearArrowClipRegion(hwnd)
            _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
            return result
        }

        if msg = WM_NCMOUSELEAVE {
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            this.StopHoverTimer(hwnd)
            _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
            SetTimer(() => (_DarkListView.HideScrollbarArrows(hwnd, headerHwnd), 0), -50)
            SetTimer(() => (_DarkListView.HideScrollbarArrows(hwnd, headerHwnd), 0), -100)
            return result
        }

        ; Handle scroll events - clip during drag, paint-over otherwise
        if msg = WM_MOUSEWHEEL || msg = WM_VSCROLL {
            isDragging := DllCall("GetCapture", "Ptr") = hwnd
            if isDragging
                _DarkListView.SetArrowClipRegion(hwnd)
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            if isDragging
                _DarkListView.ClearArrowClipRegion(hwnd)
            _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
            return result
        }

        ; Handle mouse move during scrollbar drag - clip arrows via SetWindowRgn
        if msg = WM_MOUSEMOVE {
            if DllCall("GetCapture", "Ptr") = hwnd {
                _DarkListView.SetArrowClipRegion(hwnd)
                result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
                _DarkListView.ClearArrowClipRegion(hwnd)
                _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
                return result
            }
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
        }

        ; Handle timer messages (Windows uses timers for scroll repeat)
        if msg = WM_TIMER {
            isDragging := DllCall("GetCapture", "Ptr") = hwnd
            if isDragging
                _DarkListView.SetArrowClipRegion(hwnd)
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            if isDragging
                _DarkListView.ClearArrowClipRegion(hwnd)
            _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
            return result
        }

        ; Handle capture change - drag ended
        if msg = WM_CAPTURECHANGED {
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            this.StopHoverTimer(hwnd)
            _DarkListView.HideScrollbarArrows(hwnd, headerHwnd)
            return result
        }

        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }

    /**
     * Applies dark mode to a ListView control.
     * Sets body/text/grid colors, custom-draws header and items via
     * `NM_CUSTOMDRAW`, applies `DarkMode_Explorer` theme for dark scrollbars,
     * and removes the default border.
     *
     * @param {Gui.ListView} lv - ListView control instance.
     * @param {String} [style = "Explorer"] - Theme style name.
     */
    static SetDarkMode(lv, style := "Explorer") {
        static LVS_EX_DOUBLEBUFFER := 0x10000
        static LVM_SETBKCOLOR := 0x1001
        static LVM_SETTEXTBKCOLOR := 0x1026
        static LVM_SETTEXTCOLOR := 0x1024
        static NM_CUSTOMDRAW := -12
        static UIS_SET := 1
        static UISF_HIDEFOCUS := 0x1
        static WM_CHANGEUISTATE := 0x0127
        static WM_NOTIFY := 0x4E
        static WM_THEMECHANGED := 0x031A

        lv.Header := lv.GetHeader()

        ; Set ListView body colors and grid line color
        static LVM_SETOUTLINECOLOR := 0x1047
        SendMessage(LVM_SETBKCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]), lv)
        SendMessage(LVM_SETTEXTBKCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]), lv)
        SendMessage(LVM_SETTEXTCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]), lv)
        SendMessage(LVM_SETOUTLINECOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["GridLine"]), lv)

        lv.OnMessage(WM_THEMECHANGED, (*) => 0)

        ; Custom draw header and ListView items
        lv.OnMessage(WM_NOTIFY, (lv, wParam, lParam, Msg) {
            static CDDS_ITEMPREPAINT := 0x10001
            static CDDS_PREPAINT := 0x1
            static CDDS_SUBITEM := 0x20000
            static CDDS_ITEMPOSTPAINT := 0x10002
            static CDRF_DODEFAULT := 0x0
            static CDRF_NOTIFYITEMDRAW := 0x20
            static CDRF_NOTIFYSUBITEMDRAW := 0x20
            static CDRF_SKIPDEFAULT := 0x4
            static CDRF_NEWFONT := 0x2
            static HDM_GETITEMCOUNT := 0x1200
            static HDM_GETITEMRECT := 0x1207
            static HDM_GETITEM := 0x120B
            static HDI_TEXT := 0x2
            static DT_CENTER := 0x1
            static DT_VCENTER := 0x4
            static DT_SINGLELINE := 0x20
            static CDIS_SELECTED := 0x1
            static CDIS_FOCUS := 0x10

            if (NMHDR.At(lParam).Code != NM_CUSTOMDRAW)
                return

            nmcd := NMCUSTOMDRAW.At(lParam)

            ; Handle header custom draw
            if (nmcd.hdr.hWndFrom = lv.Header) {
                switch nmcd.dwDrawStage {
                    case CDDS_PREPAINT:
                        return CDRF_NOTIFYITEMDRAW
                    case CDDS_ITEMPREPAINT:
                        hdc := nmcd.hdc
                        itemIndex := nmcd.dwItemSpec

                        rc := Buffer(16, 0)
                        SendMessage(HDM_GETITEMRECT, itemIndex, rc.Ptr, lv.Header)

                        hBrush := DllCall("CreateSolidBrush", "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Background"]), "Ptr")
                        DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", hBrush)
                        DllCall("DeleteObject", "Ptr", hBrush)

                        textBuf := Buffer(256, 0)
                        hdItem := Buffer(A_PtrSize = 8 ? 72 : 48, 0)
                        NumPut("UInt", HDI_TEXT, hdItem, 0)
                        NumPut("Ptr", textBuf.Ptr, hdItem, 8)
                        NumPut("Int", 128, hdItem, A_PtrSize = 8 ? 24 : 16)
                        SendMessage(HDM_GETITEM, itemIndex, hdItem.Ptr, lv.Header)

                        DllCall("SetTextColor", "Ptr", hdc, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
                        DllCall("SetBkMode", "Ptr", hdc, "Int", 1)

                        left := NumGet(rc, 0, "Int") + DarkTheme.Scale(8)
                        top := NumGet(rc, 4, "Int")
                        right := NumGet(rc, 8, "Int") - DarkTheme.Scale(4)
                        bottom := NumGet(rc, 12, "Int")
                        rcText := Buffer(16, 0)
                        NumPut("Int", left, "Int", top, "Int", right, "Int", bottom, rcText)

                        DllCall("DrawTextW", "Ptr", hdc, "Ptr", textBuf.Ptr, "Int", -1, "Ptr", rcText, "UInt", DT_VCENTER | DT_SINGLELINE)

                        return CDRF_SKIPDEFAULT
                }
                return CDRF_DODEFAULT
            }

            ; Handle ListView item custom draw
            if (nmcd.hdr.hWndFrom = lv.Hwnd) {
                switch nmcd.dwDrawStage {
                    case CDDS_PREPAINT:
                        return CDRF_NOTIFYITEMDRAW
                    case CDDS_ITEMPREPAINT:
                        isSelected := nmcd.uItemState & CDIS_SELECTED

                        if isSelected {
                            ; Keep selection blue even when ListView loses focus
                            DllCall("SetTextColor", "Ptr", nmcd.hdc, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
                            DllCall("SetBkColor", "Ptr", nmcd.hdc, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Selection"]))
                        } else {
                            DllCall("SetTextColor", "Ptr", nmcd.hdc, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
                            DllCall("SetBkColor", "Ptr", nmcd.hdc, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]))
                        }
                        return CDRF_NEWFONT
                }
                return CDRF_DODEFAULT
            }

            return CDRF_DODEFAULT
        })

        lv.Opt("+LV" LVS_EX_DOUBLEBUFFER)
        SendMessage(WM_CHANGEUISTATE, (UIS_SET << 8) | UISF_HIDEFOCUS, 0, lv)

        ; Apply dark theme to header
        DllCall("uxtheme\SetWindowTheme", "Ptr", lv.Header, "Str", "DarkMode_ItemsView", "Ptr", 0)
        ; Use DarkMode_Explorer for modern dark scrollbars (custom draw still controls item colors)
        DllCall("uxtheme\SetWindowTheme", "Ptr", lv.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        DarkTheme.RemoveBorder(lv.Hwnd)

        ; Store header handle
        this.HeaderHandles[lv.Hwnd] := lv.Header
    }
}

/**
 * Owner-draw dark button with hover/pressed states and rounded corners.
 * Supports both standard dark buttons and accent-colored (blue) buttons.
 * Use mode `"accent"` for primary action buttons.
 *
 * Uses window subclassing for complete control rendering via {@link Subclass}.
 */
class _DarkButton extends Gui.Button {
    static __New() {
        super.Prototype.SetDarkMode := ObjBindMethod(this, "ApplyDarkMode")
    }

    /** @type {Map} Button control instances keyed by hwnd */
    static Instances := Map()
    /** @type {Map} Window procedure callbacks */
    static Callbacks := Map()
    /** @type {Map} Original window procedures for restoration */
    static OldProcs := Map()
    /** @type {Map} Cached button text strings */
    static ButtonTexts := Map()
    /** @type {Map} Mouse hover state flags */
    static HoverStates := Map()
    /** @type {Map} Button rendering mode: "default" or "accent" */
    static ButtonModes := Map()
    /** @type {Map} Mouse pressed state flags */
    static PressedStates := Map()

    /**
     * Applies owner-draw dark mode to button.
     * @param {Gui.Button} btn - Button control instance
     * @param {String} mode - "default" for dark grey, "accent" for blue highlight
     */
    static ApplyDarkMode(btn, mode := "default") {
        hwnd := btn.Hwnd
        this.ButtonTexts[hwnd] := btn.Text
        this.HoverStates[hwnd] := false
        this.PressedStates[hwnd] := false
        this.Instances[hwnd] := btn
        this.ButtonModes[hwnd] := mode

        ; Subclass for owner-draw handling
        Subclass.Install(hwnd, ObjBindMethod(this, "ButtonProc", hwnd), this.Callbacks, this.OldProcs)

        DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1)
    }

    /**
     * Removes subclass and frees resources for a button.
     * @param {Ptr} hwnd - Button window handle
     */
    static Remove(hwnd) {
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
        for prop in [this.ButtonTexts, this.HoverStates, this.PressedStates, this.Instances, this.ButtonModes]
            prop.Delete(hwnd)
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
                static TME_LEAVE := 0x2
                tme := Buffer(24, 0)
                NumPut("UInt", 24, tme, 0)
                NumPut("UInt", TME_LEAVE, tme, 4)
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
                    static BN_CLICKED := 0
                    static WM_COMMAND := 0x0111
                    DllCall("SendMessage", "Ptr", parent, "UInt", WM_COMMAND, "Ptr", (BN_CLICKED << 16) | ctrlId, "Ptr", targetHwnd)
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
        mode := this.ButtonModes.Has(hwnd) ? this.ButtonModes[hwnd] : "default"

        ; Select colors based on mode
        if mode = "accent" {
            if isPressed
                bgColor := 0x005A9E
            else if isHover
                bgColor := 0x1A8CFF
            else
                bgColor := DarkTheme.Colors["Accent"]
            textColor := 0xFFFFFF
        } else {
            if isPressed
                bgColor := DarkTheme.Colors["ControlsActive"]
            else if isHover
                bgColor := DarkTheme.Colors["ControlsHover"]
            else
                bgColor := DarkTheme.Colors["Controls"]
            textColor := DarkTheme.Colors["Font"]
        }

        ; Fill background with parent color first (for rounded corners)
        parentBrush := DllCall("CreateSolidBrush", "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Background"]), "Ptr")
        DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", parentBrush)
        DllCall("DeleteObject", "Ptr", parentBrush)

        ; Draw rounded rectangle background
        cornerRadius := DarkTheme.Scale(8)
        brush := DllCall("CreateSolidBrush", "UInt", DarkTheme.RGBtoBGR(bgColor), "Ptr")
        pen := DllCall("CreatePen", "Int", 0, "Int", 1, "UInt", DarkTheme.RGBtoBGR(bgColor), "Ptr")
        oldBrush := DllCall("SelectObject", "Ptr", hdc, "Ptr", brush, "Ptr")
        oldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", pen, "Ptr")

        DllCall("RoundRect", "Ptr", hdc, "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", cornerRadius, "Int", cornerRadius)

        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldBrush)
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oldPen)
        DllCall("DeleteObject", "Ptr", brush)
        DllCall("DeleteObject", "Ptr", pen)

        ; Draw text
        text := this.ButtonTexts[hwnd]
        DllCall("SetBkMode", "Ptr", hdc, "Int", 1)  ; TRANSPARENT
        DllCall("SetTextColor", "Ptr", hdc, "UInt", DarkTheme.RGBtoBGR(textColor))

        hFont := DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
        oldFont := 0
        if hFont
            oldFont := DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")

        static DT_CENTER := 0x1, DT_VCENTER := 0x4, DT_SINGLELINE := 0x20
        DllCall("DrawText", "Ptr", hdc, "Str", text, "Int", -1, "Ptr", rc, "UInt", DT_CENTER | DT_VCENTER | DT_SINGLELINE)

        if oldFont
            DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont)

        DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps)
    }
}

/**
 * Owner-draw ComboBox with custom-drawn main control and styled dropdown.
 * Handles WM_PAINT for stable text rendering and rounded corners.
 */
class _DarkComboBox extends Gui.ComboBox {
    static __New() {
        super.Prototype.SetDarkMode := ObjBindMethod(this, "ApplyDarkMode")
    }

    /** @type {Map} Window procedure callbacks */
    static Callbacks := Map()
    /** @type {Map} Original window procedures */
    static OldProcs := Map()

    /**
     * Applies dark theme with owner-draw rendering.
     * @param {Gui.ComboBox} combo - ComboBox control instance
     */
    static ApplyDarkMode(combo) {
        ; Use DarkMode_CFD for dropdown appearance
        DllCall("uxtheme\SetWindowTheme", "Ptr", combo.Hwnd, "Str", "DarkMode_CFD", "Ptr", 0)
        combo.SetFont("c" Format("{:X}", DarkTheme.Colors["Font"]))

        DarkTheme.RemoveBorder(combo.Hwnd)

        ; Get and style the dropdown list (ListBox part of ComboBox)
        static CB_GETCOMBOBOXINFO := 0x0164
        cbi := Buffer(A_PtrSize = 8 ? 64 : 52, 0)
        NumPut("UInt", cbi.Size, cbi, 0)
        if DllCall("SendMessage", "Ptr", combo.Hwnd, "UInt", CB_GETCOMBOBOXINFO, "Ptr", 0, "Ptr", cbi) {
            listHwnd := NumGet(cbi, A_PtrSize = 8 ? 56 : 44, "Ptr")
            if listHwnd {
                ; Apply dark theme to dropdown list for modern scrollbar
                DllCall("uxtheme\SetWindowTheme", "Ptr", listHwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                ; Register this as a ComboBox dropdown so WM_CTLCOLORLISTBOX uses Background color
                DarkWindowProc.ComboDropdowns[listHwnd] := true
            }
        }

        ; Subclass to handle WM_NCPAINT for custom border and focus indicator
        this.SubclassCombo(combo.Hwnd)
    }

    static SubclassCombo(hwnd) {
        Subclass.Install(hwnd, ObjBindMethod(this, "ComboProc", hwnd), this.Callbacks, this.OldProcs)
    }

    /**
     * Removes subclass and frees resources for a ComboBox.
     * @param {Ptr} hwnd - ComboBox window handle
     */
    static Remove(hwnd) {
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
    }

    static ComboProc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_PAINT := 0x000F

        if hwnd != targetHwnd
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)

        ; Completely take over WM_PAINT - don't call original proc to prevent text jumping
        if msg = WM_PAINT {
            this.DrawComboBox(hwnd)
            return 0
        }

        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }

    static DrawComboBox(hwnd) {
        ; Use BeginPaint/EndPaint for proper WM_PAINT handling
        ps := Buffer(72, 0)  ; PAINTSTRUCT
        hdc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", ps, "Ptr")
        if !hdc
            return

        rc := Buffer(16)
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
        w := NumGet(rc, 8, "Int")
        h := NumGet(rc, 12, "Int")

        bgColor := DarkTheme.RGBtoBGR(DarkTheme.Colors["Background"])
        ctrlColor := DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"])
        fontColor := DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"])

        bgBrush := DllCall("CreateSolidBrush", "UInt", bgColor, "Ptr")
        ctrlBrush := DllCall("CreateSolidBrush", "UInt", ctrlColor, "Ptr")

        ; Step 1: Fill entire control with parent bg color (covers all exterior artifacts)
        fillRect := Buffer(16)
        NumPut("Int", 0, "Int", 0, "Int", w, "Int", h, fillRect)
        DllCall("FillRect", "Ptr", hdc, "Ptr", fillRect, "Ptr", bgBrush)

        ; Step 2: Fill interior with control color (rounded rect, no border)
        hOldBrush := DllCall("SelectObject", "Ptr", hdc, "Ptr", ctrlBrush, "Ptr")
        nullPen := DllCall("GetStockObject", "Int", 8, "Ptr")  ; NULL_PEN
        hOldPen := DllCall("SelectObject", "Ptr", hdc, "Ptr", nullPen, "Ptr")
        comboRadius := DarkTheme.Scale(6)
        DllCall("RoundRect", "Ptr", hdc, "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", comboRadius, "Int", comboRadius)

        ; Step 3: Draw dropdown arrow
        arrowPen := DllCall("CreatePen", "Int", 0, "Int", 2, "UInt", fontColor, "Ptr")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", arrowPen, "Ptr")

        arrowCenterX := w - DarkTheme.Scale(12)
        arrowCenterY := h // 2
        arrowHalfWidth := DarkTheme.Scale(4)
        arrowHeight := DarkTheme.Scale(3)

        DllCall("MoveToEx", "Ptr", hdc, "Int", arrowCenterX - arrowHalfWidth, "Int", arrowCenterY - arrowHeight, "Ptr", 0)
        DllCall("LineTo", "Ptr", hdc, "Int", arrowCenterX, "Int", arrowCenterY + 1)
        DllCall("MoveToEx", "Ptr", hdc, "Int", arrowCenterX, "Int", arrowCenterY + 1, "Ptr", 0)
        DllCall("LineTo", "Ptr", hdc, "Int", arrowCenterX + arrowHalfWidth, "Int", arrowCenterY - arrowHeight)

        ; Step 5: Draw text
        static WM_GETTEXT := 0x000D
        static WM_GETTEXTLENGTH := 0x000E
        static WM_GETFONT := 0x0031
        textLen := DllCall("SendMessage", "Ptr", hwnd, "UInt", WM_GETTEXTLENGTH, "Ptr", 0, "Ptr", 0, "Int")
        if textLen > 0 {
            textBuf := Buffer((textLen + 1) * 2, 0)
            DllCall("SendMessage", "Ptr", hwnd, "UInt", WM_GETTEXT, "Ptr", textLen + 1, "Ptr", textBuf)

            DllCall("SetTextColor", "Ptr", hdc, "UInt", fontColor)
            DllCall("SetBkMode", "Ptr", hdc, "Int", 1)  ; TRANSPARENT

            hFont := DllCall("SendMessage", "Ptr", hwnd, "UInt", WM_GETFONT, "Ptr", 0, "Ptr", 0, "Ptr")
            hOldFont := 0
            if hFont
                hOldFont := DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr")

            rcText := Buffer(16)
            NumPut("Int", DarkTheme.Scale(6), "Int", 0, "Int", w - DarkTheme.Scale(24), "Int", h, rcText)
            static DT_SINGLELINE := 0x20, DT_VCENTER := 0x4, DT_NOPREFIX := 0x800
            DllCall("DrawTextW", "Ptr", hdc, "Ptr", textBuf, "Int", -1, "Ptr", rcText, "UInt", DT_SINGLELINE | DT_VCENTER | DT_NOPREFIX)

            if hOldFont
                DllCall("SelectObject", "Ptr", hdc, "Ptr", hOldFont, "Ptr")
        }

        ; Cleanup
        DllCall("SelectObject", "Ptr", hdc, "Ptr", hOldPen)
        DllCall("SelectObject", "Ptr", hdc, "Ptr", hOldBrush)
        DllCall("DeleteObject", "Ptr", bgBrush)
        DllCall("DeleteObject", "Ptr", ctrlBrush)
        DllCall("DeleteObject", "Ptr", arrowPen)
        DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps)
    }
}

/**
 * Custom-drawn Slider with GDI+ anti-aliased thumb. Features circular knob
 * with blue accent border, double-buffered rendering to prevent artifacts.
 */
class _DarkSlider extends Gui.Slider {
    /** @type {Map} Window procedure callbacks */
    static Callbacks := Map()
    /** @type {Map} Original window procedures */
    static OldProcs := Map()
    /** @type {Map} Per-slider state data */
    static SliderData := Map()
    /** @type {Integer} GDI+ startup token (initialized once) */
    static GdipToken := 0

    static __New() {
        super.Prototype.SetDarkMode := ObjBindMethod(this, "ApplyDarkMode")
        ; Initialize GDI+ once for anti-aliased thumb drawing
        si := Buffer(24, 0)
        NumPut("UInt", 1, si, 0)
        token := 0
        DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", si, "Ptr", 0)
        this.GdipToken := token
    }

    /**
     * Applies custom owner-draw dark mode to slider.
     * @param {Gui.Slider} slider - Slider control instance
     */
    static ApplyDarkMode(slider) {
        ; Set empty theme to disable themed drawing
        DllCall("uxtheme\SetWindowTheme", "Ptr", slider.Hwnd, "WStr", "", "WStr", "")

        ; Store slider data
        this.SliderData[slider.Hwnd] := Map("state", "normal")

        ; Subclass for custom drawing
        this.SubclassSlider(slider.Hwnd)

        DllCall("InvalidateRect", "Ptr", slider.Hwnd, "Ptr", 0, "Int", true)
    }

    static SubclassSlider(hwnd) {
        Subclass.Install(hwnd, ObjBindMethod(this, "SliderProc", hwnd), this.Callbacks, this.OldProcs)
    }

    /**
     * Removes subclass and frees resources for a Slider.
     * @param {Ptr} hwnd - Slider window handle
     */
    static Remove(hwnd) {
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
        this.SliderData.Delete(hwnd)
    }

    /**
     * Shuts down GDI+ (call on application exit).
     */
    static Shutdown() {
        if this.GdipToken
            DllCall("gdiplus\GdiplusShutdown", "Ptr", this.GdipToken)
        this.GdipToken := 0
    }

    static SliderProc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_PAINT := 0x000F
        static WM_ERASEBKGND := 0x0014
        static WM_LBUTTONDOWN := 0x0201
        static WM_MOUSEMOVE := 0x0200
        static WM_LBUTTONUP := 0x0202
        static TBM_GETCHANNELRECT := 0x41A
        static TBM_GETTHUMBRECT := 0x0419
        static TBM_GETPOS := 0x0400
        static TBM_GETRANGEMIN := 0x0401
        static TBM_GETRANGEMAX := 0x0402

        if hwnd != targetHwnd
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)

        ; Force full invalidation on mouse events that move the thumb
        if msg = WM_LBUTTONDOWN || msg = WM_MOUSEMOVE || msg = WM_LBUTTONUP {
            result := Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
            ; Invalidate entire control to repaint cleanly
            DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", true)
            return result
        }

        if msg = WM_ERASEBKGND {
            ; Fill background
            rc := Buffer(16)
            DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
            hBrush := DllCall("CreateSolidBrush", "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Background"]), "Ptr")
            DllCall("FillRect", "Ptr", wParam, "Ptr", rc, "Ptr", hBrush)
            DllCall("DeleteObject", "Ptr", hBrush)
            return 1
        }

        if msg = WM_PAINT {
            ps := Buffer(A_PtrSize = 8 ? 72 : 64, 0)
            hdc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", ps, "Ptr")

            ; Get client rect
            rcClient := Buffer(16)
            DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rcClient)
            clientW := NumGet(rcClient, 8, "Int")
            clientH := NumGet(rcClient, 12, "Int")

            ; Use double buffering to prevent artifacts
            hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
            hBitmap := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", clientW, "Int", clientH, "Ptr")
            hOldBitmap := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBitmap, "Ptr")

            ; Fill background (draw to memory DC)
            hBrush := DllCall("CreateSolidBrush", "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Background"]), "Ptr")
            DllCall("FillRect", "Ptr", hdcMem, "Ptr", rcClient, "Ptr", hBrush)
            DllCall("DeleteObject", "Ptr", hBrush)

            ; Get channel rect (use actual Windows position)
            rcChannel := Buffer(16, 0)
            SendMessage(TBM_GETCHANNELRECT, 0, rcChannel.Ptr, hwnd)

            ; Draw track/channel using actual rect from Windows
            hBrush := DllCall("CreateSolidBrush", "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]), "Ptr")
            DllCall("FillRect", "Ptr", hdcMem, "Ptr", rcChannel, "Ptr", hBrush)
            DllCall("DeleteObject", "Ptr", hBrush)

            ; Get thumb rect
            rcThumb := Buffer(16, 0)
            SendMessage(TBM_GETTHUMBRECT, 0, rcThumb.Ptr, hwnd)
            thumbLeft := NumGet(rcThumb, 0, "Int")
            thumbTop := NumGet(rcThumb, 4, "Int")
            thumbRight := NumGet(rcThumb, 8, "Int")
            thumbBottom := NumGet(rcThumb, 12, "Int")

            ; Calculate perfect circle (use smaller dimension as diameter + extra size)
            thumbW := thumbRight - thumbLeft
            thumbH := thumbBottom - thumbTop
            diameter := Min(thumbW, thumbH) + DarkTheme.Scale(6)  ; Make knob larger

            ; Center the circle and move up 2px
            centerX := thumbLeft + (thumbW // 2)
            centerY := thumbTop + (thumbH // 2) - DarkTheme.Scale(2)  ; Move up
            circleLeft := centerX - (diameter // 2)
            circleTop := centerY - (diameter // 2)
            circleRight := circleLeft + diameter
            circleBottom := circleTop + diameter

            ; Draw thumb as white circle with blue border using GDI+ for anti-aliasing
            fillColor := 0xFFFFFFFF  ; White fill (ARGB: fully opaque white)
            borderColor := 0xFF0078D7  ; Blue border (ARGB: fully opaque accent blue)
            borderWidth := DarkTheme.Scale(4) * 1.0

            ; Create Graphics from DC (GDI+ already initialized in __New)
            pGraphics := 0
            DllCall("gdiplus\GdipCreateFromHDC", "Ptr", hdcMem, "Ptr*", &pGraphics)

            ; Enable anti-aliasing (SmoothingModeAntiAlias = 4)
            DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", 4)

            ; Create solid brush for fill
            pBrush := 0
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", fillColor, "Ptr*", &pBrush)

            ; Create pen for border
            pPen := 0
            DllCall("gdiplus\GdipCreatePen1", "UInt", borderColor, "Float", borderWidth, "Int", 2, "Ptr*", &pPen)

            ; Draw filled ellipse then border (adjust for pen width)
            halfPen := borderWidth / 2
            DllCall("gdiplus\GdipFillEllipse", "Ptr", pGraphics, "Ptr", pBrush,
                "Float", circleLeft + halfPen, "Float", circleTop + halfPen,
                "Float", diameter - borderWidth, "Float", diameter - borderWidth)
            DllCall("gdiplus\GdipDrawEllipse", "Ptr", pGraphics, "Ptr", pPen,
                "Float", circleLeft + halfPen, "Float", circleTop + halfPen,
                "Float", diameter - borderWidth, "Float", diameter - borderWidth)

            ; Cleanup GDI+ objects (but not the token)
            DllCall("gdiplus\GdipDeletePen", "Ptr", pPen)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", pBrush)
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)

            ; Blit from memory DC to screen DC
            DllCall("BitBlt", "Ptr", hdc, "Int", 0, "Int", 0, "Int", clientW, "Int", clientH, "Ptr", hdcMem, "Int", 0, "Int", 0, "UInt", 0x00CC0020)  ; SRCCOPY

            ; Clean up memory DC
            DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hOldBitmap, "Ptr")
            DllCall("DeleteObject", "Ptr", hBitmap)
            DllCall("DeleteDC", "Ptr", hdcMem)

            DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps)
            return 0
        }

        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }
}

/**
 * Dark-themed Progress bar with {@link DarkTheme} accent color fill.
 * Strips the default Windows theme and applies custom background/bar colors.
 */
class _DarkProgress extends Gui.Progress {
    static __New() {
        super.Prototype.SetDarkMode := ObjBindMethod(this, "ApplyDarkMode")
    }

    /**
     * Applies dark theme colors to the progress bar.
     *
     * @param {Gui.Progress} prog - Progress bar control instance.
     */
    static ApplyDarkMode(prog) {
        static PBM_SETBKCOLOR := 0x2001
        DllCall("uxtheme\SetWindowTheme", "Ptr", prog.Hwnd, "Str", "", "Ptr", 0)
        SendMessage(PBM_SETBKCOLOR, 0, DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]), prog)
        prog.Opt("c" Format("{:X}", DarkTheme.Colors["Accent"]))
    }
}

/**
 * Dark-themed ListBox with `DarkMode_Explorer` theme for modern scrollbar
 * appearance. Removes borders and applies {@link DarkTheme} font color.
 */
class _DarkListBox extends Gui.ListBox {
    static __New() {
        super.Prototype.SetDarkMode := ObjBindMethod(this, "ApplyDarkMode")
    }

    /**
     * Applies dark theme to the ListBox.
     *
     * @param {Gui.ListBox} lb - ListBox control instance.
     */
    static ApplyDarkMode(lb) {
        DllCall("uxtheme\SetWindowTheme", "Ptr", lb.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        lb.SetFont("c" Format("{:X}", DarkTheme.Colors["Font"]))
        DarkTheme.RemoveBorder(lb.Hwnd)
    }
}

/**
 * Custom-draw GroupBox: fills background, draws dim border, renders title in Font color.
 * WM_CTLCOLORBTN does not control GroupBox text color — a WM_PAINT subclass is required.
 */
class _DarkGroupBox {
    static Callbacks  := Map()
    static OldProcs   := Map()
    static GroupTexts := Map()

    /**
     * Applies dark theme to a GroupBox control.
     * Subclasses the control for custom WM_PAINT rendering.
     *
     * @param {Gui.GroupBox} ctrl - GroupBox control instance.
     */
    static ApplyDarkMode(ctrl) {
        hwnd := ctrl.Hwnd
        buf := Buffer(256, 0)
        DllCall("GetWindowText", "Ptr", hwnd, "Ptr", buf, "Int", 256)
        this.GroupTexts[hwnd] := StrGet(buf)
        Subclass.Install(hwnd, ObjBindMethod(this, "Proc", hwnd), this.Callbacks, this.OldProcs)
        DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1)
    }

    /**
     * Removes subclass and frees resources for a GroupBox.
     *
     * @param {Ptr} hwnd - GroupBox window handle.
     */
    static Remove(hwnd) {
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
        this.GroupTexts.Delete(hwnd)
    }

    static Proc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_PAINT      := 0x000F
        static WM_ERASEBKGND := 0x0014
        if msg = WM_ERASEBKGND {
            rc := Buffer(16)
            DllCall("GetClientRect", "Ptr", targetHwnd, "Ptr", rc)
            DllCall("FillRect", "Ptr", wParam, "Ptr", rc, "Ptr", DarkTheme.GetBrush("Background"))
            return 1
        }
        if msg = WM_PAINT {
            this.Paint(targetHwnd)
            return 0
        }
        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }

    static Paint(hwnd) {
        ps  := Buffer(72, 0)
        hdc := DllCall("BeginPaint", "Ptr", hwnd, "Ptr", ps, "Ptr")

        rc := Buffer(16)
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", rc)
        w := NumGet(rc, 8, "Int")
        h := NumGet(rc, 12, "Int")

        ; Fill entire background
        DllCall("FillRect", "Ptr", hdc, "Ptr", rc, "Ptr", DarkTheme.GetBrush("Background"))

        ; Select control font so text metrics are accurate
        hFont   := DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
        oldFont := hFont ? DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr") : 0

        ; Measure font height
        tm := Buffer(60, 0)
        DllCall("GetTextMetrics", "Ptr", hdc, "Ptr", tm)
        tmH := NumGet(tm, 0, "Int")  ; tmHeight

        ; Measure title text width
        text  := this.GroupTexts.Has(hwnd) ? this.GroupTexts[hwnd] : ""
        sz    := Buffer(8, 0)
        DllCall("GetTextExtentPoint32", "Ptr", hdc, "Str", text, "Int", StrLen(text), "Ptr", sz)
        textW := NumGet(sz, 0, "Int")

        textX   := DarkTheme.Scale(9)
        borderY := tmH // 2

        ; Draw hollow border rectangle (NULL_BRUSH = stock 5, no fill)
        borderBGR := DarkTheme.RGBtoBGR(DarkTheme.Colors["Border"])
        hPen  := DllCall("CreatePen",      "Int", 0, "Int", 1, "UInt", borderBGR, "Ptr")
        hNull := DllCall("GetStockObject", "Int", 5, "Ptr")
        oPen  := DllCall("SelectObject", "Ptr", hdc, "Ptr", hPen,  "Ptr")
        oBr   := DllCall("SelectObject", "Ptr", hdc, "Ptr", hNull, "Ptr")
        DllCall("RoundRect", "Ptr", hdc, "Int", 0, "Int", borderY, "Int", w, "Int", h, "Int", 8, "Int", 8)
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oPen)
        DllCall("SelectObject", "Ptr", hdc, "Ptr", oBr)
        DllCall("DeleteObject", "Ptr", hPen)

        ; Punch a background-colored gap in the top border line where the title sits
        if StrLen(text) > 0 {
            gapRc := Buffer(16)
            NumPut("Int", textX - 2,         "Int", borderY - 1,
                   "Int", textX + textW + 2,  "Int", borderY + 1, gapRc)
            DllCall("FillRect", "Ptr", hdc, "Ptr", gapRc, "Ptr", DarkTheme.GetBrush("Background"))
        }

        ; Draw title text in Font color (TRANSPARENT background mode)
        DllCall("SetBkMode",    "Ptr", hdc, "Int", 1)
        DllCall("SetTextColor", "Ptr", hdc, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
        textRc := Buffer(16)
        NumPut("Int", textX, "Int", 0, "Int", textX + textW + 4, "Int", tmH, textRc)
        static DT_SINGLELINE := 0x20
        DllCall("DrawText", "Ptr", hdc, "Str", text, "Int", -1, "Ptr", textRc, "UInt", DT_SINGLELINE)

        if oldFont
            DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont)
        DllCall("EndPaint", "Ptr", hwnd, "Ptr", ps)
    }
}

/**
 * Dark mode for Tab3 (SysTabControl32) controls.
 *
 * Win32 layered approach (from research):
 *   1. SetWindowTheme("DarkMode_Explorer") — registers control as dark-aware;
 *      on Win11 22H2+ the OS native rendering already draws white tab text.
 *   2. AllowDarkModeForWindow (uxtheme ordinal 133) — required dark-mode flag.
 *   3. WM_THEMECHANGED suppressed — prevents OS from resetting our theme.
 *   4. WM_ERASEBKGND — suppressed (return 1, no fill); background is drawn
 *      atomically inside the WM_PAINT double-buffer, eliminating the flash
 *      that would appear if erase and paint were separate screen writes.
 *   5. WM_PAINT — double-buffered: BeginPaint DC + CreateCompatibleDC +
 *      PaintTabs (fills memory DC) + BitBlt + EndPaint. Production pattern
 *      confirmed by darkmodelib / Notepad++ dark-mode tab implementation.
 */
class _DarkTab {
    static Callbacks := Map()
    static OldProcs  := Map()

    /**
     * Applies dark theme to a Tab3 control.
     * Registers with OS dark-mode engine, removes sunken border, and
     * subclasses for double-buffered custom WM_PAINT via {@link _DarkTab.PaintTabs}.
     *
     * @param {Gui.Tab} ctrl - Tab3 control instance.
     */
    static ApplyDarkMode(ctrl) {
        hwnd := ctrl.Hwnd
        ; Register this control as dark-aware with the OS theme engine
        DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        this._AllowDarkMode(hwnd, true)
        ; Remove sunken edge — we draw our own border (none, by design)
        DarkTheme.RemoveBorder(hwnd)
        Subclass.Install(hwnd, ObjBindMethod(this, "Proc", hwnd), this.Callbacks, this.OldProcs)
        DllCall("InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", 1)
    }

    static _AllowDarkMode(hwnd, allow) {
        try {
            uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
            if uxtheme {
                fn := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 133, "Ptr")
                if fn
                    DllCall(fn, "Ptr", hwnd, "Int", allow ? 1 : 0)
            }
        }
    }

    /**
     * Removes dark mode subclass and restores default rendering.
     *
     * @param {Ptr} hwnd - Tab3 window handle.
     */
    static Remove(hwnd) {
        this._AllowDarkMode(hwnd, false)
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
    }

    static Proc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_PAINT        := 0x000F
        static WM_ERASEBKGND   := 0x0014
        static WM_NCPAINT      := 0x0085
        static WM_THEMECHANGED := 0x031A
        ; Suppress default background erase — WM_PAINT handles it inside the
        ; double-buffer, so no separate screen write occurs before the blit.
        if msg = WM_ERASEBKGND
            return 1
        ; Suppress non-client paint — prevents the tab control from drawing its
        ; angled content-area frame border over the custom-painted background.
        if msg = WM_NCPAINT
            return 0
        ; Suppress theme changes — prevents OS from resetting SetWindowTheme
        if msg = WM_THEMECHANGED
            return 0
        if msg = WM_PAINT {
            ; Production pattern (darkmodelib / Notepad++):
            ;   1. BeginPaint validates the update region (stops WM_PAINT loop).
            ;   2. Paint into a full-size memory DC (no clip restriction).
            ;   3. BitBlt from memory DC to BeginPaint DC atomically.
            ;   4. EndPaint releases BeginPaint state.
            ; This eliminates the flash that comes from WM_ERASEBKGND + WM_PAINT
            ; writing to the screen twice, and GetDCEx/GetDC reliability issues.
            static SRCCOPY := 0xCC0020
            ps := Buffer(72, 0)
            hdc := DllCall("BeginPaint", "Ptr", targetHwnd, "Ptr", ps, "Ptr")
            rcBuf := Buffer(16)
            DllCall("GetClientRect", "Ptr", targetHwnd, "Ptr", rcBuf)
            w := NumGet(rcBuf, 8, "Int")
            h := NumGet(rcBuf, 12, "Int")
            hdcMem  := DllCall("CreateCompatibleDC",     "Ptr", hdc, "Ptr")
            hBmp    := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", w, "Int", h, "Ptr")
            hBmpOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBmp, "Ptr")
            this.PaintTabs(targetHwnd, hdcMem)
            DllCall("BitBlt", "Ptr", hdc, "Int", 0, "Int", 0, "Int", w, "Int", h,
                "Ptr", hdcMem, "Int", 0, "Int", 0, "UInt", SRCCOPY)
            DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hBmpOld)
            DllCall("DeleteObject", "Ptr", hBmp)
            DllCall("DeleteDC",     "Ptr", hdcMem)
            DllCall("EndPaint", "Ptr", targetHwnd, "Ptr", ps)
            return 0
        }
        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }

    /**
     * Full owner-draw for Tab3 WM_PAINT.
     *
     * Layout:
     *   • Entire client area → Background fill (no outer border)
     *   • Unselected tabs    → transparent background, FontDim text
     *   • Selected tab       → Controls fill, rounded corners (6px), Font text
     *   • Separator line     → 1px Border color between tab strip and content
     *
     * Pattern mirrors _DarkGroupBox.Paint / _DarkButton.PaintButton.
     */
    static PaintTabs(hwnd, hdc) {
        static TCM_GETITEMCOUNT := 0x1304  ; TCM_FIRST + 4
        static TCM_GETITEMRECT  := 0x130A  ; TCM_FIRST + 10
        static TCM_GETCURSEL    := 0x130B  ; TCM_FIRST + 11
        static TCM_GETITEM      := 0x133C  ; TCM_FIRST + 60 (W)
        static TCM_ADJUSTRECT   := 0x1328  ; TCM_FIRST + 40
        static TCIF_TEXT        := 0x1
        static DT_CENTER        := 0x1
        static DT_VCENTER       := 0x4
        static DT_SINGLELINE    := 0x20
        static NULL_PEN         := 8      ; GetStockObject(8)

        ; Geometry
        clientRc := Buffer(16)
        DllCall("GetClientRect", "Ptr", hwnd, "Ptr", clientRc)
        w := NumGet(clientRc, 8, "Int")
        h := NumGet(clientRc, 12, "Int")

        ; Fill entire background — no tab-control border
        DllCall("FillRect", "Ptr", hdc, "Ptr", clientRc, "Ptr", DarkTheme.GetBrush("Background"))

        selIdx := DllCall("SendMessage", "Ptr", hwnd, "UInt", TCM_GETCURSEL,    "Ptr", 0, "Ptr", 0, "Int")
        count   := DllCall("SendMessage", "Ptr", hwnd, "UInt", TCM_GETITEMCOUNT, "Ptr", 0, "Ptr", 0, "Int")
        if count <= 0
            return

        ; Content area top = tab strip bottom (for separator line)
        adjRc := Buffer(16)
        NumPut("Int", 0, "Int", 0, "Int", w, "Int", h, adjRc)
        DllCall("SendMessage", "Ptr", hwnd, "UInt", TCM_ADJUSTRECT, "Ptr", 0, "Ptr", adjRc)
        tabStripBottom := NumGet(adjRc, 4, "Int")

        ; Select control font
        hFont   := DllCall("SendMessage", "Ptr", hwnd, "UInt", 0x31, "Ptr", 0, "Ptr", 0, "Ptr")
        oldFont := hFont ? DllCall("SelectObject", "Ptr", hdc, "Ptr", hFont, "Ptr") : 0
        DllCall("SetBkMode", "Ptr", hdc, "Int", 1)  ; TRANSPARENT

        hNullPen := DllCall("GetStockObject", "Int", NULL_PEN, "Ptr")

        ; TCITEMW struct offsets (64-bit: pszText@16, cchTextMax@24; 32-bit: @12, @16)
        pszTextOff := A_PtrSize = 8 ? 16 : 12
        cchMaxOff  := A_PtrSize = 8 ? 24 : 16
        tcItemSz   := A_PtrSize = 8 ? 40 : 28

        loop count {
            i := A_Index - 1
            itemRc := Buffer(16)
            DllCall("SendMessage", "Ptr", hwnd, "UInt", TCM_GETITEMRECT, "Ptr", i, "Ptr", itemRc)
            left   := NumGet(itemRc, 0,  "Int")
            top    := NumGet(itemRc, 4,  "Int")
            right  := NumGet(itemRc, 8,  "Int")
            bottom := NumGet(itemRc, 12, "Int")

            if (i = selIdx) {
                ; Rounded pill: top corners round, bottom corners square.
                ; Draw full RoundRect, then overdraw bottom 6px with FillRect
                ; using same brush — squares off the bottom corner curves.
                tabBrush := DllCall("CreateSolidBrush", "UInt",
                    DarkTheme.RGBtoBGR(DarkTheme.Colors["ControlsHover"]), "Ptr")
                oPen   := DllCall("SelectObject", "Ptr", hdc, "Ptr", hNullPen, "Ptr")
                oBrush := DllCall("SelectObject", "Ptr", hdc, "Ptr", tabBrush, "Ptr")
                DllCall("RoundRect", "Ptr", hdc,
                    "Int", left+2, "Int", top, "Int", right-1, "Int", bottom+1,
                    "Int", 6, "Int", 6)
                squareRc := Buffer(16)
                NumPut("Int", left+2,    squareRc,  0)
                NumPut("Int", bottom-6,  squareRc,  4)
                NumPut("Int", right-1,   squareRc,  8)
                NumPut("Int", bottom+1,  squareRc, 12)
                DllCall("FillRect", "Ptr", hdc, "Ptr", squareRc, "Ptr", tabBrush)
                DllCall("SelectObject", "Ptr", hdc, "Ptr", oPen)
                DllCall("SelectObject", "Ptr", hdc, "Ptr", oBrush)
                DllCall("DeleteObject", "Ptr", tabBrush)
                DllCall("SetTextColor", "Ptr", hdc, "UInt",
                    DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
            } else {
                DllCall("SetTextColor", "Ptr", hdc, "UInt",
                    DarkTheme.RGBtoBGR(DarkTheme.Colors["FontDim"]))
            }

            ; Fetch label text via TCM_GETITEMW and draw centered
            textBuf := Buffer(512, 0)
            tcItem  := Buffer(tcItemSz, 0)
            NumPut("UInt", TCIF_TEXT,   tcItem, 0)
            NumPut("Ptr",  textBuf.Ptr, tcItem, pszTextOff)
            NumPut("Int",  255,         tcItem, cchMaxOff)
            DllCall("SendMessage", "Ptr", hwnd, "UInt", TCM_GETITEM, "Ptr", i, "Ptr", tcItem)
            text := StrGet(textBuf)
            DllCall("DrawText", "Ptr", hdc, "Str", text, "Int", -1, "Ptr", itemRc,
                "UInt", DT_CENTER | DT_VCENTER | DT_SINGLELINE)
        }

        ; 1px separator line between tab strip and content area
        if tabStripBottom > 0 {
            sepRc := Buffer(16)
            NumPut("Int", 0, "Int", tabStripBottom - 1, "Int", w, "Int", tabStripBottom, sepRc)
            DllCall("FillRect", "Ptr", hdc, "Ptr", sepRc, "Ptr", DarkTheme.GetBrush("Border"))
        }

        if oldFont
            DllCall("SelectObject", "Ptr", hdc, "Ptr", oldFont)
    }
}

/**
 * Window procedure subclass for handling WM_CTLCOLOR* messages.
 * Provides dark background brushes for Edit, ListBox, Button, and Static controls.
 */
class DarkWindowProc {
    /** @type {Map} Window procedure callbacks */
    static Callbacks := Map()
    /** @type {Map} Original window procedures */
    static OldProcs := Map()
    /** @type {Map} Radio button text control handles for WM_CTLCOLORSTATIC */
    static RadioTextControls := Map()
    /** @type {Map} Menu bar control handles that need Header background instead of Background */
    static MenuBarControls := Map()
    /** @type {Map} ComboBox dropdown list handles for WM_CTLCOLORLISTBOX */
    static ComboDropdowns := Map()

    /**
     * Installs dark window procedure on a window.
     * @param {Ptr} hwnd - Window handle
     */
    static Install(hwnd) {
        Subclass.Install(hwnd, ObjBindMethod(this, "Proc", hwnd), this.Callbacks, this.OldProcs)
    }

    /**
     * Removes dark window procedure and restores original.
     * @param {Ptr} hwnd - Window handle
     */
    static Uninstall(hwnd) {
        Subclass.Uninstall(hwnd, this.Callbacks, this.OldProcs)
    }

    /**
     * Handles `WM_CTLCOLOR*` messages to apply dark background brushes
     * and text colors for Edit, ListBox, Button, and Static controls.
     *
     * @param {Ptr} targetHwnd - Subclassed window handle.
     * @param {Ptr} hwnd - Message target window handle.
     * @param {Integer} msg - Windows message ID.
     * @param {Ptr} wParam - HDC of the control.
     * @param {Ptr} lParam - HWND of the control.
     * @returns {Ptr} GDI brush handle for the control background.
     */
    static Proc(targetHwnd, hwnd, msg, wParam, lParam) {
        static WM_CTLCOLOREDIT := 0x0133
        static WM_CTLCOLORLISTBOX := 0x0134
        static WM_CTLCOLORBTN := 0x0135
        static WM_CTLCOLORSTATIC := 0x0138
        static TRANSPARENT := 1

        if hwnd != targetHwnd
            return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)

        switch msg {
            case WM_CTLCOLOREDIT:
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]))
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                return DarkTheme.GetBrush("Controls")

            case WM_CTLCOLORLISTBOX:
                ; lParam = listbox hwnd - check if it's a ComboBox dropdown or standalone ListBox
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                if this.ComboDropdowns.Has(lParam) {
                    ; ComboBox dropdown - use Background color to match GUI
                    DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Background"]))
                    return DarkTheme.GetBrush("Background")
                } else {
                    ; Standalone ListBox - use Controls color
                    DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Controls"]))
                    return DarkTheme.GetBrush("Controls")
                }

            case WM_CTLCOLORBTN:
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Background"]))
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                return DarkTheme.GetBrush("Background")

            case WM_CTLCOLORSTATIC:
                ; lParam = control handle in WM_CTLCOLOR messages
                ; Menu bar controls use same background as GUI
                if this.MenuBarControls.Has(lParam) {
                    DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
                    DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                    return DllCall("gdi32\GetStockObject", "Int", 5, "Ptr")  ; HOLLOW_BRUSH - preserve BackgroundTrans
                }
                ; Radio text controls
                if this.RadioTextControls.Has(lParam) {
                    DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
                    DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Background"]))
                    DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                    return DarkTheme.GetBrush("Background")
                }
                DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Font"]))
                DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkTheme.RGBtoBGR(DarkTheme.Colors["Background"]))
                DllCall("gdi32\SetBkMode", "Ptr", wParam, "Int", TRANSPARENT)
                return DarkTheme.GetBrush("Background")
        }

        return Subclass.CallOriginal(this.OldProcs[targetHwnd], hwnd, msg, wParam, lParam)
    }
}

/**
 * Custom dark menu bar using Win32 popup menus with dark theme.
 * Uses `SetMenuInfo` for dark popup backgrounds + uxtheme dark mode APIs.
 * `WM_COMMAND` (`0x0111`) handled externally by consumer class.
 *
 * Construct with a {@link DarkGui} parent and a `Map` of layout/color options.
 * Call {@link DarkMenuBar#AddMenu} to define menus with popup items,
 * and {@link DarkMenuBar#AddToolbarButton} for icon toolbar buttons.
 */
class DarkMenuBar {
    /**
     * Creates a dark menu bar with optional toolbar.
     *
     * @param {DarkGui} parentGui - The parent GUI instance.
     * @param {Map} options - Configuration options.
     * @param {Integer} [options.menuBarHeight = 24] - Menu bar height in pixels.
     * @param {Integer} [options.toolbarHeight = 32] - Toolbar row height.
     * @param {Integer} [options.menuItemPadding = 12] - Horizontal padding per menu label.
     * @param {Integer} [options.menuFontSize = 9] - Font size for menu labels.
     * @param {Integer} [options.toolbarIconSize = 20] - Toolbar button icon size.
     * @param {Boolean} [options.showToolbar = true] - Whether to show the toolbar row.
     * @param {Integer} [options.popupOffsetX = 0] - Popup menu X offset from label.
     * @param {Integer} [options.popupOffsetY = 0] - Popup menu Y offset from label.
     */
    __New(parentGui, options) {
        this.gui := parentGui
        this.menuItems := []
        this.toolbarBtns := []
        this.hoveredMenu := ""

        this.layout := Map(
            "menuBarHeight", options.Has("menuBarHeight") ? options["menuBarHeight"] : 24,
            "toolbarHeight", options.Has("toolbarHeight") ? options["toolbarHeight"] : 32,
            "menuItemPadding", options.Has("menuItemPadding") ? options["menuItemPadding"] : 12,
            "menuFontSize", options.Has("menuFontSize") ? options["menuFontSize"] : 9,
            "toolbarIconSize", options.Has("toolbarIconSize") ? options["toolbarIconSize"] : 20,
            "toolbarButtonSpacing", options.Has("toolbarButtonSpacing") ? options["toolbarButtonSpacing"] : 4,
            "toolbarSeparatorWidth", options.Has("toolbarSeparatorWidth") ? options["toolbarSeparatorWidth"] : 1,
            "showToolbar", options.Has("showToolbar") ? options["showToolbar"] : true,
            "popupOffsetX", options.Has("popupOffsetX") ? options["popupOffsetX"] : 0,
            "popupOffsetY", options.Has("popupOffsetY") ? options["popupOffsetY"] : 0
        )

        this.colors := Map(
            "menuBarBg", options.Has("menuBarBg") ? options["menuBarBg"] : DarkTheme.Colors["Header"],
            "menuBarText", options.Has("menuBarText") ? options["menuBarText"] : DarkTheme.Colors["Font"],
            "menuBarHover", options.Has("menuBarHover") ? options["menuBarHover"] : DarkTheme.Colors["ControlsActive"],
            "menuBarActive", options.Has("menuBarActive") ? options["menuBarActive"] : DarkTheme.Colors["Accent"],
            "popupBg", options.Has("popupBg") ? options["popupBg"] : DarkTheme.Colors["Header"],
            "toolbarBg", options.Has("toolbarBg") ? options["toolbarBg"] : DarkTheme.Colors["Header"],
            "toolbarBorder", options.Has("toolbarBorder") ? options["toolbarBorder"] : DarkTheme.Colors["Border"]
        )

        this.totalHeight := this.layout["showToolbar"] ?
            (this.layout["menuBarHeight"] + this.layout["toolbarHeight"] + 1) :
            this.layout["menuBarHeight"]

        DarkMenu.Apply()
        this._AllowDarkModeForWindow()
        this.CreateMenuBar()
        if this.layout["showToolbar"] {
            this.CreateToolbar()
        }

        this._onMouseMove := this.OnMouseMove.Bind(this)
        OnMessage(0x200, this._onMouseMove)
        this._lastHoveredBtn := ""
    }

    CreateMenuBar() {
        this.menuBar := this.gui.AddText("x0 y0 w800 h" . this.layout["menuBarHeight"] . " Background" . Format("{:06X}", this.colors["menuBarBg"]))

        this.popupMenus := Map()
        this.menuStructure := Map()

        x := 8
        this.menuBarStartX := x
    }

    /**
     * Adds a named menu to the menu bar with a popup of items.
     *
     * Each item in `menuItems` is a `Map` with keys:
     * - `"text"` `{String}` - Menu item label.
     * - `"id"` `{Integer}` - Command ID for `WM_COMMAND`.
     * - `"shortcut"` `{String}` - Optional keyboard shortcut hint.
     * - `"separator"` `{Boolean}` - If `true`, draws a separator line.
     *
     * @param {String} menuName - Label displayed in the menu bar.
     * @param {Array} menuItems - Array of `Map` objects defining popup items.
     * @returns {Ptr} Handle to the created popup menu (`HMENU`).
     */
    AddMenu(menuName, menuItems) {
        hPopup := DllCall("CreatePopupMenu", "Ptr")

        for item in menuItems {
            if item.Has("separator") && item["separator"] {
                DllCall("AppendMenu", "Ptr", hPopup, "UInt", 0x0800, "Ptr", 0, "Ptr", 0)
            } else {
                itemText := item["text"]
                if item.Has("shortcut") {
                    itemText .= "`t" . item["shortcut"]
                }
                itemId := item.Has("id") ? item["id"] : 0
                DllCall("AppendMenu", "Ptr", hPopup, "UInt", 0x0000, "Ptr", itemId, "Str", itemText)
            }
        }

        this.ApplyDarkThemeToPopup(hPopup)

        itemWidth := StrLen(menuName) * 7 + this.layout["menuItemPadding"]

        ; Center label vertically in menu bar using SS_CENTERIMAGE (0x200)
        menuLabel := this.gui.AddText("x" . this.menuBarStartX . " y0 w" . itemWidth . " h" . this.layout["menuBarHeight"] . " +0x200 Center BackgroundTrans c" . Format("{:06X}", this.colors["menuBarText"]), menuName)
        menuLabel.SetFont("s" . this.layout["menuFontSize"], "Segoe UI")

        hitArea := this.gui.AddText("x" . this.menuBarStartX . " y0 w" . itemWidth . " h" . this.layout["menuBarHeight"] . " BackgroundTrans")
        hitArea.OnEvent("Click", this.ShowPopupMenu.Bind(this, hPopup, this.menuBarStartX))

        menuItemData := Map(
            "name", menuName,
            "label", menuLabel,
            "hitArea", hitArea,
            "popup", hPopup,
            "x", this.menuBarStartX,
            "width", itemWidth
        )

        this.menuItems.Push(menuItemData)
        this.popupMenus[menuName] := hPopup
        this.menuStructure[menuName] := menuItems

        ; Register with DarkWindowProc so WM_CTLCOLORSTATIC returns HOLLOW_BRUSH
        ; (preserves BackgroundTrans and white text on menu bar)
        DarkWindowProc.MenuBarControls[menuLabel.Hwnd] := true
        DarkWindowProc.MenuBarControls[hitArea.Hwnd] := true

        this.menuBarStartX += itemWidth + 4

        return hPopup
    }

    CreateToolbar() {
        toolbarY := this.layout["menuBarHeight"]

        this.toolbar := this.gui.AddText("x0 y" . toolbarY . " w800 h" . this.layout["toolbarHeight"] . " Background" . Format("{:06X}", this.colors["toolbarBg"]))
        this.toolbarBorder := this.gui.AddText("x0 y" . (toolbarY + this.layout["toolbarHeight"]) . " w800 h1 Background" . Format("{:06X}", this.colors["toolbarBorder"]))

        this.toolbarStartX := 6
        this.toolbarY := toolbarY + Integer((this.layout["toolbarHeight"] - this.layout["toolbarIconSize"]) / 2)
    }

    /**
     * Adds an icon button to the toolbar row below the menu bar.
     *
     * @param {String} icon - Single character or emoji used as button label.
     * @param {String} tooltip - Tooltip text shown on hover.
     * @param {Func} callback - Called with no arguments when clicked.
     */
    AddToolbarButton(icon, tooltip, callback) {
        btnX := this.toolbarStartX
        btnY := this.toolbarY
        btnSize := this.layout["toolbarIconSize"]

        btnBg := this.gui.AddText("x" . btnX . " y" . btnY . " w" . btnSize . " h" . btnSize . " BackgroundTrans")
        btnIcon := this.gui.AddText("x" . btnX . " y" . btnY . " w" . btnSize . " h" . btnSize . " Center BackgroundTrans c" . Format("{:06X}", this.colors["menuBarText"]), icon)
        btnIcon.SetFont("s10")

        btnHit := this.gui.AddText("x" . btnX . " y" . btnY . " w" . btnSize . " h" . btnSize . " BackgroundTrans")
        btnHit.OnEvent("Click", (*) => callback())
        btnHit.ToolTip := tooltip

        btnData := Map(
            "bg", btnBg,
            "icon", btnIcon,
            "hit", btnHit,
            "x", btnX,
            "y", btnY,
            "tooltip", tooltip
        )

        this.toolbarBtns.Push(btnData)

        this.toolbarStartX += btnSize + this.layout["toolbarButtonSpacing"]
    }

    AddToolbarSeparator() {
        btnX := this.toolbarStartX
        btnY := this.toolbarY
        btnSize := this.layout["toolbarIconSize"]

        this.gui.AddText("x" . btnX . " y" . (btnY + 1) . " w" . this.layout["toolbarSeparatorWidth"] . " h" . (btnSize - 2) . " Background" . Format("{:06X}", this.colors["toolbarBorder"]))
        this.toolbarStartX += 6
    }

    ShowPopupMenu(hPopup, x, *) {
        popupX := 0
        popupY := 0

        for item in this.menuItems {
            if item["popup"] = hPopup {
                ctrlRect := Buffer(16, 0)
                DllCall("GetWindowRect", "Ptr", item["hitArea"].Hwnd, "Ptr", ctrlRect)

                popupX := NumGet(ctrlRect, 0, "Int")   ; Left
                popupY := NumGet(ctrlRect, 12, "Int")  ; Bottom

                item["label"].Opt("Background" . Format("{:06X}", this.colors["menuBarActive"]))
                labelRef := item["label"]
                SetTimer(() => labelRef.Opt("BackgroundTrans"), -200)
                break
            }
        }

        popupX += this.layout["popupOffsetX"]
        popupY += this.layout["popupOffsetY"]

        DllCall("TrackPopupMenu", "Ptr", hPopup, "UInt", 0x0000, "Int", popupX, "Int", popupY, "Int", 0, "Ptr", this.gui.Hwnd, "Ptr", 0)
    }

    OnMouseMove(wParam, lParam, msg, hwnd) {
        if hwnd != this.gui.Hwnd
            return

        x := lParam & 0xFFFF
        y := (lParam >> 16) & 0xFFFF

        if this.layout["showToolbar"] && y > this.layout["menuBarHeight"] && y <= (this.layout["menuBarHeight"] + this.layout["toolbarHeight"]) {
            this.HandleToolbarHover(x, y)
            return
        }

        if y > this.layout["menuBarHeight"] {
            if this.hoveredMenu != "" {
                this.ClearHover()
            }
            return
        }

        hoveredItem := ""
        for item in this.menuItems {
            if x >= item["x"] && x <= item["x"] + item["width"] {
                hoveredItem := item["name"]
                break
            }
        }

        if hoveredItem != this.hoveredMenu {
            this.ClearHover()
            if hoveredItem != "" {
                for item in this.menuItems {
                    if item["name"] = hoveredItem {
                        item["label"].Opt("Background" . Format("{:06X}", this.colors["menuBarHover"]))
                        this.hoveredMenu := hoveredItem
                        break
                    }
                }
            }
        }
    }

    HandleToolbarHover(x, y) {
        hoveredBtn := ""
        for btn in this.toolbarBtns {
            btnSize := this.layout["toolbarIconSize"]
            if x >= btn["x"] && x <= btn["x"] + btnSize && y >= btn["y"] && y <= btn["y"] + btnSize {
                hoveredBtn := btn
                break
            }
        }

        if hoveredBtn != this._lastHoveredBtn {
            for btn in this.toolbarBtns {
                btn["bg"].Opt("BackgroundTrans")
            }

            if hoveredBtn != "" {
                hoveredBtn["bg"].Opt("Background" . Format("{:06X}", this.colors["menuBarHover"]))
            }

            this._lastHoveredBtn := hoveredBtn
        }
    }

    ClearHover() {
        for item in this.menuItems {
            item["label"].Opt("BackgroundTrans")
        }
        this.hoveredMenu := ""
    }

    ApplyDarkThemeToPopup(hPopup) {
        darkBrush := DllCall("CreateSolidBrush", "UInt", DarkTheme.RGBtoBGR(this.colors["popupBg"]), "Ptr")

        mi := Buffer(28, 0)
        NumPut("UInt", mi.Size, mi, 0)
        NumPut("UInt", 0x10, mi, 4)
        NumPut("Ptr", darkBrush, mi, 16)
        DllCall("SetMenuInfo", "Ptr", hPopup, "Ptr", mi)
    }

    _AllowDarkModeForWindow() {
        try {
            uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
            if !uxtheme
                uxtheme := DllCall("LoadLibrary", "Str", "uxtheme", "Ptr")
            if uxtheme {
                fn := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 133, "Ptr")
                if fn
                    DllCall(fn, "Ptr", this.gui.Hwnd, "Int", 1)
            }
        }
    }

    /**
     * Unregisters the mouse move handler and destroys popup menu handles.
     * Call before disposing the parent {@link DarkGui}.
     */
    Destroy() {
        OnMessage(0x200, this._onMouseMove, 0)
        for item in this.menuItems {
            if item.Has("popup")
                DllCall("DestroyMenu", "Ptr", item["popup"])
        }
    }

    /**
     * Returns the Y offset where content should begin below the menu/toolbar.
     *
     * @returns {Integer} Pixel offset accounting for menu bar and optional toolbar.
     */
    GetContentY() {
        return this.totalHeight
    }
}

/**
 * Dark-themed Gui class. All controls added via Add() are automatically styled.
 * Use "+Accent" option for accent-colored buttons.
 * Backward compatible: `_Dark` is an alias for `DarkGui`.
 */
class DarkGui extends Gui {
    /** @type {Map} Tracks dark-styled controls: hwnd -> controlType */
    _darkHwnds := Map()

    /**
     * Creates a new dark-themed GUI window.
     * @param {String} options - Gui options
     * @param {String} title - Window title
     */
    __New(options := "", title := A_ScriptName) {
        super.__New(options, title)
        DarkTheme.AddRef()
        this.BackColor := DarkTheme.Colors["Background"]
        this.SetFont("s9", "Segoe UI")
        DarkTitleBar.Apply(this.Hwnd)
        DarkMenu.Apply()
        DarkWindowProc.Install(this.Hwnd)
    }

    /**
     * Cleans up all dark mode resources for this GUI.
     * Removes subclasses from all tracked controls, clears stale entries from
     * {@link DarkWindowProc} tracking maps, and calls {@link DarkTheme.Release}.
     */
    __Delete() {
        ; Remove subclasses from all tracked dark controls
        for hwnd, ctrlType in this._darkHwnds {
            switch ctrlType {
                case "ListView": _DarkListView.Remove(hwnd)
                case "Button":   _DarkButton.Remove(hwnd)
                case "ComboBox": _DarkComboBox.Remove(hwnd)
                case "Slider":   _DarkSlider.Remove(hwnd)
                case "GroupBox": _DarkGroupBox.Remove(hwnd)
                case "Tab3":     _DarkTab.Remove(hwnd)
            }
        }
        this._darkHwnds.Clear()

        ; Clean stale entries from DarkWindowProc tracking maps
        for map in [DarkWindowProc.RadioTextControls, DarkWindowProc.MenuBarControls, DarkWindowProc.ComboDropdowns] {
            stale := []
            for hwnd, _ in map
                if !DllCall("IsWindow", "Ptr", hwnd)
                    stale.Push(hwnd)
            for hwnd in stale
                map.Delete(hwnd)
        }

        try DarkWindowProc.Uninstall(this.Hwnd)
        DarkTheme.Release()
    }

    /**
     * Adds a control with automatic dark mode styling.
     *
     * Delegates to the appropriate `_Dark*` class based on `controlType`.
     * Use `"+Accent"` in options for accent-colored buttons via {@link _DarkButton}.
     *
     * @param {String} controlType - Control type (`"Button"`, `"Edit"`, `"ListView"`, etc.).
     * @param {String} [options = ""] - Control options. Include `"+Accent"` for blue buttons.
     * @param {*} [content] - Control content (text, items array, etc.).
     * @returns {Gui.Control} The created and dark-styled control.
     */
    Add(controlType, options := "", content?) {
        isAccent := InStr(options, "+Accent")
        if isAccent
            options := StrReplace(options, "+Accent", "")

        switch controlType, false {
            case "Text":
                ; Add font color if not specified
                if !RegExMatch(options, "i)\bc[0-9A-Fa-f]+\b")
                    options .= " c" Format("{:X}", DarkTheme.Colors["Font"])
                return super.Add(controlType, options, content?)

            case "ListView":
                ; Add cWhite for text color if not specified
                if !RegExMatch(options, "i)\bc[0-9A-Fa-f]+\b|\bcWhite\b|\bcBlack\b")
                    options .= " cWhite"
                ctrl := super.Add(controlType, options, content?)
                ctrl.SetDarkMode()
                this._darkHwnds[ctrl.Hwnd] := "ListView"
                return ctrl

            case "Radio":
                return this._AddRadio(options, content?)

            case "Button":
                ctrl := super.Add(controlType, options, content?)
                ctrl.SetDarkMode(isAccent ? "accent" : "default")
                this._darkHwnds[ctrl.Hwnd] := "Button"
                return ctrl

            case "CheckBox":
                ctrl := super.Add(controlType, options, content?)
                DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                ctrl.SetFont("c" Format("{:X}", DarkTheme.Colors["Font"]))
                return ctrl

            case "Edit", "ComboBox", "Slider", "Progress", "ListBox", "TreeView":
                ctrl := super.Add(controlType, options, content?)
                ctrl.SetDarkMode()
                ; Track subclassed controls for cleanup
                if controlType ~= "i)^(ComboBox|Slider)$"
                    this._darkHwnds[ctrl.Hwnd] := controlType
                return ctrl

            case "GroupBox":
                ctrl := super.Add(controlType, options, content?)
                _DarkGroupBox.ApplyDarkMode(ctrl)
                this._darkHwnds[ctrl.Hwnd] := "GroupBox"
                return ctrl

            case "Tab3":
                ctrl := super.Add(controlType, options, content?)
                _DarkTab.ApplyDarkMode(ctrl)
                this._darkHwnds[ctrl.Hwnd] := "Tab3"
                return ctrl

            default:
                return super.Add(controlType, options, content?)
        }
    }

    /** Manually selects a radio and unchecks all others in its group */
    static _SelectRadio(selected, group) {
        for r in group
            r.Value := (r = selected) ? 1 : 0
    }

    /** Internal: Adds Radio with separate text control for proper dark styling */
    _AddRadio(options, text?) {
        static SM_CXMENUCHECK := 71
        static radioW := DllCall("GetSystemMetrics", "Int", SM_CXMENUCHECK)

        ; Track radio groups - new group starts with +Group or first radio
        isNewGroup := RegExMatch(options, "i)\bGroup\b") || !this.HasOwnProp("_radioGroup")
        if isNewGroup
            this._radioGroup := []
        group := this._radioGroup

        radio := super.Add("Radio", options " +0x4000000", "")
        group.Push(radio)

        ; SS_NOTIFY (0x100) enables click events on the text label
        if !InStr(options, "right")
            txt := super.Add("Text", "xp+" (radioW + 8) " yp+2 HP-4 +0x4000300 cFFFFFF", text?)
        else
            txt := super.Add("Text", "xp+8 yp+2 HP-4 +0x4000300 cFFFFFF", text?)

        DarkWindowProc.RadioTextControls[txt.Hwnd] := true

        static SWP_NOSIZE := 0x1, SWP_NOMOVE := 0x2, SWP_NOACTIVATE := 0x10
        DllCall("SetWindowPos", "Ptr", txt.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0,
            "UInt", SWP_NOSIZE | SWP_NOMOVE | SWP_NOACTIVATE | 0x40)

        DllCall("uxtheme\SetWindowTheme", "Ptr", radio.Hwnd, "Str", "DarkMode_Explorer", "Ptr", 0)

        radio.TextCtrl := txt
        radio.DefineProp("Text", {
            Get: (this) => this.TextCtrl.Text,
            Set: (this, value) => this.TextCtrl.Text := value
        })

        ; Manual radio group management - text controls break native auto-grouping
        radio.OnEvent("Click", (*) => DarkGui._SelectRadio(radio, group))
        txt.OnEvent("Click", (*) => DarkGui._SelectRadio(radio, group))

        return radio
    }
}

/** @type {DarkGui} Backward compatibility alias — `_Dark` resolves to {@link DarkGui}. */
_Dark := DarkGui

; Run standalone showcase when executed directly, skip when #Included as library
if A_LineFile = A_ScriptFullPath
    DarkModeShowcase()

class DarkModeShowcase {
    controls := Map()

    __New() {
        this.gui := DarkGui("+Resize", "Modular Dark Mode System")
        this.BuildLayout()
        this.BindEvents()
        this.gui.Show("w620 h520")
    }

    BuildLayout() {
        this.gui.Add("Text", "x20 y15 w200", "━ Text Input")
        this.controls["edit1"] := this.gui.Add("Edit", "x20 y40 w200 h25", "Single-line edit")
        this.controls["edit2"] := this.gui.Add("Edit", "x20 y75 w200 h68 +Multi", "Item A`nItem B`nItem C`nItem D`nItem E")

        this.gui.Add("Text", "x240 y15 w180", "━ Selection")
        this.controls["chk1"] := this.gui.Add("CheckBox", "x240 y40 w160 +Checked", "Feature enabled")
        this.controls["chk2"] := this.gui.Add("CheckBox", "x240 y65 w160", "Auto-save")
        this.controls["rad1"] := this.gui.Add("Radio", "x240 y95 w160 +Checked", "Option A")
        this.controls["rad2"] := this.gui.Add("Radio", "x240 y120 w160", "Option B")

        this.gui.Add("Text", "x420 y15 w180", "━ Actions")
        this.controls["btn1"] := this.gui.Add("Button", "x420 y40 w80 h28", "Apply")
        this.controls["btn2"] := this.gui.Add("Button", "+Accent x510 y40 w80 h28", "OK")
        this.controls["btn3"] := this.gui.Add("Button", "x420 y75 w170 h28", "Reset All")

        this.gui.Add("Text", "x20 y200 w200", "━ Dropdowns & Progress")
        this.controls["combo"] := this.gui.Add("ComboBox", "x20 y225 w200", ["Option 1", "Option 2", "Option 3"])
        this.controls["slider"] := this.gui.Add("Slider", "x20 y265 w200 Range0-100", 50)
        this.controls["sliderLabel"] := this.gui.Add("Text", "x20 y295 w200", "Value: 50")
        this.controls["progress"] := this.gui.Add("Progress", "x20 y320 w200 h20", 50)

        this.gui.Add("Text", "x240 y200 w350", "━ ListView")
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

        this.gui.Add("Text", "x20 y355 w200", "━ ListBox")
        this.controls["listbox"] := this.gui.Add("ListBox", "x20 y380 w200 h90", ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"])

        this.gui.Add("Text", "x240 y355 w350", "━ TreeView")
        this.controls["tv"] := this.gui.Add("TreeView", "x240 y380 w350 h83")
        p1 := this.controls["tv"].Add("Documents")
        this.controls["tv"].Add("Report.pdf", p1)
        this.controls["tv"].Add("Notes.txt", p1)
        p2 := this.controls["tv"].Add("Images")
        this.controls["tv"].Add("Photo.jpg", p2)

        this.controls["status"] := this.gui.Add("Text", "x20 y480 w580", "Status: Ready")
    }

    BindEvents() {
        this.controls["btn1"].OnEvent("Click", this.OnApply.Bind(this))
        this.controls["btn2"].OnEvent("Click", (*) => this.gui.Hide())
        this.controls["btn3"].OnEvent("Click", this.OnReset.Bind(this))
        this.controls["slider"].OnEvent("Change", this.OnSliderChange.Bind(this))
        this.gui.OnEvent("Close", (*) => ExitApp())
    }

    OnApply(*) {
        this.controls["status"].Text := "Status: Applied at " FormatTime(, "HH:mm:ss")
    }

    OnReset(*) {
        this.controls["edit1"].Value := "Single-line edit"
        this.controls["edit2"].Value := "Multi-line`nedit control"
        this.controls["chk1"].Value := 1
        this.controls["chk2"].Value := 0
        this.controls["rad1"].Value := 1
        this.controls["slider"].Value := 50
        this.controls["progress"].Value := 50
        this.controls["sliderLabel"].Text := "Value: 50"
        this.controls["status"].Text := "Status: Reset complete"
    }

    OnSliderChange(*) {
        val := this.controls["slider"].Value
        this.controls["progress"].Value := val
        this.controls["sliderLabel"].Text := "Value: " val
    }
}