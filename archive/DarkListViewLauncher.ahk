#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

DarkListViewLauncher()

class DarkListViewLauncher {
    __New() {
        this.InitializeGui()
    }
    
    InitializeGui() {
        ; Create the main GUI
        this.gui := Gui("+LastFound")
        this.gui.BackColor := "FFFFFF"
        this.gui.SetFont("s10", "Segoe UI")
        
        ; Add a title
        this.gui.AddText("y15 x15 w400 Center", "Dark ListView with White Text - Examples")
        
        ; Add description
        this.gui.AddText("y+15 x15 w400", "Select an example to run:")
        
        ; Add buttons for each example
        this.example1Button := this.gui.AddButton("y+15 x15 w400 h40", "1. Using DarkListView Class (DarkListViewDemo.ahk)")
        this.example1Button.OnEvent("Click", this.RunExample1.Bind(this))
        
        this.example2Button := this.gui.AddButton("y+10 x15 w400 h40", "2. Manual SendMessage Calls (CustomListViewColors.ahk)")
        this.example2Button.OnEvent("Click", this.RunExample2.Bind(this))
        
        this.example3Button := this.gui.AddButton("y+10 x15 w400 h40", "3. Using DarkListView Extension (DarkListViewExtended.ahk)")
        this.example3Button.OnEvent("Click", this.RunExample3.Bind(this))
        
        ; Add a button to open the README
        this.readmeButton := this.gui.AddButton("y+20 x15 w400 h30", "Open README")
        this.readmeButton.OnEvent("Click", this.OpenReadme.Bind(this))
        
        ; Setup events
        this.gui.OnEvent("Close", (*) => ExitApp())
        this.gui.OnEvent("Escape", (*) => ExitApp())
        
        ; Show the GUI - Fixed parameter format
        this.gui.Title := "Dark ListView Examples"
        this.gui.Show("w430 h250")
    }
    
    RunExample1(*) {
        Run("DarkListViewDemo.ahk")
    }
    
    RunExample2(*) {
        Run("CustomListViewColors.ahk")
    }
    
    RunExample3(*) {
        Run("DarkListViewExtended.ahk")
    }
    
    OpenReadme(*) {
        Run("DarkListViewReadme.md")
    }
}