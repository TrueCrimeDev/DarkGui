#Requires AutoHotkey v2.1-alpha.23
#SingleInstance Force
#Include ..\DarkModeModular.ahk

DllCall("LoadLibrary", "str", "Msftedit.dll")
Teleprompter()

class Teleprompter {
    static margin := 10
    static btnH  := 32
    static gap   := 8
    static winW  := 750
    static winH  := 550

    wpm            := 150
    fontSize       := 24
    wordIndex      := 0
    wordPositions  := []
    isPlaying      := false
    isPinned       := true
    scrollTargetY  := 0
    scrollCurrentY := 0.0

    __New() {
        this.controls := Map()
        this.gui := DarkGui("+Resize +AlwaysOnTop +MinSize500x300", "Teleprompter")
        this.gui.SetFont("s10", "Segoe UI")
        this.gui.MarginX := Teleprompter.margin
        this.gui.MarginY := Teleprompter.margin

        this.BuildToolbar()
        this.BuildEditor()
        this.InitRichEdit()
        this.BindEvents()
        this.SetupHotkeys()
        this.SetupTimers()

        this.gui.Show(Format("w{} h{}", Teleprompter.winW, Teleprompter.winH))
    }

    BuildToolbar() {
        m := Teleprompter.margin
        h := Teleprompter.btnH
        gap := Teleprompter.gap
        y := m, x := m

        this.controls["play"] := this.gui.Add("Button", Format("+Accent x{} y{} w80 h{}", x, y, h), "Play")
        x += 80 + gap

        this.controls["top"] := this.gui.Add("Button", Format("x{} y{} w50 h{}", x, y, h), "Top")
        x += 50 + gap * 2

        this.gui.Add("Text", Format("x{} y{} w36 h{} +0x200", x, y, h), "WPM")
        x += 40
        this.controls["wpmDn"] := this.gui.Add("Button", Format("x{} y{} w28 h{}", x, y, h), "-")
        x += 30
        this.controls["wpmLabel"] := this.gui.Add("Text", Format("x{} y{} w30 h{} Center +0x200", x, y, h), String(this.wpm))
        x += 32
        this.controls["wpmUp"] := this.gui.Add("Button", Format("x{} y{} w28 h{}", x, y, h), "+")
        x += 28 + gap * 2

        this.gui.Add("Text", Format("x{} y{} w30 h{} +0x200", x, y, h), "Font")
        x += 34
        this.controls["fontDn"] := this.gui.Add("Button", Format("x{} y{} w30 h{}", x, y, h), "A-")
        x += 32
        this.controls["fontLabel"] := this.gui.Add("Text", Format("x{} y{} w24 h{} Center +0x200", x, y, h), String(this.fontSize))
        x += 26
        this.controls["fontUp"] := this.gui.Add("Button", Format("x{} y{} w30 h{}", x, y, h), "A+")
        x += 30 + gap * 2

        this.controls["pin"] := this.gui.Add("Button", Format("x{} y{} w60 h{}", x, y, h), "Pinned")
    }

    BuildEditor() {
        m := Teleprompter.margin
        editY := m + Teleprompter.btnH + m
        w := Teleprompter.winW - m * 2
        h := Teleprompter.winH - editY - m
        this.re := this.gui.Add("Custom", Format("x{} y{} w{} h{} ClassRICHEDIT50W +0x00201044", m, editY, w, h), "")
    }

    BindEvents() {
        this.controls["play"].OnEvent("Click", this.TogglePlay.Bind(this))
        this.controls["top"].OnEvent("Click", this.ResetToTop.Bind(this))
        this.controls["wpmDn"].OnEvent("Click", (*) => this.AdjustWpm(-10))
        this.controls["wpmUp"].OnEvent("Click", (*) => this.AdjustWpm(10))
        this.controls["fontDn"].OnEvent("Click", (*) => this.AdjustFont(-2))
        this.controls["fontUp"].OnEvent("Click", (*) => this.AdjustFont(2))
        this.controls["pin"].OnEvent("Click", this.TogglePin.Bind(this))

        this.gui.OnEvent("Size", this.OnSize.Bind(this))
        this.gui.OnEvent("Close", (*) => ExitApp())
        this.gui.OnEvent("Escape", (*) => ExitApp())
    }

    SetupHotkeys() {
        HotIfWinActive("ahk_id " this.gui.Hwnd)
        Hotkey("F5", (*) => this.TogglePlay())
        Hotkey("^Up", (*) => this.AdjustWpm(10))
        Hotkey("^Down", (*) => this.AdjustWpm(-10))
        Hotkey("^Home", (*) => this.ResetToTop())
    }

    SetupTimers() {
        this.wordFn := this.WordTick.Bind(this)
        this.scrollFn := this.SmoothScrollTick.Bind(this)
    }

