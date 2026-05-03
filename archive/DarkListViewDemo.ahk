#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force
#Include DarkListView.ahk

DarkListViewDemo()

class DarkListViewDemo {
    __New() {
        this.InitializeGui()
    }
    
    InitializeGui() {
        ; Create the main GUI with dark background
        this.gui := Gui("+LastFound")
        this.gui.BackColor := "1F1F1F"
        this.gui.SetFont("s10 cFFFFFF", "Segoe UI")
        
        ; Add a title
        this.gui.AddText("y15 x15 w400", "Dark ListView with White Text Demo")
        
        ; Add explanation text
        this.gui.AddText("y+15 x15 w400", "The ListView below has white text on a dark background.")
        
        ; Create a ListView with default colors
        this.listView := this.gui.AddListView("y+10 x15 w500 h300 Background1F1F1F", ["ID", "Name", "Description"])
        
        ; Apply the white text styling
        DarkListView.SetWhiteText(this.listView)
        
        ; Add some sample data
        this.AddSampleData()
        
        ; Add a button to demonstrate selection
        this.showSelectedButton := this.gui.AddButton("y+15 x15 w200", "Show Selected Item")
        this.showSelectedButton.OnEvent("Click", this.ShowSelected.Bind(this))
        
        ; Apply dark theme to the button
        DllCall("uxtheme\SetWindowTheme", "Ptr", this.showSelectedButton.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        this.showSelectedButton.SetFont("cFFFFFF")
        
        ; Setup hotkeys and events
        this.SetupEvents()
        
        ; Show the GUI - Fixed parameter format
        this.gui.Title := "Dark ListView Demo"
        this.gui.Show("w530 h450")
    }
    
    AddSampleData() {
        ; Add some sample rows to the ListView
        this.listView.Add(, "1", "Item One", "This is the first item in the list")
        this.listView.Add(, "2", "Item Two", "This is the second item in the list")
        this.listView.Add(, "3", "Item Three", "This is the third item in the list")
        this.listView.Add(, "4", "Item Four", "This is the fourth item in the list")
        this.listView.Add(, "5", "Item Five", "This is the fifth item in the list")
        
        ; Auto-size columns
        this.listView.ModifyCol(1, "AutoHdr")
        this.listView.ModifyCol(2, "AutoHdr")
        this.listView.ModifyCol(3, "AutoHdr")
    }
    
    SetupEvents() {
        ; Set up GUI events
        this.gui.OnEvent("Close", (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
    }
    
    ShowSelected(*) {
        ; Get the selected row
        if (selectedRow := this.listView.GetNext()) {
            ; Get the text from each column
            id := this.listView.GetText(selectedRow, 1)
            name := this.listView.GetText(selectedRow, 2)
            description := this.listView.GetText(selectedRow, 3)
            
            ; Show the selected item details
            MsgBox("Selected Item:`n`nID: " id "`nName: " name "`nDescription: " description, "Selected Item")
        } else {
            MsgBox("No item selected.", "Selection Info")
        }
    }
}