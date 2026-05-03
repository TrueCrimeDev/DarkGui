#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

#DllLoad gdi32.dll
#DllLoad user32.dll
#DllLoad uxtheme.dll
#DllLoad dwmapi.dll

if A_LineFile = A_ScriptFullPath {
    if A_Args.Length && A_Args[1] = "--self-test" {
        AdvancedDarkWinApiSelfTest()
        ExitApp(0)
    }
    ADW_RunningDemo := ADW_AdvancedDarkDemo(true)
}

AdvancedDarkWinApiSelfTest() {
    ADW_Theme.Initialize()
    if ADW_Theme.GetBrush("Background") = 0
        throw Error("Theme background brush was not created")

    demo := ADW_AdvancedDarkDemo(false)
    if demo.controls.Count < 16
        throw Error("Expected demo controls were not created")
    if !demo.controls.Has("applyBtn")
        throw Error("Apply button was not registered")
    if !(demo.controls["applyBtn"] is ADW_DarkButton)
        throw Error("Apply button is not owner drawn")
    if demo.controls["taskList"].GetCount() < 6
        throw Error("Sample ListView rows were not loaded")
    if !demo.themeGui.windowProc
        throw Error("Window procedure subclass was not installed")
    ADW_Theme.ApplyPalette("Graphite")
    demo.RefreshStaticColors()
    demo.LayoutControls()
    demo.OnSliderChange()
    demo.OnReset()
    demo.Destroy()
}

class ADW_Theme {
    static Colors := Map()
    static Brushes := Map()
    static Palettes := Map()
    static ActivePalette := "Midnight"
    static _initialized := false
    static _exitRegistered := false

    static Initialize() {
        if this._initialized
            return

        this.BuildPalettes()
        this.ApplyPalette(this.ActivePalette, false)

        if !this._exitRegistered {
            OnExit(ObjBindMethod(this, "Cleanup"))
            this._exitRegistered := true
        }

        this._initialized := true
    }

    static BuildPalettes() {
        if this.Palettes.Count
            return

        midnight := Map()
        midnight["Background"] := 0x101418
        midnight["Surface"] := 0x171C22
        midnight["SurfaceAlt"] := 0x20262E
        midnight["Control"] := 0x242B34
        midnight["ControlHover"] := 0x303946
        midnight["ControlActive"] := 0x394656
        midnight["Text"] := 0xF0F4F8
        midnight["SubtleText"] := 0x9AA7B5
        midnight["MutedText"] := 0x707B87
        midnight["Accent"] := 0x2D8CFF
        midnight["AccentHover"] := 0x58A6FF
        midnight["AccentActive"] := 0x0969DA
        midnight["AccentText"] := 0xFFFFFF
        midnight["Border"] := 0x35404D
        midnight["Grid"] := 0x2A333D
        midnight["Selection"] := 0x184F80
        midnight["Warning"] := 0xE0A82E
        midnight["Success"] := 0x2EA043
        midnight["Danger"] := 0xF85149
        midnight["PanelShadow"] := 0x0B0E11
        this.Palettes["Midnight"] := midnight

        graphite := Map()
        graphite["Background"] := 0x151515
        graphite["Surface"] := 0x1D1D1D
        graphite["SurfaceAlt"] := 0x282828
        graphite["Control"] := 0x2F2F2F
        graphite["ControlHover"] := 0x3B3B3B
        graphite["ControlActive"] := 0x4A4A4A
        graphite["Text"] := 0xF5F5F5
        graphite["SubtleText"] := 0xB5B5B5
        graphite["MutedText"] := 0x808080
        graphite["Accent"] := 0x00A884
        graphite["AccentHover"] := 0x19C7A0
        graphite["AccentActive"] := 0x008F70
        graphite["AccentText"] := 0xFFFFFF
        graphite["Border"] := 0x464646
        graphite["Grid"] := 0x333333
        graphite["Selection"] := 0x176C5B
        graphite["Warning"] := 0xD29922
        graphite["Success"] := 0x3FB950
        graphite["Danger"] := 0xFF6B64
        graphite["PanelShadow"] := 0x0E0E0E
        this.Palettes["Graphite"] := graphite

        contrast := Map()
        contrast["Background"] := 0x050505
        contrast["Surface"] := 0x111111
        contrast["SurfaceAlt"] := 0x1B1B1B
        contrast["Control"] := 0x242424
        contrast["ControlHover"] := 0x383838
        contrast["ControlActive"] := 0x4F4F4F
        contrast["Text"] := 0xFFFFFF
        contrast["SubtleText"] := 0xD6D6D6
        contrast["MutedText"] := 0xA8A8A8
        contrast["Accent"] := 0xFFB000
        contrast["AccentHover"] := 0xFFC34D
        contrast["AccentActive"] := 0xD99600
        contrast["AccentText"] := 0x101010
        contrast["Border"] := 0x666666
        contrast["Grid"] := 0x3A3A3A
        contrast["Selection"] := 0x8A6200
        contrast["Warning"] := 0xFFB000
        contrast["Success"] := 0x4FE36E
        contrast["Danger"] := 0xFF5C5C
        contrast["PanelShadow"] := 0x000000
        this.Palettes["HighContrast"] := contrast
    }

    static ApplyPalette(name, redraw := true) {
        this.BuildPalettes()
        if !this.Palettes.Has(name)
            name := "Midnight"

        this.ActivePalette := name
        palette := this.Palettes[name]

        for key, value in palette
            this.SetColor(key, value, false)

        if redraw
            ADW_Gui.RedrawAll()
    }

