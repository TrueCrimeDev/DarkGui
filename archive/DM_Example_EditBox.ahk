#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

DarkModeExample()

class DarkModeExample {
    __New() {
        this.gui := Gui("+Resize", "Dark Mode GUI")
        this.gui.SetFont("s10")
        this.gui.AddText("w300", "This is a text control")
        this.gui.AddEdit("w300 h100", "This is an edit control")
        this.gui.AddButton("w300", "Button Example")
        this.gui.AddCheckbox("w300", "Checkbox Example")
        this.gui.AddListBox("w300 h100", ["Item 1", "Item 2", "Item 3"])
        
        this.darkMode := DarkModeGUI(this.gui)
        this.gui.Show()
    }
}

class DarkModeGUI {
    static Instances := Map()
    static WindowProcOldMap := Map()
    static WindowProcCallbacks := Map()
    static TextBackgroundBrush := 0
    
    static Dark := Map(
        "Background", 0x171717,
        "Controls", 0x1b1b1b,
        "Font", 0xE0E0E0
    )
    
    static WM_CTLCOLOREDIT := 0x0133
    static WM_CTLCOLORLISTBOX := 0x0134
    static WM_CTLCOLORBTN := 0x0135
    static WM_CTLCOLORSTATIC := 0x0138
    static DC_BRUSH := 18
    static GWL_WNDPROC := -4
    
    static GetWindowLong := A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"
    static SetWindowLong := A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"
    
    Gui := ""
    
    __New(GuiObj) {
        if (!DarkModeGUI.TextBackgroundBrush)
            DarkModeGUI.TextBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", DarkModeGUI.Dark["Background"], "Ptr")
        
        this.Gui := GuiObj
        this.SetWindowDarkMode()
        this.SetControlsTheme()
        this.SetupWindowProc()
    }
    
    SetWindowDarkMode() {
        this.Gui.BackColor := DarkModeGUI.Dark["Background"]
        
        if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
            DWMWA_USE_IMMERSIVE_DARK_MODE := 19
            if (VerCompare(A_OSVersion, "10.0.18985") >= 0)
                DWMWA_USE_IMMERSIVE_DARK_MODE := 20
                
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Gui.hWnd, 
                   "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", true, "Int", 4)
        }
    }
    
    SetControlsTheme() {
        for hWnd, GuiCtrlObj in this.Gui {
            switch GuiCtrlObj.Type {
                case "Button", "CheckBox", "Radio", "ListBox", "UpDown":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                
                case "ComboBox", "DDL":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_CFD", "Ptr", 0)
                
                case "Edit":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
                
                case "ListView":
                    SendMessage(0x1024, 0, DarkModeGUI.Dark["Font"], GuiCtrlObj.hWnd)      ; LVM_SETTEXTCOLOR
                    SendMessage(0x1026, 0, DarkModeGUI.Dark["Background"], GuiCtrlObj.hWnd) ; LVM_SETTEXTBKCOLOR
                    SendMessage(0x1001, 0, DarkModeGUI.Dark["Background"], GuiCtrlObj.hWnd) ; LVM_SETBKCOLOR
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
            }
        }
    }
    
    SetupWindowProc() {
        DarkModeGUI.Instances[this.Gui.Hwnd] := this
        
        if (!DarkModeGUI.WindowProcOldMap.Has(this.Gui.Hwnd)) {
            oldProc := DllCall("user32\" DarkModeGUI.GetWindowLong, "Ptr", this.Gui.Hwnd, "Int", DarkModeGUI.GWL_WNDPROC, "Ptr")
            DarkModeGUI.WindowProcOldMap[this.Gui.Hwnd] := oldProc
            
            callback := CallbackCreate(DarkModeWindowProc, , 4)
            DarkModeGUI.WindowProcCallbacks[this.Gui.Hwnd] := callback
            DllCall("user32\" DarkModeGUI.SetWindowLong, "Ptr", this.Gui.Hwnd, "Int", DarkModeGUI.GWL_WNDPROC, "Ptr", callback, "Ptr")
        }
    }
    
    __Delete() {
        if (DarkModeGUI.WindowProcOldMap.Has(this.Gui.Hwnd)) {
            DllCall("user32\" DarkModeGUI.SetWindowLong, "Ptr", this.Gui.Hwnd, 
                   "Int", DarkModeGUI.GWL_WNDPROC, "Ptr", DarkModeGUI.WindowProcOldMap[this.Gui.Hwnd], "Ptr")
                   
            CallbackFree(DarkModeGUI.WindowProcCallbacks[this.Gui.Hwnd])
            DarkModeGUI.WindowProcCallbacks.Delete(this.Gui.Hwnd)
            DarkModeGUI.WindowProcOldMap.Delete(this.Gui.Hwnd)
        }
        
        if (DarkModeGUI.Instances.Has(this.Gui.Hwnd))
            DarkModeGUI.Instances.Delete(this.Gui.Hwnd)
    }
}

DarkModeWindowProc(hwnd, uMsg, wParam, lParam) {
    Critical
    
    switch uMsg {
        case DarkModeGUI.WM_CTLCOLOREDIT, DarkModeGUI.WM_CTLCOLORLISTBOX:
            DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkModeGUI.Dark["Font"])
            DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkModeGUI.Dark["Controls"])
            DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", DarkModeGUI.Dark["Controls"])
            return DllCall("gdi32\GetStockObject", "Int", DarkModeGUI.DC_BRUSH, "Ptr")
            
        case DarkModeGUI.WM_CTLCOLORBTN:
            DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", DarkModeGUI.Dark["Background"])
            return DllCall("gdi32\GetStockObject", "Int", DarkModeGUI.DC_BRUSH, "Ptr")
            
        case DarkModeGUI.WM_CTLCOLORSTATIC:
            DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkModeGUI.Dark["Font"])
            DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkModeGUI.Dark["Background"])
            return DarkModeGUI.TextBackgroundBrush
    }
    
    if (DarkModeGUI.WindowProcOldMap.Has(hwnd))
        return DllCall("user32\CallWindowProc", "Ptr", DarkModeGUI.WindowProcOldMap[hwnd], 
                      "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam)
    
    return 0
}