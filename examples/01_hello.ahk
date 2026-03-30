#Requires AutoHotkey v2.1-alpha.23
#SingleInstance Force
#Include ..\DarkModeModular.ahk
#Include ..\Layout.ahk

winW := 320
lay := Layout(winW, 15, 10)

g := DarkGui(, "Hello Dark World")
g.SetFont("s12", "Segoe UI")

g.Add("Text", lay.Row(24, "Center"), "Welcome to DarkGui!")
g.Add("Text", lay.Row(24, "Center cA0A0A0"), "A dark mode framework for AHK v2")

lay.Space(5)
btns := lay.ButtonRow(140, 2, 36)
g.Add("Button", btns[1], "Close").OnEvent("Click", (*) => ExitApp())
g.Add("Button", "+Accent " btns[2], "Get Started").OnEvent("Click", (*) => MsgBox("Let's go!"))

g.Show("w" winW " h" lay.CurrentY)
g.OnEvent("Close", (*) => ExitApp())
