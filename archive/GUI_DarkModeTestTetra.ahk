#Requires AutoHotkey v2.1-alpha.14
#SingleInstance Force

DarkGui()

class DarkGui {
  __New() {    
    this.gui := Gui("+AlwaysOnTop")
    this.SetupColors()
    SetDarkWindowFrame(this.gui)
    SetWinAttr(this.gui)
    this.SetupGui()
    SetWinTheme(this.gui)
    this.SetupHotkeys()
    this.gui.Show()
  }

  SetupGui() {
    this.gui.SetFont("s11 cWhite", "Segoe UI")
    this.gui.AddText("cWhite", "Enter:")
    this.gui.AddEdit("vMyEdit w200")
    this.gui.AddCheckBox("xm y+10 Checked h23 w20")
    this.gui.AddText("x+1 yp 0x200 h10", "Checkbox")
    this.gui.AddButton("xm y+10 w100 h30", "Submit").OnEvent("Click", this.Submit.Bind(this))
    this.gui.AddListView("xm y+10 w200 h100 cWhite", ["Column 1", "Column 2"])
    this.gui.AddComboBox("xm y+10 w200 cWhite", ["Option 1", "Option 2", "Option 3"])
  }

  Submit(*) {
    saved := this.gui.Submit()
    MsgBox("Input: " saved.MyEdit "`nCheckbox: " saved.MyCheck)
  }

  SetupColors() {
    global TextBGBrush := DllCall("gdi32\CreateSolidBrush", "UInt", "0x202020", "Ptr")
  }

  SetupHotkeys() {
    HotKey("Escape", (*) => this.gui.Hide())
  }
}

SetMenuAttr() {
  DarkColors := Map("Background", "0x202020", "Controls", "0x404040", "Font", "0xE0E0E0")
  if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
    DWMWA_USE_IMMERSIVE_DARK_MODE := 19
    if (VerCompare(A_OSVersion, "10.0.18985") >= 0) {
      DWMWA_USE_IMMERSIVE_DARK_MODE := 20
    }
    uxtheme := DllCall("kernel32\GetModuleHandle", "Str", "uxtheme", "Ptr")
    SetPreferredAppMode := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
    FlushMenuThemes := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")

    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", A_ScriptHwnd, "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", True, "Int", 4)
    DllCall(SetPreferredAppMode, "Int", 2)
    DllCall(FlushMenuThemes)
  }
}

SetWinAttr(GuiObj) {
  DarkColors := Map("Background", "0x202020", "Controls", "0x404040", "Font", "0xE0E0E0")
  if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
    DWMWA_USE_IMMERSIVE_DARK_MODE := 19
    if (VerCompare(A_OSVersion, "10.0.18985") >= 0) {
      DWMWA_USE_IMMERSIVE_DARK_MODE := 20
    }
    uxtheme := DllCall("kernel32\GetModuleHandle", "Str", "uxtheme", "Ptr")
    SetPreferredAppMode := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
    FlushMenuThemes := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")

    DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", GuiObj.Hwnd, "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", True, "Int", 4)
    DllCall(SetPreferredAppMode, "Int", 2)
    DllCall(FlushMenuThemes)
    GuiObj.BackColor := DarkColors["Background"]
  }
}

