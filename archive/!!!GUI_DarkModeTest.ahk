#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

DarkGui()

class DarkGui {
    __New() {
        this.darkMode := w32dm()
        this.darkColors := Map(
            "Background", 0x202020,
            "Text", 0xE0E0E0,
            "ControlBg", 0x2D2D2D,
            "ButtonBg", 0x404040,
            "Accent", 0x0078D7,
            "BorderColor", 0x404040,
            "DisabledText", 0x808080
        )
        this.gui := Gui("+Resize +MinSize400x300", "Dark Mode GUI Example")
        this.gui.BackColor := this.darkColors["Background"]
        this.gui.SetFont("s10 c" Format("{:X}", this.darkColors["Text"]), "Segoe UI")
        this.gui.AddText("w300", "This is a text label with dark mode")
        this.edit := this.gui.AddEdit("w300 h80 Background" Format("{:X}", this.darkColors["ControlBg"]), "Edit control with dark mode")
        this.listBox := this.gui.AddListBox("w300 h120 Background" Format("{:X}", this.darkColors["ControlBg"]), ["Item 1", "Item 2", "Item 3", "Item 4"])
        this.button := this.gui.AddButton("w300 Background" Format("{:X}", this.darkColors["ButtonBg"]), "Close").OnEvent("Click", (*) => this.gui.Hide())
        this.hwnd := this.gui.Hwnd
        this.ApplyDarkMode()
        this.gui.Show()
    }

    ApplyDarkMode() {
        this.darkMode.AllowDModeForWin(this.hwnd, true)
        this.darkMode.RefreshTitleBarThemeColor(this.hwnd)
        this.prevWndProc := DllCall("SetWindowLongPtr", "Ptr", this.hwnd, "Int", -4,  ; GWLP_WNDPROC
                                     "Ptr", CallbackCreate(this.WindowProc.Bind(this)), "Ptr")
        this.darkMode.EnumChildWinsForDMode(this.hwnd)
    }

