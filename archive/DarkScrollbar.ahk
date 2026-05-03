#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

#Include DarkModeModular.ahk

DarkScrollDemo()

class DeferPos {
    static pBegin := 0
    static pDefer := 0
    static pEnd := 0

    static __New() {
        hmod := DllCall("GetModuleHandle", "str", "User32", "ptr")
        this.pBegin := DllCall("GetProcAddress", "ptr", hmod, "astr", "BeginDeferWindowPos", "ptr")
        this.pDefer := DllCall("GetProcAddress", "ptr", hmod, "astr", "DeferWindowPos", "ptr")
        this.pEnd := DllCall("GetProcAddress", "ptr", hmod, "astr", "EndDeferWindowPos", "ptr")
    }

    __New(count) {
        if !(this.hdwp := DllCall(DeferPos.pBegin, "int", count, "ptr"))
            throw OSError()
    }

    Add(hwnd, x, y, w, h, flags := 0x0214) {
        if !(this.hdwp := DllCall(DeferPos.pDefer
            , "ptr", this.hdwp
            , "ptr", hwnd
            , "ptr", 0
            , "int", x
            , "int", y
            , "int", w
            , "int", h
            , "uint", flags
            , "ptr"))
            throw OSError()
        return this
    }

    End() {
        if !DllCall(DeferPos.pEnd, "ptr", this.hdwp, "int")
            throw OSError()
    }
}

class DarkScrollOverlay {
    thumbPad := 3
    thumbMinH := 30
    barWidth := 14

    __New(parentGui, targetCtrl) {
        this.parentGui := parentGui
        this.parentHwnd := parentGui.Hwnd
        this.targetCtrl := targetCtrl
        this.targetHwnd := targetCtrl.Hwnd
        this.thumbY := 0
        this.thumbH := 40
        this.overlayH := 0
        this.overlayX := 0
        this.overlayY := 0
        this.dragging := false
        this.dragOffset := 0
        this.hovering := false
        this.visible := false
        this.lastPos := -1

        trackBGR := DarkTheme.RGBtoBGR(DarkTheme.Colors["ScrollTrack"])
        this.overlay := Gui("+Parent" this.parentHwnd " -Caption")
        this.overlay.BackColor := Format("{:06X}", trackBGR)
        this.overlayHwnd := this.overlay.Hwnd

        this.brushTrack := DarkTheme.GetBrush("ScrollTrack")
            || DllCall("CreateSolidBrush", "uint", DarkTheme.RGBtoBGR(0x3C3C3C), "ptr")
        this.brushThumb := DarkTheme.GetBrush("ScrollThumb")
            || DllCall("CreateSolidBrush", "uint", DarkTheme.RGBtoBGR(0x5A5A5A), "ptr")
        this.brushHover := DarkTheme.GetBrush("ScrollThumbHover")
            || DllCall("CreateSolidBrush", "uint", DarkTheme.RGBtoBGR(0x787878), "ptr")
        this.brushActive := DllCall("CreateSolidBrush", "uint", DarkTheme.RGBtoBGR(0x999999), "ptr")
        this._ownsBrushActive := true

        this.paintCb := this.OnPaint.Bind(this)
        this.eraseCb := this.OnEraseBkgnd.Bind(this)
        this.downCb := this.OnLButtonDown.Bind(this)
        this.upCb := this.OnLButtonUp.Bind(this)
        this.moveCb := this.OnMouseMove.Bind(this)
        this.wheelCb := this.OnMouseWheel.Bind(this)
        this.leaveCb := this.OnMouseLeave.Bind(this)
        this.activateCb := this.OnMouseActivate.Bind(this)

        OnMessage(0x000F, this.paintCb)
        OnMessage(0x0014, this.eraseCb)
        OnMessage(0x0021, this.activateCb)
        OnMessage(0x0200, this.moveCb)
        OnMessage(0x0201, this.downCb)
        OnMessage(0x0202, this.upCb)
        OnMessage(0x020A, this.wheelCb)
        OnMessage(0x02A3, this.leaveCb)

        this.pollRef := this.PollScroll.Bind(this)
        SetTimer(this.pollRef, 16)
    }

    GetScrollInfo() {
        si := Buffer(28, 0)
        NumPut("uint", 28, si, 0)
        NumPut("uint", 0x17, si, 4)
        DllCall("GetScrollInfo", "ptr", this.targetHwnd, "int", 1, "ptr", si, "int")
        return Map(
            "min", NumGet(si, 8, "int"),
            "max", NumGet(si, 12, "int"),
            "page", NumGet(si, 16, "uint"),
            "pos", NumGet(si, 20, "int")
        )
    }

