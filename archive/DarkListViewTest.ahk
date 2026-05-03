#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

; Explicitly include the _Dark.ahk file we modified
#Include ..\ClautoHotkey\_Dark.ahk

; Simple test class
class LVHeaderTest {
    gui := ""
    darkMode := ""
    listView := ""
    
    __New() {
        ; Create a new GUI
        this.gui := Gui("+Resize", "Dark Mode ListView Header Test")
        
        ; Apply dark theme
        this.darkMode := _Dark(this.gui)
        
        ; Add a text description
        this.darkMode.AddDarkText("w400", "ListView with white header text (0xFFFFFF)")
        
        ; Add a ListView with headers to test
        this.listView := this.darkMode.AddListView("r10 w400 h200", ["Column 1", "Column 2", "Column 3"])
        
        ; Add sample data
        Loop 5 {
            this.listView.Add(, "Item " A_Index, "Data " Chr(64 + A_Index), "Example " A_Index)
        }
        
        ; Add a close button
        closeBtn := this.darkMode.AddDarkButton("w100 h30 xm y+20", "Close")
        closeBtn.OnEvent("Click", (*) => this.gui.Destroy())
        
        ; Show the GUI
        this.gui.Show()
        return this
    }
}

; Create and run the test
test := LVHeaderTest()
