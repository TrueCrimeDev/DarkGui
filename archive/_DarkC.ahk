#Requires AutoHotkey v2.1-alpha
#SingleInstance Force

class _DarkC {
  static Theme := Map(
    "Background", 0x202020,
    "Text", 0xF0F0F0,
    "ControlBackground", 0x2A2A2A,
    "ControlText", 0xF0F0F0,
    "ButtonFace", 0x3F3F3F,
    "ButtonText", 0xF0F0F0,
    "Accent", 0x0078D7
  )

  static BrushCache := Map()

  static ProcessWindowMessage(hwnd, uMsg, wParam, lParam, *) {
    static WM_CTLCOLOREDIT := 0x0133
    static WM_CTLCOLORLISTBOX := 0x0134
    static WM_CTLCOLORBTN := 0x0135
    static WM_CTLCOLORSTATIC := 0x0138

    if (uMsg = WM_CTLCOLOREDIT || uMsg = WM_CTLCOLORLISTBOX ||
      uMsg = WM_CTLCOLORBTN || uMsg = WM_CTLCOLORSTATIC) {

      DllCall("SetTextColor", "Ptr", wParam, "UInt", _DarkC.Theme["Text"])
      DllCall("SetBkColor", "Ptr", wParam, "UInt", _DarkC.Theme["ControlBackground"])

      color := _DarkC.Theme["ControlBackground"]
      if (!_DarkC.BrushCache.Has(color))
        _DarkC.BrushCache[color] := DllCall("CreateSolidBrush", "UInt", color, "Ptr")

      return _DarkC.BrushCache[color]
    }

    origProc := _DarkExt.WindowMap.Get(hwnd, _DarkExt.DefaultWindowProc)
    return DllCall("CallWindowProc", "Ptr", origProc, "Ptr", hwnd,
      "UInt", uMsg, "Ptr", wParam, "Ptr", lParam, "Ptr")
  }

  static CleanupBrushes() {
    for color, brush in _DarkC.BrushCache
      DllCall("DeleteObject", "Ptr", brush)

    _DarkC.BrushCache := Map()
  }
}

class _DarkExt extends Gui {
  static WindowMap := Map()
  static DefaultWindowProc := 0
  static WindowProcCallback := 0

  __New(Options := "", Title := A_ScriptName, EventObj?) {
    super.__New(Options, Title, EventObj ?? this)

    this.BackColor := _DarkC.Theme["Background"]

    this.ApplyDarkMode()
    this.SetupWindowProc()
  }

  ApplyDarkMode() {
    if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
      DWMWA_USE_IMMERSIVE_DARK_MODE := 19
      if (VerCompare(A_OSVersion, "10.0.18985") >= 0)
        DWMWA_USE_IMMERSIVE_DARK_MODE := 20

      try {
        uxtheme := DllCall("kernel32\GetModuleHandle", "Str", "uxtheme", "Ptr")
        if (uxtheme) {
          SetPreferredAppMode := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
          FlushMenuThemes := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")

          if (SetPreferredAppMode && FlushMenuThemes) {
            this.SetWindowAttribute(DWMWA_USE_IMMERSIVE_DARK_MODE, true)
            DllCall(SetPreferredAppMode, "Int", 2)
            DllCall(FlushMenuThemes)
          }
        }
      } catch as err {
        OutputDebug("Failed to apply dark mode: " err.Message)
      }
    }

