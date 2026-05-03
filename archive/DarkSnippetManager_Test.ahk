#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

; Test if DarkSnippetManager loads properly
#Include _Dark.ahk

try {
    ; Try to create the GUI
    gui := _Dark("+Resize", "Test")
    gui.SetFont("s10", "Consolas")
    
    ; Try to add controls
    gui.Add("Text", "x10 y10", "Test Label")
    edit := gui.Add("Edit", "x10 y40 w200", "Test content")
    btn := gui.Add("Button", "x10 y80 w100", "Test")
    
    gui.Show("w400 h200")
    
    ; Try to read the JSON file
    dataFile := A_ScriptDir "\snippets.json"
    if FileExist(dataFile) {
        jsonText := FileRead(dataFile)
        MsgBox("File loaded! Size: " StrLen(jsonText) " chars`nFirst 50 chars: " SubStr(jsonText, 1, 50))
    } else {
        MsgBox("File not found: " dataFile)
    }
    
} catch Error as e {
    MsgBox("Error: " e.Message "`nLine: " e.Line)
}
