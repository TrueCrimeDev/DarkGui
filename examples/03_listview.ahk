#Requires AutoHotkey v2.1-alpha.23
#SingleInstance Force
#Include ..\DarkModeModular.ahk
#Include ..\Layout.ahk

winW := 500
lay := Layout(winW, 15, 8)

g := DarkGui("+Resize", "ListView Demo")
g.SetFont("s10", "Segoe UI")

g.Add("Text", lay.Section(), "FILE BROWSER")

lv := g.Add("ListView", lay.Row(280, "+Grid"), ["Name", "Type", "Size", "Modified"])

files := [
    ["DarkModeModular.ahk", "AutoHotkey", "48 KB",  "2026-03-15"],
    ["README.md",           "Markdown",   "3 KB",   "2026-03-20"],
    ["package.json",        "JSON",       "1 KB",   "2026-03-18"],
    ["screenshot.png",      "Image",      "856 KB", "2026-03-10"],
    ["backup.zip",          "Archive",    "15 MB",  "2026-03-05"],
    ["database.sqlite",     "Database",   "128 MB", "2026-02-28"],
    ["config.ini",          "INI",        "4 KB",   "2026-03-22"],
    ["output.log",          "Log",        "12 KB",  "2026-03-25"],
    ["styles.css",          "CSS",        "8 KB",   "2026-03-12"],
    ["index.html",          "HTML",       "5 KB",   "2026-03-14"]
]

for f in files
    lv.Add("", f[1], f[2], f[3], f[4])

lv.ModifyCol(1, 160)
lv.ModifyCol(2, 100)
lv.ModifyCol(3, 80)
lv.ModifyCol(4, 110)

status := g.Add("Text", lay.Row(20), "Select a file to see details")

lv.OnEvent("ItemSelect", (*) => OnSelect())

OnSelect() {
    row := lv.GetNext()
    if row
        status.Text := "Selected: " lv.GetText(row, 1) " (" lv.GetText(row, 3) ")"
}

g.Show("w" winW " h" lay.CurrentY)
g.OnEvent("Close", (*) => ExitApp())