    this.SetDarkMenu()
  }

  SetupWindowProc() {
    if (!_DarkExt.WindowProcCallback) {
      _DarkExt.WindowProcCallback := CallbackCreate(_DarkC.ProcessWindowMessage, "Fast")
      _DarkExt.DefaultWindowProc := 0
    }

    origProc := DllCall("GetWindowLongPtr", "Ptr", this.Hwnd, "Int", -4, "Ptr")
    _DarkExt.WindowMap[this.Hwnd] := origProc

    if (!_DarkExt.DefaultWindowProc)
      _DarkExt.DefaultWindowProc := origProc

    DllCall("SetWindowLongPtr", "Ptr", this.Hwnd, "Int", -4, "Ptr", _DarkExt.WindowProcCallback)
  }

  Show(Options := "") {
    result := super.Show(Options)
    DllCall("RedrawWindow", "Ptr", this.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0287)
    return result
  }

  SetDarkMenu() {
    try {
      uxtheme := DllCall("GetModuleHandle", "Ptr", StrPtr("uxtheme"), "Ptr")
      if (uxtheme) {
        SetPreferredAppMode := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
        FlushMenuThemes := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")

        if (SetPreferredAppMode && FlushMenuThemes) {
          DllCall(SetPreferredAppMode, "Int", 1)
          DllCall(FlushMenuThemes)
        }
      }
    } catch as err {
      OutputDebug("Failed to set dark menu: " err.Message)
    }
  }

  SetWindowAttribute(dwAttribute, pvAttribute) {
    try {
      return DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Hwnd,
        "Uint", dwAttribute, "Uint*", pvAttribute, "Int", 4)
    } catch as err {
      OutputDebug("Failed to set window attribute: " err.Message)
      return 0
    }
  }

  ApplyDarkToControl(control, options := "") {
    if (control is Gui.Text)
      control.Opt("c" _DarkC.Theme["Text"] " " options)
    else if (control is Gui.Button)
      control.Opt("Background" _DarkC.Theme["ButtonFace"] " c" _DarkC.Theme["ButtonText"] " " options)
    else if (control is Gui.Edit || control is Gui.ListBox || control is Gui.ComboBox || control is Gui.ListView)
      control.Opt("Background" _DarkC.Theme["ControlBackground"] " c" _DarkC.Theme["Text"] " " options)

    return control
  }

  CreateStructs() {
    RECT := Map(
      "left", 0,
      "top", 0,
      "right", 0,
      "bottom", 0
    )

    NMHDR := Map(
      "hwndFrom", 0,
      "idFrom", 0,
      "code", 0
    )

    NMCUSTOMDRAW := Map(
      "hdr", NMHDR,
      "dwDrawStage", 0,
      "hdc", 0,
      "rc", RECT,
      "dwItemSpec", 0,
      "uItemState", 0,
      "lItemlParam", 0
    )

    return NMCUSTOMDRAW
  }

  ProcessCustomDraw(lParam) {
    NMCD := this.CreateStructs()
    NMCD["hdr"]["hwndFrom"] := NumGet(lParam, 0, "Ptr")
    NMCD["hdr"]["idFrom"] := NumGet(lParam, A_PtrSize, "Ptr")
    NMCD["hdr"]["code"] := NumGet(lParam, A_PtrSize * 2, "UInt")

    rectOffset := A_PtrSize * 2 + 4 + A_PtrSize
    NMCD["rc"]["left"] := NumGet(lParam, rectOffset, "Int")
    NMCD["rc"]["top"] := NumGet(lParam, rectOffset + 4, "Int")
    NMCD["rc"]["right"] := NumGet(lParam, rectOffset + 8, "Int")
    NMCD["rc"]["bottom"] := NumGet(lParam, rectOffset + 12, "Int")

    dwItemSpecOffset := rectOffset + 16
    NMCD["dwItemSpec"] := NumGet(lParam, dwItemSpecOffset, "UPtr")
    NMCD["uItemState"] := NumGet(lParam, dwItemSpecOffset + A_PtrSize, "UInt")
    NMCD["lItemlParam"] := NumGet(lParam, dwItemSpecOffset + A_PtrSize + 4, "Ptr")
    return NMCD
  }

  __Delete() {
    if (_DarkExt.WindowMap.Has(this.Hwnd))
      _DarkExt.WindowMap.Delete(this.Hwnd)

    if (_DarkExt.WindowMap.Count = 0) {
      _DarkC.CleanupBrushes()

      if (_DarkExt.WindowProcCallback) {
        CallbackFree(_DarkExt.WindowProcCallback)
        _DarkExt.WindowProcCallback := 0
      }
    }
  }
}

class DarkGUIExample {
  __New() {
    this.CreateGui()
    this.SetupEvents()
    this.gui.Show("w500 h400")
  }

  CreateGui() {
    this.gui := _DarkExt("+Resize +MinSize400x300", "Dark GUI Example")

    this.gui.SetFont("s10 c" _DarkC.Theme["Text"])
    this.gui.AddText("w480", "Welcome to Dark Mode GUI")

    this.gui.AddEdit("xm w480 h100 vNoteInput", "Enter some text here...")

    this.gui.AddButton("xm y+20 w150 vSaveBtn", "Save")
      .OnEvent("Click", this.OnSave.Bind(this))

    this.gui.AddButton("x+20 w150 vClearBtn", "Clear")
      .OnEvent("Click", this.OnClear.Bind(this))

    this.gui.AddListBox("xm y+20 w480 h120 vItemList", ["Item 1", "Item 2", "Item 3"])
      .OnEvent("Change", this.OnItemSelect.Bind(this))

    this.gui.AddStatusBar().SetText("Ready")
  }

  SetupEvents() {
    this.gui.OnEvent("Close", this.OnClose.Bind(this))
    this.gui.OnEvent("Escape", this.OnEscape.Bind(this))
    this.gui.OnEvent("Size", this.OnSize.Bind(this))
  }

  OnSave(*) {
    saved := this.gui.Submit(false)
    MsgBox("Text saved: " saved.NoteInput)
    this.gui.StatusBar.SetText("Text saved")
  }

  OnClear(*) {
    this.gui["NoteInput"].Value := ""
    this.gui.StatusBar.SetText("Text cleared")
  }

  OnItemSelect(*) {
    selectedItem := this.gui["ItemList"].Text
    this.gui.StatusBar.SetText("Selected: " selectedItem)
  }

  OnSize(thisGui, minMax, width, height) {
    if (minMax = -1)
      return

    this.gui["NoteInput"].Move(, , width - 20)
    this.gui["ItemList"].Move(, , width - 20, height - 250)
  }

  OnClose(*) {
    this.ExitApp()
  }

  OnEscape(*) {
    this.ExitApp()
  }

  ExitApp() {
    ExitApp()
  }
}

myGui := DarkGUIExample()