#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

#Include DarkMode.ahk

DarkModeGUIDemo()

class DarkModeGUIDemo {
    controls := Map()

    ; Layout constants - explicit column/row system
    static col1 := 20      ; Text inputs, Dropdowns, TreeView
    static col2 := 260     ; Selection, ListView label, ListBox
    static col3 := 520     ; Buttons, Theme info
    static colW1 := 220    ; Width for columns 1 & 2
    static colW3 := 280    ; Width for column 3

    __New() {
        this.gui := DarkGui("+Resize", "Dark Mode GUI Demo - All Controls Showcase")
        this.gui.MarginX := 20
        this.gui.MarginY := 15
        this.BuildLayout()
        this.BindEvents()
        this.gui.Show("w820 h680")
    }

    BuildLayout() {
        this.AddTextInputSection()
        this.AddSelectionSection()
        this.AddButtonSection()
        this.AddDropdownProgressSection()
        this.AddListViewSection()
        this.AddTreeViewSection()
        this.AddListBoxSection()
        this.AddThemeInfoSection()
        this.AddStatusBar()
    }

    AddTextInputSection() {
        ; Column 1, starting at y15
        y := 15
        this.gui.Add("Text", "x" DarkModeGUIDemo.col1 " y" y " w200", "TEXT INPUT CONTROLS")

        y += 25
        this.gui.Add("Text", "x" DarkModeGUIDemo.col1 " y" y " w100 cA0A0A0", "Single-line:")
        y += 20
        this.controls["edit1"] := this.gui.Add("Edit", "x" DarkModeGUIDemo.col1 " y" y " w220 h28", "Enter text here...")

        y += 40
        this.gui.Add("Text", "x" DarkModeGUIDemo.col1 " y" y " w100 cA0A0A0", "Multi-line:")
        y += 20
        this.controls["edit2"] := this.gui.Add("Edit", "x" DarkModeGUIDemo.col1 " y" y " w220 h80 +Multi",
            "Multi-line edit control`nWith multiple lines`nFor longer content`nLine 4")
    }

    AddSelectionSection() {
        ; Column 2, starting at y15
        y := 15
        this.gui.Add("Text", "x" DarkModeGUIDemo.col2 " y" y " w200", "SELECTION CONTROLS")

        y += 25
        this.gui.Add("Text", "x" DarkModeGUIDemo.col2 " y" y " w100 cA0A0A0", "CheckBoxes:")
        y += 20
        this.controls["chk1"] := this.gui.Add("CheckBox", "x" DarkModeGUIDemo.col2 " y" y " w180 +Checked", "Enable dark mode")
        y += 25
        this.controls["chk2"] := this.gui.Add("CheckBox", "x" DarkModeGUIDemo.col2 " y" y " w180", "Auto-save settings")
        y += 25
        this.controls["chk3"] := this.gui.Add("CheckBox", "x" DarkModeGUIDemo.col2 " y" y " w180 +Checked", "Show notifications")

        y += 35
        this.gui.Add("Text", "x" DarkModeGUIDemo.col2 " y" y " w100 cA0A0A0", "Radio Buttons:")
        y += 20
        this.controls["rad1"] := this.gui.Add("Radio", "x" DarkModeGUIDemo.col2 " y" y " w180 +Checked", "System default")
        y += 25
        this.controls["rad2"] := this.gui.Add("Radio", "x" DarkModeGUIDemo.col2 " y" y " w180", "Always dark")
        y += 25
        this.controls["rad3"] := this.gui.Add("Radio", "x" DarkModeGUIDemo.col2 " y" y " w180", "Always light")
    }

