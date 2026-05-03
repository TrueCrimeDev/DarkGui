#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

#Include Lib\_Dark.ahk

SettingsManager()

class SettingsManager {
    __New() {
        this.InitializeProperties()
        this.CreateGui()
        this.LoadSettings()
        this.ShowGui()
    }

    InitializeProperties() {
        this.configFile := A_ScriptDir "\settings.ini"
        this.links := Map()
    }

    CreateGui() {
        this.gui := Gui("+Resize", "Settings")
        this.gui.SetFont("s11 cffffff", "Segoe UI")
        this.gui.OnEvent("Close", (*) => this.gui.Hide())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
        
        this.tabs := this.gui.AddTab3("w600 h400", ["General", "Links", "Advanced"])
        
        this.tabs.Value := 1
        this.CreateGeneralTab()
        
        this.tabs.Value := 2
        this.CreateLinksTab()
        
        this.tabs.Value := 3
        this.CreateAdvancedTab()
        
        this.tabs.Value := 1
        
        this.darkMode := _Dark(this.gui)
        this.linksList.SetDarkMode()
    }
    
    CreateGeneralTab() {
        this.gui.AddText("xm y+20 w580 Section", "Application Settings")
        this.gui.SetFont("s11 cffffff", "Segoe UI")

        this.startWithWindows := this.gui.AddCheckbox("xm y+15", "Start with Windows")
        this.startWithWindows.OnEvent("Click", this.SaveSettings.Bind(this))
        
        this.showInTray := this.gui.AddCheckbox("xm y+10", "Show in system tray")
        this.showInTray.OnEvent("Click", this.SaveSettings.Bind(this))
        
        this.darkModeEnabled := this.gui.AddCheckbox("xm y+10", "Dark Mode (requires restart)")
        this.darkModeEnabled.OnEvent("Click", this.SaveSettings.Bind(this))
        
        this.gui.AddText("xm y+20 w580", "Notification Settings")
        this.enableNotifications := this.gui.AddCheckbox("xm y+15", "Enable notifications")
        this.enableNotifications.OnEvent("Click", this.SaveSettings.Bind(this))
        
        this.gui.AddText("xm y+15 w100", "Check interval:")
        this.checkInterval := this.gui.AddDropDownList("x+10 w120", ["5 minutes", "15 minutes", "30 minutes", "1 hour"])
        this.checkInterval.OnEvent("Change", this.SaveSettings.Bind(this))
    }

    CreateLinksTab() {
        this.gui.AddText("xm y+20 w100 Section", "Link Name:")
        this.linkName := this.gui.AddEdit("x+10 w200", "")
        
        this.gui.AddText("xm y+10 w100", "URL:")
        this.linkUrl := this.gui.AddEdit("x+10 w200", "")
        
        this.addLinkBtn := this.gui.AddButton("xm y+20 w100", "Add Link")
        this.addLinkBtn.OnEvent("Click", this.AddLinkClicked.Bind(this))
        
        this.updateLinkBtn := this.gui.AddButton("x+10 w100", "Update Link")
        this.updateLinkBtn.OnEvent("Click", this.UpdateLinkClicked.Bind(this))
        
        this.deleteLinkBtn := this.gui.AddButton("x+10 w100", "Delete Link")
        this.deleteLinkBtn.OnEvent("Click", this.DeleteLinkClicked.Bind(this))
        
        this.linksList := this.gui.AddListView("xm y+20 w580 h250", ["Name", "URL"])
        this.linksList.OnEvent("ItemSelect", this.LinkSelected.Bind(this))
        
        this.linksList.ModifyCol(1, 200)
        this.linksList.ModifyCol(2, 360)
    }
    
    CreateAdvancedTab() {
        this.gui.AddText("xm y+20 w580 Section", "File Settings")
        this.gui.AddText("xm y+15", "Config File Path:")
        this.configPathEdit := this.gui.AddEdit("xm y+5 w400 ReadOnly", this.configFile)
        this.browseBtn := this.gui.AddButton("x+10 w80", "Browse...")
        this.browseBtn.OnEvent("Click", this.BrowseConfigFile.Bind(this))
        
        this.gui.AddText("xm y+20 w580", "Data Management")
        this.exportBtn := this.gui.AddButton("xm y+15 w150", "Export Settings")
        this.exportBtn.OnEvent("Click", this.ExportSettings.Bind(this))
        
        this.importBtn := this.gui.AddButton("x+20 w150", "Import Settings")
        this.importBtn.OnEvent("Click", this.ImportSettings.Bind(this))
        
        this.resetBtn := this.gui.AddButton("x+20 w150", "Reset All Settings")
        this.resetBtn.OnEvent("Click", this.ResetSettings.Bind(this))
    }

    AddLinkClicked(*) {
        name := this.linkName.Value
        url := this.linkUrl.Value
        
        if (name && url) {
            this.AddLink(name, url)
            this.linkName.Value := ""
            this.linkUrl.Value := ""
        } else {
            MsgBox("Please enter both a name and URL for the link.")
        }
    }

    UpdateLinkClicked(*) {
        rowNum := this.linksList.GetNext()
        if (!rowNum) {
            MsgBox("Please select a link to update.")
            return
        }
        
        name := this.linkName.Value
        url := this.linkUrl.Value
        
        if (name && url) {
            this.EditLink(rowNum, name, url)
        } else {
            MsgBox("Please enter both a name and URL for the link.")
        }
    }

