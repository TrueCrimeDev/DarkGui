#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

; Global variable for dark mode instance
global darkModeInstance := ""

DarkGui()

class DarkGui {
    __New() {
        ; Initialize Dark Mode
        this.darkMode := Win32DarkMode()
        darkModeInstance := this.darkMode
        
        ; Create GUI and setup controls
        this.gui := Gui("+Resize", "Dark Mode Example")
        this.gui.SetFont("s10")
        this.gui.AddText("w300", "Dark mode example")
        this.gui.AddButton("w300", "OK").OnEvent("Click", (*) => this.gui.Hide())
        
        ; Apply dark mode
        this.hwnd := this.gui.Hwnd
        this.ApplyDarkMode()
        
        ; Show GUI
        this.gui.Show()
    }
    
    ApplyDarkMode() {
        ; Apply dark mode to window
        this.darkMode.AllowDModeForWin(this.hwnd, true)
        this.darkMode.RefreshTitleBarThemeColor(this.hwnd)
        
        ; Use direct function reference for callback
        DllCall("EnumChildWindows", "Ptr", this.hwnd, "Ptr", CallbackCreate(ProcessChildWindow), "Ptr", 0)
    }
}

; Standalone callback function with correct parameter signature
ProcessChildWindow(hwnd, lParam) {
    if (!DllCall("IsWindow", "Ptr", hwnd))
        return true
        
    darkModeInstance.AllowDModeForWin(hwnd, Win32DarkMode.dEnabled)
    
    ; Get control type and apply appropriate styling
    className := Buffer(64)
    if (DllCall("GetClassName", "Ptr", hwnd, "Ptr", className, "Int", 32))
        className := StrGet(className)
    else
        className := ""
    
    ; Apply appropriate styling based on control type
    if (Win32DarkMode.pfnSetWinTheme)
        DllCall(Win32DarkMode.pfnSetWinTheme, "Ptr", hwnd, "WStr", "Explorer", "Ptr", 0)
    
    SendMessage(0x031A, 0, 0, hwnd)  ; WM_THEMECHANGED
    
    return true
}

class Win32DarkMode {
  static pfnSetWinCompAttr := 0
  static pfnShouldAppsDMode := 0
  static pfnAllowDModeForWin := 0
  static pfnAllowDModeForApp := 0
  static pfnRefreshImColorState := 0
  static pfnIsDModeAllowedForWin := 0
  static pfnGetIsImColorUsingHC := 0
  static pfnOpenNcThemeData := 0
  static pfnShouldSysDMode := 0
  static pfnSetPrefAppMode := 0
  static pfnGetThemeColor := 0
  static pfnSetWinTheme := 0
  static pfnOpenThemeData := 0
  static pfnCloseThemeData := 0

  static Default := 0
  static AllowD := 1
  static ForceD := 2
  static ForceLight := 3
  static Max := 4

  static dSupported := false
  static dEnabled := false
  static buildNum := 0
  static hbrBkgnd := 0
  static hMainWnd := 0
  static AltInitDialogMsgID := 0

  static BUTTbkgnd := 0x202020
  static BUTTtext := 0xFFFFFF
  static BUTTbkgndDis := 0x404040
  static BUTTtextDis := 0x808080

  static TREEbkgnd := 0x202020
  static TREEtext := 0xFFFFFF
  static TREEbkgndDis := 0x404040
  static TREEtextDis := 0x808080

  static EDITbkgnd := 0x202020
  static EDITtext := 0xFFFFFF
  static EDITbkgndDis := 0x404040
  static EDITtextDis := 0x808080

  static LISTbkgnd := 0x202020
  static LISTtext := 0xFFFFFF
  static LISTbkgndDis := 0x404040
  static LISTtextDis := 0x808080

  static DColButt := ""
  static DColTree := ""
  static DColEdit := ""
  static DColList := ""
  static DColor := ""
  static ColorWinStd := ""