    AddButtonSection() {
        ; Column 3, starting at y15
        y := 15
        this.gui.Add("Text", "x" DarkModeGUIDemo.col3 " y" y " w280", "BUTTON CONTROLS")

        y += 25
        this.gui.Add("Text", "x" DarkModeGUIDemo.col3 " y" y " w100 cA0A0A0", "Standard Buttons:")
        y += 20
        this.controls["btnNormal1"] := this.gui.Add("Button", "x" DarkModeGUIDemo.col3 " y" y " w90 h32", "Normal")
        this.controls["btnNormal2"] := this.gui.Add("Button", "x" (DarkModeGUIDemo.col3 + 100) " y" y " w90 h32", "Settings")
        this.controls["btnNormal3"] := this.gui.Add("Button", "x" (DarkModeGUIDemo.col3 + 200) " y" y " w90 h32", "Cancel")

        y += 50
        this.gui.Add("Text", "x" DarkModeGUIDemo.col3 " y" y " w100 cA0A0A0", "Accent Buttons:")
        y += 20
        this.controls["btnAccent1"] := this.gui.Add("Button", "+Accent x" DarkModeGUIDemo.col3 " y" y " w90 h32", "Apply")
        this.controls["btnAccent2"] := this.gui.Add("Button", "+Accent x" (DarkModeGUIDemo.col3 + 100) " y" y " w90 h32", "Save")
        this.controls["btnAccent3"] := this.gui.Add("Button", "+Accent x" (DarkModeGUIDemo.col3 + 200) " y" y " w90 h32", "OK")

        y += 45
        this.gui.Add("Text", "x" DarkModeGUIDemo.col3 " y" y " w280 cA0A0A0", "Button States: Normal → Hover → Pressed")
    }

    AddDropdownProgressSection() {
        ; Column 1, second section starting at y280
        y := 280
        this.gui.Add("Text", "x" DarkModeGUIDemo.col1 " y" y " w220", "DROPDOWN & SLIDERS")

        y += 25
        this.gui.Add("Text", "x" DarkModeGUIDemo.col1 " y" y " w100 cA0A0A0", "ComboBox:")
        y += 20
        this.controls["combo"] := this.gui.Add("ComboBox", "x" DarkModeGUIDemo.col1 " y" y " w220",
            ["Select an option...", "Dark Theme", "Light Theme", "System Theme", "Custom Theme"])

        y += 40
        this.gui.Add("Text", "x" DarkModeGUIDemo.col1 " y" y " w100 cA0A0A0", "Slider (0-100):")
        y += 20
        this.controls["slider"] := this.gui.Add("Slider", "x" DarkModeGUIDemo.col1 " y" y " w220 Range0-100", 65)
        y += 30
        this.controls["sliderLabel"] := this.gui.Add("Text", "x" DarkModeGUIDemo.col1 " y" y " w220", "Brightness: 65%")

        y += 25
        this.gui.Add("Text", "x" DarkModeGUIDemo.col1 " y" y " w100 cA0A0A0", "Progress Bar:")
        y += 20
        this.controls["progress"] := this.gui.Add("Progress", "x" DarkModeGUIDemo.col1 " y" y " w220 h22", 65)
        y += 28
        this.controls["progressLabel"] := this.gui.Add("Text", "x" DarkModeGUIDemo.col1 " y" y " w220 cA0A0A0", "Loading: 65%")
    }

    AddListViewSection() {
        ; Spans columns 2-3, starting at y280
        y := 280
        this.gui.Add("Text", "x" DarkModeGUIDemo.col2 " y" y " w280", "LISTVIEW CONTROL")

        y += 25
        ; ListView spans from col2 to near edge (col2=260, width=540 fits in 820-wide window)
        this.controls["lv"] := this.gui.Add("ListView", "x" DarkModeGUIDemo.col2 " y" y " w540 h140 +Grid",
            ["Filename", "Type", "Size", "Modified"])

        this.controls["lv"].Add("", "DarkMode.ahk", "AutoHotkey", "48 KB", "2026-01-10")
        this.controls["lv"].Add("", "Settings.json", "JSON", "2 KB", "2026-01-09")
        this.controls["lv"].Add("", "UserGuide.pdf", "PDF", "1.2 MB", "2026-01-08")
        this.controls["lv"].Add("", "Screenshot.png", "Image", "856 KB", "2026-01-07")
        this.controls["lv"].Add("", "Backup.zip", "Archive", "15 MB", "2026-01-06")
        this.controls["lv"].Add("", "Database.sqlite", "Database", "128 MB", "2026-01-05")
        this.controls["lv"].Add("", "Config.ini", "INI", "4 KB", "2026-01-04")
        this.controls["lv"].Add("", "Log.txt", "Text", "12 KB", "2026-01-03")

        this.controls["lv"].ModifyCol(1, 180)
        this.controls["lv"].ModifyCol(2, 120)
        this.controls["lv"].ModifyCol(3, 100)
        this.controls["lv"].ModifyCol(4, 120)
    }