    DeleteLinkClicked(*) {
        rowNum := this.linksList.GetNext()
        if (!rowNum) {
            MsgBox("Please select a link to delete.")
            return
        }
        
        if (MsgBox("Are you sure you want to delete this link?", "Confirm Delete", "YesNo") = "Yes") {
            this.DeleteLink(rowNum)
        }
    }

    LinkSelected(*) {
        rowNum := this.linksList.GetNext()
        if (rowNum) {
            name := this.linksList.GetText(rowNum, 1)
            url := this.linksList.GetText(rowNum, 2)
            
            this.linkName.Value := name
            this.linkUrl.Value := url
        }
    }

    AddLink(name, url) {
        this.links[name] := url
        this.linksList.Add(, name, url)
        this.SaveSettings()
    }

    EditLink(rowNum, name, url) {
        originalName := this.linksList.GetText(rowNum, 1)
        this.links.Delete(originalName)
        this.links[name] := url
        this.linksList.Modify(rowNum, , name, url)
        this.SaveSettings()
    }

    DeleteLink(rowNum) {
        name := this.linksList.GetText(rowNum, 1)
        this.links.Delete(name)
        this.linksList.Delete(rowNum)
        this.SaveSettings()
    }

    LoadSettings() {
        this.startWithWindows.Value := 0
        this.showInTray.Value := 1
        this.darkModeEnabled.Value := 1
        this.enableNotifications.Value := 1
        this.checkInterval.Choose(2)
        
        try {
            this.startWithWindows.Value := IniRead(this.configFile, "General", "StartWithWindows", 0)
            this.showInTray.Value := IniRead(this.configFile, "General", "ShowInTray", 1)
            this.darkModeEnabled.Value := IniRead(this.configFile, "General", "DarkMode", 1)
            
            this.enableNotifications.Value := IniRead(this.configFile, "Notifications", "Enabled", 1)
            intervalValue := IniRead(this.configFile, "Notifications", "CheckInterval", "15 minutes")
            
            for i, item in ["5 minutes", "15 minutes", "30 minutes", "1 hour"] {
                if (item = intervalValue) {
                    this.checkInterval.Choose(i)
                    break
                }
            }
        } catch as err {
            ; Ignore errors if the file doesn't exist yet
        }
        
        this.links := Map()
        this.linksList.Delete()
        
        try {
            loop {
                linkValue := IniRead(this.configFile, "Links", "Link" . A_Index, "ERROR")
                if (linkValue = "ERROR")
                    break
                    
                linkData := StrSplit(linkValue, "|")
                if (linkData.Length >= 2) {
                    name := linkData[1]
                    url := linkData[2]
                    
                    this.links[name] := url
                    this.linksList.Add(, name, url)
                }
            }
        } catch as err {
            ; Ignore errors if the section doesn't exist
        }
    }

    SaveSettings(*) {
        IniWrite(this.startWithWindows.Value, this.configFile, "General", "StartWithWindows")
        IniWrite(this.showInTray.Value, this.configFile, "General", "ShowInTray")
        IniWrite(this.darkModeEnabled.Value, this.configFile, "General", "DarkMode")
        
        IniWrite(this.enableNotifications.Value, this.configFile, "Notifications", "Enabled")
        IniWrite(this.checkInterval.Text, this.configFile, "Notifications", "CheckInterval")
        
        IniDelete(this.configFile, "Links")
        
        index := 1
        for name, url in this.links {
            IniWrite(name . "|" . url, this.configFile, "Links", "Link" . index)
            index++
        }
    }
    
    BrowseConfigFile(*) {
        newPath := FileSelect("S", this.configFile, "Select Config File Location", "INI Files (*.ini)")
        if (newPath) {
            this.configFile := newPath
            this.configPathEdit.Value := newPath
            this.SaveSettings()
            this.LoadSettings()
        }
    }

    ExportSettings(*) {
        exportPath := FileSelect("S", A_ScriptDir "\settings_export.ini", "Export Settings", "INI Files (*.ini)")
        if (exportPath) {
            FileCopy(this.configFile, exportPath, 1)
            MsgBox("Settings exported successfully.")
        }
    }

    ImportSettings(*) {
        importPath := FileSelect(3, , "Import Settings", "INI Files (*.ini)")
        if (importPath) {
            if (MsgBox("Import settings from " importPath "? Current settings will be overwritten.", "Confirm Import", "YesNo") = "Yes") {
                FileCopy(importPath, this.configFile, 1)
                this.LoadSettings()
                MsgBox("Settings imported successfully.")
            }
        }
    }
    
    ResetSettings(*) {
        if (MsgBox("Are you sure you want to reset all settings?", "Confirm Reset", "YesNo") = "Yes") {
            try {
                FileDelete(this.configFile)
            } catch as err {
                ; Ignore errors if file doesn't exist
            }
            
            IniWrite(0, this.configFile, "General", "StartWithWindows")
            IniWrite(1, this.configFile, "General", "ShowInTray")
            IniWrite(1, this.configFile, "General", "DarkMode")
            
            IniWrite(1, this.configFile, "Notifications", "Enabled")
            IniWrite("15 minutes", this.configFile, "Notifications", "CheckInterval")
            
            this.LoadSettings()
            MsgBox("Settings have been reset to defaults.")
        }
    }

    ShowGui() {
        this.gui.Show()
    }
}