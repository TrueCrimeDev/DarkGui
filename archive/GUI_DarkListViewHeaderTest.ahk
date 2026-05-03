#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

#Include Lib/_Dark.ahk

TestDarkControls()

class TestDarkControls {
    __New() {
        this.CreateGui()
        this.gui.Show("w600 h600", "Dark Mode Controls Test")
    }

    CreateGui() {
        this.gui := Gui("+Resize")
        this.gui.SetFont("s10", "Segoe UI")
        this.darkMode := _Dark(this.gui)
        
        ; Add ListView with multiple columns
        this.darkMode.AddDarkText("y15 x15 w550", "ListView with Dark Mode Header Text")
        this.darkListView := this.darkMode.AddListView("y+10 x15 w550 h200", ["ID", "Name", "Description", "Value"])
        
        ; Add sample data
        loop 10 {
            this.darkListView.Add(, A_Index, "Item " A_Index, "Description for item " A_Index, "Value " A_Index)
        }
        
        ; Add a MonthCal control
        this.darkMode.AddDarkText("y+20 x15 w300", "MonthCal with Dark Mode Colors")
        this.darkMonthCal := this.darkMode.AddDarkMonthCal("y+10 x15")
        
        ; Create a close button
        this.darkMode.AddDarkButton("y+20 x15 w100", "Close").OnEvent("Click", (*) => this.gui.Destroy())
    }
}
