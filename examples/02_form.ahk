#Requires AutoHotkey v2.1-alpha.23
#SingleInstance Force
#Include ..\DarkModeModular.ahk
#Include ..\Layout.ahk

winW := 320
lay := Layout(winW, 15, 8)

g := DarkGui(, "Form Controls")
g.SetFont("s10", "Segoe UI")

g.Add("Text", lay.Section(), "PERSONAL INFO")
lr := lay.LabelRow(70, 26)
g.Add("Text", lr[1] " cA0A0A0", "Name:")
g.Add("Edit", lr[2], "John Doe")

lr := lay.LabelRow(70, 26)
g.Add("Text", lr[1] " cA0A0A0", "Email:")
g.Add("Edit", lr[2], "john@example.com")

lr := lay.LabelRow(70, 26)
g.Add("Text", lr[1] " cA0A0A0", "Role:")
g.Add("ComboBox", lr[2], ["Developer", "Designer", "Manager", "QA Engineer"])

lay.Space(4)
g.Add("Text", lay.Section(), "PREFERENCES")
cols := lay.Columns(2, 22)
g.Add("CheckBox", cols[1] " +Checked", "Dark mode")
g.Add("CheckBox", cols[2] " +Checked", "Auto-save")
lay.Advance(22)
cols := lay.Columns(2, 22)
g.Add("CheckBox", cols[1], "Notifications")
g.Add("CheckBox", cols[2], "Telemetry")
lay.Advance(22)

lay.Space(4)
g.Add("Text", lay.Section(), "THEME")
cols := lay.Columns(3, 22)
g.Add("Radio", cols[1] " +Checked", "System")
g.Add("Radio", cols[2], "Dark")
g.Add("Radio", cols[3], "Light")
lay.Advance(22)

lay.Space(8)
btns := lay.ButtonRow(90, 2, 32)
g.Add("Button", "+Accent " btns[1], "Save").OnEvent("Click", (*) => MsgBox("Saved!"))
g.Add("Button", btns[2], "Cancel").OnEvent("Click", (*) => ExitApp())

g.Show("w" winW " h" lay.CurrentY)
g.OnEvent("Close", (*) => ExitApp())