    CalcThumb() {
        si := this.GetScrollInfo()
        range := si["max"] - si["min"] + 1
        if range <= Integer(si["page"]) || range = 0 {
            this.thumbH := this.overlayH
            this.thumbY := 0
            return false
        }
        this.thumbH := Max(this.thumbMinH, Integer(si["page"] / range * this.overlayH))
        scrollable := si["max"] - si["min"] - si["page"] + 1
        if scrollable > 0
            this.thumbY := Integer((si["pos"] - si["min"]) / scrollable * (this.overlayH - this.thumbH))
        else
            this.thumbY := 0
        return true
    }

    Redraw() {
        DllCall("InvalidateRect", "ptr", this.overlayHwnd, "ptr", 0, "int", 0)
    }

    AddToDeferPos(dwp, x, y, h) {
        this.overlayX := x
        this.overlayY := y
        this.overlayH := h
        si := this.GetScrollInfo()
        needsScroll := (si["max"] - si["min"] + 1) > Integer(si["page"])
        if needsScroll {
            flags := 0x0214
            if !this.visible
                flags |= 0x0040
            dwp.Add(this.overlayHwnd, x, y, this.barWidth, h, flags)
            this.visible := true
        } else if this.visible {
            dwp.Add(this.overlayHwnd, 0, 0, 0, 0, 0x0214 | 0x0080 | 0x0003)
            this.visible := false
        }
        return needsScroll
    }

    Update() {
        if this.visible {
            this.CalcThumb()
            this.Redraw()
        }
    }

    PollScroll(*) {
        if !this.visible
            return
        si := this.GetScrollInfo()
        if si["pos"] != this.lastPos {
            this.lastPos := si["pos"]
            this.CalcThumb()
            this.Redraw()
        }
    }

    OnPaint(wParam, lParam, msg, hwnd) {
        if hwnd != this.overlayHwnd
            return
        ps := Buffer(72, 0)
        hdc := DllCall("BeginPaint", "ptr", hwnd, "ptr", ps, "ptr")

        memDC := DllCall("CreateCompatibleDC", "ptr", hdc, "ptr")
        bmp := DllCall("CreateCompatibleBitmap", "ptr", hdc, "int", this.barWidth, "int", this.overlayH, "ptr")
        oldBmp := DllCall("SelectObject", "ptr", memDC, "ptr", bmp, "ptr")

        rc := Buffer(16)
        NumPut("int", 0, "int", 0, "int", this.barWidth, "int", this.overlayH, rc)
        DllCall("FillRect", "ptr", memDC, "ptr", rc, "ptr", this.brushTrack)

        brush := this.dragging ? this.brushActive : this.hovering ? this.brushHover : this.brushThumb
        pad := this.thumbPad
        nullPen := DllCall("GetStockObject", "int", 5, "ptr")
        oldPen := DllCall("SelectObject", "ptr", memDC, "ptr", nullPen, "ptr")
        oldBr := DllCall("SelectObject", "ptr", memDC, "ptr", brush, "ptr")
        DllCall("RoundRect", "ptr", memDC
            , "int", pad
            , "int", this.thumbY + pad
            , "int", this.barWidth - pad
            , "int", this.thumbY + this.thumbH - pad
            , "int", 6
            , "int", 6)
        DllCall("SelectObject", "ptr", memDC, "ptr", oldBr)
        DllCall("SelectObject", "ptr", memDC, "ptr", oldPen)

        DllCall("BitBlt", "ptr", hdc
            , "int", 0, "int", 0, "int", this.barWidth, "int", this.overlayH
            , "ptr", memDC, "int", 0, "int", 0, "uint", 0x00CC0020)

        DllCall("SelectObject", "ptr", memDC, "ptr", oldBmp)
        DllCall("DeleteObject", "ptr", bmp)
        DllCall("DeleteDC", "ptr", memDC)
        DllCall("EndPaint", "ptr", hwnd, "ptr", ps)
        return 0
    }

    OnEraseBkgnd(wParam, lParam, msg, hwnd) {
        if hwnd = this.overlayHwnd
            return 1
    }

    OnMouseActivate(wParam, lParam, msg, hwnd) {
        if hwnd = this.overlayHwnd
            return 3
    }

    OnLButtonDown(wParam, lParam, msg, hwnd) {
        if hwnd != this.overlayHwnd
            return
        mouseY := (lParam >> 16) & 0xFFFF
        if mouseY > 0x7FFF
            mouseY -= 0x10000

        if mouseY >= this.thumbY && mouseY <= this.thumbY + this.thumbH {
            this.dragging := true
            this.dragOffset := mouseY - this.thumbY
            DllCall("SetCapture", "ptr", this.overlayHwnd)
            this.Redraw()
        } else if mouseY < this.thumbY {
            DllCall("SendMessage", "ptr", this.targetHwnd, "uint", 0x0115, "ptr", 2, "ptr", 0)
        } else {
            DllCall("SendMessage", "ptr", this.targetHwnd, "uint", 0x0115, "ptr", 3, "ptr", 0)
        }
        return 0
    }

