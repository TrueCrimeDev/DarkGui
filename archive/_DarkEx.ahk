#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

#Include Lib\_Dark.ahk

DemoApp2()

class DemoApp2 {
    __New() {
        this.settings := Map(
            "RadialMenu", Map(
                "HotKey", "!Capslock",
                "EnableAdvanced", true
            ),
            "Interface", Map(
                "Language", "English"
            )
        )
        
        this.InitializeGui()
        this.SetupControls()
        this.gui.Show()
    }
    
    InitializeGui() {
        this.gui := Gui("+Resize", "Task Manager")
        this.gui.SetFont("s10 cffffff", "Segoe UI")
        this.gui.OnEvent("Close", (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        
        this.gui.AddText("y15 x15", "Name:")
        this.nameEdit := this.gui.AddEdit("w250 x15")
        
        this.gui.AddText("y+10 x15", "Priority:")
        this.priority := this.gui.AddDropDownList("w250 Choose1", ["High", "Medium", "Low"])
        
        this.gui.AddText("y+20 x15 w250", "Settings")
        
        this.gui.AddText("y+10 x15", "Hotkey:")
        this.hotkeyCombo := this.gui.AddComboBox("w250 x15", 
            ["!Capslock", "#Capslock", "^Capslock", "+Capslock"])
        
        this.enableAdvanced := this.gui.AddCheckBox("y+15 x15 w250", "Enable advanced features")
        
        this.gui.AddText("y+15 x15", "Language:")
        this.language := this.gui.AddDropDownList("w250 x15 Choose1", ["English", "German", "French"])
        
        saveBtn := this.gui.AddButton("y+20 w120 x15", "Save Task")
        clearBtn := this.gui.AddButton("x+10 w120", "Clear")
        
        this.listView := this.gui.AddListView("y+20 x15 w250 h150", ["Name", "Priority"])
        
        _Dark(this.gui)

        saveBtn.OnEvent("Click", this.SaveTask.Bind(this))
        clearBtn.OnEvent("Click", this.ClearFields.Bind(this))
        this.hotkeyCombo.OnEvent("Change", this.UpdateSettings.Bind(this))
        this.enableAdvanced.OnEvent("Click", this.UpdateSettings.Bind(this))
        this.language.OnEvent("Change", this.UpdateSettings.Bind(this))
        
        this.SetupHotkeys()
    }
    
    SetupControls() {
        this.hotkeyCombo.Text := this.settings["RadialMenu"]["HotKey"]
        this.enableAdvanced.Value := this.settings["RadialMenu"]["EnableAdvanced"] ? 1 : 0
        this.language.Choose(this.settings["Interface"]["Language"])
    }
    
    UpdateSettings(*) {
        this.settings["RadialMenu"]["HotKey"] := this.hotkeyCombo.Text
        this.settings["RadialMenu"]["EnableAdvanced"] := this.enableAdvanced.Value = 1
        this.settings["Interface"]["Language"] := this.language.Text
        
        ToolTip("Settings updated")
        SetTimer () => ToolTip(), -2000
    }
    
    SetupHotkeys() {
        HotIfWinActive("ahk_id " this.gui.Hwnd)
        Hotkey("Escape", (*) => this.gui.Hide())
        HotIfWinActive()
        
        Hotkey("^r", (*) => this.Reset())
    }
    
    SaveTask(*) {
        if (this.nameEdit.Value = "")
            return
            
        this.listView.Add(, this.nameEdit.Value, this.priority.Text)
        this.ClearFields()
    }
    
    ClearFields(*) {
        this.nameEdit.Value := ""
        this.priority.Choose(1)
    }
    
    Reset(*) {
        this.ClearFields()
        this.hotkeyCombo.Text := "!Capslock"
        this.enableAdvanced.Value := 1
        this.language.Choose("English")
        this.UpdateSettings()
    }
}

