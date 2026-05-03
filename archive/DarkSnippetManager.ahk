#Requires AutoHotkey v2.0
#SingleInstance Force

; SnippetManager - A dark-themed tool for managing and using text snippets
; Object-oriented implementation

/**
 * Main application class for the Snippet Manager
 * Encapsulates all functionality in an OOP design
 */
class SnippetManager {
    ; Class properties
    gui := ""                ; Main GUI object
    snippets := Map()        ; Collection of snippets
    previousWindow := 0      ; Tracks previous active window
    controls := Map()        ; Stores GUI controls
    darkTheme := ""          ; Dark theme instance
    tooltipTimer := 0        ; Timer for tooltip messages

    /**
     * Constructor - Initialize the Snippet Manager
     */
    __New() {
        ; Load default snippets
        this.snippets := Map(
            "Greeting", "Hello [Name],`n`nI hope this message finds you well.",
            "Closing", "Best regards,`n[Your Name]",
            "Reminder", "Just a friendly reminder about [topic].",
            "Follow-up", "Following up on my previous message about [topic]."
        )
        
        ; Store current active window
        this.previousWindow := WinExist("A")
        
        ; Initialize the GUI
        this.InitializeGui()
        
        ; Set up hotkey for toggling the GUI
        HotKey("^!s", ObjBindMethod(this, "Toggle"))
    }
    
    /**
     * Initialize and setup the GUI with all controls and events
     */
    InitializeGui() {
        ; Create main GUI
        this.gui := Gui("+Resize +MinSize400x300", "Snippet Manager")
        this.gui.SetFont("s10", "Segoe UI")
        
        ; Initialize dark theme
        this.darkTheme := DarkTheme(this.gui)
        
        ; Add title
        this.controls["titleText"] := this.gui.AddText("y15 x15 w370 Center 0x200 cFFFFFF", "Snippet Manager")
        
        ; Add snippets listbox section
        this.controls["labelSnippets"] := this.gui.AddText("y+15 x15 w370 0x200 cFFFFFF", "Available Snippets:")
        
        ; Create array of snippet names for the listbox
        snippetNames := []
        for name, _ in this.snippets
            snippetNames.Push(name)
        
        ; Add listbox with snippets
        this.controls["snippetListBox"] := this.gui.AddListBox("y+5 x15 w370 h150 vSnippetList", snippetNames)
        this.controls["snippetListBox"].Choose(1)  ; Select first item by default
        
        ; Add preview area
        this.controls["previewLabel"] := this.gui.AddText("y+15 x15 w370 0x200 cFFFFFF", "Preview:")
        this.controls["snippetPreview"] := this.gui.AddEdit("y+5 x15 w370 h80 ReadOnly", this.GetSelectedSnippetText())
        
        ; Add action buttons
        this.controls["copyButton"] := this.gui.AddButton("y+15 x15 w180", "Copy to Clipboard")
        this.controls["copyButton"].OnEvent("Click", ObjBindMethod(this, "CopyToClipboard"))
        
        this.controls["sendButton"] := this.gui.AddButton("y+0 x+10 w180", "Send to Window")
        this.controls["sendButton"].OnEvent("Click", ObjBindMethod(this, "SendToWindow"))
        
        ; Add status area for tooltips
        this.controls["statusText"] := this.gui.AddText("y+15 x15 w370 Center 0x200 cFFFFFF", "")
        
        ; Set up events
        this.gui.OnEvent("Close", (*) => ExitApp())
        this.gui.OnEvent("Size", ObjBindMethod(this, "HandleSize"))
        this.controls["snippetListBox"].OnEvent("Change", ObjBindMethod(this, "UpdatePreview"))
    }
    
    /**
     * Get the text of the currently selected snippet
     * @returns {String} The selected snippet text or empty string
     */
    GetSelectedSnippetText() {
        selected := this.controls.HasProp("snippetListBox") ? this.controls["snippetListBox"].Text : ""
        return this.snippets.Has(selected) ? this.snippets[selected] : ""
    }
    
    /**
     * Add a new snippet to the collection
     * @param {String} name - Name/title of the snippet
     * @param {String} text - Content of the snippet
     */
    AddSnippet(name, text) {
        if (name && text) {
            this.snippets[name] := text
            this.UpdateListBox()
            this.ShowTooltip("Snippet added: " name)
        }
    }
    
