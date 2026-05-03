#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

; Include _Dark.ahk from the parent directory
#Include ..\_Dark.ahk

; Create and show the test window
test := DarkModeListViewTest()

class DarkModeListViewTest {
    gui := ""
    darkMode := ""
    listView := ""
    
    __New() {
        ; Create the GUI
        this.gui := Gui("+Resize", "Dark Mode ListView Header Test")
        
        ; Apply dark theme to the GUI
        this.darkMode := _Dark(this.gui)
        
        ; Create some controls
        this.darkMode.AddDarkText("w400", "ListView with white header text (0xFFFFFF)")
        
        ; Add a ListView with several columns to showcase the header text color
        this.listView := this.darkMode.AddListView("r10 w400 h200", ["Column 1", "Column 2", "Column 3"])
        
        ; Add some sample data
        this.PopulateListView()
        
        ; Add a button to close the GUI
        closeBtn := this.darkMode.AddDarkButton("w100 h30 xm y+20", "Close")
        closeBtn.OnEvent("Click", ObjBindMethod(this, "CloseWindow"))
        
        ; Set up event handlers
        this.gui.OnEvent("Close", ObjBindMethod(this, "CloseWindow"))
        
        ; Show the GUI
        this.gui.Show()
        
        return this
    }
    
    PopulateListView() {
        ; Add sample data to the ListView
        this.listView.Add(, "Item 1", "Data A", "Example 1")
        this.listView.Add(, "Item 2", "Data B", "Example 2")
        this.listView.Add(, "Item 3", "Data C", "Example 3")
        this.listView.Add(, "Item 4", "Data D", "Example 4")
        this.listView.Add(, "Item 5", "Data E", "Example 5")
    }
    
    CloseWindow(*) {
        this.gui.Destroy()
    }
}