    InitRichEdit() {
        SendMessage(0x0443, 0, 0x1A1A1A, this.re)
        SendMessage(0x0448, 0, 0, this.re)
        this.ApplyDefaultFormat()
        this.SetParaCenter()
        this.SetText("Paste your text here, then press Play or F5.`r`n`r`n"
            "Words advance at the WPM rate. Read words get struck through and dimmed. "
            "The current word is highlighted.")
    }

    SetParaCenter() {
        pf := Buffer(188, 0)
        NumPut("uint", 188, pf, 0)
        NumPut("uint", 0x108, pf, 4)
        NumPut("ushort", 3, pf, 24)
        NumPut("int", 28, pf, 164)
        NumPut("UChar", 5, pf, 170)
        SendMessage(0x00B1, 0, -1, this.re)
        SendMessage(0x0447, 0, pf.Ptr, this.re)
        SendMessage(0x00B1, 0, 0, this.re)
    }

    ApplyDefaultFormat() {
        cf := this.CF2({color: 0xE8E8E8, size: this.fontSize, face: "Segoe UI", bold: false, strike: false, clearBack: true})
        SendMessage(0x00B1, 0, -1, this.re)
        SendMessage(0x0444, 1, cf.Ptr, this.re)
        SendMessage(0x00B1, 0, 0, this.re)
    }

    SetText(text) {
        SendMessage(0x000C, 0, StrPtr(text), this.re)
        this.ApplyDefaultFormat()
        this.SetParaCenter()
    }

    GetText() {
        len := SendMessage(0x000E, 0, 0, this.re)
        if !len
            return ""
        buf := Buffer((len + 1) * 2, 0)
        SendMessage(0x000D, len + 1, buf.Ptr, this.re)
        return StrReplace(StrGet(buf, "UTF-16"), "`r`n", "`r")
    }

    BGR(rgb) => ((rgb & 0xFF) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 0xFF)

    CF2(o) {
        cf := Buffer(116, 0)
        NumPut("uint", 116, cf, 0)
        mask := 0, effects := 0
        if o.HasProp("color") {
            mask |= 0x40000000
            NumPut("uint", this.BGR(o.color), cf, 20)
        }
        if o.HasProp("size") {
            mask |= 0x80000000
            NumPut("int", o.size * 20, cf, 12)
        }
        if o.HasProp("face") {
            mask |= 0x20000000
            StrPut(o.face, cf.Ptr + 26, 32, "UTF-16")
        }
        if o.HasProp("bold") {
            mask |= 1
            effects |= o.bold ? 1 : 0
        }
        if o.HasProp("strike") {
            mask |= 8
            effects |= o.strike ? 8 : 0
        }
        if o.HasProp("backColor") {
            mask |= 0x04000000
            NumPut("uint", this.BGR(o.backColor), cf, 96)
        } else if o.HasProp("clearBack") && o.clearBack {
            mask |= 0x04000000
            effects |= 0x04000000
        }
        NumPut("uint", mask, cf, 4)
        NumPut("uint", effects, cf, 8)
        return cf
    }

    FmtRange(s, e, o) {
        cf := this.CF2(o)
        SendMessage(0x00B1, s, e, this.re)
        SendMessage(0x0444, 1, cf.Ptr, this.re)
    }

    TogglePlay(*) {
        if this.isPlaying
            this.Pause()
        else
            this.Play()
    }

    Play() {
        text := this.GetText()
        if !text
            return
        this.ParseWords(text)
        if !this.wordPositions.Length
            return

        this.isPlaying := true
        this.controls["play"].Text := "Pause"
        SendMessage(0x00CF, 1, 0, this.re)

        SendMessage(0x000B, 0, 0, this.re)
        this.FmtRange(0, StrLen(text), {color: 0xE8E8E8, bold: false, strike: false, clearBack: true})

        if this.wordIndex <= 0 || this.wordIndex > this.wordPositions.Length
            this.wordIndex := 1

        loop this.wordIndex - 1 {
            wp := this.wordPositions[A_Index]
            this.FmtRange(wp.s, wp.e, {color: 0x555555, strike: true, clearBack: true})
        }

        this.HighlightWord()
        SendMessage(0x000B, 1, 0, this.re)
        DllCall("InvalidateRect", "ptr", this.re.Hwnd, "ptr", 0, "int", 1)

        SetTimer(this.wordFn, Round(60000 / this.wpm))
    }

    Pause() {
        this.isPlaying := false
        this.controls["play"].Text := "Play"
        SetTimer(this.wordFn, 0)
        SetTimer(this.scrollFn, 0)
        SendMessage(0x00CF, 0, 0, this.re)
    }