    /**
     * Remove a snippet from the collection
     * @param {String} name - Name of the snippet to remove
     */
    RemoveSnippet(name := "") {
        if (!name && this.controls.HasProp("snippetListBox"))
            name := this.controls["snippetListBox"].Text
            
        if (this.snippets.Has(name)) {
            this.snippets.Delete(name)
            this.UpdateListBox()
            this.ShowTooltip("Snippet removed: " name)
        }
    }
    
    /**
     * Update the listbox after snippet collection changes
     */
    UpdateListBox() {
        if (!this.controls.HasProp("snippetListBox"))
            return
            
        ; Create array of snippet names
        snippetNames := []
        for name, _ in this.snippets
            snippetNames.Push(name)
        
        ; Update the listbox
        this.controls["snippetListBox"].Delete()
        for _, name in snippetNames
            this.controls["snippetListBox"].Add([name])
            
        ; Select first item if available
        if (snippetNames.Length > 0)
            this.controls["snippetListBox"].Choose(1)
            
        ; Update preview
        this.UpdatePreview()
    }
    
    /**
     * Update the preview area when selection changes
     */
    UpdatePreview(*) {
        if (this.controls.HasProp("snippetPreview"))
            this.controls["snippetPreview"].Value := this.GetSelectedSnippetText()
    }
    
    /**
     * Copy the selected snippet to clipboard
     */
    CopyToClipboard(*) {
        selected := this.controls["snippetListBox"].Text
        
        if (this.snippets.Has(selected)) {
            A_Clipboard := this.snippets[selected]
            this.ShowTooltip("Copied to clipboard!")
        }
    }
    
    /**
     * Send the selected snippet to the previous window
     */
    SendToWindow(*) {
        selected := this.controls["snippetListBox"].Text
        
        if (this.snippets.Has(selected) && WinExist("ahk_id " this.previousWindow)) {
            ; Activate previous window
            WinActivate("ahk_id " this.previousWindow)
            
            ; Wait for activation
            Sleep(100)
            
            ; Send the text
            SendText(this.snippets[selected])
            
            ; Return to this GUI
            WinActivate("ahk_id " this.gui.Hwnd)
            
            this.ShowTooltip("Text sent to window!")
        } else {
            this.ShowTooltip("Unable to send - window not available!")
        }
    }
    
    /**
     * Display a temporary tooltip message in the status area
     * @param {String} text - Message to display
     */
    ShowTooltip(text) {
        if (!this.controls.HasProp("statusText"))
            return
            
        ; Display a tooltip in the status area
        this.controls["statusText"].Text := text
        
        ; Clear any existing timer
        if (this.tooltipTimer) {
            SetTimer(this.tooltipTimer, 0)
            this.tooltipTimer := 0
        }
        
        ; Create new timer to clear the tooltip
        this.tooltipTimer := ObjBindMethod(this, "ClearTooltip")
        SetTimer(this.tooltipTimer, -3000)  ; Clear after 3 seconds
    }
    
    /**
     * Clear the tooltip message
     */
    ClearTooltip(*) {
        if (this.controls.HasProp("statusText"))
            this.controls["statusText"].Text := ""
        this.tooltipTimer := 0
    }
    
    /**
     * Toggle the visibility of the GUI
     */
    Toggle(*) {
        if (WinExist("ahk_id " this.gui.Hwnd)) {
            if (WinActive("ahk_id " this.gui.Hwnd))
                this.Hide()
            else
                this.Show()
        } else {
            this.Show()
        }
    }
    
    /**
     * Show the GUI and track the previously active window
     */
    Show() {
        this.previousWindow := WinExist("A")
        this.gui.Show()
    }
    
    /**
     * Hide the GUI
     */
    Hide() {
        this.gui.Hide()
    }
    
    /**
     * Handle GUI resize events to reposition controls
     */
    HandleSize(thisGui, minMax, width, height) {
        ; Minimized state
        if (minMax = -1)
            return
            
        ; Calculate control positions
        listboxHeight := height - 220
        buttonY := height - 130
        statusY := height - 40
        
        ; Resize controls
        this.controls["snippetListBox"].Move(, , 370, listboxHeight)
        this.controls["snippetPreview"].Move(, buttonY - 100, 370, 80)
        this.controls["copyButton"].Move(, buttonY)
        this.controls["sendButton"].Move(, buttonY)
        this.controls["statusText"].Move(, statusY)
    }
}