    static SetColor(name, value, redraw := true) {
        if this.Brushes.Has(name) && this.Brushes[name]
            DllCall("gdi32\DeleteObject", "Ptr", this.Brushes[name], "Int")

        this.Colors[name] := value
        this.Brushes[name] := DllCall("gdi32\CreateSolidBrush", "UInt", this.RgbToBgr(value), "Ptr")

        if redraw
            ADW_Gui.RedrawAll()
    }

    static GetColor(name) {
        this.Initialize()
        return this.Colors.Has(name) ? this.Colors[name] : 0
    }

    static GetBrush(name) {
        this.Initialize()
        if this.Brushes.Has(name)
            return this.Brushes[name]
        return 0
    }

    static Hex(name) {
        return Format("{:06X}", this.GetColor(name))
    }

    static Scale(value) {
        return Round(value * A_ScreenDPI / 96)
    }

    static RgbToBgr(rgb) {
        return ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF)
    }

    static BgrToRgb(bgr) {
        return this.RgbToBgr(bgr)
    }

    static SetDcColors(hdc, textName, backName) {
        DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", this.RgbToBgr(this.GetColor(textName)), "UInt")
        DllCall("gdi32\SetBkColor", "Ptr", hdc, "UInt", this.RgbToBgr(this.GetColor(backName)), "UInt")
    }

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
        style := ADW_WinApi.GetWindowLong(hwnd, GWL_STYLE)
        exStyle := ADW_WinApi.GetWindowLong(hwnd, GWL_EXSTYLE)
        ADW_WinApi.SetWindowLong(hwnd, GWL_STYLE, style & ~WS_BORDER)
        ADW_WinApi.SetWindowLong(hwnd, GWL_EXSTYLE, exStyle & ~(WS_EX_CLIENTEDGE | WS_EX_STATICEDGE))
        DllCall("user32\SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER, "Int")
    }

    static Cleanup(*) {
        for name, brush in this.Brushes {
            if brush
                DllCall("gdi32\DeleteObject", "Ptr", brush, "Int")
        }
        this.Brushes.Clear()
        this._initialized := false
    }
}

class ADW_WinApi {
    static GetWindowLong(hwnd, index) {
        fn := A_PtrSize = 8 ? "user32\GetWindowLongPtr" : "user32\GetWindowLong"
        return DllCall(fn, "Ptr", hwnd, "Int", index, "Ptr")
    }

    static SetWindowLong(hwnd, index, value) {
        fn := A_PtrSize = 8 ? "user32\SetWindowLongPtr" : "user32\SetWindowLong"
        return DllCall(fn, "Ptr", hwnd, "Int", index, "Ptr", value, "Ptr")
    }

    static ApplyAppDarkMode() {
        hTheme := DllCall("kernel32\LoadLibrary", "Str", "uxtheme.dll", "Ptr")
        if !hTheme
            return false

        setPreferredAppMode := DllCall("kernel32\GetProcAddress", "Ptr", hTheme, "Ptr", 135, "Ptr")
        flushMenuThemes := DllCall("kernel32\GetProcAddress", "Ptr", hTheme, "Ptr", 136, "Ptr")

        if setPreferredAppMode
            DllCall(setPreferredAppMode, "Int", 2, "Int")
        if flushMenuThemes
            DllCall(flushMenuThemes, "Int")
        return true
    }

    static AllowDarkModeForWindow(hwnd, allow := true) {
        hTheme := DllCall("kernel32\LoadLibrary", "Str", "uxtheme.dll", "Ptr")
        if !hTheme
            return false

        allowDarkModeForWindow := DllCall("kernel32\GetProcAddress", "Ptr", hTheme, "Ptr", 133, "Ptr")
        if !allowDarkModeForWindow
            return false

        return DllCall(allowDarkModeForWindow, "Ptr", hwnd, "Int", allow, "Int") != 0
    }

    static SetWindowTheme(hwnd, appName := "DarkMode_Explorer", subId := "") {
        ADW_WinApi.AllowDarkModeForWindow(hwnd, true)
        return DllCall("uxtheme\SetWindowTheme", "Ptr", hwnd, "Str", appName, "Str", subId, "Int")
    }

    static ApplyChrome(hwnd) {
        if VerCompare(A_OSVersion, "10.0.17763") < 0
            return false

        darkAttr := VerCompare(A_OSVersion, "10.0.18985") >= 0 ? 20 : 19
        enabled := 1
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", darkAttr, "Int*", enabled, "Int", 4, "Int")

        if VerCompare(A_OSVersion, "10.0.22000") >= 0 {
            cornerPref := 2
            backdrop := 2
            borderColor := ADW_Theme.RgbToBgr(ADW_Theme.GetColor("Border"))
            captionColor := ADW_Theme.RgbToBgr(ADW_Theme.GetColor("Surface"))
            textColor := ADW_Theme.RgbToBgr(ADW_Theme.GetColor("Text"))
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 33, "Int*", cornerPref, "Int", 4, "Int")
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 34, "Int*", borderColor, "Int", 4, "Int")
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 35, "Int*", captionColor, "Int", 4, "Int")
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 36, "Int*", textColor, "Int", 4, "Int")
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", 38, "Int*", backdrop, "Int", 4, "Int")
        }
        return true
    }

    static Redraw(hwnd) {
        static RDW_INVALIDATE := 0x0001
        static RDW_UPDATENOW := 0x0100
        static RDW_ALLCHILDREN := 0x0080
        static RDW_FRAME := 0x0400
        DllCall("user32\RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", RDW_INVALIDATE | RDW_UPDATENOW | RDW_ALLCHILDREN | RDW_FRAME, "Int")
    }

    static Invalidate(hwnd) {
        DllCall("user32\InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", true, "Int")
    }

    static TrackMouseLeave(hwnd) {
        size := A_PtrSize = 8 ? 24 : 16
        tme := Buffer(size, 0)
        NumPut("UInt", size, tme, 0)
        NumPut("UInt", 0x00000002, tme, 4)
        NumPut("Ptr", hwnd, tme, 8)
        return DllCall("user32\TrackMouseEvent", "Ptr", tme, "Int")
    }

    static GetClassName(hwnd) {
        buf := Buffer(512, 0)
        len := DllCall("user32\GetClassNameW", "Ptr", hwnd, "Ptr", buf, "Int", 256, "Int")
        if len <= 0
            return ""
        return StrGet(buf, len, "UTF-16")
    }

    static LoWord(value) {
        result := value & 0xFFFF
        return result > 0x7FFF ? result - 0x10000 : result
    }

    static HiWord(value) {
        result := (value >> 16) & 0xFFFF
        return result > 0x7FFF ? result - 0x10000 : result
    }
}

