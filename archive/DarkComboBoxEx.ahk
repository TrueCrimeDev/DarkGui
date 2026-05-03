#Requires AutoHotkey v2.0
#SingleInstance Force

; Dark Mode ComboBoxEx GUI
; ========================

; Enable dark mode for ALL common controls (must be called BEFORE creating GUI)
SetAppDarkMode(2)  ; 2 = ForceDark

; Dark colors
BG_COLOR := 0x1E1E1E
TEXT_COLOR := 0xE0E0E0
CTRL_BG := 0x2D2D2D

; Create image list
Icons := [74, 77, 80, 82, 94, 95, 101, 102, 103]
HIL := IL_Create(9, 9)
For Icon In Icons
    IL_Add(HIL, "Imageres.dll", Icon)

; Create Dark GUI
Items := ["One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"]
Win := Gui("+DPIScale", "Dark ComboBoxEx")
Win.BackColor := BG_COLOR
Win.MarginX := 20
Win.MarginY := 20
Win.OnEvent("Close", (*) => ExitApp())

; Apply dark title bar
SetWindowAttribute(Win.Hwnd, 20, True)

; Labels
Win.SetFont("s10 cE0E0E0", "Segoe UI")
Win.AddText("xm", "ComboBoxEx - Combo:")
CBE1 := ComboBoxEx(Win, "Combo", "xm y+5 r10 w200")
For Index, Item In Items
    CBE1.Add(Item, Index)
CBE1.Choose(1)

Win.AddText("xm y+15", "ComboBoxEx - DDL:")
CBE2 := ComboBoxEx(Win, "DDL", "xm y+5 r10 w200")
For Index, Item In Items
    CBE2.Add(Item, Index)
CBE2.Choose(1)

; Status text
StatusText := Win.AddText("xm y+20 w200", "Press Ctrl+Shift+T for values")

Win.Show()

^+T:: {
    MsgBox("Combo: " CBE1.Value " - " CBE1.Text "`nDDL: " CBE2.Value " - " CBE2.Text, "Values", 0x40)
}

; ======================================================================================================================
; Dark Mode Functions
; ======================================================================================================================
SetWindowAttribute(hwnd, attr, value) {
    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "Int", attr, "Int*", value, "Int", 4)
}

SetAppDarkMode(mode) {
    ; mode: 0=Default, 1=AllowDark, 2=ForceDark, 3=ForceLight, 4=Max
    ; This enables dark mode for common controls (dropdowns, scrollbars, etc.)
    Static uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
    Static SetPreferredAppMode := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
    Static FlushMenuThemes := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")

    DllCall(SetPreferredAppMode, "Int", mode)
    DllCall(FlushMenuThemes)
}

; ======================================================================================================================
; ComboBoxEx Class
; ======================================================================================================================
Class ComboBoxEx {
    __New(Win, Style, XYWH := "") {
        Static CBS := {Combo: 0x0002, DDL: 0x0003}
        Static WS := 0x40000000 + 0x10000000

        Styles := WS | CBS.%Style%
        CBB := Win.AddCustom("ClassComboBoxEx32 " . XYWH . " " . Styles)

        ; Set edit control style for Combo
        (Style = "Combo") && ControlSetStyle("+0x1000", SendMessage(0x0407, 0, 0, CBB))

        ; Set image list
        SendMessage(0x0402, 0, HIL, CBB)

        ; Store references
        This.DefineProp("Ctrl", {Get: (*) => CBB})
        Local Edit := (Style = "DDL" ? 0 : SendMessage(0x0407, 0, 0, This))
        This.DefineProp("Edit", {Get: (*) => Edit})
        This.DefineProp("Style", {Get: (*) => Style})

        ; Apply dark theme to ComboBox
        This.ApplyDarkTheme()
    }

    ApplyDarkTheme() {
        ; Get the inner ComboBox handle (CBEM_GETCOMBOCONTROL = 0x0406)
        hwndCombo := SendMessage(0x0406, 0, 0, This.Ctrl)

        ; Apply dark theme to ComboBoxEx
        DllCall("uxtheme\SetWindowTheme", "Ptr", This.Hwnd, "Str", "DarkMode_CFD", "Ptr", 0)

        ; Apply dark theme to inner ComboBox
        if hwndCombo
            DllCall("uxtheme\SetWindowTheme", "Ptr", hwndCombo, "Str", "DarkMode_CFD", "Ptr", 0)

        ; Get ComboBox info for list and edit handles
        Static CB_GETCOMBOBOXINFO := 0x0164
        CBI := Buffer(40 + A_PtrSize * 3, 0)
        NumPut("UInt", CBI.Size, CBI)

        if hwndCombo
            DllCall("GetComboBoxInfo", "Ptr", hwndCombo, "Ptr", CBI)

        hwndList := NumGet(CBI, 40 + A_PtrSize * 2, "Ptr")
        if hwndList
            DllCall("uxtheme\SetWindowTheme", "Ptr", hwndList, "Str", "DarkMode_CFD", "Ptr", 0)

        ; Dark theme for edit control
        if This.Edit
            DllCall("uxtheme\SetWindowTheme", "Ptr", This.Edit, "Str", "DarkMode_CFD", "Ptr", 0)
    }

    Add(Item, Icon := 0) {
        Local CBEI := Buffer(A_PtrSize * 7, 0)
        Local Mask := (Icon < 1) ? 0x01 : 0x07
        Icon--
        NumPut("UPtr", Mask, "Ptr", -1, "Ptr", StrPtr(Item), "Int", 0, "Int", Icon, "Int", Icon, CBEI)
        SendMessage(0x040B, 0, CBEI, This)
    }

    Choose(Index) => ControlChooseIndex(Index, This)
    Delete(Index?) => (IsSet(Index) ? ControlDeleteItem(Index, This) : SendMessage(0x014B, 0, 0, This))
    Focus() => This.Ctrl.Focus()
    GetPos(&X?, &Y?, &Width?, &Height?) {
        This.Ctrl.GetPos(&X, &Y, &Width, &Height)
    }
    Move(X?, Y?, Width?, Height?) {
        This.Ctrl.Move(X?, Y?, Width?, Height?)
    }
    OnCommand(NotifyCode, Callback, AddRemove?) {
        This.Ctrl.OnCommand(NotifyCode, Callback, AddRemove?)
    }
    OnNotify(NotifyCode, Callback, AddRemove?) {
        This.Ctrl.OnNotify(NotifyCode, Callback, AddRemove?)
    }
    Redraw() => This.Ctrl.Redraw()
    SetFont(Options?, FontName?) => This.Ctrl.SetFont(Options?, FontName?)

    ClassNN => This.Ctrl.ClassNN
    Enabled {
        Get => This.Ctrl.Enabled
        Set => This.Ctrl.Enabled := Value
    }
    Focused => This.Ctrl.Focused
    Gui => This.Ctrl.Gui
    Hwnd => This.Ctrl.Hwnd
    Type => "Custom.ComboBoxEx_" . This.Style

    Value {
        Get => ControlGetIndex(This)
        Set => Throw Error("Value property is readonly!", -1)
    }

    Text {
        Get {
            Local Item := ControlGetIndex(This)
            If Item = 0 {
                If This.Edit
                    Return ControlGetText(This.Edit)
                Else
                    Return ""
            }
            Else
                Return ControlGetChoice(This)
        }
        Set => Throw Error("Text property is readonly!", -1)
    }

    Visible {
        Get => This.Ctrl.Visible
        Set => This.Ctrl.Visible := Value
    }
}