/**
 * DarkTheme class for managing dark mode appearance
 * Handles all the dark theme functionality for GUI elements
 */
class DarkTheme {
    ; Class properties
    gui := ""                ; Reference to parent GUI
    colors := Map()          ; Theme color definitions
    textBackgroundBrush := 0 ; Brush for text backgrounds
    windowProcNew := 0       ; New window procedure
    windowProcOld := 0       ; Old window procedure reference
    isInitialized := false   ; Initialization status
    isDarkMode := true       ; Dark mode state
    
    ; Static control style constants
    static GWL_WNDPROC := -4
    static GWL_STYLE := -16
    static ES_MULTILINE := 0x0004
    static GetWindowLong := A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"
    static SetWindowLong := A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"
    
    ; ListView message constants
    static LVM_GETTEXTCOLOR := 0x1023
    static LVM_SETTEXTCOLOR := 0x1024
    static LVM_GETTEXTBKCOLOR := 0x1025
    static LVM_SETTEXTBKCOLOR := 0x1026
    static LVM_GETBKCOLOR := 0x1000
    static LVM_SETBKCOLOR := 0x1001
    static LVM_GETHEADER := 0x101F
    
    ; WM message constants
    static WM_CTLCOLOREDIT := 0x0133
    static WM_CTLCOLORLISTBOX := 0x0134
    static WM_CTLCOLORBTN := 0x0135
    static WM_CTLCOLORSTATIC := 0x0138
    static DC_BRUSH := 18
    
    /**
     * Constructor - Initialize the dark theme for a GUI
     * @param {Gui} guiObj - The GUI to apply dark theme to
     * @param {Boolean} darkMode - Whether to enable dark mode
     */
    __New(guiObj, darkMode := true) {
        ; Store reference to GUI
        this.gui := guiObj
        
        ; Define dark theme colors
        this.colors := Map(
            "Background", "0x202020", 
            "Controls", "0x404040", 
            "Font", "0xE0E0E0"
        )
        
        ; Create brush for text background
        this.textBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", this.colors["Background"], "Ptr")
        
        ; Set dark mode state
        this.isDarkMode := darkMode
        
        ; Apply dark theme to window
        this.SetWindowAttribute()
        
        ; Apply theme to all controls
        this.SetWindowTheme()
    }
    