class ADW_Subclass {
    static Callbacks := Map()
    static OldProcs := Map()

    static Install(hwnd, boundProc) {
        if this.OldProcs.Has(hwnd)
            return false

        callback := CallbackCreate(boundProc, , 4)
        oldProc := ADW_WinApi.SetWindowLong(hwnd, -4, callback)
        if !oldProc {
            CallbackFree(callback)
            return false
        }

        this.Callbacks[hwnd] := callback
        this.OldProcs[hwnd] := oldProc
        return true
    }

    static Uninstall(hwnd) {
        if !this.OldProcs.Has(hwnd)
            return

        ADW_WinApi.SetWindowLong(hwnd, -4, this.OldProcs[hwnd])
        CallbackFree(this.Callbacks[hwnd])
        this.Callbacks.Delete(hwnd)
        this.OldProcs.Delete(hwnd)
    }

    static CallOriginal(hwnd, msg, wParam, lParam) {
        if !this.OldProcs.Has(hwnd)
            return DllCall("user32\DefWindowProcW", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")

        return DllCall("user32\CallWindowProcW", "Ptr", this.OldProcs[hwnd], "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }
}

class ADW_DarkButton {
    static Instances := Map()

    __New(gui, options := "", text := "", variant := "default") {
        ADW_Theme.Initialize()
        this.parentGui := gui
        this._text := text
        this.variant := variant
        this.hover := false
        this.pressed := false
        this._enabled := true
        this.clickHandler := 0

        cleanOptions := RegExReplace(options, "i)\bDefault\b|\+Accent")
        cleanOptions .= " +0x100 +0x200 +0x1 +0x4000000"
        this.ctrl := gui.Add("Text", cleanOptions, text)
        this.ctrl.SetFont("s9 c" ADW_Theme.Hex(variant = "accent" ? "AccentText" : "Text"), "Segoe UI")
        this.ctrl.Opt("+Background" ADW_Theme.Hex(variant = "accent" ? "Accent" : "Control"))
        ADW_DarkButton.Instances[this.ctrl.Hwnd] := this
        ADW_Subclass.Install(this.ctrl.Hwnd, ObjBindMethod(this, "Proc"))
    }

    Hwnd => this.ctrl.Hwnd

    Text {
        get {
            return this._text
        }
        set {
            this._text := value
            this.ctrl.Text := value
            this.Redraw()
        }
    }

    Enabled {
        get {
            return this._enabled
        }
        set {
            this._enabled := value ? true : false
            this.ctrl.Enabled := this._enabled
            this.Redraw()
        }
    }

    OnEvent(eventName, callback) {
        if eventName = "Click"
            this.clickHandler := callback
    }

    Move(x?, y?, w?, h?) {
        this.ctrl.Move(x?, y?, w?, h?)
        this.Redraw()
    }

    Focus() {
        this.ctrl.Focus()
    }

    Redraw() {
        ADW_WinApi.Invalidate(this.ctrl.Hwnd)
    }

    Destroy() {
        ADW_Subclass.Uninstall(this.ctrl.Hwnd)
        if ADW_DarkButton.Instances.Has(this.ctrl.Hwnd)
            ADW_DarkButton.Instances.Delete(this.ctrl.Hwnd)
    }

    Proc(hwnd, msg, wParam, lParam) {
        static WM_PAINT := 0x000F
        static WM_ERASEBKGND := 0x0014
        static WM_MOUSEMOVE := 0x0200
        static WM_MOUSELEAVE := 0x02A3
        static WM_LBUTTONDOWN := 0x0201
        static WM_LBUTTONUP := 0x0202
        static WM_CAPTURECHANGED := 0x0215
        static WM_SETCURSOR := 0x0020

        if msg = WM_ERASEBKGND
            return 1

        if msg = WM_PAINT {
            this.Paint(hwnd)
            return 0
        }

        if msg = WM_MOUSEMOVE {
            this.HandleMouseMove(hwnd)
            return 0
        }

        if msg = WM_MOUSELEAVE {
            this.hover := false
            this.Redraw()
            return 0
        }

        if msg = WM_LBUTTONDOWN {
            if this._enabled {
                this.pressed := true
                DllCall("user32\SetCapture", "Ptr", hwnd, "Ptr")
                this.Redraw()
            }
            return 0
        }

        if msg = WM_LBUTTONUP {
            wasPressed := this.pressed
            this.pressed := false
            DllCall("user32\ReleaseCapture", "Int")
            this.Redraw()
            if wasPressed && this._enabled && this.IsPointInside(lParam) && this.clickHandler
                this.clickHandler.Call(this)
            return 0
        }

        if msg = WM_CAPTURECHANGED {
            this.pressed := false
            this.Redraw()
            return 0
        }

        if msg = WM_SETCURSOR {
            DllCall("user32\SetCursor", "Ptr", DllCall("user32\LoadCursor", "Ptr", 0, "Ptr", 32649, "Ptr"), "Ptr")
            return 1
        }

        return ADW_Subclass.CallOriginal(hwnd, msg, wParam, lParam)
    }

    HandleMouseMove(hwnd) {
        if !this.hover {
            this.hover := true
            ADW_WinApi.TrackMouseLeave(hwnd)
            this.Redraw()
        }
    }

    IsPointInside(lParam) {
        x := ADW_WinApi.LoWord(lParam)
        y := ADW_WinApi.HiWord(lParam)
        rc := Buffer(16, 0)
        DllCall("user32\GetClientRect", "Ptr", this.ctrl.Hwnd, "Ptr", rc, "Int")
        w := NumGet(rc, 8, "Int")
        h := NumGet(rc, 12, "Int")
        return x >= 0 && y >= 0 && x < w && y < h
    }

    Paint(hwnd) {
        psSize := A_PtrSize = 8 ? 72 : 64
        ps := Buffer(psSize, 0)
        hdc := DllCall("user32\BeginPaint", "Ptr", hwnd, "Ptr", ps, "Ptr")
        rc := Buffer(16, 0)
        DllCall("user32\GetClientRect", "Ptr", hwnd, "Ptr", rc, "Int")

        backName := this.GetBackColorName()
        textName := this.GetTextColorName()
        borderName := this.variant = "accent" ? "AccentHover" : "Border"

        brush := ADW_Theme.GetBrush(backName)
        pen := DllCall("gdi32\CreatePen", "Int", 0, "Int", 1, "UInt", ADW_Theme.RgbToBgr(ADW_Theme.GetColor(borderName)), "Ptr")
        oldBrush := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", brush, "Ptr")
        oldPen := DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", pen, "Ptr")

        w := NumGet(rc, 8, "Int")
        h := NumGet(rc, 12, "Int")
        radius := ADW_Theme.Scale(10)
        DllCall("gdi32\RoundRect", "Ptr", hdc, "Int", 0, "Int", 0, "Int", w, "Int", h, "Int", radius, "Int", radius, "Int")

        DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", oldBrush, "Ptr")
        DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr", oldPen, "Ptr")
        DllCall("gdi32\DeleteObject", "Ptr", pen, "Int")

        DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", 1, "Int")
        DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", ADW_Theme.RgbToBgr(ADW_Theme.GetColor(textName)), "UInt")
        DllCall("user32\DrawTextW", "Ptr", hdc, "Str", this._text, "Int", -1, "Ptr", rc, "UInt", 0x00000001 | 0x00000004 | 0x00000020 | 0x00000800, "Int")
        DllCall("user32\EndPaint", "Ptr", hwnd, "Ptr", ps, "Int")
    }

    GetBackColorName() {
        if !this._enabled
            return "SurfaceAlt"
        if this.variant = "accent" {
            if this.pressed
                return "AccentActive"
            if this.hover
                return "AccentHover"
            return "Accent"
        }
        if this.pressed
            return "ControlActive"
        if this.hover
            return "ControlHover"
        return "Control"
    }

    GetTextColorName() {
        if !this._enabled
            return "MutedText"
        return this.variant = "accent" ? "AccentText" : "Text"
    }
}

class ADW_WindowProc {
    __New(gui) {
        this.gui := gui
        this.hwnd := gui.Hwnd
        ADW_Subclass.Install(this.hwnd, ObjBindMethod(this, "Proc"))
    }

    Destroy() {
        ADW_Subclass.Uninstall(this.hwnd)
    }

    Proc(hwnd, msg, wParam, lParam) {
        static WM_CTLCOLOREDIT := 0x0133
        static WM_CTLCOLORLISTBOX := 0x0134
        static WM_CTLCOLORBTN := 0x0135
        static WM_CTLCOLORSTATIC := 0x0138
        static WM_CTLCOLORDLG := 0x0136
        static WM_THEMECHANGED := 0x031A
        static WM_SETTINGCHANGE := 0x001A

        switch msg {
            case WM_CTLCOLOREDIT:
                ADW_Theme.SetDcColors(wParam, "Text", "Control")
                return ADW_Theme.GetBrush("Control")
            case WM_CTLCOLORLISTBOX:
                ADW_Theme.SetDcColors(wParam, "Text", "Control")
                return ADW_Theme.GetBrush("Control")
            case WM_CTLCOLORBTN:
                ADW_Theme.SetDcColors(wParam, "Text", "Background")
                return ADW_Theme.GetBrush("Background")
            case WM_CTLCOLORSTATIC:
                ADW_Theme.SetDcColors(wParam, "Text", "Background")
                return ADW_Theme.GetBrush("Background")
            case WM_CTLCOLORDLG:
                return ADW_Theme.GetBrush("Background")
            case WM_THEMECHANGED, WM_SETTINGCHANGE:
                this.gui.ApplyThemeToAllControls()
                ADW_WinApi.ApplyChrome(hwnd)
                ADW_WinApi.Redraw(hwnd)
                return 0
        }

        return ADW_Subclass.CallOriginal(hwnd, msg, wParam, lParam)
    }
}

class ADW_Gui extends Gui {
    static Instances := Map()

    __New(options := "", title := A_ScriptName) {
        ADW_Theme.Initialize()
        ADW_WinApi.ApplyAppDarkMode()
        super.__New(options, title)
        this.controlsByHwnd := Map()
        this.customButtons := []
        this.disposed := false
        this.BackColor := ADW_Theme.GetColor("Background")
        this.SetFont("s9 c" ADW_Theme.Hex("Text"), "Segoe UI")
        ADW_WinApi.ApplyChrome(this.Hwnd)
        this.windowProc := ADW_WindowProc(this)
        ADW_Gui.Instances[this.Hwnd] := this
    }

    Add(controlType, options := "", content?) {
        isAccent := InStr(options, "+Accent") > 0
        if isAccent
            options := StrReplace(options, "+Accent")

        switch controlType, false {
            case "Button":
                button := ADW_DarkButton(this, options, content?, isAccent ? "accent" : "default")
                this.customButtons.Push(button)
                this.controlsByHwnd[button.Hwnd] := "Button"
                return button
            case "Text":
                if !RegExMatch(options, "i)\bc[0-9A-Fa-f]+\b")
                    options .= " c" ADW_Theme.Hex("Text")
                ctrl := super.Add(controlType, options, content?)
                this.controlsByHwnd[ctrl.Hwnd] := controlType
                return ctrl
            default:
                ctrl := super.Add(controlType, options, content?)
                this.StyleControl(ctrl, controlType)
                this.controlsByHwnd[ctrl.Hwnd] := controlType
                return ctrl
        }
    }

    StyleControl(ctrl, controlType) {
        ctrl.SetFont("c" ADW_Theme.Hex("Text"), "Segoe UI")

        switch controlType, false {
            case "Edit":
                ADW_WinApi.SetWindowTheme(ctrl.Hwnd, "DarkMode_Explorer")
                ADW_Theme.RemoveBorder(ctrl.Hwnd)
            case "ComboBox", "DropDownList":
                ADW_WinApi.SetWindowTheme(ctrl.Hwnd, "DarkMode_CFD")
            case "ListBox":
                ADW_WinApi.SetWindowTheme(ctrl.Hwnd, "DarkMode_Explorer")
                ADW_Theme.RemoveBorder(ctrl.Hwnd)
            case "ListView":
                ADW_WinApi.SetWindowTheme(ctrl.Hwnd, "ItemsView")
                this.StyleListView(ctrl)
            case "TreeView":
                ADW_WinApi.SetWindowTheme(ctrl.Hwnd, "DarkMode_Explorer")
                this.StyleTreeView(ctrl)
                ADW_Theme.RemoveBorder(ctrl.Hwnd)
            case "CheckBox", "Radio":
                ADW_WinApi.SetWindowTheme(ctrl.Hwnd, "DarkMode_Explorer")
            case "Slider":
                ADW_WinApi.SetWindowTheme(ctrl.Hwnd, "DarkMode_Explorer")
            case "Progress":
                this.StyleProgress(ctrl)
        }
    }

    StyleListView(ctrl) {
        static LVM_SETBKCOLOR := 0x1001
        static LVM_SETTEXTCOLOR := 0x1024
        static LVM_SETTEXTBKCOLOR := 0x1026
        static LVM_GETHEADER := 0x101F
        SendMessage(LVM_SETBKCOLOR, 0, ADW_Theme.RgbToBgr(ADW_Theme.GetColor("Control")), ctrl.Hwnd)
        SendMessage(LVM_SETTEXTCOLOR, 0, ADW_Theme.RgbToBgr(ADW_Theme.GetColor("Text")), ctrl.Hwnd)
        SendMessage(LVM_SETTEXTBKCOLOR, 0, ADW_Theme.RgbToBgr(ADW_Theme.GetColor("Control")), ctrl.Hwnd)
        header := SendMessage(LVM_GETHEADER, 0, 0, ctrl.Hwnd)
        if header
            ADW_WinApi.SetWindowTheme(header, "ItemsView")
    }

    StyleTreeView(ctrl) {
        static TVM_SETBKCOLOR := 0x111D
        static TVM_SETTEXTCOLOR := 0x111E
        static TVM_SETLINECOLOR := 0x1128
        SendMessage(TVM_SETBKCOLOR, 0, ADW_Theme.RgbToBgr(ADW_Theme.GetColor("Control")), ctrl.Hwnd)
        SendMessage(TVM_SETTEXTCOLOR, 0, ADW_Theme.RgbToBgr(ADW_Theme.GetColor("Text")), ctrl.Hwnd)
        SendMessage(TVM_SETLINECOLOR, 0, ADW_Theme.RgbToBgr(ADW_Theme.GetColor("Border")), ctrl.Hwnd)
    }

    StyleProgress(ctrl) {
        static PBM_SETBARCOLOR := 0x0409
        static PBM_SETBKCOLOR := 0x2001
        SendMessage(PBM_SETBARCOLOR, 0, ADW_Theme.RgbToBgr(ADW_Theme.GetColor("Accent")), ctrl.Hwnd)
        SendMessage(PBM_SETBKCOLOR, 0, ADW_Theme.RgbToBgr(ADW_Theme.GetColor("Control")), ctrl.Hwnd)
    }

    ApplyThemeToAllControls() {
        this.BackColor := ADW_Theme.GetColor("Background")
        this.SetFont("s9 c" ADW_Theme.Hex("Text"), "Segoe UI")
        for hwnd, controlType in this.controlsByHwnd {
            if controlType = "Button"
                continue
            try {
                ctrl := GuiCtrlFromHwnd(hwnd)
                this.StyleControl(ctrl, controlType)
            } catch as err {
                OutputDebug("AdvancedDarkWinApiGui stale control hwnd " hwnd ": " err.Message)
            }
        }
        for button in this.customButtons
            button.Redraw()
        ADW_WinApi.ApplyChrome(this.Hwnd)
        ADW_WinApi.Redraw(this.Hwnd)
    }

    Dispose() {
        if this.disposed
            return

        this.disposed := true
        for button in this.customButtons
            button.Destroy()
        this.customButtons := []
        if this.windowProc
            this.windowProc.Destroy()
        if ADW_Gui.Instances.Has(this.Hwnd)
            ADW_Gui.Instances.Delete(this.Hwnd)
    }

    __Delete() {
        this.Dispose()
    }

    static RedrawAll() {
        for hwnd, gui in ADW_Gui.Instances {
            if DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
                gui.ApplyThemeToAllControls()
        }
    }
}

class ADW_AdvancedDarkDemo {
    __New(autoShow := true) {
        this.controls := Map()
        this.metrics := Map()
        this.themeGui := ADW_Gui("+Resize +MinSize880x620", "Advanced Dark WinAPI GUI")
        this.themeGui.MarginX := 18
        this.themeGui.MarginY := 16
        this.BuildMetrics(980, 680)
        this.BuildUi()
        this.LoadSampleData()
        this.BindEvents()
        if autoShow
            this.Show()
    }

    BuildMetrics(width, height) {
        this.metrics["width"] := Max(width, 880)
        this.metrics["height"] := Max(height, 620)
        this.metrics["pad"] := 18
        this.metrics["sidebarW"] := 210
        this.metrics["topH"] := 72
        this.metrics["statusH"] := 36
        this.metrics["contentX"] := this.metrics["sidebarW"] + this.metrics["pad"]
        this.metrics["contentY"] := this.metrics["topH"] + this.metrics["pad"]
        this.metrics["contentW"] := this.metrics["width"] - this.metrics["contentX"] - this.metrics["pad"]
        this.metrics["contentH"] := this.metrics["height"] - this.metrics["contentY"] - this.metrics["statusH"] - this.metrics["pad"]
    }

    BuildUi() {
        gui := this.themeGui
        m := this.metrics

        this.controls["sidebarFill"] := gui.Add("Progress", "x0 y0 w" m["sidebarW"] " h" m["height"] " Background" ADW_Theme.Hex("Surface") " c" ADW_Theme.Hex("Surface"), 100)
        this.controls["topFill"] := gui.Add("Progress", "x" m["sidebarW"] " y0 w" (m["width"] - m["sidebarW"]) " h" m["topH"] " Background" ADW_Theme.Hex("Background") " c" ADW_Theme.Hex("Background"), 100)
        this.controls["title"] := gui.Add("Text", "x24 y20 w170 h24 c" ADW_Theme.Hex("Text"), "WinAPI Dark")
        this.controls["subtitle"] := gui.Add("Text", "x24 y45 w170 h18 c" ADW_Theme.Hex("SubtleText"), "DWM + UxTheme + GDI")

        this.controls["nav1"] := gui.Add("Text", "x24 y104 w160 h24 c" ADW_Theme.Hex("Accent"), "Dashboard")
        this.controls["nav2"] := gui.Add("Text", "x24 y136 w160 h24 c" ADW_Theme.Hex("SubtleText"), "Controls")
        this.controls["nav3"] := gui.Add("Text", "x24 y168 w160 h24 c" ADW_Theme.Hex("SubtleText"), "Telemetry")
        this.controls["nav4"] := gui.Add("Text", "x24 y200 w160 h24 c" ADW_Theme.Hex("SubtleText"), "Theme")

        this.controls["header"] := gui.Add("Text", "x" m["contentX"] " y18 w420 h28 c" ADW_Theme.Hex("Text"), "Advanced dark mode control surface")
        this.controls["headerSub"] := gui.Add("Text", "x" m["contentX"] " y46 w520 h18 c" ADW_Theme.Hex("SubtleText"), "Owner drawn buttons, dark native controls, DWM chrome, palette switching, and responsive layout")

        themeX := m["width"] - 248
        this.controls["themeLabel"] := gui.Add("Text", "x" themeX " y22 w68 h20 c" ADW_Theme.Hex("SubtleText"), "Palette")
        this.controls["themeDrop"] := gui.Add("DropDownList", "x" (themeX + 70) " y18 w150 h120 Choose1", ["Midnight", "Graphite", "HighContrast"])

        this.controls["searchLabel"] := gui.Add("Text", "x" m["contentX"] " y" m["contentY"] " w120 h20 c" ADW_Theme.Hex("SubtleText"), "Quick filter")
        this.controls["searchEdit"] := gui.Add("Edit", "x" m["contentX"] " y" (m["contentY"] + 23) " w300 h30", "Find script, module, or control")
        this.controls["categoryDrop"] := gui.Add("ComboBox", "x" (m["contentX"] + 318) " y" (m["contentY"] + 23) " w180 h120 Choose1", ["All modules", "GUI", "WinAPI", "Controls", "Testing"])
        this.controls["applyBtn"] := gui.Add("Button", "+Accent x" (m["contentX"] + 516) " y" (m["contentY"] + 22) " w120 h34", "Apply")
        this.controls["resetBtn"] := gui.Add("Button", "x" (m["contentX"] + 646) " y" (m["contentY"] + 22) " w96 h34", "Reset")

        listY := m["contentY"] + 74
        listH := Max(238, m["contentH"] - 184)
        this.controls["listTitle"] := gui.Add("Text", "x" m["contentX"] " y" listY " w240 h22 c" ADW_Theme.Hex("Text"), "Themed ListView")
        this.controls["taskList"] := gui.Add("ListView", "x" m["contentX"] " y" (listY + 28) " w" (m["contentW"] - 266) " h" listH " +Grid", ["Component", "Layer", "State", "Detail"])

        sideX := m["contentX"] + m["contentW"] - 246
        this.controls["optionTitle"] := gui.Add("Text", "x" sideX " y" listY " w220 h22 c" ADW_Theme.Hex("Text"), "Runtime options")
        this.controls["chkDwm"] := gui.Add("CheckBox", "x" sideX " y" (listY + 34) " w190 h24 +Checked", "DWM dark chrome")
        this.controls["chkMenus"] := gui.Add("CheckBox", "x" sideX " y" (listY + 62) " w190 h24 +Checked", "Dark popup menus")
        this.controls["chkBorders"] := gui.Add("CheckBox", "x" sideX " y" (listY + 90) " w190 h24 +Checked", "Flat edit borders")
        this.controls["radioCompact"] := gui.Add("Radio", "x" sideX " y" (listY + 132) " w190 h24 +Checked Group", "Compact density")
        this.controls["radioComfort"] := gui.Add("Radio", "x" sideX " y" (listY + 160) " w190 h24", "Comfort density")
        this.controls["treeTitle"] := gui.Add("Text", "x" sideX " y" (listY + 204) " w220 h22 c" ADW_Theme.Hex("Text"), "Control tree")
        this.controls["controlTree"] := gui.Add("TreeView", "x" sideX " y" (listY + 232) " w220 h" Max(92, listH - 204))

        bottomY := listY + listH + 42
        this.controls["sliderLabel"] := gui.Add("Text", "x" m["contentX"] " y" bottomY " w210 h20 c" ADW_Theme.Hex("SubtleText"), "Accent strength: 72")
        this.controls["accentSlider"] := gui.Add("Slider", "x" m["contentX"] " y" (bottomY + 24) " w260 h32 Range0-100 ToolTip", 72)
        this.controls["progress"] := gui.Add("Progress", "x" (m["contentX"] + 286) " y" (bottomY + 28) " w220 h20", 72)
        this.controls["logBox"] := gui.Add("Edit", "x" (m["contentX"] + 530) " y" bottomY " w" Max(220, m["contentW"] - 530) " h58 +Multi -Wrap ReadOnly", "Ready`r`nWinAPI layers initialized")

        this.controls["statusFill"] := gui.Add("Progress", "x" m["sidebarW"] " y" (m["height"] - m["statusH"]) " w" (m["width"] - m["sidebarW"]) " h" m["statusH"] " Background" ADW_Theme.Hex("SurfaceAlt") " c" ADW_Theme.Hex("SurfaceAlt"), 100)
        this.controls["status"] := gui.Add("Text", "x" m["contentX"] " y" (m["height"] - 27) " w620 h20 c" ADW_Theme.Hex("SubtleText"), "Ready | Four layers active")
    }

    LoadSampleData() {
        lv := this.controls["taskList"]
        lv.Add("", "ADW_Gui", "Window", "Active", "Subclassed parent WndProc with WM_CTLCOLOR handling")
        lv.Add("", "ADW_DarkButton", "GDI", "Active", "Owner drawn hover and pressed states")
        lv.Add("", "ListView", "UxTheme", "Active", "ItemsView theme and dark color messages")
        lv.Add("", "TreeView", "UxTheme", "Active", "DarkMode_Explorer with explicit BGR colors")
        lv.Add("", "DWM chrome", "Dwmapi", "Active", "Dark title bar, border color, rounded corners")
        lv.Add("", "Palette", "Theme", "Active", "Runtime brush recreation and full redraw")
        lv.ModifyCol(1, 150)
        lv.ModifyCol(2, 100)
        lv.ModifyCol(3, 80)
        lv.ModifyCol(4, 360)

        tv := this.controls["controlTree"]
        root := tv.Add("AdvancedDarkWinApiGui", , "Expand")
        nativeNode := tv.Add("Native controls", root, "Expand")
        tv.Add("Edit", nativeNode)
        tv.Add("ComboBox", nativeNode)
        tv.Add("ListView", nativeNode)
        tv.Add("TreeView", nativeNode)
        customNode := tv.Add("Custom controls", root, "Expand")
        tv.Add("Owner drawn button", customNode)
        tv.Add("Responsive layout", customNode)
    }

    BindEvents() {
        this.controls["applyBtn"].OnEvent("Click", this.OnApply.Bind(this))
        this.controls["resetBtn"].OnEvent("Click", this.OnReset.Bind(this))
        this.controls["themeDrop"].OnEvent("Change", this.OnThemeChange.Bind(this))
        this.controls["accentSlider"].OnEvent("Change", this.OnSliderChange.Bind(this))
        this.controls["taskList"].OnEvent("ItemSelect", this.OnListSelect.Bind(this))
        this.controls["categoryDrop"].OnEvent("Change", this.OnCategoryChange.Bind(this))
        this.controls["searchEdit"].OnEvent("Change", this.OnSearchChange.Bind(this))
        this.themeGui.OnEvent("Size", this.OnResize.Bind(this))
        this.themeGui.OnEvent("Close", this.OnClose.Bind(this))
        this.themeGui.OnEvent("Escape", this.OnClose.Bind(this))
    }

    Show() {
        this.themeGui.Show("w" this.metrics["width"] " h" this.metrics["height"])
    }

    Destroy() {
        this.themeGui.Dispose()
        this.themeGui.Destroy()
    }

    OnClose(*) {
        this.Destroy()
        ExitApp()
    }

    OnApply(*) {
        this.Log("Applied current filter and theme settings")
        this.controls["status"].Text := "Applied | " FormatTime(A_Now, "HH:mm:ss")
    }

    OnReset(*) {
        this.controls["searchEdit"].Text := ""
        this.controls["categoryDrop"].Choose(1)
        this.controls["accentSlider"].Value := 72
        this.OnSliderChange()
        this.Log("Reset controls to defaults")
    }

    OnThemeChange(*) {
        name := this.controls["themeDrop"].Text
        ADW_Theme.ApplyPalette(name)
        this.RefreshStaticColors()
        this.Log("Palette changed to " name)
    }

    OnSliderChange(*) {
        value := this.controls["accentSlider"].Value
        this.controls["progress"].Value := value
        this.controls["sliderLabel"].Text := "Accent strength: " value
        this.controls["status"].Text := "Accent strength " value " | " ADW_Theme.ActivePalette
    }

    OnListSelect(*) {
        row := this.controls["taskList"].GetNext()
        if row
            this.controls["status"].Text := "Selected " this.controls["taskList"].GetText(row, 1)
    }

    OnCategoryChange(*) {
        this.Log("Category set to " this.controls["categoryDrop"].Text)
    }

    OnSearchChange(*) {
        text := this.controls["searchEdit"].Text
        if text = ""
            this.controls["status"].Text := "Search cleared"
        else
            this.controls["status"].Text := "Searching for " text
    }

    OnResize(guiObj, minMax, width, height) {
        if minMax = -1
            return

        this.BuildMetrics(width, height)
        this.LayoutControls()
    }

    LayoutControls() {
        m := this.metrics
        this.controls["sidebarFill"].Move(0, 0, m["sidebarW"], m["height"])
        this.controls["topFill"].Move(m["sidebarW"], 0, m["width"] - m["sidebarW"], m["topH"])
        this.controls["header"].Move(m["contentX"], 18, Min(520, m["contentW"] - 260), 28)
        this.controls["headerSub"].Move(m["contentX"], 46, Min(620, m["contentW"] - 260), 18)

        themeX := m["width"] - 248
        this.controls["themeLabel"].Move(themeX, 22, 68, 20)
        this.controls["themeDrop"].Move(themeX + 70, 18, 150, 120)

        this.controls["searchLabel"].Move(m["contentX"], m["contentY"], 120, 20)
        this.controls["searchEdit"].Move(m["contentX"], m["contentY"] + 23, 300, 30)
        this.controls["categoryDrop"].Move(m["contentX"] + 318, m["contentY"] + 23, 180, 120)
        this.controls["applyBtn"].Move(m["contentX"] + 516, m["contentY"] + 22, 120, 34)
        this.controls["resetBtn"].Move(m["contentX"] + 646, m["contentY"] + 22, 96, 34)

        listY := m["contentY"] + 74
        listH := Max(238, m["contentH"] - 184)
        sideX := m["contentX"] + m["contentW"] - 246
        this.controls["listTitle"].Move(m["contentX"], listY, 240, 22)
        this.controls["taskList"].Move(m["contentX"], listY + 28, m["contentW"] - 266, listH)
        this.controls["optionTitle"].Move(sideX, listY, 220, 22)
        this.controls["chkDwm"].Move(sideX, listY + 34, 190, 24)
        this.controls["chkMenus"].Move(sideX, listY + 62, 190, 24)
        this.controls["chkBorders"].Move(sideX, listY + 90, 190, 24)
        this.controls["radioCompact"].Move(sideX, listY + 132, 190, 24)
        this.controls["radioComfort"].Move(sideX, listY + 160, 190, 24)
        this.controls["treeTitle"].Move(sideX, listY + 204, 220, 22)
        this.controls["controlTree"].Move(sideX, listY + 232, 220, Max(92, listH - 204))

        bottomY := listY + listH + 42
        this.controls["sliderLabel"].Move(m["contentX"], bottomY, 210, 20)
        this.controls["accentSlider"].Move(m["contentX"], bottomY + 24, 260, 32)
        this.controls["progress"].Move(m["contentX"] + 286, bottomY + 28, 220, 20)
        this.controls["logBox"].Move(m["contentX"] + 530, bottomY, Max(220, m["contentW"] - 530), 58)
        this.controls["statusFill"].Move(m["sidebarW"], m["height"] - m["statusH"], m["width"] - m["sidebarW"], m["statusH"])
        this.controls["status"].Move(m["contentX"], m["height"] - 27, m["contentW"], 20)
    }

    RefreshStaticColors() {
        textControls := ["title", "header", "listTitle", "optionTitle", "treeTitle"]
        for key in textControls
            this.controls[key].SetFont("c" ADW_Theme.Hex("Text"))

        subtleControls := ["subtitle", "headerSub", "themeLabel", "searchLabel", "sliderLabel", "status"]
        for key in subtleControls
            this.controls[key].SetFont("c" ADW_Theme.Hex("SubtleText"))

        this.controls["nav1"].SetFont("c" ADW_Theme.Hex("Accent"))
        for key in ["nav2", "nav3", "nav4"]
            this.controls[key].SetFont("c" ADW_Theme.Hex("SubtleText"))

        this.controls["sidebarFill"].Opt("Background" ADW_Theme.Hex("Surface") " c" ADW_Theme.Hex("Surface"))
        this.controls["topFill"].Opt("Background" ADW_Theme.Hex("Background") " c" ADW_Theme.Hex("Background"))
        this.controls["statusFill"].Opt("Background" ADW_Theme.Hex("SurfaceAlt") " c" ADW_Theme.Hex("SurfaceAlt"))
    }

    Log(message) {
        stamp := FormatTime(A_Now, "HH:mm:ss")
        this.controls["logBox"].Text := stamp "  " message "`r`n" this.controls["logBox"].Text
    }
}