    OnLButtonUp(wParam, lParam, msg, hwnd) {
        if !this.dragging
            return
        this.dragging := false
        DllCall("ReleaseCapture")
        DllCall("SendMessage", "ptr", this.targetHwnd, "uint", 0x0115, "ptr", 8, "ptr", 0)
        this.CalcThumb()
        this.Redraw()
        return 0
    }

    OnMouseMove(wParam, lParam, msg, hwnd) {
        if hwnd != this.overlayHwnd && !this.dragging
            return

        mouseY := (lParam >> 16) & 0xFFFF
        if mouseY > 0x7FFF
            mouseY -= 0x10000

        if this.dragging {
            si := this.GetScrollInfo()
            trackRange := this.overlayH - this.thumbH
            if trackRange <= 0
                return 0
            newThumbY := Max(0, Min(mouseY - this.dragOffset, trackRange))
            ratio := newThumbY / trackRange
            scrollRange := si["max"] - si["min"] - si["page"] + 1
            newPos := si["min"] + Integer(ratio * scrollRange)
            newPos := Max(si["min"], Min(newPos, si["max"] - Integer(si["page"]) + 1))
            wP := (newPos << 16) | 5
            DllCall("SendMessage", "ptr", this.targetHwnd, "uint", 0x0115, "ptr", wP, "ptr", 0)
            return 0
        }

        if hwnd = this.overlayHwnd {
            wasHovering := this.hovering
            this.hovering := mouseY >= this.thumbY && mouseY <= this.thumbY + this.thumbH
            if this.hovering != wasHovering {
                this.Redraw()
                if this.hovering {
                    tme := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
                    NumPut("uint", A_PtrSize = 8 ? 24 : 16, tme, 0)
                    NumPut("uint", 0x02, tme, 4)
                    NumPut("ptr", this.overlayHwnd, tme, 8)
                    DllCall("TrackMouseEvent", "ptr", tme)
                }
            }
        }
    }

    OnMouseWheel(wParam, lParam, msg, hwnd) {
        if hwnd != this.overlayHwnd
            return
        DllCall("SendMessage", "ptr", this.targetHwnd, "uint", 0x020A, "ptr", wParam, "ptr", lParam)
        return 0
    }

    OnMouseLeave(wParam, lParam, msg, hwnd) {
        if hwnd != this.overlayHwnd
            return
        if this.hovering {
            this.hovering := false
            this.Redraw()
        }
    }

    __Delete() {
        SetTimer(this.pollRef, 0)
        OnMessage(0x000F, this.paintCb, 0)
        OnMessage(0x0014, this.eraseCb, 0)
        OnMessage(0x0021, this.activateCb, 0)
        OnMessage(0x0200, this.moveCb, 0)
        OnMessage(0x0201, this.downCb, 0)
        OnMessage(0x0202, this.upCb, 0)
        OnMessage(0x020A, this.wheelCb, 0)
        OnMessage(0x02A3, this.leaveCb, 0)
        if this._ownsBrushActive
            DllCall("DeleteObject", "ptr", this.brushActive)
        this.overlay.Destroy()
    }
}

class DarkScrollDemo {
    __New() {
        this.pad := 10
        this.gui := DarkGui("+Resize", "DarkScroll")
        this.gui.MarginX := this.pad
        this.gui.MarginY := this.pad

        this.lv := this.gui.Add("ListView", "xm w460 h360 +LV0x10000", ["Name", "Size", "Modified"])
        this.lv.ModifyCol(1, 200)
        this.lv.ModifyCol(2, 100)
        this.lv.ModifyCol(3, 140)

        loop 200
            this.lv.Add(, "Item " A_Index, Random(1, 9999) " KB", FormatTime(, "yyyy-MM-dd HH:mm"))

        this.scrollbar := DarkScrollOverlay(this.gui, this.lv)

        this.gui.OnEvent("Close", (*) => ExitApp())
        this.gui.OnEvent("Size", this.OnSize.Bind(this))
        this.gui.Show("w480 h380")
        this.LayoutControls(480, 380)
    }

    LayoutControls(width, height) {
        pad := this.pad
        lvW := width - pad * 2
        lvH := height - pad * 2
        sbX := pad + lvW - this.scrollbar.barWidth
        sbY := pad

        dwp := DeferPos(2)
        dwp.Add(this.lv.Hwnd, pad, pad, lvW, lvH)
        this.scrollbar.AddToDeferPos(dwp, sbX, sbY, lvH)
        dwp.End()

        this.scrollbar.Update()
    }

    OnSize(thisGui, minMax, width, height) {
        if minMax = -1
            return
        this.LayoutControls(width, height)
    }
}