    WindowProc(hwnd, msg, wParam, lParam) {
        result := 0
        if (this.darkMode.HandleDMode(hwnd, msg, wParam, lParam, &result))
            return result

        ; Custom handling for WM_NOTIFY -> NM_CUSTOMDRAW for ListView
        ; Note: AutoHotkey's Gui controls often wrap standard controls.
        ; Direct NM_CUSTOMDRAW handling might be complex or unnecessary if
        ; WM_CTLCOLOR* messages are sufficient via HandleDMode.
        ; The original code had ListView handling here, which might conflict
        ; or be redundant with the w32dm class's WM_CTLCOLOR* handling.
        ; Keeping it simple for now unless specific ListView issues arise.
        ; if (msg == 0x004E) {  ; WM_NOTIFY
        ;     nmhdr := Buffer(lParam)
        ;     code := NumGet(nmhdr, A_PtrSize * 2, "Int") ; NMHDR offset for code

        ;     if (code == -12) { ; NM_CUSTOMDRAW
        ;         nmcd := Buffer(lParam) ; NMCUSTOMDRAW structure starts like NMHDR
        ;         hwndFrom := NumGet(nmcd, 0, "Ptr")
        ;         ; idFrom := NumGet(nmcd, A_PtrSize, "UInt") ; Control ID (might not be reliable)
        ;         dwDrawStage := NumGet(nmcd, A_PtrSize * 2 + 8, "UInt") ; dwDrawStage offset

        ;         switch (dwDrawStage) {
        ;             case 1: ; CDDS_PREPAINT
        ;                 return 0x00000010 ; CDRF_NOTIFYITEMDRAW

        ;             case 0x00010001: ; CDDS_ITEMPREPAINT
        ;                 if (this.darkMode.IsListView(hwndFrom)) { ; Check if it's the ListView
        ;                      ; Adjust offsets based on NMLVCUSTOMDRAW structure
        ;                      ; clrText is at offset: A_PtrSize*2 + 16
        ;                      ; clrTextBk is at offset: A_PtrSize*2 + 20
        ;                     NumPut("UInt", this.darkColors["Text"], nmcd, A_PtrSize * 2 + 16)
        ;                     NumPut("UInt", this.darkColors["ControlBg"], nmcd, A_PtrSize * 2 + 20)
        ;                     return 0 ; CDRF_DODEFAULT (or CDRF_NEWFONT if changing font)
        ;                 }smartscreen.exe	c:\windows\system32\smartscreen.exe	65116	8	200	1380	4/5/2025 1:57 PM	10.0.26100.3575	596.00 KB (610,304 bytes)	3/17/2025 8:00 PM

        ;         }
        ;     }
        ; }

        ; Call the original window procedure
        return DllCall("CallWindowProc", "Ptr", this.prevWndProc, "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }

    ; IsListView check moved to w32dm class for consistency
    ; IsListView(hWnd) {
    ;     className := Buffer(64)
    ;     if (DllCall("GetClassName", "Ptr", hWnd, "Ptr", className, "Int", 64)) ; Increased buffer size
    ;         return StrGet(className) == "SysListView32"
    ;     
    ; }
}


; ==============================================================================
; w32dm - Windows Dark Mode Helper Class
; ==============================================================================
class w32dm {
 static pfnSetWinCompAttr := 0
 static pfnShouldAppsDMode := 0
 static pfnAllowDModeForWin := 0
 static pfnAllowDModeForApp := 0
 static pfnRefreshImColorState := 0
 static pfnIsDModeAllowedForWin := 0
 static pfnGetIsImColorUsingHC := 0
 static pfnOpenNcThemeData := 0
 static pfnShouldSysDMode := 0 ; Not used in current logic, but kept for completeness
 static pfnSetPrefAppMode := 0
 static pfnGetThemeColor := 0
 static pfnSetWinTheme := 0
 static pfnOpenThemeData := 0
 static pfnCloseThemeData := 0

 ; PreferredAppMode enum (for ord135 / SetPreferredAppMode)
 static Default := 0
 static AllowD := 1
 static ForceD := 2
 static ForceLight := 3
 static Max := 4

 static dSupported := false
 static dEnabled := false ; System dark mode is enabled AND high contrast is OFF
 static buildNum := 0
 static hMainWnd := 0 ; Track the main window
 static AltInitDialogMsgID := 0 ; Optional alternative message to trigger init

 ; Default Dark Colors (can be overridden)
 static BUTTbkgnd := 0x3A3A3A ; Slightly lighter button background
 static BUTTtext := 0xE0E0E0
 static BUTTbkgndDis := 0x505050
 static BUTTtextDis := 0x808080

 static TREEbkgnd := 0x2D2D2D
 static TREEtext := 0xE0E0E0
 static TREEbkgndDis := 0x404040
 static TREEtextDis := 0x808080

 static EDITbkgnd := 0x2D2D2D
 static EDITtext := 0xE0E0E0
 static EDITbkgndDis := 0x404040
 static EDITtextDis := 0x808080

 static LISTbkgnd := 0x2D2D2D ; Background for list views/boxes
 static LISTtext := 0xE0E0E0
 static LISTbkgndDis := 0x404040
 static LISTtextDis := 0x808080

 static DColButt := ""
 static DColTree := ""
 static DColEdit := ""
 static DColList := ""
 static DColor := "" ; Generic fallback color scheme
 static ColorWinStd := "" ; Stores standard system colors (cached)

 __New() {
  ; Initialize ColorScheme objects AFTER static colors are defined
  w32dm.DColButt := ColorScheme(w32dm.BUTTbkgnd, w32dm.BUTTtext, w32dm.BUTTbkgndDis, w32dm.BUTTtextDis)
  w32dm.DColTree := ColorScheme(w32dm.TREEbkgnd, w32dm.TREEtext, w32dm.TREEbkgndDis, w32dm.TREEtextDis)
  w32dm.DColEdit := ColorScheme(w32dm.EDITbkgnd, w32dm.EDITtext, w32dm.EDITbkgndDis, w32dm.EDITtextDis)
  w32dm.DColList := ColorScheme(w32dm.LISTbkgnd, w32dm.LISTtext, w32dm.LISTbkgndDis, w32dm.LISTtextDis)
  w32dm.DColor := ColorScheme(w32dm.EDITbkgnd, w32dm.EDITtext, w32dm.EDITbkgndDis, w32dm.EDITtextDis) ; Fallback to Edit colors
  w32dm.ColorWinStd := ColorScheme(0, 0, 0, 0) ; Placeholder, will be filled by GetColorWinStd

  this.InitDMode() ; Initialize dark mode support detection
  return this
 }

 InitDMode(altInitDialogMsg := 0) {
  w32dm.AltInitDialogMsgID := altInitDialogMsg
  w32dm.buildNum := this.GetWinBuildNum()

  ; Check if build number is known to support dark mode APIs
  if (w32dm.buildNum && this.CheckBuildNum(w32dm.buildNum)) {
   hUxtheme := DllCall("LoadLibraryExW", "Str", "uxtheme.dll", "Ptr", 0, "UInt", 0x00000800, "Ptr") ; LOAD_LIBRARY_SEARCH_SYSTEM32
   if (hUxtheme) {
    ; Get function pointers (using ordinal numbers where known)
    w32dm.pfnOpenNcThemeData := DllCall("GetProcAddress", "Ptr", hUxtheme, "Ptr", 49, "Ptr") ; Ordinal 49
    w32dm.pfnRefreshImColorState := DllCall("GetProcAddress", "Ptr", hUxtheme, "Ptr", 104, "Ptr") ; Ordinal 104
    w32dm.pfnGetIsImColorUsingHC := DllCall("GetProcAddress", "Ptr", hUxtheme, "Ptr", 106, "Ptr") ; Ordinal 106
    w32dm.pfnShouldAppsDMode := DllCall("GetProcAddress", "Ptr", hUxtheme, "Ptr", 132, "Ptr") ; Ordinal 132
    w32dm.pfnAllowDModeForWin := DllCall("GetProcAddress", "Ptr", hUxtheme, "Ptr", 133, "Ptr") ; Ordinal 133
    ord135 := DllCall("GetProcAddress", "Ptr", hUxtheme, "Ptr", 135, "Ptr") ; Ordinal 135 (different functions based on build)
    w32dm.pfnIsDModeAllowedForWin := DllCall("GetProcAddress", "Ptr", hUxtheme, "Ptr", 137, "Ptr") ; Ordinal 137

    ; Differentiate Ordinal 135 based on build number
    if (w32dm.buildNum < 18362) { ; 1903 threshold
     w32dm.pfnAllowDModeForApp := ord135
    } else {
     w32dm.pfnSetPrefAppMode := ord135 ; Renamed to SetPreferredAppMode in later builds
    }

    ; Get function pointers (using names where ordinals are less reliable or standard)
    hUser32 := DllCall("GetModuleHandle", "Str", "user32.dll", "Ptr")
    w32dm.pfnSetWinCompAttr := DllCall("GetProcAddress", "Ptr", hUser32, "AStr", "SetWindowCompositionAttribute", "Ptr")
    w32dm.pfnGetThemeColor := DllCall("GetProcAddress", "Ptr", hUxtheme, "AStr", "GetThemeColor", "Ptr")
    w32dm.pfnSetWinTheme := DllCall("GetProcAddress", "Ptr", hUxtheme, "AStr", "SetWindowTheme", "Ptr")
    w32dm.pfnOpenThemeData := DllCall("GetProcAddress", "Ptr", hUxtheme, "AStr", "OpenThemeData", "Ptr")
    w32dm.pfnCloseThemeData := DllCall("GetProcAddress", "Ptr", hUxtheme, "AStr", "CloseThemeData", "Ptr")

    ; Check if all necessary functions were loaded
    if (w32dm.pfnOpenNcThemeData &&
     w32dm.pfnRefreshImColorState &&
     w32dm.pfnShouldAppsDMode &&
     w32dm.pfnAllowDModeForWin &&
     (w32dm.pfnAllowDModeForApp || w32dm.pfnSetPrefAppMode) && ; Need one of these
     w32dm.pfnIsDModeAllowedForWin &&
     w32dm.pfnGetThemeColor && ; Needed for some advanced theming (not strictly required for basic dark mode)
     w32dm.pfnSetWinTheme && ; Needed for theming standard controls
     w32dm.pfnOpenThemeData && ; Needed for theme handles
     w32dm.pfnCloseThemeData) { ; Needed to close theme handles

     w32dm.dSupported := true
     this.AllowDModeForApp(true) ; Signal that the app supports dark mode
     this.RefreshImColorState() ; Refresh the immersive color state
     ; Check if system-wide dark mode is enabled AND high contrast is off
     w32dm.dEnabled := this.ShouldAppsDMode() && !this.IsHighContrast()
    } else {
        OutputDebug("w32dm: Failed to load one or more required UxTheme functions.")
    }
    ; Note: We don't FreeLibrary hUxtheme as it's needed throughout the app's lifetime.
   } else {
       OutputDebug("w32dm: Failed to load uxtheme.dll")
   }
  } else {
      OutputDebug("w32dm: Windows build " w32dm.buildNum " not recognized or doesn't support dark mode APIs.")
  }
 }

 GetWinBuildNum() {
  try {
   ; Use RegRead for robust reading
   return Integer(RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion", "CurrentBuildNumber"))
  } catch Error as e {
   OutputDebug("w32dm: Failed to read Windows build number - " e.Message)
   return 0
  }
 }

 CheckBuildNum(buildNum) {
    ; Check against known builds supporting dark mode APIs (starting from 1809 / build 17763)
    ; Includes major versions like 1809, 1903, 1909, 2004, 20H2, 21H1, 21H2, 22H2 (Win10/11), 24H2
    return (buildNum >= 17763)
 }

 IsDSupported() {
  return w32dm.dSupported
 }

 IsDEnabled() {
  ; Check the cached value first
  return w32dm.dEnabled
 }

 ; --- Accessor methods for color schemes ---
 GetColorList() => w32dm.DColList
 GetColorTree() => w32dm.DColTree
 GetColorEdit() => w32dm.DColEdit
 GetColorButton() => w32dm.DColButt
 GetColorGeneric() => w32dm.DColor ; Generic fallback

 AllowDModeForWin(hWnd, allow) {
  if (w32dm.dSupported && w32dm.pfnAllowDModeForWin && DllCall("IsWindow", "Ptr", hWnd)) {
   return DllCall(w32dm.pfnAllowDModeForWin, "Ptr", hWnd, "Int", allow)
  }
  
  return 
 }

 IsHighContrast() {
  static SPI_GETHIGHCONTRAST := 0x42
  static HCF_HIGHCONTRASTON := 0x1
  ; HIGHCONTRAST structure size (cbSize field)
  static HIGHCONTRAST_SIZE := A_PtrSize = 8 ? 16 : 12 ; Adjusted for 32/64-bit ptr size

  vHC := Buffer(HIGHCONTRAST_SIZE, 0)
  NumPut("UInt", HIGHCONTRAST_SIZE, vHC, 0, "UInt") ; cbSize

  if (DllCall("SystemParametersInfo", "UInt", SPI_GETHIGHCONTRAST, "UInt", HIGHCONTRAST_SIZE, "Ptr", vHC, "UInt", 0)) {
   dwFlags := NumGet(vHC, A_PtrSize, "UInt") ; dwFlags offset
   return (dwFlags & HCF_HIGHCONTRASTON) != 0
  }
  OutputDebug("w32dm: SystemParametersInfo SPI_GETHIGHCONTRAST failed.")
  return  ; Assume not high contrast if API fails
 }

 RefreshTitleBarThemeColor(hWnd) {
    if (!w32dm.dSupported || !DllCall("IsWindow", "Ptr", hWnd)) {
        return
    }

    ; Determine if dark mode should be applied to this specific window's title bar
    useDarkMode := this.IsDModeAllowedForWin(hWnd) && this.ShouldAppsDMode() && !this.IsHighContrast()

    if (w32dm.buildNum >= 17763 && w32dm.buildNum < 18362) { ; For builds 1809 (17763) up to 1903 (exclusive)
        ; Use SetProp for older builds (less reliable, undocumented)
        DllCall("SetPropW", "Ptr", hWnd, "Str", "UseImmersiveDarkModeColors", "Ptr", useDarkMode)
    }
    else if (w32dm.buildNum >= 18362 && w32dm.pfnSetWinCompAttr) { ; For builds 1903 (18362) and later
        ; Use SetWindowCompositionAttribute (preferred method)
        ; WCA_USEDARKMODECOLORS = 26 (undocumented, value confirmed via online resources)
        attrData := Buffer(12) ; Structure size for WINDOWCOMPOSITIONATTRIBDATA
        data := useDarkMode ? 1 : 0 ; DWORD value (BOOL)
        NumPut("UInt", 26, attrData, 0, "UInt")  ; Attribute (WCA_USEDARKMODECOLORS)
        NumPut("Ptr", &data, attrData, A_PtrSize, "Ptr") ; pvData (pointer to the value)
        NumPut("UInt", 4, attrData, A_PtrSize * 2, "UInt") ; cbData (size of the value)

        hr := DllCall(w32dm.pfnSetWinCompAttr, "Ptr", hWnd, "Ptr", attrData)
        if (hr != 0) { ; S_OK is 0
            OutputDebug("w32dm: SetWindowCompositionAttribute failed with HRESULT: " hr)
        }
    } else {
        OutputDebug("w32dm: Title bar theming not supported or SetWindowCompositionAttribute failed for build " w32dm.buildNum)
    }

    ; Force redraw of the non-client area (title bar, borders)
    DllCall("SetWindowPos", "Ptr", hWnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0020 | 0x0001 | 0x0002 | 0x0004 | 0x0100) ; SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED
 }

 IsColorSchemeChangeMsg(msg, lParam) {
    ; Check for standard WM_SETTINGCHANGE with "ImmersiveColorSet"
    if (msg == 0x001A && lParam != 0 && StrGet(lParam) == "ImmersiveColorSet") { ; WM_SETTINGCHANGE
        OutputDebug("w32dm: Received WM_SETTINGCHANGE with ImmersiveColorSet.")
        ; No need to call RefreshImmersiveColorState here, it's done in the message handler
        return true
    }
    ; Check for undocumented WM_THEMECHANGED (0x031A) - often broadcast after theme changes
    ; Note: We send this message ourselves later, so avoid infinite loops if possible
    ; if (msg == 0x031A) {
    ;     OutputDebug("w32dm: Received WM_THEMECHANGED.")
    ;     return true
    ; }

    ; This check might be redundant or less reliable than WM_SETTINGCHANGE
    ; this.GetIsImColorUsingHC(0) ; Refreshing based on this is probably not needed
    return 
 }

 AllowDModeForApp(allow) {
  if (!w32dm.dSupported) 
  return

  mode := allow ? w32dm.AllowD : w32dm.Default

  ; Use the correct function based on the Windows build
  if (w32dm.pfnAllowDModeForApp) { ; Older builds
   DllCall(w32dm.pfnAllowDModeForApp, "Int", allow) ; Parameter is simple BOOL (0 or 1)
  } else if (w32dm.pfnSetPrefAppMode) { ; Newer builds
   DllCall(w32dm.pfnSetPrefAppMode, "Int", mode) ; Parameter is PreferredAppMode enum
  }
 }

 RefreshImColorState() {
  if (w32dm.dSupported && w32dm.pfnRefreshImColorState)
   DllCall(w32dm.pfnRefreshImColorState)
 }

 IsDModeAllowedForWin(hWnd) {
  if (w32dm.dSupported && w32dm.pfnIsDModeAllowedForWin && DllCall("IsWindow", "Ptr", hWnd))
   return DllCall(w32dm.pfnIsDModeAllowedForWin, "Ptr", hWnd)
  
  return 
 }

 ShouldAppsDMode() {
  if (w32dm.dSupported && w32dm.pfnShouldAppsDMode)
   return DllCall(w32dm.pfnShouldAppsDMode)
  
  return 
 }

 GetIsImColorUsingHC(mode) {
  ; This function seems related to high contrast, might not be essential for basic dark mode
  if (w32dm.dSupported && w32dm.pfnGetIsImColorUsingHC)
   return DllCall(w32dm.pfnGetIsImColorUsingHC, "Int", mode)
  
  return 
 }

 ; Handles WM_CTLCOLOR* messages for specific controls
 HandleWMCTLCOLORMsg(hdc, hwnd, &lresult, pcolors) {
  lresult := 0 ; Default: system handles message
  if (w32dm.dEnabled && pcolors != "") { ; Only if dark mode is enabled and we have colors defined
   bkcolor := 0
   textcolor := 0
   hBrush := 0

   isEnabled := DllCall("IsWindowEnabled", "Ptr", hwnd)

   if (!isEnabled) { ; Disabled state
    bkcolor := pcolors.crBkgndDis
    textcolor := pcolors.crTextDis
    hBrush := pcolors.GetBkgndDisBrush() ; Use cached disabled brush
   } else { ; Enabled state
    bkcolor := pcolors.crBkgnd
    textcolor := pcolors.crText
    hBrush := pcolors.GetBkgndBrush() ; Use cached enabled brush
   }

   DllCall("SetTextColor", "Ptr", hdc, "UInt", textcolor)
   DllCall("SetBkColor", "Ptr", hdc, "UInt", bkcolor)
   lresult := hBrush ; Return the brush handle
   return true ; Indicate message was handled
  }
  return  ; Indicate message was not handled (use default processing)
 }

 ; Central message handler for dark mode related messages
 HandleDMode(hWnd, msg, wParam, lParam, &lresult) {
  if (!this.IsDSupported()) {
   lresult := 0
   return  ; Dark mode not supported, do nothing
  }

  ; Allow substituting a custom message for WM_INITDIALOG
  effectiveMsg := (w32dm.AltInitDialogMsgID != 0 && w32dm.AltInitDialogMsgID == msg) ? 0x0110 : msg

  ; Handle WM_CREATE or first WM_INITDIALOG for the main window
  if ((effectiveMsg == 0x0001 || effectiveMsg == 0x0110) && w32dm.hMainWnd == 0) { ; WM_CREATE or WM_INITDIALOG
   w32dm.hMainWnd := hWnd ; Store the main window handle
   OutputDebug("w32dm: Main window identified as HWND " w32dm.hMainWnd)
   ; Apply initial theme settings for the main window upon creation/init
   this.ApplyThemeToWindowAndChildren(hWnd)
  }

  switch effectiveMsg {

   ; Dialog/Window Initialization
   case 0x0110: ; WM_INITDIALOG (or substituted message)
    ; Theme already applied if it's the main window,
    ; but re-apply here for non-main dialogs or as a failsafe.
    this.ApplyThemeToWindowAndChildren(hWnd)
    lresult := 1 ; Typically return TRUE for WM_INITDIALOG
    return  ; Allow default dialog init to proceed after theming

   ; Control Colorization Messages
   case 0x0138: ; WM_CTLCOLORBTN
    return this.HandleWMCTLCOLORMsg(wParam, lParam, &lresult, w32dm.DColButt)
   case 0x0133: ; WM_CTLCOLOREDIT
    return this.HandleWMCTLCOLORMsg(wParam, lParam, &lresult, w32dm.DColEdit)
   case 0x0134: ; WM_CTLCOLORLISTBOX
    return this.HandleWMCTLCOLORMsg(wParam, lParam, &lresult, w32dm.DColList)

   ; These often need generic handling or specific checks
   case 0x0132: ; WM_CTLCOLORMSGBOX (Rarely needed for custom GUIs)
   case 0x0135: ; WM_CTLCOLORDLG (Main dialog background, often handled by Gui.BackColor)
   case 0x0136: ; WM_CTLCOLORSCROLLBAR (Difficult to theme reliably)
   case 0x0137: ; WM_CTLCOLORSTATIC
    ; Static controls often use the dialog background. Use generic colors.
    return this.HandleWMCTLCOLORMsg(wParam, lParam, &lresult, w32dm.DColor)

   ; Custom Draw Notifications (Less common now with WM_CTLCOLOR*)
   case 0x004E: ; WM_NOTIFY
    if (w32dm.dEnabled) {
     ; Basic handling for disabled ListView (consider removing if WM_CTLCOLOR* is sufficient)
     nmhdr := Buffer(lParam)
     hwndFrom := NumGet(nmhdr, 0, "Ptr") ; hwndFrom is at offset 0
     code := NumGet(nmhdr, A_PtrSize * 2, "Int") ; code is after hwndFrom and idFrom

     if (code == -12 && !DllCall("IsWindowEnabled", "Ptr", hwndFrom) && this.IsListView(hwndFrom)) { ; NM_CUSTOMDRAW
      lresult := this.HandleDisabledLVCustomDraw(lParam)
      ; Setting DWL_MSGRESULT (8) often used here
      DllCall("SetWindowLongPtr", "Ptr", hWnd, "Int", 8, "Ptr", lresult) ; DWL_MSGRESULT
      return true ; Message handled
     }
    }

   ; System Settings / Theme Change Detection
   case 0x001A, 0x031A: ; WM_SETTINGCHANGE, WM_THEMECHANGED
    if (this.IsColorSchemeChangeMsg(msg, lParam)) {
     OutputDebug("w32dm: Color scheme change detected.")
     ; Update the global enabled state based on current system settings
     oldEnabledState := w32dm.dEnabled
     w32dm.dEnabled := this.ShouldAppsDMode() && !this.IsHighContrast()

     ; If the state actually changed, re-theme all relevant windows
     if (w32dm.dEnabled != oldEnabledState) {
        OutputDebug("w32dm: Dark mode enabled state changed to: " w32dm.dEnabled)
        ; Re-theme the main window and its children
        if (DllCall("IsWindow", "Ptr", w32dm.hMainWnd)) {
             this.ApplyThemeToWindowAndChildren(w32dm.hMainWnd)
             ; Also re-theme the current window if it's not the main one
             if (hWnd != w32dm.hMainWnd) {
                 this.ApplyThemeToWindowAndChildren(hWnd)
             }
        } else {
            OutputDebug("w32dm: Main window handle invalid during theme refresh.")
        }
     } else {
        OutputDebug("w32dm: Theme change detected, but effective dark mode state (" w32dm.dEnabled ") unchanged.")
        ; Even if state didn't change, might need redraw for subtle changes
        this.RefreshTitleBarThemeColor(hWnd) ; Refresh just the title bar
        DllCall("RedrawWindow", "Ptr", hWnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0100 | 0x0004 | 0x0001) ; RDW_INVALIDATE | RDW_FRAME | RDW_UPDATENOW
     }
     lresult := 0
     return true ; Indicate message was handled (prevent default processing if needed)
    }

    ; Window Destruction - Clean up resources (optional but good practice)
   case 0x0002: ; WM_DESTROY
    ; If this is the main window, clean up shared resources like brushes
    if (hWnd == w32dm.hMainWnd) {
     OutputDebug("w32dm: Main window destroyed. Cleaning up color schemes.")
     w32dm.DColButt := "" ; Release ColorScheme objects (triggers __Delete)
     w32dm.DColTree := ""
     w32dm.DColEdit := ""
     w32dm.DColList := ""
     w32dm.DColor := ""
     w32dm.ColorWinStd := ""
     w32dm.hMainWnd := 0 ; Reset main window handle
    }
  }

  lresult := 0
  return  ; Message not handled by dark mode logic
 }

 ; Gets the class name of a window
 GetClassName(hWnd) {
  if (!hWnd || !DllCall("IsWindow", "Ptr", hWnd)) 
  return ""
  className := Buffer(260) ; Max class name length is 256 + null terminator
  if (DllCall("GetClassName", "Ptr", hWnd, "Ptr", className, "Int", 260))
   return StrGet(className)
  return ""
 }

 ; Identifies specific control types based on class name
 GetWinType(hWnd) {
    className := this.GetClassName(hWnd)
    if (className == "") 
    return "WINtypeUnknown"

    switch className {
        case "SysListView32": return "WINtypeListView"
        case "ListBox": return "WINtypeList" ; Standard list box
        case "SysTreeView32": return "WINtypeTreeView"
        case "SysHeader32": return "WINtypeHeader"
        case "ComboBox": return "WINtypeCombo"
        case "Button": return "WINtypeButton"
        case "Edit": return "WINtypeEdit" ; Standard edit control
        case "RichEdit20W", "RichEdit50W": return "WINtypeRichEdit" ; Rich Edit
        case "SysLink": return "WINtypeSysLink"
        case "Static": return "WINtypeStatic"
        case "msctls_trackbar32": return "WINtypeTrackbar"
        case "msctls_progress32": return "WINtypeProgress"
        case "msctls_updown32": return "WINtypeUpDown"
        case "SysDateTimePick32": return "WINtypeDateTime"
        case "SysMonthCal32": return "WINtypeMonthCal"
        case "ToolbarWindow32": return "WINtypeToolbar"
        case "ReBarWindow32": return "WINtypeRebar"
        case "tooltips_class32": return "WINtypeTooltip"
        case "ScrollBar": return "WINtypeScrollbar" ; Note: often part of other controls
        default: return "WINtypeDefault" ; Any other class
    }
 }


 ; Special handling for disabled ListView NM_CUSTOMDRAW (may be less needed now)
 HandleDisabledLVCustomDraw(plvnmcd) {
  nmcd := Buffer(plvnmcd)
  dwDrawStage := NumGet(nmcd, A_PtrSize * 2 + 8, "UInt") ; Offset for dwDrawStage in NMLVCUSTOMDRAW

  if (dwDrawStage == 1) ; CDDS_PREPAINT
   return 0x00000010 ; CDRF_NOTIFYITEMDRAW

  if (dwDrawStage == 0x00010001) { ; CDDS_ITEMPREPAINT
   ; Set disabled colors for the item
   NumPut("UInt", w32dm.DColList.crTextDis, nmcd, A_PtrSize * 2 + 16) ; clrText offset
   NumPut("UInt", w32dm.DColList.crBkgndDis, nmcd, A_PtrSize * 2 + 20) ; clrTextBk offset
   return 0x10 ; CDRF_NEWFONT (forces redraw with new colors)
  }
  return 0 ; CDRF_DODEFAULT
 }

 ; Applies theme settings to a parent window AND iterates through its children
 ApplyThemeToWindowAndChildren(hWnd) {
    if (!DllCall("IsWindow", "Ptr", hWnd)) 
    return

    OutputDebug("w32dm: Applying theme to HWND " hWnd " and children. Dark Mode Enabled: " w32dm.dEnabled)

    ; 1. Theme the parent window itself
    this.AllowDModeForWin(hWnd, w32dm.dEnabled)
    this.RefreshTitleBarThemeColor(hWnd)

    ; 2. Enumerate and theme child windows
    this.EnumChildWinsForDMode(hWnd)

    ; 3. Force redraw of the parent window and all children
    DllCall("RedrawWindow", "Ptr", hWnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0100 | 0x0004 | 0x0001 | 0x0080) ; RDW_INVALIDATE | RDW_FRAME | RDW_UPDATENOW | RDW_ALLCHILDREN
 }


 ; Enumerates child windows and calls ApplyThemeToChild for each
 EnumChildWinsForDMode(hWnd) {
    ; Use a bound method directly with CallbackCreate if possible, or manage instance context
    enumProc := this.EnumChildCallback.Bind(this)
    pCallback := CallbackCreate(enumProc, "F", 3) ; "F" for Fast, 3 parameters (hwnd, lParam, UserData - though UserData isn't used here)

    ; lParam (last parameter of EnumChildWindows) can pass context if needed, but Bind(this) handles it.
    DllCall("EnumChildWindows", "Ptr", hWnd, "Ptr", pCallback, "Ptr", 0)

    ; Release the callback (important!)
    CallbackFree(pCallback)
 }

 ; Callback function used by EnumChildWinsForDMode
 EnumChildCallback(childHwnd, lParam) {
    ; 'this' is automatically available here because we used .Bind(this)
    this.ApplyThemeToChild(childHwnd)
    return true ; Continue enumeration
 }


 ; Applies theme settings to a single child window
 ApplyThemeToChild(childHwnd) {
    if (!DllCall("IsWindow", "Ptr", childHwnd)) 
    return

    OutputDebug("w32dm: Applying theme to Child HWND " childHwnd)

    this.AllowDModeForWin(childHwnd, w32dm.dEnabled)

    subAppName := "Explorer" ; Default theme application name
    subIdList := ""        ; Default theme ID list

    winType := this.GetWinType(childHwnd)
    pcolors := "" ; Placeholder for color scheme object

    ; Apply specific themes or messages based on control type
    switch winType {
        case "WINtypeListView":
            this.InitListView(childHwnd) ; Handles its own SetWindowTheme and color messages
            subAppName := "" ; InitListView handles theming
        case "WINtypeTreeView":
            subAppName := w32dm.dEnabled ? "Explorer" : "" ; Use Explorer theme only if dark mode is on
            pcolors := this.GetColorTree()
            ; Use TVM_SETBKCOLOR and TVM_SETTEXTCOLOR messages
            SendMessage(0x111D, 0, w32dm.dEnabled ? pcolors.crBkgnd : -1, childHwnd) ; TVM_SETBKCOLOR (-1 default)
            SendMessage(0x111C, 0, w32dm.dEnabled ? pcolors.crText : -1, childHwnd) ; TVM_SETTEXTCOLOR (-1 default)
            ;SendMessage(0x1128, 0, pcolors.crText, childHwnd) ; TVM_SETINSERTMARKCOLOR (might not be needed)
        case "WINtypeHeader":
            subAppName := w32dm.dEnabled ? "ItemsView" : "" ; Specific theme for list/details view headers
        case "WINtypeCombo":
             ; ComboBox theming is tricky; SetWindowTheme might not be enough.
             ; Often relies on WM_CTLCOLOR* for the Edit/List parts.
             subAppName := w32dm.dEnabled ? "CFD" : "" ; Try "CFD" (Common File Dialog) theme or ""
        case "WINtypeButton":
            style := DllCall("GetWindowLong", "Ptr", childHwnd, "Int", -16) ; GWL_STYLE
            btnStyle := style & 0x0F ; Get button style part
            ; Only apply Explorer theme to standard push buttons (0x00) and default buttons (0x01).
            ; Checkboxes (0x02), Radio (0x04), GroupBox (0x07), AutoCheckBox (0x03), AutoRadio (0x09) etc.,
            ; rely heavily on WM_CTLCOLORBTN. Setting Explorer theme can break their appearance.
            if (btnStyle == 0x00 || btnStyle == 0x01) {
                subAppName := w32dm.dEnabled ? "Explorer" : ""
            } else {
                subAppName := "" ; Don't theme other button types, use WM_CTLCOLORBTN
            }
        case "WINtypeEdit", "WINtypeRichEdit":
            ; Edit controls usually themed well by WM_CTLCOLOREDIT
            ; RichEdit might need specific messages if WM_CTLCOLOR isn't enough
            subAppName := w32dm.dEnabled ? "TEXTINPUT" : "" ; Try "TEXTINPUT" theme or ""
             pcolors := this.GetColorEdit()
             ; Example for RichEdit background (may override WM_CTLCOLOR)
             ; if (winType == "WINtypeRichEdit") {
             ;    SendMessage(0x0443, 0, w32dm.dEnabled ? pcolors.crBkgnd : DllCall("GetSysColor", "Int", 5, "UInt"), childHwnd) ; EM_SETBKGNDCOLOR (COLOR_WINDOW)
             ; }
        case "WINtypeSysLink":
             ; SysLink controls have specific messages for theming
             LITEM := Buffer(A_PtrSize = 8 ? 48 : 40) ; LITEM structure size varies slightly
             mask := 0x01 | 0x08 ; LIF_ITEMINDEX | LIF_STATE
             stateMask := 0x01 ; LIS_ENABLED (check if this is correct usage)
             state := w32dm.dEnabled ? 0x01 : 0 ; Set state based on dark mode? Needs verification.
             NumPut("UInt", mask, LITEM, 0, "UInt")
             NumPut("Int", 0, LITEM, 8, "Int") ; iLink = 0 (apply to all links?)
             NumPut("UInt", stateMask, LITEM, 12, "UInt")
             NumPut("UInt", state, LITEM, 16, "UInt")
             SendMessage(0x0704, 0, LITEM, childHwnd) ; LM_SETITEM (Note: May need correct iLink index)
             subAppName := "" ; Likely doesn't use standard theming much

        case "WINtypeTrackbar":
            subAppName := w32dm.dEnabled ? "Explorer::TrackBar" : ""
        case "WINtypeProgress":
             subAppName := w32dm.dEnabled ? "Explorer::Progress" : ""
        case "WINtypeToolbar":
             subAppName := w32dm.dEnabled ? "Explorer::Toolbar" : ""
        case "WINtypeTooltip":
             subAppName := w32dm.dEnabled ? "Explorer::Tooltip" : ""
        case "WINtypeDateTime", "WINtypeMonthCal":
             subAppName := w32dm.dEnabled ? "Explorer::DateTime" : ""
        case "WINtypeStatic":
            subAppName := "" ; Let WM_CTLCOLORSTATIC handle it
        default:
            ; Keep default "Explorer" theme for unknown types if dark mode is on
            subAppName := w32dm.dEnabled ? "Explorer" : ""
    }

    ; Apply the determined theme using SetWindowTheme if an app name is set
    if (subAppName != "" && w32dm.pfnSetWinTheme) {
        OutputDebug("w32dm: SetWindowTheme(" childHwnd ", '" subAppName "', '" subIdList "')")
        DllCall(w32dm.pfnSetWinTheme, "Ptr", childHwnd, "WStr", subAppName, "WStr", subIdList)
    } else if (subAppName == "" && w32dm.dEnabled && w32dm.pfnSetWinTheme) {
         ; If we explicitly clear the theme (subAppName=""), ensure it's cleared even in dark mode
         OutputDebug("w32dm: Clearing SetWindowTheme for HWND " childHwnd)
         DllCall(w32dm.pfnSetWinTheme, "Ptr", childHwnd, "WStr", "", "WStr", "")
    }


    ; Send a message to the child window to update its appearance if necessary
    ; WM_THEMECHANGED (0x031A) is often used for this.
    ; WM_SETTINGCHANGE (0x001A) could also work but might be heavier.
    ; ****************************************************************
    ; *** THIS IS THE CORRECTED LINE USING DllCall ***
    ; ****************************************************************
    DllCall("SendMessage", "Ptr", childHwnd, "UInt", 0x031A, "Ptr", 0, "Ptr", 0) ; WM_THEMECHANGED

    ; Alternatively, force a redraw (might be less efficient than specific messages)
    ; DllCall("RedrawWindow", "Ptr", childHwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0100 | 0x0004 | 0x0001) ; RDW_INVALIDATE | RDW_FRAME | RDW_UPDATENOW
 }


 ; Initializes ListView specific theme settings
 InitListView(hListView) {
  if (!DllCall("IsWindow", "Ptr", hListView)) 
  return

  ; LVM_GETHEADER = 0x101F
  hHeader := SendMessage(0x101F, 0, 0, hListView)

  if (w32dm.dEnabled) {
   if (w32dm.pfnSetWinTheme) {
    ; Apply "ItemsView" theme to header and listview for Win11-like appearance
    DllCall(w32dm.pfnSetWinTheme, "Ptr", hHeader, "WStr", "ItemsView", "Ptr", 0)
    DllCall(w32dm.pfnSetWinTheme, "Ptr", hListView, "WStr", "ItemsView", "Ptr", 0)
    ; Alternative: "Explorer" theme for a more standard dark look
    ; DllCall(w32dm.pfnSetWinTheme, "Ptr", hHeader, "WStr", "Explorer", "Ptr", 0)
    ; DllCall(w32dm.pfnSetWinTheme, "Ptr", hListView, "WStr", "Explorer", "Ptr", 0)
   }
   pcolors := this.GetColorList()
   ; Set text and background colors using ListView messages
   SendMessage(0x1024, 0, pcolors.crText, hListView)    ; LVM_SETTEXTCOLOR (-1 default)
   SendMessage(0x1026, 0, pcolors.crBkgnd, hListView)   ; LVM_SETTEXTBKCOLOR (-1 default)
   SendMessage(0x1001, 0, pcolors.crBkgnd, hListView)   ; LVM_SETBKCOLOR (CLR_NONE default)
   ; Set outline color (can help with grid lines or borders if enabled)
   ; SendMessage(0x1090, 0, pcolors.crTextDis, hListView) ; LVM_SETOUTLINECOLOR (COLOR_WINDOW default) - Use a border color if desired
  } else {
   ; Revert to default theme if dark mode is disabled
   if (w32dm.pfnSetWinTheme) {
    DllCall(w32dm.pfnSetWinTheme, "Ptr", hHeader, "Ptr", 0, "Ptr", 0) ; Clear theme
    DllCall(w32dm.pfnSetWinTheme, "Ptr", hListView, "Ptr", 0, "Ptr", 0) ; Clear theme
   }
   ; Reset colors to system default (-1)
   SendMessage(0x1024, 0, -1, hListView) ; LVM_SETTEXTCOLOR
   SendMessage(0x1026, 0, -1, hListView) ; LVM_SETTEXTBKCOLOR
   SendMessage(0x1001, 0, -1, hListView) ; LVM_SETBKCOLOR (CLR_NONE might be better: DllCall("GetSysColor", "Int", 5))
   ; SendMessage(0x1090, 0, -1, hListView) ; LVM_SETOUTLINECOLOR
  }
  ; Ensure header redraws correctly after theme change
    if (DllCall("IsWindow", "Ptr", hHeader)) {
        DllCall("InvalidateRect", "Ptr", hHeader, "Ptr", 0, "Int", 1) ; Invalidate header rect
        DllCall("UpdateWindow", "Ptr", hHeader) ; Force repaint
    }
 }


 ; Helper to set text on a SysLink control and potentially update its theme state
 ; (hWndDlg is the parent, resId is the control ID)
 SetLinkText(hWndDlg, resId, text) {
    hCtrl := DllCall("GetDlgItem", "Ptr", hWndDlg, "Int", resId, "Ptr")
    if (!hCtrl) 
    return 

    result := DllCall("SetWindowText", "Ptr", hCtrl, "Str", text)

    ; Re-apply SysLink theme state after changing text (if needed)
     LITEM := Buffer(A_PtrSize = 8 ? 48 : 40)
     mask := 0x01 | 0x08
     stateMask := 0x01
     state := w32dm.dEnabled ? 0x01 : 0
     NumPut("UInt", mask, LITEM, 0, "UInt")
     NumPut("Int", 0, LITEM, 8, "Int") ; iLink = 0
     NumPut("UInt", stateMask, LITEM, 12, "UInt")
     NumPut("UInt", state, LITEM, 16, "UInt")
     SendMessage(0x0704, 0, LITEM, hCtrl) ; LM_SETITEM

    return result
 }

 ; Retrieves the appropriate dark color scheme based on the window type
 GetDColors(hWnd) {
  winType := this.GetWinType(hWnd)
  switch winType {
   case "WINtypeButton": return w32dm.DColButt
   case "WINtypeEdit", "WINtypeRichEdit": return w32dm.DColEdit
   case "WINtypeListView", "WINtypeList": return w32dm.DColList
   case "WINtypeTreeView": return w32dm.DColTree
   case "WINtypeCombo": return w32dm.DColEdit ; Combo often uses Edit colors for its parts
   default: return w32dm.DColor ; Fallback generic scheme
  }
 }

 ; Caches and returns standard system colors (for light mode reference)
 GetColorWinStd() {
  if (w32dm.ColorWinStd.crBkgnd == 0 && w32dm.ColorWinStd.crText == 0) { ; Check if not initialized
   w32dm.ColorWinStd.crBkgnd := DllCall("GetSysColor", "Int", 5, "UInt")  ; COLOR_WINDOW
   w32dm.ColorWinStd.crText := DllCall("GetSysColor", "Int", 8, "UInt")   ; COLOR_WINDOWTEXT
   w32dm.ColorWinStd.crBkgndDis := DllCall("GetSysColor", "Int", 15, "UInt") ; COLOR_BTNFACE or COLOR_3DFACE
   w32dm.ColorWinStd.crTextDis := DllCall("GetSysColor", "Int", 17, "UInt")  ; COLOR_GRAYTEXT
   ; Ensure brushes are created if needed (they are lazy-loaded by GetBkgnd*Brush methods)
  }
  return w32dm.ColorWinStd
 }
}


; ==============================================================================
; ColorScheme Factory Function
; Creates an object holding colors and cached brush handles.
; ==============================================================================
ColorScheme(crBkgnd, crText, crBkgndDis, crTextDis) {
 obj := Map(
  "crBkgnd", crBkgnd,
  "crText", crText,
  "crBkgndDis", crBkgndDis,
  "crTextDis", crTextDis,
  "hBkgndBrush", 0, ; Cached brush handle (enabled)
  "hBkgndDisBrush", 0 ; Cached brush handle (disabled)
 )

 ; Method to get the enabled background brush (creates if needed)
 getBkgndBrush(self) {
  if (!self.hBkgndBrush && self.crBkgnd != "") { ; Only create if color is valid
   self.hBkgndBrush := DllCall("CreateSolidBrush", "UInt", self.crBkgnd, "Ptr")
   OutputDebug("ColorScheme: Created Enabled Brush " self.hBkgndBrush " for color " Format("0x{:X}", self.crBkgnd))
  }
  return self.hBkgndBrush
 }
 obj.DefineProp("GetBkgndBrush", { Call: getBkgndBrush })

 ; Method to get the disabled background brush (creates if needed)
 getBkgndDisBrush(self) {
  if (!self.hBkgndDisBrush && self.crBkgndDis != "") { ; Only create if color is valid
   self.hBkgndDisBrush := DllCall("CreateSolidBrush", "UInt", self.crBkgndDis, "Ptr")
   OutputDebug("ColorScheme: Created Disabled Brush " self.hBkgndDisBrush " for color " Format("0x{:X}", self.crBkgndDis))
  }
  return self.hBkgndDisBrush
 }
 obj.DefineProp("GetBkgndDisBrush", { Call: getBkgndDisBrush })

 ; Meta-function to delete brushes when the object is released
 deleteFunc(self, *) {
  OutputDebug("ColorScheme: Deleting brushes...")
  if (self.hBkgndBrush) {
   OutputDebug(" -> Deleting Enabled Brush " self.hBkgndBrush)
   DllCall("DeleteObject", "Ptr", self.hBkgndBrush)
   self.hBkgndBrush := 0 ; Clear handle after deletion
  }
  if (self.hBkgndDisBrush) {
   OutputDebug(" -> Deleting Disabled Brush " self.hBkgndDisBrush)
   DllCall("DeleteObject", "Ptr", self.hBkgndDisBrush)
   self.hBkgndDisBrush := 0 ; Clear handle after deletion
  }
 }
 obj.DefineProp("__Delete", { Call: deleteFunc })

 return obj
}