    AddTreeViewSection() {
        ; Column 1, third section starting at y490
        y := 490
        this.gui.Add("Text", "x" DarkModeGUIDemo.col1 " y" y " w220", "TREEVIEW CONTROL")

        y += 25
        this.controls["tv"] := this.gui.Add("TreeView", "x" DarkModeGUIDemo.col1 " y" y " w220 h140")

        root1 := this.controls["tv"].Add("Documents", , "Expand")
        this.controls["tv"].Add("Reports", root1)
        this.controls["tv"].Add("Contracts", root1)
        this.controls["tv"].Add("Templates", root1)

        root2 := this.controls["tv"].Add("Projects", , "Expand")
        proj1 := this.controls["tv"].Add("DarkMode GUI", root2)
        this.controls["tv"].Add("DarkMode.ahk", proj1)
        this.controls["tv"].Add("Module_GUI.md", proj1)
        proj2 := this.controls["tv"].Add("Other Projects", root2)
        this.controls["tv"].Add("Script1.ahk", proj2)

        root3 := this.controls["tv"].Add("Settings")
        this.controls["tv"].Add("Config.ini", root3)
        this.controls["tv"].Add("User Preferences", root3)
    }

    AddListBoxSection() {
        ; Column 2, third section starting at y490
        y := 490
        this.gui.Add("Text", "x" DarkModeGUIDemo.col2 " y" y " w220", "LISTBOX CONTROL")

        y += 25
        this.controls["listbox"] := this.gui.Add("ListBox", "x" DarkModeGUIDemo.col2 " y" y " w220 h140 +Multi",
            ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta", "Iota", "Kappa"])
    }

    AddThemeInfoSection() {
        ; Column 3, third section starting at y490
        y := 490
        this.gui.Add("Text", "x" DarkModeGUIDemo.col3 " y" y " w280", "THEME INFORMATION")

        y += 25
        this.gui.Add("Text", "x" DarkModeGUIDemo.col3 " y" y " w280 cA0A0A0", "Color Palette (RGB hex):")

        colorInfo := [
            ["Background", DarkTheme.GetColor("Background")],
            ["Controls", DarkTheme.GetColor("Controls")],
            ["Font", DarkTheme.GetColor("Font")],
            ["Accent", DarkTheme.GetColor("Accent")],
            ["Selection", DarkTheme.GetColor("Selection")]
        ]

        y += 22
        for item in colorInfo {
            hex := Format("0x{:06X}", item[2])
            this.gui.Add("Text", "x" DarkModeGUIDemo.col3 " y" y " w120", item[1] . ":")
            this.gui.Add("Text", "x" (DarkModeGUIDemo.col3 + 130) " y" y " w80 cA0A0A0", hex)
            y += 22
        }
    }

    AddStatusBar() {
        this.gui.Add("Text", "x0 y645 w820 h35 +0x4 BackgroundTrans", "")
        this.controls["status"] := this.gui.Add("Text", "x20 y650 w780",
            "Ready | Four theming layers active: DWM, UxTheme, SetWindowTheme, WndProc")
    }

    BindEvents() {
        this.controls["btnNormal1"].OnEvent("Click", (*) => this.UpdateStatus("Normal button clicked"))
        this.controls["btnNormal2"].OnEvent("Click", (*) => this.ShowSettings())
        this.controls["btnNormal3"].OnEvent("Click", (*) => this.gui.Hide())

        this.controls["btnAccent1"].OnEvent("Click", (*) => this.ApplyChanges())
        this.controls["btnAccent2"].OnEvent("Click", (*) => this.SaveSettings())
        this.controls["btnAccent3"].OnEvent("Click", (*) => this.gui.Hide())

        this.controls["slider"].OnEvent("Change", (*) => this.OnSliderChange())
        this.controls["combo"].OnEvent("Change", (*) => this.OnComboChange())

        this.controls["lv"].OnEvent("ItemSelect", (*) => this.OnListViewSelect())
        this.controls["tv"].OnEvent("ItemSelect", (*) => this.OnTreeViewSelect())
        this.controls["listbox"].OnEvent("Change", (*) => this.OnListBoxChange())

        this.controls["chk1"].OnEvent("Click", (*) => this.OnCheckboxToggle())

        this.gui.OnEvent("Close", (*) => ExitApp())
        this.gui.OnEvent("Escape", (*) => ExitApp())
    }

    UpdateStatus(msg) {
        timestamp := FormatTime(A_Now, "HH:mm:ss")
        this.controls["status"].Text := timestamp " | " msg
    }

    ShowSettings() {
        settingsGui := DarkGui("+Owner" this.gui.Hwnd, "Settings")
        settingsGui.Add("Text", "w300", "This is a modal settings dialog")
        settingsGui.Add("Text", "w300 cA0A0A0", "Demonstrating nested DarkGui windows")
        settingsGui.Add("Button", "+Accent w100", "Close").OnEvent("Click", (*) => settingsGui.Destroy())
        settingsGui.Show()
        this.UpdateStatus("Settings dialog opened")
    }

    ApplyChanges() {
        this.UpdateStatus("Changes applied successfully")
        this.AnimateProgress()
    }

    SaveSettings() {
        this.UpdateStatus("Settings saved to config file")
    }

    AnimateProgress() {
        this.controls["progress"].Value := 0
        this.controls["progressLabel"].Text := "Saving: 0%"

        SetTimer(this.ProgressTick.Bind(this), 30)
    }

    ProgressTick() {
        val := this.controls["progress"].Value + 2
        if val > 100 {
            val := 100
            SetTimer(this.ProgressTick.Bind(this), 0)
            this.controls["progressLabel"].Text := "Complete!"
            SetTimer(() => (this.controls["progressLabel"].Text := "Loading: " this.controls["slider"].Value "%"), -1500)
        } else {
            this.controls["progressLabel"].Text := "Saving: " val "%"
        }
        this.controls["progress"].Value := val
    }

    OnSliderChange() {
        val := this.controls["slider"].Value
        this.controls["sliderLabel"].Text := "Brightness: " val "%"
        this.controls["progress"].Value := val
        this.controls["progressLabel"].Text := "Loading: " val "%"
    }

    OnComboChange() {
        selected := this.controls["combo"].Text
        this.UpdateStatus("Theme changed to: " selected)
    }

    OnListViewSelect() {
        row := this.controls["lv"].GetNext()
        if row {
            filename := this.controls["lv"].GetText(row, 1)
            this.UpdateStatus("Selected file: " filename)
        }
    }

    OnTreeViewSelect() {
        id := this.controls["tv"].GetSelection()
        if id {
            text := this.controls["tv"].GetText(id)
            this.UpdateStatus("Selected node: " text)
        }
    }

    OnListBoxChange() {
        static LB_GETCOUNT := 0x018B
        static LB_GETSEL := 0x0187
        static LB_GETTEXT := 0x0189
        static LB_GETTEXTLEN := 0x018A

        selected := []
        hwnd := this.controls["listbox"].Hwnd
        count := SendMessage(LB_GETCOUNT, 0, 0, hwnd)

        loop count {
            idx := A_Index - 1
            if SendMessage(LB_GETSEL, idx, 0, hwnd) > 0 {
                len := SendMessage(LB_GETTEXTLEN, idx, 0, hwnd)
                buf := Buffer((len + 1) * 2, 0)
                SendMessage(LB_GETTEXT, idx, buf.Ptr, hwnd)
                selected.Push(StrGet(buf, "UTF-16"))
            }
        }
        if selected.Length
            this.UpdateStatus("ListBox selected: " this.JoinArray(selected, ", "))
    }

    OnCheckboxToggle() {
        state := this.controls["chk1"].Value ? "enabled" : "disabled"
        this.UpdateStatus("Dark mode " state)
    }

    JoinArray(arr, delim := ", ") {
        result := ""
        for item in arr
            result .= (result ? delim : "") . item
        return result
    }
}
