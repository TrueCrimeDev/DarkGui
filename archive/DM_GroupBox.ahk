#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force
#Include Lib\WAPI.ahk
#Include Lib\struct.ahk

DarkModeGui()
class DarkModeGui {
    __New() {
        this.gui := Gui("+Resize", "Dark Mode GroupBox Demo")
        this.gui.BackColor := "202020"
        this.SetupControls()
        this.SetupEvents()
        this.gui.Show("w500 h400")
    }
    
    SetupControls() {
        this.gui.SetFont("cWhite")
        
        this.gb1 := this.gui.AddGroupBox("x20 y20 w220 h150 cFFFFFF Background202020", "Basic Settings")
        
        this.gui.AddText("xp+15 yp+30 w190", "Text Color:")
        this.colorEdit := this.gui.AddEdit("xp y+5 w190", "FFFFFF")
        
        this.gui.AddText("xp y+15 w190", "Background Color:")
        this.bgColorEdit := this.gui.AddEdit("xp y+5 w190", "202020")
        
        this.gb2 := this.gui.AddGroupBox("x260 y20 w220 h150 c00FF00 Background202020", "Border Options")
        
        this.gui.AddText("xp+15 yp+30 w190", "Border Width:")
        this.widthEdit := this.gui.AddEdit("xp y+5 w190", "3")
        
        this.gui.AddText("xp y+15 w190", "Border Color:")
        this.borderColorEdit := this.gui.AddEdit("xp y+5 w190", "FFFFFF")
        
        this.gb3 := this.gui.AddGroupBox("x20 y190 w460 h180 cFFFFFF Background202020", "Preview")
        
        this.previewBox := this.gui.AddGroupBox("xp+20 yp+40 w420 h120 cFFFFFF Background202020", "Custom GroupBox")
        
        this.applyBtn := this.gui.AddButton("x380 y+15 w100", "Apply Style")
        this.applyBtn.OnEvent("Click", this.ApplyCustomStyle.Bind(this))
    }
    
    SetupEvents() {
        this.gui.OnEvent("Close", (*) => ExitApp())
        this.gui.OnEvent("Escape", (*) => ExitApp())
    }
    
    ApplyCustomStyle(*) {
        try {
            txColor := this.colorEdit.Value
            bgColor := this.bgColorEdit.Value
            
            this.previewBox.Opt("c" txColor " Background" bgColor)
            this.previewBox.Redraw()
        } catch as err {
            MsgBox("Invalid input values. Please check your entries: " err.Message)
        }
    }
}

DarkGroupBox(groupBoxCtrl, borderWidth := 3, txColor := 0xFFFFFF, txBgColor := 0x202020, borderColor := 0xFFFFFF) {
    static WM_PAINT := 0x000F
    static callbacks := Map()
    
    if callbacks.Has(groupBoxCtrl.Hwnd)
        SetTimer(callbacks[groupBoxCtrl.Hwnd], 0)
    
    callback := PaintGroupBox.Bind(groupBoxCtrl, borderWidth, txColor, txBgColor, borderColor)
    callbacks[groupBoxCtrl.Hwnd] := callback
    
    OnMessage(WM_PAINT, callback, groupBoxCtrl.Hwnd)
    
    return groupBoxCtrl
}

PaintGroupBox(gCtrl, borderWidth, txColor, txBgColor, borderColor, wParam, lParam, msg, hwnd) {
    static DT_CALCRECT := 0x00000400
    static PS_SOLID := 0

    ps := Buffer(68)
    hdc := WAPI.BeginPaint(hwnd, ps)
    
    WAPI.GetClientRect(hwnd, rc := RECT())
    WAPI.SelectObject(hdc, hPen := WAPI.CreatePen(PS_SOLID, borderWidth, RgbToBgr(borderColor)))
    WAPI.FrameRect(hdc, rc, hPen)

    WAPI.SelectObject(hdc, hbrush := WAPI.CreateSolidBrush(RgbToBgr("0x" gCtrl.Gui.BackColor)))
    WAPI.Rectangle(hdc, rc.left, rc.top, rc.right, rc.bottom)
    
    WAPI.SetTextColor(hdc, RgbToBgr(txColor))
    WAPI.SetBkColor(hdc, RgbToBgr(txBgColor))

    textFlags := GetTextFlags(gCtrl, &center, &vcenter, &right, &bottom)
    WAPI.DrawText(hdc, StrPtr(gCtrl.Text), -1, rct := RECT(), DT_CALCRECT)
    WAPI.OffsetRect(rc, right ? -9 : center ? 0 : 6, (rct.bottom-rct.top)/-2)
    WAPI.DrawText(hdc, StrPtr(gCtrl.Text), -1, rc, textFlags)
    WAPI.EndPaint(hwnd, ps)
    WAPI.DeleteObject(hPen)
    WAPI.DeleteObject(hbrush)
    return 0
}

GetTextFlags(ctrl, &center?, &vcenter?, &right?, &bottom?) {
    static BS_BOTTOM := 0x800, BS_CENTER := 0x300, BS_LEFT := 0x100, BS_LEFTTEXT := 0x20
    static BS_MULTILINE := 0x2000, BS_RIGHT := 0x200, BS_TOP := 0x0400, BS_VCENTER := 0x0C00
    static DT_BOTTOM := 0x8, DT_CENTER := 0x1, DT_LEFT := 0x0, DT_RIGHT := 0x2
    static DT_SINGLELINE := 0x20, DT_TOP := 0x0, DT_VCENTER := 0x4, DT_WORDBREAK := 0x10
    
    dwStyle := ControlGetStyle(ctrl)
    txC := dwStyle & BS_CENTER
    txR := dwStyle & BS_RIGHT
    txL := dwStyle & BS_LEFT
    dwTextFlags := (dwStyle & BS_BOTTOM) ? DT_BOTTOM : !(dwStyle & BS_TOP) ? DT_VCENTER : DT_TOP
    
    if (ctrl.Type = "Button") 
        dwTextFlags |= (txC && txR && !txL) ? DT_RIGHT : (txC && txL && !txR) ? DT_LEFT : DT_CENTER
    else
        dwTextFlags |= txL && txR ? DT_CENTER : !txL && txR ? DT_RIGHT : DT_LEFT

    if !(dwStyle & BS_MULTILINE) 
        dwTextFlags |= DT_SINGLELINE

    if (ctrl.Type = "GroupBox")
        dwTextFlags &= ~(DT_VCENTER | DT_SINGLELINE)
    
    center := !!(dwTextFlags & DT_CENTER)
    vcenter := !!(dwTextFlags & DT_VCENTER)
    right := !!(dwTextFlags & DT_RIGHT)
    bottom := !!(dwTextFlags & DT_BOTTOM)
    
    return dwTextFlags | DT_WORDBREAK
}

RgbToBgr(color) {
    if (Type(color) = "String")
        return RgbToBgr(Number(SubStr(color, 1, 2) = "0x" ? color : "0x" color))
    return (color >> 16 & 0xFF) | (color & 0xFF00) | ((color & 0xFF) << 16)
}