  __New() {
    Win32DarkMode.DColButt := ColorScheme(Win32DarkMode.BUTTbkgnd, Win32DarkMode.BUTTtext, Win32DarkMode.BUTTbkgndDis, Win32DarkMode.BUTTtextDis)
    Win32DarkMode.DColTree := ColorScheme(Win32DarkMode.TREEbkgnd, Win32DarkMode.TREEtext, Win32DarkMode.TREEbkgndDis, Win32DarkMode.TREEtextDis)
    Win32DarkMode.DColEdit := ColorScheme(Win32DarkMode.EDITbkgnd, Win32DarkMode.EDITtext, Win32DarkMode.EDITbkgndDis, Win32DarkMode.EDITtextDis)
    Win32DarkMode.DColList := ColorScheme(Win32DarkMode.LISTbkgnd, Win32DarkMode.LISTtext, Win32DarkMode.LISTbkgndDis, Win32DarkMode.LISTtextDis)
    Win32DarkMode.DColor := ColorScheme(Win32DarkMode.EDITbkgnd, Win32DarkMode.EDITtext, Win32DarkMode.EDITbkgndDis, Win32DarkMode.EDITtextDis)
    Win32DarkMode.ColorWinStd := ColorScheme(0, 0, 0, 0)
    this.InitDMode()
    return this
  }

