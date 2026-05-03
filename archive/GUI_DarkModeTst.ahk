
class _DarkExt extends Gui {
    Static OriginalWindowProc := 0
    Static __New() {
    }

    __New(Options := "", Title := A_ScriptName, EventObj?) {
        super.__New(Options, Title, EventObj ?? this)

        this.BackColor := _DarkC.Theme["Background"]

        if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
            DWMWA_USE_IMMERSIVE_DARK_MODE := 19
            if (VerCompare(A_OSVersion, "10.0.18985") >= 0)
                DWMWA_USE_IMMERSIVE_DARK_MODE := 20

            uxtheme := DllCall("kernel32\GetModuleHandle", "Str", "uxtheme", "Ptr")
            SetPreferredAppMode := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
            FlushMenuThemes := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")

            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.hWnd,
                "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", true, "Int", 4)
            DllCall(SetPreferredAppMode, "Int", 2)
            DllCall(FlushMenuThemes)
        }

        this.SetDarkMenu()

        if (!_DarkExt.OriginalWindowProc) {
            _DarkExt.OriginalWindowProc := DllCall("GetWindowLongPtr", "Ptr", this.Hwnd, "Int", -4, "Ptr")
            WindowProc := CallbackCreate(_DarkC.ProcessWindowMessage, "Fast")
            DllCall("SetWindowLongPtr", "Ptr", this.Hwnd, "Int", -4, "Ptr", WindowProc)
        }
    }

    Show(Options := "") {
        result := super.Show(Options)
        DllCall("RedrawWindow", "Ptr", this.Hwnd, "Ptr", 0, "Ptr", 0,
            "UInt", 0x0287)

        return result
    }

    SetDarkMenu() {
        uxtheme := DllCall("GetModuleHandle", "Ptr", StrPtr("uxtheme"), "Ptr")
        SetPreferredAppMode := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
        FlushMenuThemes := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")
        DllCall(SetPreferredAppMode, "Int", 1)
        DllCall(FlushMenuThemes)
    }

    SetWindowAttribute(dwAttribute, pvAttribute?) {
        return DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Hwnd, "Uint", dwAttribute, "Uint*", pvAttribute, "Int", 4)
    }

    CreateStructs() {
        RECT := Map(
            "left", 0,
            "top", 0,
            "right", 0,
            "bottom", 0
        )

        NMHDR := Map(
            "hwndFrom", 0,
            "idFrom", 0,
            "code", 0
        )

        NMCUSTOMDRAW := Map(
            "hdr", NMHDR,
            "dwDrawStage", 0,
            "hdc", 0,
            "rc", RECT,
            "dwItemSpec", 0,
            "uItemState", 0,
            "lItemlParam", 0
        )

        return NMCUSTOMDRAW
    }

    ProcessCustomDraw(lParam) {
        NMCD := this.CreateStructs()  ; Fix: Use this.CreateStructs() instead of just CreateStructs()
        NMCD["hdr"]["hwndFrom"] := NumGet(lParam, 0, "Ptr")
        NMCD["hdr"]["idFrom"] := NumGet(lParam, A_PtrSize, "Ptr")
        NMCD["hdr"]["code"] := NumGet(lParam, A_PtrSize * 2, "UInt")

        rectOffset := A_PtrSize * 2 + 4 + A_PtrSize
        NMCD["rc"]["left"] := NumGet(lParam, rectOffset, "Int")
        NMCD["rc"]["top"] := NumGet(lParam, rectOffset + 4, "Int")
        NMCD["rc"]["right"] := NumGet(lParam, rectOffset + 8, "Int")
        NMCD["rc"]["bottom"] := NumGet(lParam, rectOffset + 12, "Int")

        dwItemSpecOffset := rectOffset + 16
        NMCD["dwItemSpec"] := NumGet(lParam, dwItemSpecOffset, "UPtr")
        NMCD["uItemState"] := NumGet(lParam, dwItemSpecOffset + A_PtrSize, "UInt")
        NMCD["lItemlParam"] := NumGet(lParam, dwItemSpecOffset + A_PtrSize + 4, "Ptr")
        return NMCD
    }
}