SetWinTheme(GuiObj) {
  DarkColors := Map("Background", "0x202020", "Controls", "0x404040", "Font", "0xE0E0E0")
  static GWL_WNDPROC := -4
  static GWL_STYLE := -16
  static ES_MULTILINE := 0x0004
  static LVM_GETTEXTCOLOR := 0x1023
  static LVM_SETTEXTCOLOR := 0x1024
  
  static GWL_WNDPROC        := -4
	static GWL_STYLE          := -16
	static ES_MULTILINE       := 0x0004
	static LVM_GETTEXTCOLOR   := 0x1023
	static LVM_SETTEXTCOLOR   := 0x1024
	static LVM_GETTEXTBKCOLOR := 0x1025
	static LVM_SETTEXTBKCOLOR := 0x1026
	static LVM_GETBKCOLOR     := 0x1000
	static LVM_SETBKCOLOR     := 0x1001
	static LVM_GETHEADER      := 0x101F
  static LVM_GETTEXTBKCOLOR := 0x1025
  static LVM_SETTEXTBKCOLOR := 0x1026
  static LVIF_TEXT               := 0x00000001
  static LVM_GETBKCOLOR := 0x1000
  static LVS_EDITLABELS          := 0x0200

  static LVM_GETITEMTEXTW        := 0x1073 ; (LVM_FIRST + 115)
  static LVM_SETBKCOLOR := 0x1001
  static LVM_GETHEADER := 0x101F
  static GetWindowLong := A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"
  static SetWindowLong := A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"
  Init := False
  LV_Init := False

  Mode_Explorer := "DarkMode_Explorer"
  Mode_CFD := "DarkMode_CFD"
  Mode_ItemsView := "DarkMode_ItemsView"

  for hWnd, GuiCtrlObj in GuiObj {
    switch GuiCtrlObj.Type {
      case "Button", "CheckBox", "ListBox", "UpDown", "Text":
      {
        DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_Explorer, "Ptr", 0)
      }
      case "ComboBox", "DDL":
      {
        DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_CFD, "Ptr", 0)
      }
      case "Edit":
      {
        if (DllCall("user32\" . GetWindowLong, "Ptr", GuiCtrlObj.hWnd, "Int", GWL_STYLE) & ES_MULTILINE) {
          DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_Explorer, "Ptr", 0)
        } else {
          DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_CFD, "Ptr", 0)
        }
      }
      case "ListView":
      {
        if !(LV_Init) {
          static LV_TEXTCOLOR := SendMessage(LVM_GETTEXTCOLOR, 0, 0, GuiCtrlObj.hWnd)
          static LV_TEXTBKCOLOR := SendMessage(LVM_GETTEXTBKCOLOR, 0, 0, GuiCtrlObj.hWnd)
          static LV_BKCOLOR := SendMessage(LVM_GETBKCOLOR, 0, 0, GuiCtrlObj.hWnd)
          static LV_EDITLABELS := SendMessage(LVS_EDITLABELS, 0, 0, GuiCtrlObj.hWnd)
          LV_Init := True
        }
        GuiCtrlObj.Opt("-Redraw")
        SendMessage(LVS_EDITLABELS, 0, DarkColors["Font"], GuiCtrlObj.hWnd)
        SendMessage(LVM_SETTEXTCOLOR, 0, DarkColors["Font"], GuiCtrlObj.hWnd)
        SendMessage(LVM_SETTEXTBKCOLOR, 0, DarkColors["Background"], GuiCtrlObj.hWnd)
        SendMessage(LVM_SETBKCOLOR, 0, DarkColors["Background"], GuiCtrlObj.hWnd)
        DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_Explorer, "Ptr", 0)
        LV_Header := SendMessage(LVM_GETHEADER, 0, 0, GuiCtrlObj.hWnd)
        DllCall("uxtheme\SetWindowTheme", "Ptr", LV_Header, "Str", Mode_ItemsView, "Ptr", 0)
        GuiCtrlObj.Opt("+Redraw")
      }
    }
  }
  if !(Init) {
    global WindowProcNew := CallbackCreate(WindowProc)
    global WindowProcOld := DllCall("user32\" . SetWindowLong, "Ptr", GuiObj.Hwnd, "Int", GWL_WNDPROC, "Ptr", WindowProcNew, "Ptr")
    Init := True
  }
}

WindowProc(hwnd, uMsg, wParam, lParam) {
  critical
  DarkColors := Map("Background", "0x202020", "Controls", "0x404040", "Font", "0xE0E0E0")
  static WM_CTLCOLOREDIT := 0x0133
  static WM_CTLCOLORLISTBOX := 0x0134
  static WM_CTLCOLORBTN := 0x0135
  static WM_CTLCOLORSTATIC := 0x0138
  static DC_BRUSH := 18

  switch uMsg {
    case WM_CTLCOLOREDIT, WM_CTLCOLORLISTBOX:
    {
      DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkColors["Font"])
      DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkColors["Controls"])
      DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", DarkColors["Controls"], "UInt")
      return DllCall("gdi32\GetStockObject", "Int", DC_BRUSH, "Ptr")
    }
    case WM_CTLCOLORBTN:
    {
      DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", DarkColors["Background"], "UInt")
      return DllCall("gdi32\GetStockObject", "Int", DC_BRUSH, "Ptr")
    }
    case WM_CTLCOLORSTATIC:
    {
      DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkColors["Font"])
      DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkColors["Background"])
      return TextBGBrush
    }
  }
  return DllCall("user32\CallWindowProc", "Ptr", WindowProcOld, "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", lParam)
}

SetDarkWindowFrame(hwnd, boolEnable:=1) {
    hwnd := WinExist(hwnd)
    if VerCompare(A_OSVersion, "10.0.17763") >= 0
        attr := 19
    if VerCompare(A_OSVersion, "10.0.18985") >= 0
        attr := 20
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", attr, "int*", boolEnable, "int", 4)
}