#Requires AutoHotkey v2.1-alpha.23
#SingleInstance Force
#Include ..\DarkModeModular.ahk
#Include ..\Layout.ahk

winW := 400
margin := 15
lay := Layout(winW, margin, 10)

g := DarkGui(, "Tabs Demo")
g.SetFont("s10", "Segoe UI")

tabW := winW - margin * 2
tabH := 270
tabs := g.Add("Tab3", Format("x{} y{} w{} h{}", margin, margin, tabW, tabH), ["General", "Appearance", "About"])

; --- General tab ---
tabs.UseTab("General")
tabLay := Layout(winW, 25, 8)
tabLay.Space(35)

g.Add("Text", tabLay.Section(), "APPLICATION SETTINGS")
lr := tabLay.LabelRow(90, 26)
g.Add("Text", lr[1] " cA0A0A0", "Username:")
g.Add("Edit", lr[2], "admin")

lr := tabLay.LabelRow(90, 26)
g.Add("Text", lr[1] " cA0A0A0", "Language:")
g.Add("ComboBox", lr[2], ["English", "Spanish", "French", "German"])

g.Add("CheckBox", tabLay.Row(22, "+Checked"), "Start with Windows")
g.Add("CheckBox", tabLay.Row(22), "Check for updates")

; --- Appearance tab ---
tabs.UseTab("Appearance")
tabLay2 := Layout(winW, 25, 8)
tabLay2.Space(35)

g.Add("Text", tabLay2.Section(), "DISPLAY SETTINGS")
lr := tabLay2.LabelRow(90, 26)
g.Add("Text", lr[1] " cA0A0A0", "Font size:")
g.Add("Slider", lr[2] " Range8-24", 12)

lr := tabLay2.LabelRow(90, 26)
g.Add("Text", lr[1] " cA0A0A0", "Opacity:")
slider := g.Add("Slider", lr[2] " Range20-100", 100)
opLabel := g.Add("Text", tabLay2.Row(20), "Window opacity: 100%")
slider.OnEvent("Change", (*) => opLabel.Text := "Window opacity: " slider.Value "%")

; --- About tab ---
tabs.UseTab("About")
tabLay3 := Layout(winW, 25, 8)
tabLay3.Space(35)

g.Add("Text", tabLay3.Row(24), "DarkGui Framework")
g.Add("Text", tabLay3.Row(20, "cA0A0A0"), "A dark mode GUI framework for AutoHotkey v2")
g.Add("Text", tabLay3.Row(20, "cA0A0A0"), "Version: 1.0.0")
g.Add("Text", tabLay3.Row(20, "cA0A0A0"), "License: MIT")
g.Add("Text", tabLay3.Row(20, "c0078D7"), "github.com/TrueCrimeDev/DarkGui")

tabs.UseTab()

; Buttons below tabs
lay.y := margin + tabH + 10
btns := lay.ButtonRow(80, 2, 32)
g.Add("Button", "+Accent " btns[1], "OK").OnEvent("Click", (*) => ExitApp())
g.Add("Button", btns[2], "Cancel").OnEvent("Click", (*) => ExitApp())

g.Show("w" winW " h" lay.CurrentY)
g.OnEvent("Close", (*) => ExitApp())
