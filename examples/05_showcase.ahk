#Requires AutoHotkey v2.1-alpha.23
#SingleInstance Force
#Include ..\DarkModeModular.ahk
#Include ..\Layout.ahk

ShowcaseApp()

class ShowcaseApp {
    controls := Map()

    __New() {
        this.gui := DarkGui("+Resize", "DarkGui Showcase")
        this.gui.SetFont("s10", "Segoe UI")
        this.BuildLayout()
        this.BindEvents()
        this.gui.Show("w700 h520")
    }

    BuildLayout() {
        g := this.gui

        ; --- Column 1: Inputs (x15, w215) ---
        col1 := Layout(245, 15, 8)

        g.Add("Text", col1.Section(), "TEXT INPUTS")
        lr := col1.LabelRow(55, 26)
        g.Add("Text", lr[1] " cA0A0A0", "Name:")
        this.controls["name"] := g.Add("Edit", lr[2], "DarkGui User")

        lr := col1.LabelRow(55, 70)
        g.Add("Text", lr[1] " cA0A0A0", "Notes:")
        this.controls["notes"] := g.Add("Edit", lr[2] " +Multi", "Multi-line`nedit control`nwith scrolling")

        g.Add("Text", col1.Section(), "SELECTION")
        cols := col1.Columns(2, 22)
        this.controls["chk1"] := g.Add("CheckBox", cols[1] " +Checked", "Feature A")
        this.controls["chk2"] := g.Add("CheckBox", cols[2], "Feature B")
        col1.Advance(22)
        cols := col1.Columns(2, 22)
        this.controls["rad1"] := g.Add("Radio", cols[1] " +Checked", "Mode 1")
        this.controls["rad2"] := g.Add("Radio", cols[2], "Mode 2")
        col1.Advance(22)

        g.Add("Text", col1.Section(), "DROPDOWNS & SLIDERS")
        this.controls["combo"] := g.Add("ComboBox", col1.Row(26), ["Dark Theme", "Light Theme", "System", "Custom"])
        this.controls["slider"] := g.Add("Slider", col1.Row(30, "Range0-100"), 65)
        this.controls["sliderLabel"] := g.Add("Text", col1.Row(20), "Value: 65")
        this.controls["progress"] := g.Add("Progress", col1.Row(18), 65)

        ; --- Column 2: Buttons + ListView (x250, w430) ---
        col2 := Layout(700, 250, 8)

        g.Add("Text", col2.Section(), "BUTTONS")
        cols := col2.Columns(3, 30)
        this.controls["btn1"] := g.Add("Button", cols[1], "Normal")
        this.controls["btn2"] := g.Add("Button", "+Accent " cols[2], "Accent")
        this.controls["btn3"] := g.Add("Button", cols[3], "Third")
        col2.Advance(30)

        g.Add("Text", col2.Section(), "LISTVIEW")
        this.controls["lv"] := g.Add("ListView", col2.Row(140, "+Grid"), ["File", "Type", "Size"])
        this.controls["lv"].Add("", "DarkModeModular.ahk", "AHK", "48 KB")
        this.controls["lv"].Add("", "README.md", "Markdown", "3 KB")
        this.controls["lv"].Add("", "screenshot.png", "Image", "856 KB")
        this.controls["lv"].Add("", "config.json", "JSON", "1 KB")
        this.controls["lv"].Add("", "backup.zip", "Archive", "15 MB")
        this.controls["lv"].Add("", "styles.css", "CSS", "8 KB")
        this.controls["lv"].ModifyCol(1, 200)
        this.controls["lv"].ModifyCol(2, 100)
        this.controls["lv"].ModifyCol(3, 100)

        ; --- Bottom row: TreeView + ListBox ---
        g.Add("Text", col2.Section(), "TREEVIEW & LISTBOX")
        cols := col2.Columns(2, 150)
        this.controls["tv"] := g.Add("TreeView", cols[1])
        p1 := this.controls["tv"].Add("Documents", , "Expand")
        this.controls["tv"].Add("Report.pdf", p1)
        this.controls["tv"].Add("Notes.txt", p1)
        p2 := this.controls["tv"].Add("Scripts", , "Expand")
        this.controls["tv"].Add("DarkGui.ahk", p2)
        this.controls["tv"].Add("Utils.ahk", p2)
        p3 := this.controls["tv"].Add("Config")
        this.controls["tv"].Add("settings.ini", p3)

        this.controls["listbox"] := g.Add("ListBox", cols[2],
            ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta"])
        col2.Advance(150)

        this.controls["status"] := g.Add("Text", "x15 y490 w670", "Ready")
    }

    BindEvents() {
        this.controls["btn1"].OnEvent("Click", (*) => this.UpdateStatus("Normal button clicked"))
        this.controls["btn2"].OnEvent("Click", (*) => this.UpdateStatus("Accent button clicked"))
        this.controls["btn3"].OnEvent("Click", (*) => this.UpdateStatus("Third button clicked"))
        this.controls["slider"].OnEvent("Change", (*) => this.OnSlider())
        this.controls["lv"].OnEvent("ItemSelect", (*) => this.OnListView())
        this.gui.OnEvent("Close", (*) => ExitApp())
    }

    UpdateStatus(msg) {
        this.controls["status"].Text := FormatTime(, "HH:mm:ss") " | " msg
    }

    OnSlider() {
        val := this.controls["slider"].Value
        this.controls["sliderLabel"].Text := "Value: " val
        this.controls["progress"].Value := val
    }

    OnListView() {
        row := this.controls["lv"].GetNext()
        if row
            this.UpdateStatus("Selected: " this.controls["lv"].GetText(row, 1))
    }
}