  InitDMode(altInitDialogMsg := 0) {
    Win32DarkMode.AltInitDialogMsgID := altInitDialogMsg

    Win32DarkMode.buildNum := this.GetWinBuildNum()

    if (Win32DarkMode.buildNum && this.CheckBuildNum(Win32DarkMode.buildNum)) {
      hUxtheme := DllCall("LoadLibraryExW", "Str", "uxtheme.dll", "Ptr", 0, "UInt", 0x00000800, "Ptr")

      if (hUxtheme) {
        Win32DarkMode.pfnOpenNcThemeData := DllCall("GetProcAddress", "Ptr", hUxtheme, "Ptr", 49, "Ptr")
        Win32DarkMode.pfnRefreshImColorState := DllCall("GetProcAddress", "Ptr", hUxtheme, "Ptr", 104, "Ptr")
        Win32DarkMode.pfnGetIsImColorUsingHC := DllCall("GetProcAddress", "Ptr", hUxtheme, "Ptr", 106, "Ptr")
        Win32DarkMode.pfnShouldAppsDMode := DllCall("GetProcAddress", "Ptr", hUxtheme, "Ptr", 132, "Ptr")
        Win32DarkMode.pfnAllowDModeForWin := DllCall("GetProcAddress", "Ptr", hUxtheme, "Ptr", 133, "Ptr")

        ord135 := DllCall("GetProcAddress", "Ptr", hUxtheme, "Ptr", 135, "Ptr")
        if (Win32DarkMode.buildNum < 18362)
          Win32DarkMode.pfnAllowDModeForApp := ord135
        else
          Win32DarkMode.pfnSetPrefAppMode := ord135

        Win32DarkMode.pfnIsDModeAllowedForWin := DllCall("GetProcAddress", "Ptr", hUxtheme, "Ptr", 137, "Ptr")

        Win32DarkMode.pfnSetWinCompAttr := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "user32.dll", "Ptr"), "AStr", "SetWindowCompositionAttribute", "Ptr")

        Win32DarkMode.pfnGetThemeColor := DllCall("GetProcAddress", "Ptr", hUxtheme, "AStr", "GetThemeColor", "Ptr")
        Win32DarkMode.pfnSetWinTheme := DllCall("GetProcAddress", "Ptr", hUxtheme, "AStr", "SetWindowTheme", "Ptr")
        Win32DarkMode.pfnOpenThemeData := DllCall("GetProcAddress", "Ptr", hUxtheme, "AStr", "OpenThemeData", "Ptr")
        Win32DarkMode.pfnCloseThemeData := DllCall("GetProcAddress", "Ptr", hUxtheme, "AStr", "CloseThemeData", "Ptr")

        if (Win32DarkMode.pfnOpenNcThemeData &&
          Win32DarkMode.pfnRefreshImColorState &&
          Win32DarkMode.pfnShouldAppsDMode &&
          Win32DarkMode.pfnAllowDModeForWin &&
          (Win32DarkMode.pfnAllowDModeForApp || Win32DarkMode.pfnSetPrefAppMode) &&
          Win32DarkMode.pfnIsDModeAllowedForWin &&
          Win32DarkMode.pfnGetThemeColor &&
          Win32DarkMode.pfnSetWinTheme &&
          Win32DarkMode.pfnOpenThemeData &&
          Win32DarkMode.pfnCloseThemeData) {

          Win32DarkMode.dSupported := true

          this.AllowDModeForApp(true)
          this.RefreshImColorState()

          Win32DarkMode.dEnabled := this.ShouldAppsDMode() && !this.IsHighContrast()
        }
      }
    }
  }

  GetWinBuildNum() {
    try {
      return Integer(RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "CurrentBuildNumber"))
    } catch {
      return 0
    }
  }

  CheckBuildNum(buildNum) {
    return (buildNum == 17763 ||  ; 1809
      buildNum == 18362 ||  ; 1903
      buildNum == 18363 ||  ; 1909
      buildNum == 19041 ||  ; 2004
      buildNum == 19042 ||  ; 20H2
      buildNum == 19043 ||  ; 21H1
      buildNum == 19044 ||  ; 21H2
      buildNum == 19045 ||  ; 22H2
      buildNum == 22000 ||  ; 21H2 win11
      buildNum == 22621 ||  ; 22H2
      buildNum == 22631 ||  ; 23H2
      buildNum == 26100)    ; 24H2
  }

  IsDSupported() {
    return Win32DarkMode.dSupported
  }

  IsDEnabled() {
    return Win32DarkMode.dEnabled
  }

  GetColorList() {
    return Win32DarkMode.DColList
  }

  GetColorTree() {
    return Win32DarkMode.DColTree
  }

  GetColorEdit() {
    return Win32DarkMode.DColEdit
  }

  GetColorButton() {
    return Win32DarkMode.DColButt
  }

  AllowDModeForWin(hWnd, allow) {
    if (Win32DarkMode.dSupported && Win32DarkMode.pfnAllowDModeForWin) {
      return DllCall(Win32DarkMode.pfnAllowDModeForWin, "Ptr", hWnd, "Int", allow)
    }
    return false
  }

  IsHighContrast() {
    static HIGHCONTRASTW := 0x42
    static HCF_HIGHCONTRASTON := 0x1

    vHC := Buffer(HIGHCONTRASTW, 0)
    NumPut("UInt", HIGHCONTRASTW, vHC, 0)

    if (DllCall("SystemParametersInfo", "UInt", 0x42, "UInt", HIGHCONTRASTW, "Ptr", vHC, "UInt", 0)) {
      dwFlags := NumGet(vHC, 8, "UInt")
      return (dwFlags & HCF_HIGHCONTRASTON) != 0
    }
    return false
  }

  RefreshTitleBarThemeColor(hWnd) {
    dark := 0

    if (Win32DarkMode.pfnIsDModeAllowedForWin &&
      Win32DarkMode.pfnShouldAppsDMode &&
      this.IsDModeAllowedForWin(hWnd) &&
      this.ShouldAppsDMode() &&
      !this.IsHighContrast()) {
      dark := 1
    }

    if (Win32DarkMode.buildNum < 18362)
      DllCall("SetPropW", "Ptr", hWnd, "Str", "UseImmersiveDarkModeColors", "Ptr", dark)
    else if (Win32DarkMode.pfnSetWinCompAttr) {
      data := Buffer(12, 0)
      NumPut("UInt", 26, data, 0)  ; WCA_USEDARKMODECOLORS
      NumPut("Ptr", &dark, data, 4)
      NumPut("UInt", 4, data, 8)   ; sizeof(BOOL)

      DllCall(Win32DarkMode.pfnSetWinCompAttr, "Ptr", hWnd, "Ptr", data)
    }
  }

  IsColorSchemeChangeMsg(lParam) {
    if (lParam && StrGet(lParam) == "ImmersiveColorSet") {
      this.RefreshImColorState()
      return true
    }
    this.GetIsImColorUsingHC(0)  ; IHCM_REFRESH
    return false
  }

  AllowDModeForApp(allow) {
    if (Win32DarkMode.pfnAllowDModeForApp)
      DllCall(Win32DarkMode.pfnAllowDModeForApp, "Int", allow)
    else if (Win32DarkMode.pfnSetPrefAppMode)
      DllCall(Win32DarkMode.pfnSetPrefAppMode, "Int", allow ? Win32DarkMode.AllowD : Win32DarkMode.Default)
  }

  RefreshImColorState() {
    if (Win32DarkMode.pfnRefreshImColorState)
      DllCall(Win32DarkMode.pfnRefreshImColorState)
  }

  IsDModeAllowedForWin(hWnd) {
    if (Win32DarkMode.pfnIsDModeAllowedForWin)
      return DllCall(Win32DarkMode.pfnIsDModeAllowedForWin, "Ptr", hWnd)
    return false
  }

  ShouldAppsDMode() {
    if (Win32DarkMode.pfnShouldAppsDMode)
      return DllCall(Win32DarkMode.pfnShouldAppsDMode)
    return false
  }

  GetIsImColorUsingHC(mode) {
    if (Win32DarkMode.pfnGetIsImColorUsingHC)
      return DllCall(Win32DarkMode.pfnGetIsImColorUsingHC, "Int", mode)
    return false
  }

  HandleWMCTLCOLORMsg(hdc, hwnd, &lresult, pcolors) {
    if (Win32DarkMode.dEnabled) {
      bkcolor := pcolors.crBkgnd
      textcolor := pcolors.crText

      if (!DllCall("IsWindowEnabled", "Ptr", hwnd)) {
        bkcolor := pcolors.crBkgndDis
        textcolor := pcolors.crTextDis
        lresult := pcolors.GetBkgndDisBrush()
      } else {
        lresult := pcolors.GetBkgndBrush()
      }

      DllCall("SetTextColor", "Ptr", hdc, "UInt", textcolor)
      DllCall("SetBkColor", "Ptr", hdc, "UInt", bkcolor)

      return true
    }

    lresult := 0
    return false
  }

  HandleDMode(hWnd, msg, wParam, lParam, &lresult) {
    if (!this.IsDSupported())
      return false

    if (Win32DarkMode.AltInitDialogMsgID != 0 && Win32DarkMode.AltInitDialogMsgID == msg)
      msg := 0x0110  ; WM_INITDIALOG

    if (msg == 0x0001)  ; WM_CREATE
      if (Win32DarkMode.hMainWnd == 0)
        Win32DarkMode.hMainWnd := hWnd

    switch msg {
      case 0x0110:  ; WM_INITDIALOG
        if (Win32DarkMode.dEnabled) {
          this.AllowDModeForWin(hWnd, true)
          this.RefreshTitleBarThemeColor(hWnd)
          this.EnumChildWinsForDMode(hWnd)
        }

      case 0x0002:  ; WM_DESTROY
        if (Win32DarkMode.hbrBkgnd && hWnd == Win32DarkMode.hMainWnd) {
          DllCall("DeleteObject", "Ptr", Win32DarkMode.hbrBkgnd)
          Win32DarkMode.hbrBkgnd := 0
        }

      case 0x0138:  ; WM_CTLCOLORBTN
        return this.HandleWMCTLCOLORMsg(wParam, lParam, &lresult, Win32DarkMode.DColButt)

      case 0x0133:  ; WM_CTLCOLOREDIT
        return this.HandleWMCTLCOLORMsg(wParam, lParam, &lresult, Win32DarkMode.DColEdit)

      case 0x0134:  ; WM_CTLCOLORLISTBOX
        return this.HandleWMCTLCOLORMsg(wParam, lParam, &lresult, Win32DarkMode.DColList)

      case 0x0135:  ; WM_CTLCOLORSCROLLBAR
      case 0x0136:  ; WM_CTLCOLORDLG
      case 0x0137:  ; WM_CTLCOLORSTATIC
        return this.HandleWMCTLCOLORMsg(wParam, lParam, &lresult, Win32DarkMode.DColor)

      case 0x004E:  ; WM_NOTIFY
        if (Win32DarkMode.dEnabled) {
          nmhdr := Buffer(lParam)
          code := NumGet(nmhdr, 8, "Int")  ; code member of NMHDR
          if (code == -12)  ; NM_CUSTOMDRAW
            if (!DllCall("IsWindowEnabled", "Ptr", NumGet(nmhdr, 0, "Ptr")))  ; hwndFrom
              if (this.IsListView(NumGet(nmhdr, 0, "Ptr"))) {
                lresult := this.HandleDisabledLVCustomDraw(lParam)
                DllCall("SetWindowLongPtr", "Ptr", hWnd, "Int", 8, "Ptr", lresult)  ; DWLP_MSGRESULT
                return true
              }
        }

      case 0x001A:  ; WM_SETTINGCHANGE
        if (this.IsColorSchemeChangeMsg(lParam)) {
          if (hWnd == Win32DarkMode.hMainWnd)
            Win32DarkMode.dEnabled := this.ShouldAppsDMode() && !this.IsHighContrast()
          PostMessage(hWnd, 0x031A, 0, 0)  ; Post WM_THEMECHANGED
        }

      case 0x031A:  ; WM_THEMECHANGED
        this.AllowDModeForWin(hWnd, Win32DarkMode.dEnabled)
        this.RefreshTitleBarThemeColor(hWnd)
        this.EnumChildWinsForDMode(hWnd)
        DllCall("RedrawWindow", "Ptr", hWnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0001 | 0x0002)  ; RDW_INVALIDATE | RDW_ERASE
    }

    lresult := 0
    return false
  }

  IsListView(hWnd) {
    className := this.GetClassName(hWnd)
    return (className == "SysListView32")
  }

  GetClassName(hWnd) {
    className := Buffer(64)
    if (DllCall("GetClassName", "Ptr", hWnd, "Ptr", className, "Int", 32))
      return StrGet(className)
    return ""
  }

  HandleDisabledLVCustomDraw(plvnmcd) {
    nmcd := Buffer(plvnmcd)
    dwDrawStage := NumGet(nmcd, 16, "UInt")  ; dwDrawStage in NMCUSTOMDRAW

    if (dwDrawStage == 1)  ; CDDS_PREPAINT
      return 0x00000010  ; CDRF_NOTIFYITEMDRAW

    if (dwDrawStage == 0x00010001) {  ; CDDS_ITEMPREPAINT
      NumPut("UInt", Win32DarkMode.DColList.crBkgndDis, nmcd, 36)  ; clrTextBk
      NumPut("UInt", Win32DarkMode.DColList.crTextDis, nmcd, 32)   ; clrText
    }

    return 0  ; CDRF_DODEFAULT
  }

  EnumChildWinsForDMode(hWnd) {
    DllCall("EnumChildWindows", "Ptr", hWnd, "Ptr", CallbackCreate(this.DarkThemeChangedForChildren.Bind(this)), "Ptr", 0)
  }

  DarkThemeChangedForChildren(hWnd, lParam) {
    if (!DllCall("IsWindow", "Ptr", hWnd))
      return true

    this.AllowDModeForWin(hWnd, Win32DarkMode.dEnabled)

    subappname := "Explorer"
    subidlist := ""

    winType := this.GetWinType(hWnd)

    switch winType {
      case "WINtypeListView":
        this.InitListView(hWnd)

      case "WINtypeTreeView":
        subappname := ""
        subidlist := ""

        pcolors := this.GetColorTree()
        SendMessage(0x111B, 0, pcolors.crText, hWnd)    ; TVM_SETTEXTCOLOR
        SendMessage(0x111D, 0, pcolors.crBkgnd, hWnd)  ; TVM_SETBKCOLOR
        SendMessage(0x1128, 0, pcolors.crText, hWnd)    ; TVM_SETLINECOLOR

      case "WINtypeHeader":
        subappname := "ItemsView"

      case "WINtypeCombo":
        subappname := ""
        subidlist := ""

      case "WINtypeButton":
        style := DllCall("GetWindowLong", "Ptr", hWnd, "Int", -16)  ; GWL_STYLE
        if ((style & 0x0F) == 0x02 || (style & 0x0F) == 0x03 || (style & 0x0F) == 0x04 || (style & 0x0F) == 0x09 || (style & 0x0F) == 0x07) {
          subappname := ""
          subidlist := ""
        }

      case "WINtypeRichEdit":
        pcolors := this.GetColorEdit()
        SendMessage(0x0443, 0, pcolors.crBkgnd, hWnd)  ; EM_SETBKGNDCOLOR

        CHARFORMAT := Buffer(60, 0)
        NumPut("UInt", 60, CHARFORMAT, 0)        ; cbSize
        NumPut("UInt", 0x00000100, CHARFORMAT, 4)  ; dwMask (CFM_COLOR)
        NumPut("UInt", pcolors.crText, CHARFORMAT, 20)  ; crTextColor
        NumPut("UInt", 0, CHARFORMAT, 8)        ; dwEffects

        SendMessage(0x0444, 0, CHARFORMAT, hWnd)  ; EM_SETCHARFORMAT with SCF_DEFAULT

      case "WINtypeSysLink":
        LITEM := Buffer(60, 0)
        NumPut("UInt", 0x01 | 0x08, LITEM, 0)  ; mask = LIF_ITEMINDEX | LIF_STATE
        NumPut("UInt", Win32DarkMode.dEnabled ? 0x01 : 0, LITEM, 8)  ; state = LIS_DEFAULTCOLORS
        NumPut("UInt", 0x01, LITEM, 12)  ; stateMask = LIS_DEFAULTCOLORS

        SendMessage(0x0704, 0, LITEM, hWnd)  ; LM_SETITEM
    }

    if (!Win32DarkMode.dEnabled) {
      subappname := ""
      subidlist := ""
    }

    if (Win32DarkMode.pfnSetWinTheme)
      DllCall(Win32DarkMode.pfnSetWinTheme, "Ptr", hWnd, "WStr", subappname, "WStr", subidlist)

    SendMessage(0x031A, 0, 0, hWnd)  ; WM_THEMECHANGED

    return true
  }

  GetWinType(hWnd) {
    if (hWnd) {
      className := this.GetClassName(hWnd)

      if (className == "SysListView32")
        return "WINtypeListView"
      else if (className == "List")
        return "WINtypeList"
      else if (className == "SysTreeView32")
        return "WINtypeTreeView"
      else if (className == "SysHeader32")
        return "WINtypeHeader"
      else if (className == "ComboBox")
        return "WINtypeCombo"
      else if (className == "Button")
        return "WINtypeButton"
      else if (className == "RichEdit20W")
        return "WINtypeRichEdit"
      else if (className == "SysLink")
        return "WINtypeSysLink"
    }

    return "WINtypeDefault"
  }

  InitListView(hListView) {
    hHeader := SendMessage(0x101F, 0, 0, hListView)  ; LVM_GETHEADER

    if (Win32DarkMode.dEnabled) {
      if (Win32DarkMode.pfnSetWinTheme) {
        DllCall(Win32DarkMode.pfnSetWinTheme, "Ptr", hHeader, "WStr", "ItemsView", "Ptr", 0)
        DllCall(Win32DarkMode.pfnSetWinTheme, "Ptr", hListView, "WStr", "ItemsView", "Ptr", 0)
      }

      pcolors := this.GetColorList()
      SendMessage(0x1036, 0, pcolors.crText, hListView)     ; LVM_SETTEXTCOLOR
      SendMessage(0x1038, 0, pcolors.crBkgnd, hListView)  ; LVM_SETTEXTBKCOLOR
      SendMessage(0x1034, 0, pcolors.crBkgnd, hListView)  ; LVM_SETBKCOLOR
    } else {
      if (Win32DarkMode.pfnSetWinTheme) {
        DllCall(Win32DarkMode.pfnSetWinTheme, "Ptr", hHeader, "Ptr", 0, "Ptr", 0)
        DllCall(Win32DarkMode.pfnSetWinTheme, "Ptr", hListView, "Ptr", 0, "Ptr", 0)
      }
    }
  }

  SetLinkText(hWndDlg, resId, text) {
    result := DllCall("SetDlgItemText", "Ptr", hWndDlg, "Int", resId, "Str", text)

    LITEM := Buffer(60, 0)
    NumPut("UInt", 0x01 | 0x08, LITEM, 0)  ; mask = LIF_ITEMINDEX | LIF_STATE
    NumPut("UInt", Win32DarkMode.dEnabled ? 0x01 : 0, LITEM, 8)  ; state = LIS_DEFAULTCOLORS
    NumPut("UInt", 0x01, LITEM, 12)  ; stateMask = LIS_DEFAULTCOLORS

    hCtrl := DllCall("GetDlgItem", "Ptr", hWndDlg, "Int", resId, "Ptr")
    SendMessage(0x0704, 0, LITEM, hCtrl)  ; LM_SETITEM

    return result
  }

  GetDColors(hWnd, &ppcolors) {
    winType := this.GetWinType(hWnd)
    switch winType {
      case "WINtypeButton":
        ppcolors := Win32DarkMode.DColButt
      case "WINtypeEdit":
        ppcolors := Win32DarkMode.DColEdit
      case "WINtypeListView", "WINtypeList":
        ppcolors := Win32DarkMode.DColList
      case "WINtypeTreeView":
        ppcolors := Win32DarkMode.DColTree
      default:
        ppcolors := Win32DarkMode.DColor
    }
  }

  GetColorWinStd() {
    if (Win32DarkMode.ColorWinStd.crBkgnd == Win32DarkMode.ColorWinStd.crText) {
      Win32DarkMode.ColorWinStd.crBkgnd := DllCall("GetSysColor", "Int", 5, "UInt")  ; COLOR_WINDOW
      Win32DarkMode.ColorWinStd.crText := DllCall("GetSysColor", "Int", 8, "UInt")   ; COLOR_WINDOWTEXT
      Win32DarkMode.ColorWinStd.crBkgndDis := DllCall("GetSysColor", "Int", 5, "UInt")  ; COLOR_WINDOW
      Win32DarkMode.ColorWinStd.crTextDis := DllCall("GetSysColor", "Int", 17, "UInt")  ; COLOR_GRAYTEXT
    }
    return Win32DarkMode.ColorWinStd
  }
}
ColorScheme(crBkgnd, crText, crBkgndDis, crTextDis) {
  obj := {}

  obj.crBkgnd := crBkgnd
  obj.crText := crText
  obj.crBkgndDis := crBkgndDis
  obj.crTextDis := crTextDis
  obj.hBkgndBrush := 0
  obj.hBkgndDisBrush := 0

  getBkgndBrush(self) {
    if (!self.hBkgndBrush)
      self.hBkgndBrush := DllCall("CreateSolidBrush", "UInt", self.crBkgnd, "Ptr")
    return self.hBkgndBrush
  }

  obj.DefineProp("GetBkgndBrush", {Call: getBkgndBrush})

  getBkgndDisBrush(self) {
    if (!self.hBkgndDisBrush)
      self.hBkgndDisBrush := DllCall("CreateSolidBrush", "UInt", self.crBkgndDis, "Ptr")
    return self.hBkgndDisBrush
  }

  obj.DefineProp("GetBkgndDisBrush", {Call: getBkgndDisBrush})

  deleteFunc(self) {
    if (self.hBkgndBrush)
      DllCall("DeleteObject", "Ptr", self.hBkgndBrush)
    if (self.hBkgndDisBrush)
      DllCall("DeleteObject", "Ptr", self.hBkgndDisBrush)
  }

  obj.DefineProp("__Delete", {Call: deleteFunc})

  return obj
}


