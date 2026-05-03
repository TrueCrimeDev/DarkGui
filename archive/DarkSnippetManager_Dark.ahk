#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

SimpleDarkApp()

class SimpleDarkApp {
    __New() {
        this.InitializeGui()
    }
    
    InitializeGui() {
        this.gui := Gui("+LastFound")
        this.gui.BackColor := "1F1F1F"
        this.gui.SetFont("s10 cFFFFFF", "Segoe UI")
        this.darkMode := _Dark(this.gui)
        
        ; Add dark mode controls
        this.gui.AddText("y15 x15", "Dark Mode Controls Demo:")
        
        ; Checkbox
        this.darkCheckbox := this.darkMode.AddDarkCheckBox("y+15 x15 w250", "Enable feature")
        
        ; Input field with label
        this.gui.AddText("y+15 x15", "Input:")
        this.darkInput := this.darkMode.AddDarkEdit("y+5 x15 w250", "Sample text")
        
        ; Dropdown with label
        this.gui.AddText("y+15 x15", "Select option:")
        this.darkCombo := this.darkMode.AddDarkComboBox("y+5 x15 w250", ["Option 1", "Option 2", "Option 3"])
        
        ; ListView
        this.gui.AddText("y+15 x15", "Items:")
        this.darkListView := this.darkMode.AddListView("y+5 x15 w300 h150", ["Item", "Value"])
        
        ; Button
        this.actionButton := this.darkMode.AddDarkButton("y+15 x15 w120", "Run Action")
        this.actionButton.OnEvent("Click", this.PerformAction.Bind(this))
        
        this.SetupHotkeys()
        
        ; Add some sample data to ListView
        this.darkListView.Add(, "Item 1", "Value 1")
        this.darkListView.Add(, "Item 2", "Value 2")
        this.darkListView.Add(, "Item 3", "Value 3")
        
        ; Show the GUI
        this.gui.Show("w350 h450", "Dark Mode Demo")
    }
    
    SetupHotkeys() {
        this.gui.OnEvent("Close", (*) => ExitApp())
        this.gui.OnEvent("Escape", (*) => ExitApp())
    }
    
    PerformAction(*) {
        selected := this.darkListView.GetText(this.darkListView.GetNext())
        MsgBox("Action performed!" . (selected ? "`nSelected: " . selected : ""))
    }
}

; The main Dark class that manages all dark mode GUI elements
class _Dark {
    __New(guiObj) {
        this.gui := guiObj
        
        ; Set dark mode title bar
        if (attr := ((VerCompare(A_OSVersion, "10.0.18985") >= 0) ? 20 : 
                   (VerCompare(A_OSVersion, "10.0.17763") >= 0) ? 19 : 0))
            DllCall("dwmapi\DwmSetWindowAttribute", "ptr", this.gui.hwnd, "int", attr, "int*", true, "int", 4)
            
        ; Set dark theme for context menus
        uxtheme := DllCall("GetModuleHandle", "ptr", StrPtr("uxtheme"), "ptr")
        SetPreferredAppMode := DllCall("GetProcAddress", "ptr", uxtheme, "ptr", 135, "ptr")
        FlushMenuThemes := DllCall("GetProcAddress", "ptr", uxtheme, "ptr", 136, "ptr")
        DllCall(SetPreferredAppMode, "int", 1)    
        DllCall(FlushMenuThemes)
    }
    