    /**
     * Apply dark mode window attributes
     */
    SetWindowAttribute() {
        static PreferredAppMode := Map("Default", 0, "AllowDark", 1, "ForceDark", 2, "ForceLight", 3, "Max", 4)
        
        if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
            DWMWA_USE_IMMERSIVE_DARK_MODE := 19
            if (VerCompare(A_OSVersion, "10.0.18985") >= 0) {
                DWMWA_USE_IMMERSIVE_DARK_MODE := 20
            }
            
            uxtheme := DllCall("kernel32\GetModuleHandle", "Str", "uxtheme", "Ptr")
            SetPreferredAppMode := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
            FlushMenuThemes := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")
            
            if (this.isDarkMode) {
                DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.gui.hWnd, "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", True, "Int", 4)
                DllCall(SetPreferredAppMode, "Int", PreferredAppMode["ForceDark"])
                DllCall(FlushMenuThemes)
                this.gui.BackColor := this.colors["Background"]
            } else {
                DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.gui.hWnd, "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", False, "Int", 4)
                DllCall(SetPreferredAppMode, "Int", PreferredAppMode["Default"])
                DllCall(FlushMenuThemes)
                this.gui.BackColor := "Default"
            }
        }
    }
    
    /**
     * Apply theme to all GUI controls
     */
    SetWindowTheme() {
        static LV_Init := false
        static LV_TEXTCOLOR, LV_TEXTBKCOLOR, LV_BKCOLOR
        
        ; Theme mode strings
        Mode_Explorer := (this.isDarkMode ? "DarkMode_Explorer" : "Explorer")
        Mode_CFD := (this.isDarkMode ? "DarkMode_CFD" : "CFD")
        Mode_ItemsView := (this.isDarkMode ? "DarkMode_ItemsView" : "ItemsView")
        
        ; Apply theme to each control
        for hWnd, GuiCtrlObj in this.gui {
            switch GuiCtrlObj.Type {
                case "Button", "CheckBox", "ListBox", "UpDown":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_Explorer, "Ptr", 0)
                
                case "ComboBox", "DDL":
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_CFD, "Ptr", 0)
                
                case "Edit":
                    if (DllCall("user32\" DarkTheme.GetWindowLong, "Ptr", GuiCtrlObj.hWnd, "Int", DarkTheme.GWL_STYLE) & DarkTheme.ES_MULTILINE) {
                        DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_Explorer, "Ptr", 0)
                    } else {
                        DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_CFD, "Ptr", 0)
                    }
                
                case "ListView":
                    if (!LV_Init) {
                        LV_TEXTCOLOR := SendMessage(DarkTheme.LVM_GETTEXTCOLOR, 0, 0, GuiCtrlObj.hWnd)
                        LV_TEXTBKCOLOR := SendMessage(DarkTheme.LVM_GETTEXTBKCOLOR, 0, 0, GuiCtrlObj.hWnd)
                        LV_BKCOLOR := SendMessage(DarkTheme.LVM_GETBKCOLOR, 0, 0, GuiCtrlObj.hWnd)
                        LV_Init := true
                    }
                    
                    GuiCtrlObj.Opt("-Redraw")
                    if (this.isDarkMode) {
                        SendMessage(DarkTheme.LVM_SETTEXTCOLOR, 0, this.colors["Font"], GuiCtrlObj.hWnd)
                        SendMessage(DarkTheme.LVM_SETTEXTBKCOLOR, 0, this.colors["Background"], GuiCtrlObj.hWnd)
                        SendMessage(DarkTheme.LVM_SETBKCOLOR, 0, this.colors["Background"], GuiCtrlObj.hWnd)
                    } else {
                        SendMessage(DarkTheme.LVM_SETTEXTCOLOR, 0, LV_TEXTCOLOR, GuiCtrlObj.hWnd)
                        SendMessage(DarkTheme.LVM_SETTEXTBKCOLOR, 0, LV_TEXTBKCOLOR, GuiCtrlObj.hWnd)
                        SendMessage(DarkTheme.LVM_SETBKCOLOR, 0, LV_BKCOLOR, GuiCtrlObj.hWnd)
                    }
                    
                    DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_Explorer, "Ptr", 0)
                    
                    ; Header Text theming
                    LV_Header := SendMessage(DarkTheme.LVM_GETHEADER, 0, 0, GuiCtrlObj.hWnd)
                    DllCall("uxtheme\SetWindowTheme", "Ptr", LV_Header, "Str", Mode_ItemsView, "Ptr", 0)
                    GuiCtrlObj.Opt("+Redraw")
            }
        }
        
        ; Set up window procedure subclassing
        if (!this.isInitialized) {
            this.windowProcNew := CallbackCreate(ObjBindMethod(this, "WindowProc"), , 4)
            this.windowProcOld := DllCall("user32\" DarkTheme.SetWindowLong, "Ptr", this.gui.Hwnd, "Int", DarkTheme.GWL_WNDPROC, "Ptr", this.windowProcNew, "Ptr")
            this.isInitialized := true
        }
    }
    
    /**
     * Window procedure for handling control coloring
     */
    WindowProc(hwnd, uMsg, wParam, lParam) {
        Critical
        
        if (this.isDarkMode) {
            switch uMsg {
                case DarkTheme.WM_CTLCOLOREDIT, DarkTheme.WM_CTLCOLORLISTBOX:
                    DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", this.colors["Font"])
                    DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", this.colors["Controls"])
                    DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", this.colors["Controls"], "UInt")
                    return DllCall("gdi32\GetStockObject", "Int", DarkTheme.DC_BRUSH, "Ptr")
                
                case DarkTheme.WM_CTLCOLORBTN:
                    DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", this.colors["Background"], "UInt")
                    return DllCall("gdi32\GetStockObject", "Int", DarkTheme.DC_BRUSH, "Ptr")
                
                case DarkTheme.WM_CTLCOLORSTATIC:
                    DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", this.colors["Font"])
                    DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", this.colors["Background"])
                    return this.textBackgroundBrush
            }
        }
        
        return DllCall("user32\CallWindowProc", "Ptr", this.windowProcOld, "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam)
    }
}

/**
 * SendMessage helper function
 * Handles sending window messages to controls
 */
SendMessage(msg, wParam, lParam, hwnd) {
    static SendMessageW := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32", "Ptr"), "AStr", "SendMessageW", "Ptr")
    return DllCall(SendMessageW, "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
}

; Create and initialize the Snippet Manager application
snippetApp := SnippetManager()
snippetApp.Show()
