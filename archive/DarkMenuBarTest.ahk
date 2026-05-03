#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

; Suppress DarkModeModular's auto-run showcase
__DARKMODEMODULAR_NOAUTORUN := true
#Include DarkModeModular.ahk

; =============================================================================
; Test — DarkMenuBar (from DarkModeModular) + _Dark GUI with sample controls
; =============================================================================
DarkMenuBarTest()

class DarkMenuBarTest {
    controls := Map()
    callbacks := Map()

    __New() {
        this.gui := _Dark("+Resize -DPIScale", "Dark MenuBar Test")

        menuBarOptions := Map(
            "menuBarHeight", 24,
            "showToolbar", false
        )
        this.menuBar := DarkMenuBar(this.gui, menuBarOptions)
        this.menuBar.SetDarkWindowFrame()
        this.BuildMenus()

        OnMessage(0x0111, this.MenuCommandHandler.Bind(this))

        this.yOffset := this.menuBar.GetContentY()
        this.BuildLayout()
        this.BindEvents()
        this.gui.Show("w620 h" (520 + this.yOffset))
    }

    BuildMenus() {
        this.menuBar.AddMenu("File", [
            Map("text", "New",        "shortcut", "Ctrl+N", "id", 101),
            Map("text", "Open...",     "shortcut", "Ctrl+O", "id", 102),
            Map("text", "Save",        "shortcut", "Ctrl+S", "id", 103),
            Map("separator", true),
            Map("text", "Exit",        "id", 104)
        ])
        this.callbacks[101] := (*) => this.OnMenuAction("New")
        this.callbacks[102] := (*) => this.OnMenuAction("Open")
        this.callbacks[103] := (*) => this.OnMenuAction("Save")
        this.callbacks[104] := (*) => ExitApp()

        this.menuBar.AddMenu("Edit", [
            Map("text", "Undo",       "shortcut", "Ctrl+Z", "id", 201),
            Map("text", "Redo",       "shortcut", "Ctrl+Y", "id", 202),
            Map("separator", true),
            Map("text", "Cut",        "shortcut", "Ctrl+X", "id", 203),
            Map("text", "Copy",       "shortcut", "Ctrl+C", "id", 204),
            Map("text", "Paste",      "shortcut", "Ctrl+V", "id", 205)
        ])
        this.callbacks[201] := (*) => this.OnMenuAction("Undo")
        this.callbacks[202] := (*) => this.OnMenuAction("Redo")
        this.callbacks[203] := (*) => this.OnMenuAction("Cut")
        this.callbacks[204] := (*) => this.OnMenuAction("Copy")
        this.callbacks[205] := (*) => this.OnMenuAction("Paste")

        this.menuBar.AddMenu("View", [
            Map("text", "Zoom In",    "shortcut", "Ctrl++", "id", 301),
            Map("text", "Zoom Out",   "shortcut", "Ctrl+-", "id", 302),
            Map("separator", true),
            Map("text", "Full Screen", "shortcut", "F11",   "id", 303)
        ])
        this.callbacks[301] := (*) => this.OnMenuAction("Zoom In")
        this.callbacks[302] := (*) => this.OnMenuAction("Zoom Out")
        this.callbacks[303] := (*) => this.OnMenuAction("Full Screen")

        this.menuBar.AddMenu("Help", [
            Map("text", "About",      "id", 401)
        ])
        this.callbacks[401] := (*) => MsgBox("Dark MenuBar Test`nCQT-style dark menus + DarkModeModular controls", "About")
    }

    MenuCommandHandler(wParam, lParam, msg, hwnd) {
        if hwnd != this.gui.Hwnd
            return
        cmdId := wParam & 0xFFFF
        if this.callbacks.Has(cmdId)
            SetTimer(() => this.callbacks[cmdId](), -1)
    }

    BuildLayout() {
        y := this.yOffset

        this.gui.Add("Text", "x20 y" (y + 15) " w200", "━ Text Input")
        this.controls["edit1"] := this.gui.Add("Edit", "x20 y" (y + 40) " w200 h25", "Single-line edit")
        this.controls["edit2"] := this.gui.Add("Edit", "x20 y" (y + 75) " w200 h68 +Multi", "Item A`nItem B`nItem C`nItem D`nItem E")

        this.gui.Add("Text", "x240 y" (y + 15) " w180", "━ Selection")
        this.controls["chk1"] := this.gui.Add("CheckBox", "x240 y" (y + 40) " w160 +Checked", "Feature enabled")
        this.controls["chk2"] := this.gui.Add("CheckBox", "x240 y" (y + 65) " w160", "Auto-save")
        this.controls["rad1"] := this.gui.Add("Radio", "x240 y" (y + 95) " w160 +Checked", "Option A")
        this.controls["rad2"] := this.gui.Add("Radio", "x240 y" (y + 120) " w160", "Option B")

        this.gui.Add("Text", "x420 y" (y + 15) " w180", "━ Actions")
        this.controls["btn1"] := this.gui.Add("Button", "x420 y" (y + 40) " w80 h28", "Apply")
        this.controls["btn2"] := this.gui.Add("Button", "+Accent x510 y" (y + 40) " w80 h28", "OK")
        this.controls["btn3"] := this.gui.Add("Button", "x420 y" (y + 75) " w170 h28", "Reset All")

        this.gui.Add("Text", "x20 y" (y + 200) " w200", "━ Dropdowns & Progress")
        this.controls["combo"] := this.gui.Add("ComboBox", "x20 y" (y + 225) " w200", ["Option 1", "Option 2", "Option 3"])
        this.controls["slider"] := this.gui.Add("Slider", "x20 y" (y + 265) " w200 Range0-100", 50)
        this.controls["sliderLabel"] := this.gui.Add("Text", "x20 y" (y + 295) " w200", "Value: 50")
        this.controls["progress"] := this.gui.Add("Progress", "x20 y" (y + 320) " w200 h20", 50)

        this.gui.Add("Text", "x240 y" (y + 200) " w350", "━ ListView")
        this.controls["lv"] := this.gui.Add("ListView", "x240 y" (y + 225) " w350 h115", ["Name", "Type", "Size"])
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

        this.gui.Add("Text", "x20 y" (y + 355) " w200", "━ Status")
        this.controls["status"] := this.gui.Add("Text", "x20 y" (y + 380) " w580 h25", "Status: Ready - use menus above")

        this.gui.Add("Text", "x240 y" (y + 355) " w350", "━ TreeView")
        this.controls["tv"] := this.gui.Add("TreeView", "x240 y" (y + 380) " w350 h83")
        p1 := this.controls["tv"].Add("Documents")
        this.controls["tv"].Add("Report.pdf", p1)
        this.controls["tv"].Add("Notes.txt", p1)
        p2 := this.controls["tv"].Add("Images")
        this.controls["tv"].Add("Photo.jpg", p2)
    }

    BindEvents() {
        this.controls["btn1"].OnEvent("Click", this.OnApply.Bind(this))
        this.controls["btn2"].OnEvent("Click", (*) => this.gui.Hide())
        this.controls["btn3"].OnEvent("Click", this.OnReset.Bind(this))
        this.controls["slider"].OnEvent("Change", this.OnSliderChange.Bind(this))
        this.gui.OnEvent("Close", (*) => ExitApp())
    }

    OnMenuAction(action) {
        this.controls["status"].Text := "Menu: " action " at " FormatTime(, "HH:mm:ss")
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