    ; Custom dark checkbox implementation
    AddDarkCheckBox(Options, Text) {
        static SM_CXMENUCHECK := 71
        static SM_CYMENUCHECK := 72
        static checkBoxW := SysGet(SM_CXMENUCHECK)
        static checkBoxH := SysGet(SM_CYMENUCHECK)
        
        ; Extract custom text color if specified
        textColor := ""  ; Use inherited color
        
        if RegExMatch(Options, "i)text([0-9A-F]{6})", &match) {
            textColor := match[1]
            Options := RegExReplace(Options, "i)\s*text[0-9A-F]{6}", "")
        }
        
        ; Create checkbox with no text
        chbox := this.gui.Add("Checkbox", Options " r1.2 +0x4000000", "")
        
        ; Create text control with proper styling
        if !InStr(Options, "right") {
            txtOptions := "xp+" (checkBoxW+5) " yp+1 HP-4 +0x4000200"
            if (textColor != "")
                txtOptions .= " c" textColor
            txt := this.gui.Add("Text", txtOptions, Text)
        } else {
            txtOptions := "xp+5 yp+1 HP-4 +0x4000200"
            if (textColor != "")
                txtOptions .= " c" textColor
            txt := this.gui.Add("Text", txtOptions, Text)
        }
        
        ; Store the text control with the checkbox
        chbox.txtControl := txt
        
        ; Override the Text property
        chbox.DeleteProp("Text")
        chbox.DefineProp("Text", {
            Get: () => txt.Text,
            Set: (_, value) => txt.Text := value
        })
        
        ; Apply dark theme
        DllCall("uxtheme\SetWindowTheme", "Ptr", chbox.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        
        ; Make text appear on top and handle window z-order
        DllCall("User32\SetWindowPos", "ptr", txt.Hwnd, "ptr", 0, 
                "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x43, "int")
        
        return chbox
    }
    
    ; Custom dark ListView implementation
    AddListView(Options, Headers) {
        ; Create ListView with the provided options
        lv := this.gui.Add("ListView", Options " Background1F1F1F", Headers)
        
        ; Apply dark mode theme to ListView
        DllCall("uxtheme\SetWindowTheme", "Ptr", lv.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        
        ; Set text color to white
        SendMessage(0x1033, 0, 0xFFFFFF, lv.hWnd)  ; LVM_SETTEXTCOLOR
        
        ; Set background color to dark
        SendMessage(0x1026, 0, 0x1F1F1F, lv.hWnd)  ; LVM_SETBKCOLOR
        
        ; Set text background color (when selected)
        SendMessage(0x1043, 0, 0x1F1F1F, lv.hWnd)  ; LVM_SETTEXTBKCOLOR
        
        ; Improve selection appearance
        static CLR_DEFAULT := 0xFF000000
        SendMessage(0x104D, 0, 0x404040, lv.hWnd)  ; LVM_SETSELECTEDCOLUMN - darker selection
        
        return lv
    }
    
    ; Custom dark Button implementation
    AddDarkButton(Options, Text) {
        ; Create button with the provided options
        btn := this.gui.Add("Button", Options, Text)
        
        ; Apply dark mode theme to Button
        DllCall("uxtheme\SetWindowTheme", "Ptr", btn.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        
        ; Apply custom button styles
        static BS_FLAT := 0x8000
        static GWL_STYLE := -16
        btnStyle := DllCall("GetWindowLong", "Ptr", btn.hWnd, "Int", GWL_STYLE, "Int")
        DllCall("SetWindowLong", "Ptr", btn.hWnd, "Int", GWL_STYLE, "Int", btnStyle | BS_FLAT)
        
        ; Create custom brush for background color
        static darkBtnColor := 0x333333  ; Dark gray
        static darkBtnHoverColor := 0x444444  ; Slightly lighter gray for hover
        
        ; Set custom drawing behavior
        DllCall("uxtheme\SetPreferredAppMode", "Int", 1)  ; Force dark mode
        
        return btn
    }
    
    ; Custom dark Edit control implementation
    AddDarkEdit(Options, Text := "") {
        ; Create edit control with the provided options
        edit := this.gui.Add("Edit", Options, Text)
        
        ; Apply dark mode theme to Edit control
        DllCall("uxtheme\SetWindowTheme", "Ptr", edit.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        
        ; Set text and background colors
        static EM_SETBKGNDCOLOR := 0x1001
        DllCall("SendMessage", "Ptr", edit.hWnd, "UInt", EM_SETBKGNDCOLOR, "Ptr", 0, "Ptr", 0x2A2A2A)
        
        return edit
    }
    
    ; Custom dark Combobox implementation
    AddDarkComboBox(Options, Items := "") {
        ; Create combobox with the provided options
        combo := this.gui.Add("ComboBox", Options, Items)
        
        ; Apply dark mode theme
        DllCall("uxtheme\SetWindowTheme", "Ptr", combo.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        
        return combo
    }
}