; Standalone callback function for EnumChildWindows
EnumChildProc(hwnd, lParam) {
    global darkModeInstance
    
    if (!DllCall("IsWindow", "Ptr", hwnd))
        return true
        
    darkModeInstance.AllowDModeForWin(hwnd, Win32DarkMode.dEnabled)
    
    subappname := "Explorer"
    subidlist := ""
    
    className := Buffer(64)
    if (DllCall("GetClassName", "Ptr", hwnd, "Ptr", className, "Int", 32))
        className := StrGet(className)
    else
        className := ""
    
    ; Apply theme based on control type
    if (className == "SysListView32") {
        ; ListView styling
        hHeader := SendMessage(0x101F, 0, 0, hwnd)
        
        if (Win32DarkMode.dEnabled && Win32DarkMode.pfnSetWinTheme) {
            DllCall(Win32DarkMode.pfnSetWinTheme, "Ptr", hHeader, "WStr", "ItemsView", "Ptr", 0)
            DllCall(Win32DarkMode.pfnSetWinTheme, "Ptr", hwnd, "WStr", "ItemsView", "Ptr", 0)
            
            pcolors := darkModeInstance.GetColorList()
            SendMessage(0x1036, 0, pcolors.crText, hwnd)
            SendMessage(0x1038, 0, pcolors.crBkgnd, hwnd)
            SendMessage(0x1034, 0, pcolors.crBkgnd, hwnd)
        }
    } else if (className == "SysTreeView32") {
        ; TreeView styling
        subappname := ""
        subidlist := ""
        
        pcolors := darkModeInstance.GetColorTree()
        SendMessage(0x111B, 0, pcolors.crText, hwnd)
        SendMessage(0x111D, 0, pcolors.crBkgnd, hwnd)
        SendMessage(0x1128, 0, pcolors.crText, hwnd)
    }
    
    ; Set theme
    if (Win32DarkMode.pfnSetWinTheme)
        DllCall(Win32DarkMode.pfnSetWinTheme, "Ptr", hwnd, "WStr", subappname, "WStr", subidlist)
    
    SendMessage(0x031A, 0, 0, hwnd)  ; WM_THEMECHANGED
    
    return true
}

; Standalone window procedure
WindowProc(hwnd, msg, wParam, lParam) {
    global darkModeInstance
    static prevWndProc := 0
    
    if (!prevWndProc)
        prevWndProc := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -4, "Ptr")
    
    result := 0
    if (darkModeInstance.HandleDMode(hwnd, msg, wParam, lParam, &result))
        return result
    
    return DllCall("CallWindowProc", "Ptr", prevWndProc, "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
}