    ParseWords(text) {
        this.wordPositions := []
        p := 1
        while RegExMatch(text, "\S+", &match, p) {
            this.wordPositions.Push({s: match.Pos - 1, e: match.Pos - 1 + match.Len})
            p := match.Pos + match.Len
        }
    }

    WordTick() {
        SendMessage(0x000B, 0, 0, this.re)

        if this.wordIndex >= 1 && this.wordIndex <= this.wordPositions.Length {
            wp := this.wordPositions[this.wordIndex]
            this.FmtRange(wp.s, wp.e, {color: 0x555555, bold: false, strike: true, clearBack: true})
        }

        this.wordIndex++

        if this.wordIndex > this.wordPositions.Length {
            SendMessage(0x000B, 1, 0, this.re)
            DllCall("InvalidateRect", "ptr", this.re.Hwnd, "ptr", 0, "int", 1)
            this.Pause()
            return
        }

        this.HighlightWord()
        SendMessage(0x000B, 1, 0, this.re)
        DllCall("InvalidateRect", "ptr", this.re.Hwnd, "ptr", 0, "int", 1)
    }

    HighlightWord() {
        if this.wordIndex < 1 || this.wordIndex > this.wordPositions.Length
            return
        wp := this.wordPositions[this.wordIndex]
        this.FmtRange(wp.s, wp.e, {color: 0xFFFFFF, bold: true, strike: false, backColor: 0x264F78})
        this.EnsureWordVisible()
    }

    EnsureWordVisible() {
        wp := this.wordPositions[this.wordIndex]

        ptScroll := Buffer(8, 0)
        SendMessage(0x04DD, 0, ptScroll.Ptr, this.re)
        scrollY := NumGet(ptScroll, 4, "int")

        ptChar := Buffer(8, 0)
        SendMessage(0x00D6, ptChar.Ptr, wp.s, this.re)
        caretY := NumGet(ptChar, 4, "int")

        rect := Buffer(16, 0)
        DllCall("GetClientRect", "ptr", this.re.Hwnd, "ptr", rect)
        clientH := NumGet(rect, 12, "int")

        zone := clientH // 3

        if caretY < 0 || caretY > zone {
            this.scrollTargetY := scrollY + caretY - zone
            if this.scrollTargetY < 0
                this.scrollTargetY := 0
            this.scrollCurrentY := scrollY + 0.0
            SetTimer(this.scrollFn, 16)
        }
    }

    SmoothScrollTick() {
        diff := this.scrollTargetY - this.scrollCurrentY
        if Abs(diff) < 1.0 {
            this.scrollCurrentY := this.scrollTargetY + 0.0
            SetTimer(this.scrollFn, 0)
        } else {
            this.scrollCurrentY += diff * 0.15
        }
        pt := Buffer(8, 0)
        NumPut("int", 0, pt, 0)
        NumPut("int", Round(this.scrollCurrentY), pt, 4)
        SendMessage(0x04DE, 0, pt.Ptr, this.re)
    }

    AdjustWpm(d) {
        this.wpm := Max(10, Min(400, this.wpm + d))
        this.controls["wpmLabel"].Text := String(this.wpm)
        if this.isPlaying
            SetTimer(this.wordFn, Round(60000 / this.wpm))
    }

    AdjustFont(d) {
        this.fontSize := Max(14, Min(60, this.fontSize + d))
        this.controls["fontLabel"].Text := String(this.fontSize)
        cf := this.CF2({size: this.fontSize})
        SendMessage(0x00B1, 0, -1, this.re)
        SendMessage(0x0444, 1, cf.Ptr, this.re)
        SendMessage(0x00B1, 0, 0, this.re)
    }

    TogglePin(*) {
        this.isPinned := !this.isPinned
        this.gui.Opt(this.isPinned ? "+AlwaysOnTop" : "-AlwaysOnTop")
        this.controls["pin"].Text := this.isPinned ? "Pinned" : "Float"
    }

    ResetToTop(*) {
        if this.isPlaying
            this.Pause()
        this.wordIndex := 0
        text := this.GetText()
        if text {
            SendMessage(0x000B, 0, 0, this.re)
            this.FmtRange(0, StrLen(text), {color: 0xE8E8E8, bold: false, strike: false, clearBack: true})
            SendMessage(0x000B, 1, 0, this.re)
            DllCall("InvalidateRect", "ptr", this.re.Hwnd, "ptr", 0, "int", 1)
        }
        pt := Buffer(8, 0)
        SendMessage(0x04DE, 0, pt.Ptr, this.re)
    }

    OnSize(guiObj, minMax, w, h) {
        if minMax = -1
            return
        m := Teleprompter.margin
        editY := m + Teleprompter.btnH + m
        this.re.Move(m, editY, w - m * 2, h - editY - m)
    }
}
