#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

EnhancedDarkApp()

class EnhancedDarkApp {
    __New() {
        this.InitializeGui()
        this.SetupControls()
        this.gui.Show()
    }

    InitializeGui() {
        this.gui := Gui("+Resize", "Enhanced Dark Mode Demo")
        this.gui.SetFont("s10", "Segoe UI")
        this.darkMode := _Dark(this.gui)

        this.darkMode.AddDarkText("y15 x15 w300", "Basic Controls")
        this.darkCheckbox := this.darkMode.AddDarkCheckBox("y+10 x15 w250", "Enable feature")
        this.darkListView := this.darkMode.AddListView("y+10 x15 w300 h120", ["Item", "Value"])
        this.actionButton := this.darkMode.AddDarkButton("y+10 x15 w120", "Run Action")
        this.darkEdit := this.darkMode.AddDarkEdit("y+10 x15 w200 h24", "Sample text input")
        this.darkComboBox := this.darkMode.AddDarkComboBox("y+10 x15 w200", ["Option 1", "Option 2", "Option 3"])

        this.darkMode.AddDarkText("y+20 x15 w300", "Advanced Controls")
        this.darkGroupBox := this.darkMode.AddDarkGroupBox("y+10 x15 w300 h80", "Group Settings")
        this.darkRadio1 := this.darkMode.AddDarkRadio("xp+15 yp+25 w250", "Option A")
        this.darkRadio2 := this.darkMode.AddDarkRadio("xp y+10 w250", "Option B")

        this.darkMode.AddDarkText("y+20 x15 w300", "Enhanced Controls")
        this.darkSlider := this.darkMode.AddDarkSlider("y+10 x15 w200 h30 Range0-100", 50)
        this.darkProgress := this.darkMode.AddDarkProgress("y+15 x15 w200 h20", 50)
        this.darkDateTime := this.darkMode.AddDarkDateTime("y+15 x15 w200")
        this.darkMonthCal := this.darkMode.AddDarkMonthCal("y+15 x15")
        this.darkTabs := this.darkMode.AddDarkTab3("y+15 x15 w300 h150", ["Tab 1", "Tab 2", "Tab 3"])

        this.gui.Tab := 1
        this.darkMode.AddDarkText("y+10 x25 w280", "Content for Tab 1")
        this.darkMode.AddDarkEdit("y+10 x25 w280 h80", "Tab 1 content area")

        this.gui.Tab := 2
        this.darkMode.AddDarkText("y+10 x25 w280", "Content for Tab 2")
        this.darkMode.AddDarkButton("y+10 x25 w100", "Tab 2 Button")

        this.gui.Tab := 3
        this.darkMode.AddDarkText("y+10 x25 w280", "Content for Tab 3")
        this.darkMode.AddDarkListBox("y+10 x25 w200 h80", ["List Item 1", "List Item 2", "List Item 3"])

        this.gui.Tab := ""

        this.darkMode.AddDarkText("y+20 x15 w300", "Theme Settings")
        this.themeSelecter := this.darkMode.AddDarkComboBox("y+10 x15 w200", ["Dark Blue", "Dark Gray", "Dark Green", "Dark Purple"])
            .OnEvent("Change", this.ThemeChanged.Bind(this))
        this.actionButton.OnEvent("Click", this.ButtonClicked.Bind(this))
        this.darkSlider.OnEvent("Change", this.SliderChanged.Bind(this))
    }

    ButtonClicked(*) {
        MsgBox("Button clicked!")
    }

    SliderChanged(*) {
        this.darkProgress.Value := this.darkSlider.Value
    }

    ThemeChanged(*) {
        local themeIndex, themes
        themeIndex := this.themeSelecter.Text
        themes := Map(
            "Dark Blue", Map("Background", 0x1A1A2E, "Controls", 0x16213E, "Font", 0xE0E0E0, "HeaderFont", 0xFFFFFF),
            "Dark Gray", Map("Background", 0x171717, "Controls", 0x1E1E1E, "Font", 0xE0E0E0, "HeaderFont", 0xFFFFFF),
            "Dark Green", Map("Background", 0x0A2A12, "Controls", 0x103619, "Font", 0xE0E0E0, "HeaderFont", 0xFFFFFF),
            "Dark Purple", Map("Background", 0x240041, "Controls", 0x3C096C, "Font", 0xE0E0E0, "HeaderFont", 0xFFFFFF)
        )
        if themes.Has(themeIndex) {
            this.darkMode.SetTheme(themes[themeIndex])
        }
    }

    SetupControls() {
        this.darkListView.Add(, "Item 1", "Value 1")
        this.darkListView.Add(, "Item 2", "Value 2")
        this.darkListView.Add(, "Item 3", "Value 3")
    }
}

class _Dark {
    class RECT {
        left   := 0 ; i32
        top    := 0 ; i32
        right  := 0 ; i32
        bottom := 0 ; i32
    }
    class NMHDR {
        hwndFrom := 0 ; uptr
        idFrom   := 0 ; uptr
        code     := 0 ; i32
    }
    class NMCUSTOMDRAW {
        hdr         := 0 ; NMHDR (embedded)
        dwDrawStage := 0 ; u32
        hdc         := 0 ; uptr
        rc          := 0 ; RECT (embedded)
        dwItemSpec  := 0 ; uptr
        uItemState  := 0 ; u32
        lItemlParam := 0 ; iptr
        __New() {
            this.hdr := _Dark.NMHDR()
            this.rc := _Dark.RECT()
        }
    }

class DarkListView extends Gui.ListView {
		class RECT {
			left: i32
            top: i32
            right: i32
            bottom: i32
		}

		class NMHDR { 
            hwndFrom: uptr
            idFrom  : uptr
            code : i32 
        }

		class NMCUSTOMDRAW {
			hdr        : DarkTheme.DarkListView.NMHDR
			dwDrawStage: u32
			hdc        : uptr
			rc         : DarkTheme.DarkListView.RECT
			dwItemSpec : uptr
			uItemState : u32
			lItemlParam: iptr
		}

		static __New() {
			static LVM_GETHEADER := 0x101F

			super.Prototype.GetHeader   := SendMessage.Bind(LVM_GETHEADER, 0, 0)
			super.Prototype.SetDarkMode := this.SetDarkMode.Bind(this)
		}

		static Initialize() {
		}

		static SetDarkMode(lv) {
			static LVS_EX_DOUBLEBUFFER := 0x10000
			static NM_CUSTOMDRAW       := -12
			static UIS_SET             := 1
			static UISF_HIDEFOCUS      := 0x1
			static WM_CHANGEUISTATE    := 0x0127
			static WM_NOTIFY           := 0x4E
			static WM_THEMECHANGED     := 0x031A

			lv.Header := lv.GetHeader()

			lv.OnMessage(WM_THEMECHANGED, (*) => 0)

			lv.OnMessage(WM_NOTIFY, (lv, wParam, lParam, Msg) {
				static CDDS_ITEMPREPAINT   := 0x10001
				static CDDS_PREPAINT       := 0x1
				static CDRF_DODEFAULT      := 0x0
				static CDRF_NOTIFYITEMDRAW := 0x20

				if (StructFromPtr(DarkTheme.DarkListView.NMHDR, lParam).Code != NM_CUSTOMDRAW)
					return

				nmcd := StructFromPtr(DarkTheme.DarkListView.NMCUSTOMDRAW, lParam)

				if (nmcd.hdr.hWndFrom != lv.Header)
					return

				switch nmcd.dwDrawStage {
					case CDDS_PREPAINT:
						return CDRF_NOTIFYITEMDRAW
					case CDDS_ITEMPREPAINT:
						SetTextColor(nmcd.hdc, DarkTheme.DarkColors["Font", true])
				}

				return CDRF_DODEFAULT
			})

			lv.Opt("+LV" . LVS_EX_DOUBLEBUFFER)

			SendMessage(WM_CHANGEUISTATE, (UIS_SET << 8) | UISF_HIDEFOCUS, 0, lv)

			SetWindowTheme(lv.Header, "DarkMode_ItemsView")
			SetWindowTheme(lv.Hwnd, "DarkMode_Explorer")

			SetTextColor(hdc, color) => DllCall("SetTextColor", "Ptr", hdc, "UInt", color)

			SetWindowTheme(hwnd, appName, subIdList?) => DllCall("uxtheme\SetWindowTheme", "ptr", hwnd, "ptr", StrPtr(appName), "ptr", subIdList ?? 0)
		}
	}


    static StructFromPtr(StructClass, ptr) {
        local obj, nmhdrSize, dwDrawStageOffset, hdcOffset, rcOffset, dwItemSpecOffset, uItemStateOffset, lItemlParamOffset
        obj := StructClass()
        if obj.HasOwnProp("dwDrawStage") 
        {
            nmhdrSize := A_PtrSize * 2 + 4
            dwDrawStageOffset := nmhdrSize
            hdcOffset := nmhdrSize + 4
            rcOffset := hdcOffset + A_PtrSize
            dwItemSpecOffset := hdcOffset + A_PtrSize + 16
            uItemStateOffset := dwItemSpecOffset + A_PtrSize
            lItemlParamOffset := dwItemSpecOffset + A_PtrSize + 4
            obj.hdr.hwndFrom := NumGet(ptr, 0, "UPtr")
            obj.hdr.idFrom := NumGet(ptr, A_PtrSize, "UPtr")
            obj.hdr.code := NumGet(ptr, A_PtrSize * 2, "Int")
            obj.dwDrawStage := NumGet(ptr, dwDrawStageOffset, "UInt")
            obj.hdc := NumGet(ptr, hdcOffset, "UPtr")
            obj.rc.left := NumGet(ptr, rcOffset + 0, "Int")
            obj.rc.top := NumGet(ptr, rcOffset + 4, "Int")
            obj.rc.right := NumGet(ptr, rcOffset + 8, "Int")
            obj.rc.bottom := NumGet(ptr, rcOffset + 12, "Int")
            obj.dwItemSpec := NumGet(ptr, dwItemSpecOffset, "UPtr")
            obj.uItemState := NumGet(ptr, uItemStateOffset, "UInt")
            obj.lItemlParam := NumGet(ptr, lItemlParamOffset, "IPtr")
            return obj
        } else if obj.HasOwnProp("hwndFrom") { ; NMHDR
             obj.hwndFrom := NumGet(ptr, 0, "UPtr")
             obj.idFrom := NumGet(ptr, A_PtrSize, "UPtr")
             obj.code := NumGet(ptr, A_PtrSize * 2, "Int")
             return obj
        } else if obj.HasOwnProp("left") { ; RECT
             obj.left := NumGet(ptr, 0, "Int")
             obj.top := NumGet(ptr, 4, "Int")
             obj.right := NumGet(ptr, 8, "Int")
             obj.bottom := NumGet(ptr, 12, "Int")
             return obj
        }
        return obj ; Fallback
    }

    ; --- Default Theme Colors ---
    static Dark := Map("Background", 0x171717, "Controls", 0x1b1b1b, "ComboBoxBg", 0x1E1E1E, "Font", 0xE0E0E0,
                       "SliderThumb", 0x3E3E3E, "SliderTrack", 0x2D2D2D, "ProgressFill", 0x0078D7,
                       "HeaderFont", 0xFFFFFF)

    ; --- Static State Properties ---
    static Instances := Map()
    static WindowProcOldMap := Map()
    static WindowProcCallbacks := Map()
    static TextBackgroundBrush := 0
    static ControlsBackgroundBrush := 0
    static ButtonColors := Map()
    static ComboBoxes := Map()
    static TextControls := Map()
    static DarkCheckboxPairs := Map()
    static GroupBoxes := Map()
    static RadioButtons := Map()
    static SliderControls := Map()
    static ProgressControls := Map()
    static DateTimeControls := Map()
    static MonthCalControls := Map()
    static TabControls := Map()
    static ListBoxControls := Map()
    static sWindowProcCallback := 0 ; Static reference for the main window proc callback

    ; --- Win32 Constants ---
    static WM_CTLCOLOREDIT := 0x0133, WM_CTLCOLORLISTBOX := 0x0134, WM_CTLCOLORBTN := 0x0135, WM_CTLCOLORSTATIC := 0x0138
    static WM_NOTIFY := 0x004E, WM_PAINT := 0x000F, WM_ERASEBKGND := 0x0014, WM_THEMECHANGED := 0x031A, WM_CHANGEUISTATE := 0x0127
    static WM_DESTROY := 0x0002 ; To clean up subclassing
    static NM_CUSTOMDRAW := -12
    static CDDS_PREPAINT := 0x00000001, CDDS_ITEMPREPAINT := 0x00010001
    static CDRF_DODEFAULT := 0x0, CDRF_NEWFONT := 0x00000002, CDRF_NOTIFYITEMDRAW := 0x00000020, CDRF_SKIPDEFAULT := 0x00000004
    static LVM_GETHEADER := 0x101F, LVM_SETBKCOLOR := 0x1001, LVM_SETTEXTCOLOR := 0x1024, LVM_SETTEXTBKCOLOR := 0x1026
    static LVS_EX_DOUBLEBUFFER := 0x10000
    static UIS_SET := 1, UISF_HIDEFOCUS := 0x1
    static TRANSPARENT := 1
    static GWL_WNDPROC := -4
    static GetWindowLong := A_PtrSize = 8 ? "GetWindowLongPtr" : "GetWindowLong"
    static SetWindowLong := A_PtrSize = 8 ? "SetWindowLongPtr" : "SetWindowLong"

    ; --- Static Initializer ---
    static __New() {
        ; Create callback only once and store statically
        if !_Dark.sWindowProcCallback {
            _Dark.sWindowProcCallback := CallbackCreate(ObjBindMethod(_Dark, "ProcessWindowMessage"), "F", 4)
        }

        if !_Dark.TextBackgroundBrush {
            _Dark.TextBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Dark["Background"], "Ptr")
        }
        if !_Dark.ControlsBackgroundBrush {
            _Dark.ControlsBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Dark["Controls"], "Ptr")
        }
    }

    ; --- Insertion: New static RegisterListView method ---
    static RegisterListView(lv) {
        ; Store a reference to ListView controls
        if !_Dark.HasProp("RegisteredListViews")
            _Dark.RegisteredListViews := Map()
        _Dark.RegisteredListViews[lv.Hwnd] := lv
    }

    ; --- Static Helper Methods ---
    static SendMessage(msg, wParam, lParam, hwndOrControl) {
        local hwnd, result
        hwnd := HasProp(hwndOrControl, "Hwnd") ? hwndOrControl.Hwnd : hwndOrControl
        if !hwnd || !IsObject(hwnd) && !IsInteger(hwnd) { ; Basic check
            OutputDebug("SendMessage Error: Invalid HWND.")
            return
        }
        result := DllCall("user32\SendMessage", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
        return result
    }

    static SetTextColor(hdc, color) {
        local result
        result := DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", color)
        return result
    }

    static SetBkMode(hdc, mode) {
        local result
        result := DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", mode)
        return result
    }

    static SetWindowTheme(hwnd, appName, subIdList?) {
         local result
         result := DllCall("uxtheme\SetWindowTheme", "ptr", hwnd, "ptr", StrPtr(appName), "ptr", subIdList ?? 0)
         return result
    }


    ; --- Main Window Message Processor ---
    static ProcessWindowMessage(hwnd, msg, wParam, lParam) {
        local oldProc, lResult, ctrlHwnd, isCheckboxText, cbHwnd, pair
        ; Get original proc safely
        oldProc := _Dark.WindowProcOldMap.Has(hwnd) ? _Dark.WindowProcOldMap[hwnd] : 0

        ; Call original first (allows default processing, may be needed for some messages)
        ; Exception: WM_CTLCOLOR* should return our brush, so don't call original first for those.
        lResult := 0
        if (msg != _Dark.WM_CTLCOLOREDIT && msg != _Dark.WM_CTLCOLORLISTBOX && msg != _Dark.WM_CTLCOLORBTN && msg != _Dark.WM_CTLCOLORSTATIC) {
             if oldProc {
                 lResult := DllCall("CallWindowProc", "Ptr", oldProc, "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
             } else {
                 lResult := DllCall("DefWindowProc", "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
             }
        }

        ; --- Our Custom Handling ---
        try {
            ctrlHwnd := lParam ; Often the control's HWND in WM_CTLCOLOR*

            switch msg {
                case _Dark.WM_CTLCOLOREDIT, _Dark.WM_CTLCOLORLISTBOX:
                    if _Dark.ComboBoxes.Has(ctrlHwnd) {
                        _Dark.SetTextColor(wParam, _Dark.Dark["Font"])
                        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Dark["ComboBoxBg"])
                        return _Dark.ControlsBackgroundBrush
                    } else {
                        _Dark.SetTextColor(wParam, _Dark.Dark["Font"])
                        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Dark["Controls"])
                        return _Dark.ControlsBackgroundBrush
                    }

                case _Dark.WM_CTLCOLORBTN:
                    if _Dark.ButtonColors.Has(ctrlHwnd) {
                        _Dark.SetTextColor(wParam, _Dark.ButtonColors[ctrlHwnd]["text"])
                        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.ButtonColors[ctrlHwnd]["bg"])
                        _Dark.SetBkMode(wParam, _Dark.TRANSPARENT)
                        if _Dark.RadioButtons.Has(ctrlHwnd) || _Dark.DarkCheckboxPairs.Has(ctrlHwnd) {
                             return _Dark.TextBackgroundBrush
                        } else {
                             return _Dark.ControlsBackgroundBrush
                        }
                    }

                case _Dark.WM_CTLCOLORSTATIC:
                    isCheckboxText := false
                    for cbHwnd, pair in _Dark.DarkCheckboxPairs {
                         if pair.text.Hwnd == ctrlHwnd {
                              isCheckboxText := true
                              break
                         }
                    }

                    if _Dark.TextControls.Has(ctrlHwnd) || _Dark.GroupBoxes.Has(ctrlHwnd) || isCheckboxText || _Dark.RadioButtons.Has(ctrlHwnd) {
                        _Dark.SetTextColor(wParam, _Dark.Dark["Font"])
                        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", _Dark.Dark["Background"])
                        _Dark.SetBkMode(wParam, _Dark.TRANSPARENT)
                        return _Dark.TextBackgroundBrush
                    }

                case _Dark.WM_DESTROY: ; Clean up subclassing
                    OutputDebug("ProcessWindowMessage: WM_DESTROY received for HWND=" hwnd)
                    if oldProc {
                        DllCall(_Dark.SetWindowLong, "Ptr", hwnd, "Int", _Dark.GWL_WNDPROC, "Ptr", oldProc) ; Restore original
                        _Dark.WindowProcOldMap.Delete(hwnd)
                         if (_Dark.WindowProcCallbacks.Has(hwnd)) {
                              _Dark.WindowProcCallbacks.Delete(hwnd)
                         }
                    }
                    if (_Dark.Instances.Has(hwnd)) {
                        _Dark.Instances.Delete(hwnd)
                    }
            }
        } Catch as e {
             OutputDebug("ProcessWindowMessage Error: " e.Message " for Msg=" msg " HWND=" hwnd)
        }

        ; Return the result from the original call (or 0 if handled here and no specific return needed)
        return lResult
    }


    ; =====================================================
    ; Instance Methods
    ; =====================================================
    __New(GuiObj) {
        _Dark.__New()
        this.Gui := GuiObj
        this.darkCheckboxes := Map()
        this.Gui.BackColor := _Dark.Dark["Background"]

        ; Apply immersive dark mode
        if VerCompare(A_OSVersion, "10.0.17763") >= 0 {
            local DWMWA_USE_IMMERSIVE_DARK_MODE, uxtheme, AllowDarkModeForApp, FlushMenuThemes
            DWMWA_USE_IMMERSIVE_DARK_MODE := VerCompare(A_OSVersion, "10.0.18985") >= 0 ? 20 : 19
            uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
            if uxtheme {
                 AllowDarkModeForApp := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
                 FlushMenuThemes := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")
                 DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.Gui.hWnd, "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "Int*", true, "Int", 4)
                 if AllowDarkModeForApp {
                      DllCall(AllowDarkModeForApp, "Int", 1)
                 }
                 if FlushMenuThemes {
                      DllCall(FlushMenuThemes)
                 }
            } else {
                 OutputDebug("Failed to get uxtheme module handle.")
            }
        }

        this.SetupWindowProc()
        this.RedrawAllControls()
        _Dark.Instances[this.Gui.Hwnd] := this
        this.Gui.OnEvent("Close", this.OnGuiClose.Bind(this)) ; Hook Close event for cleanup
        return this
    }

    OnGuiClose(theGui) {
         local hwnd, oldProc
         OutputDebug("OnGuiClose triggered for HWND=" theGui.Hwnd)
         hwnd := theGui.Hwnd
         if _Dark.WindowProcOldMap.Has(hwnd) {
              oldProc := _Dark.WindowProcOldMap[hwnd]
              DllCall(_Dark.SetWindowLong, "Ptr", hwnd, "Int", _Dark.GWL_WNDPROC, "Ptr", oldProc)
              _Dark.WindowProcOldMap.Delete(hwnd)
              _Dark.WindowProcCallbacks.Delete(hwnd)
         }
         if _Dark.Instances.Has(hwnd) {
             _Dark.Instances.Delete(hwnd)
         }
    }

    SetupWindowProc() {
        local hwnd, originalProc, err
        hwnd := this.Gui.Hwnd
        if _Dark.WindowProcOldMap.Has(hwnd) {
             OutputDebug("SetupWindowProc: Already subclassed HWND=" hwnd)
             return
        }

        if !_Dark.sWindowProcCallback {
             OutputDebug("SetupWindowProc Error: Static callback not created.")
             return
        }

        originalProc := DllCall(_Dark.SetWindowLong, "Ptr", hwnd, "Int", _Dark.GWL_WNDPROC, "Ptr", _Dark.sWindowProcCallback, "Ptr")

        if (originalProc = 0 && DllCall("GetLastError") != 0) {
             err := DllCall("GetLastError")
             OutputDebug("SetupWindowProc Error: SetWindowLong failed for HWND=" hwnd ". Error code: " err)
        } else {
             OutputDebug("SetupWindowProc: Successfully subclassed HWND=" hwnd ". Original Proc=" originalProc)
             _Dark.WindowProcOldMap[hwnd] := originalProc
             _Dark.WindowProcCallbacks[hwnd] := _Dark.sWindowProcCallback
        }
    }

    SetTheme(themeMap) {
        local key, value
        for key, value in themeMap {
             if _Dark.Dark.Has(key) {
                  _Dark.Dark[key] := value
             }
        }
        if !themeMap.Has("HeaderFont") && themeMap.Has("Font") {
             _Dark.Dark["HeaderFont"] := themeMap["Font"] == 0x000000 ? 0xFFFFFF : themeMap["Font"]
        } else if !themeMap.Has("HeaderFont") {
             _Dark.Dark["HeaderFont"] := 0xFFFFFF
        }
        this.Gui.BackColor := _Dark.Dark["Background"]
        if _Dark.TextBackgroundBrush {
             DllCall("DeleteObject", "Ptr", _Dark.TextBackgroundBrush)
        }
        _Dark.TextBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Dark["Background"], "Ptr")
        if _Dark.ControlsBackgroundBrush {
             DllCall("DeleteObject", "Ptr", _Dark.ControlsBackgroundBrush)
        }
        _Dark.ControlsBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", _Dark.Dark["Controls"], "Ptr")
        this.SetControlsTheme()
        this.RedrawAllControls()
        OutputDebug("SetTheme applied. HeaderFont is now " _Dark.Dark["HeaderFont"])
    }

    RedrawAllControls() {
        OutputDebug("RedrawAllControls called for HWND=" this.Gui.Hwnd)
        DllCall("RedrawWindow", "Ptr", this.Gui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0001 | 0x0080 | 0x0100 | 0x0400)
    }

    SetControlsTheme() {
        local hWnd, GuiCtrlObj, needsInvalidate, oldBg, oldText, newBg, newText
        OutputDebug("SetControlsTheme called.")
        for hWnd, GuiCtrlObj in this.Gui {
             needsInvalidate := false
             if _Dark.ButtonColors.Has(GuiCtrlObj.Hwnd) {
                 oldBg := _Dark.ButtonColors[GuiCtrlObj.Hwnd].bg
                 oldText := _Dark.ButtonColors[GuiCtrlObj.Hwnd].text
                 newBg := (GuiCtrlObj.Type == "Button") ? _Dark.Dark["Controls"] : _Dark.Dark["Background"]
                 newText := _Dark.Dark["Font"]
                 if (oldBg != newBg || oldText != newText) {
                      _Dark.ButtonColors[GuiCtrlObj.Hwnd].bg   := newBg
                      _Dark.ButtonColors[GuiCtrlObj.Hwnd].text := newText
                      needsInvalidate := true
                 }
             }

             if (needsInvalidate || GuiCtrlObj.Type = "ListView") {
                 OutputDebug("SetControlsTheme: Invalidating HWND=" GuiCtrlObj.Hwnd " Type=" GuiCtrlObj.Type)
                 DllCall("InvalidateRect", "Ptr", GuiCtrlObj.Hwnd, "Ptr", 0, "Int", true)
                 if (GuiCtrlObj.Type = "ListView" && GuiCtrlObj.HasProp("Header") && GuiCtrlObj.Header) {
                     OutputDebug("SetControlsTheme: Invalidating Header HWND=" GuiCtrlObj.Header)
                     DllCall("InvalidateRect", "Ptr", GuiCtrlObj.Header, "Ptr", 0, "Int", true)
                 }
             }
        }
    }

static HandleListViewNotify(ctrl, wParam, lParam, msg) {
    local hdr, nmcd
    hdr := _Dark.StructFromPtr(_Dark.NMHDR, lParam)
    OutputDebug("HandleListViewNotify: Received Code=" hdr.code " from HWND=" hdr.hwndFrom ". Target Header HWND=" ctrl.Header)

    if (hdr.code != _Dark.NM_CUSTOMDRAW || hdr.hwndFrom != ctrl.Header) {
         OutputDebug("HandleListViewNotify: Ignoring notification (code not NM_CUSTOMDRAW or source mismatch).")
         return
    }

    nmcd := _Dark.StructFromPtr(_Dark.NMCUSTOMDRAW, lParam)
    OutputDebug("HandleListViewNotify: NM_CUSTOMDRAW from Header. Stage=" nmcd.dwDrawStage ", HDC=" nmcd.hdc)

    if (!nmcd.hdc) {
        OutputDebug("HandleListViewNotify: Error - HDC is null.")
        return _Dark.CDRF_DODEFAULT
    }

    try {
        if (nmcd.dwDrawStage == _Dark.CDDS_PREPAINT) {
            OutputDebug("HandleListViewNotify: Stage=CDDS_PREPAINT. Requesting item notifications.")
            return _Dark.CDRF_NOTIFYITEMDRAW
        }

        if (nmcd.dwDrawStage == _Dark.CDDS_ITEMPREPAINT) {
            OutputDebug("HandleListViewNotify: Stage=CDDS_ITEMPREPAINT. Setting header text color to " _Dark.Dark["HeaderFont"])
            _Dark.SetTextColor(nmcd.hdc, _Dark.Dark["HeaderFont"])
            _Dark.SetBkMode(nmcd.hdc, _Dark.TRANSPARENT)
            OutputDebug("HandleListViewNotify: TextColor and BkMode set. Returning CDRF_NEWFONT.")
            return _Dark.CDRF_NEWFONT
        }
    } Catch as e {
        OutputDebug("HandleListViewNotify: Error during custom draw - " e.Message " at line " e.Line)
    }

    OutputDebug("HandleListViewNotify: Stage=" nmcd.dwDrawStage ". Performing default drawing.")
    return _Dark.CDRF_DODEFAULT
}

; --- AddDark* Methods ---
AddListView(Options, Headers) {
    local lv
    lv := this.Gui.Add("ListView", Options, Headers)
    OutputDebug("AddListView: Added LV HWND=" lv.Hwnd)

    _Dark.SendMessage(_Dark.LVM_SETTEXTCOLOR, 0, _Dark.Dark["Font"], lv.hWnd)
    _Dark.SendMessage(_Dark.LVM_SETBKCOLOR, 0, _Dark.Dark["Background"], lv.hWnd)
    _Dark.SendMessage(_Dark.LVM_SETTEXTBKCOLOR, 0, _Dark.Dark["Background"], lv.hWnd)
    lv.Opt("+LV" _Dark.LVS_EX_DOUBLEBUFFER)

    lv.Header := _Dark.SendMessage(_Dark.LVM_GETHEADER, 0, 0, lv.Hwnd)
    OutputDebug("AddListView: Got Header HWND=" lv.Header)
    if (!lv.Header) {
        OutputDebug("AddListView: Error - Failed to get header control handle.")
        return lv
    }

    _Dark.SetWindowTheme(lv.Header, "")
    OutputDebug("AddListView: Cleared theme for Header HWND=" lv.Header)

    _Dark.SetWindowTheme(lv.Hwnd, "Explorer")

    ; Store a reference to the ListView in its callback handler
    _Dark.RegisterListView(lv)
    
    ; Use standard function callbacks
    lv.OnMessage(_Dark.WM_NOTIFY, LV_NotifyHandler)
    lv.OnMessage(_Dark.WM_THEMECHANGED, LV_ThemeChangedHandler)

    _Dark.SendMessage(_Dark.WM_CHANGEUISTATE, (_Dark.UIS_SET << 16) | _Dark.UISF_HIDEFOCUS, 0, lv.Hwnd)

    DllCall("InvalidateRect", "Ptr", lv.Header, "Ptr", 0, "Int", true)
    DllCall("InvalidateRect", "Ptr", lv.Hwnd, "Ptr", 0, "Int", true)
    return lv

    ; Nested functions for OnMessage handlers
    LV_NotifyHandler(wParam, lParam, msg) {
        return _Dark.HandleListViewNotify(lv, wParam, lParam, msg)
    }
    
    LV_ThemeChangedHandler(wParam, lParam, msg) {
        OutputDebug("AddListView: WM_THEMECHANGED received for LV HWND=" lv.Hwnd)
        if (lv.HasProp("Header") && lv.Header) {
            DllCall("InvalidateRect", "Ptr", lv.Header, "Ptr", 0, "Int", true)
        }
        return 0
    }
}

    AddDarkCheckBox(Options, Text) {
        local chbox, txtOptions, txt, pair
        static SM_CXMENUCHECK := 71, checkBoxW := DllCall("GetSystemMetrics", "Int", SM_CXMENUCHECK, "Int")
        chbox := this.Gui.AddCheckBox(Options, "")
        txtOptions := "yp+2"
        if !InStr(Options, "right") {
             txtOptions := "xp+" (checkBoxW + 4) " " txtOptions
        } else {
             txtOptions := "xp+4 " txtOptions
        }
        txt := this.Gui.AddText(txtOptions, Text)
        pair := Map("checkbox", chbox, "text", txt)
        _Dark.DarkCheckboxPairs[chbox.Hwnd] := pair
        _Dark.TextControls[txt.Hwnd] := true
        chbox.DefineProp("Text", { Get: (*) => txt.Value, Set: (value, *) => txt.Value := value })
        _Dark.SetWindowTheme(chbox.hWnd, "")
        _Dark.ButtonColors[chbox.Hwnd] := Map("bg", _Dark.Dark["Background"], "text", _Dark.Dark["Font"])
        DllCall("InvalidateRect", "Ptr", chbox.Hwnd, "Ptr", 0, "Int", true)
        DllCall("InvalidateRect", "Ptr", txt.Hwnd, "Ptr", 0, "Int", true)
        return chbox
    }

    AddDarkButton(Options, Text) {
        local btn
        btn := this.Gui.AddButton(Options, Text)
        _Dark.SetWindowTheme(btn.hWnd, "Explorer")
        _Dark.ButtonColors[btn.Hwnd] := Map("bg", _Dark.Dark["Controls"], "text", _Dark.Dark["Font"])
        DllCall("InvalidateRect", "Ptr", btn.hWnd, "Ptr", 0, "Int", true)
        return btn
    }

    AddDarkEdit(Options, Text := "") {
        local edit
        edit := this.Gui.AddEdit(Options, Text)
        _Dark.SetWindowTheme(edit.hWnd, "Explorer")
        DllCall("InvalidateRect", "Ptr", edit.hWnd, "Ptr", 0, "Int", true)
        return edit
    }

    AddDarkComboBox(Options, Items := "") {
        local combo
        combo := this.Gui.AddComboBox(Options, Items)
        _Dark.SetWindowTheme(combo.hWnd, "CFD")
        _Dark.ComboBoxes[combo.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", combo.hWnd, "Ptr", 0, "Int", true)
        return combo
    }

    AddDarkText(Options, Text := "") {
        local txt
        txt := this.Gui.AddText(Options, Text)
        _Dark.TextControls[txt.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", txt.hWnd, "Ptr", 0, "Int", true)
        return txt
    }

    AddDarkGroupBox(Options, Text := "") {
        local groupBox
        groupBox := this.Gui.AddGroupBox(Options, Text)
        _Dark.SetWindowTheme(groupBox.hWnd, "")
        _Dark.GroupBoxes[groupBox.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", groupBox.hWnd, "Ptr", 0, "Int", true)
        return groupBox
    }

    AddDarkRadio(Options, Text := "") {
        local radio
        radio := this.Gui.AddRadio(Options, Text)
        _Dark.SetWindowTheme(radio.hWnd, "")
        _Dark.ButtonColors[radio.Hwnd] := Map("bg", _Dark.Dark["Background"], "text", _Dark.Dark["Font"])
        _Dark.RadioButtons[radio.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", radio.Hwnd, "Ptr", 0, "Int", true)
        return radio
    }

    AddDarkListBox(Options, Items := "") {
        local listBox
        listBox := this.Gui.AddListBox(Options, Items)
        _Dark.SetWindowTheme(listBox.hWnd, "Explorer")
        _Dark.ListBoxControls[listBox.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", listBox.hWnd, "Ptr", 0, "Int", true)
        return listBox
    }

    AddDarkSlider(Options, StartingValue := 0) {
        local slider
        slider := this.Gui.AddSlider(Options, StartingValue)
        _Dark.SetWindowTheme(slider.hWnd, "Explorer")
        _Dark.SliderControls[slider.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", slider.hWnd, "Ptr", 0, "Int", true)
        return slider
    }

    AddDarkProgress(Options, StartingValue := 0) {
        local progress
        progress := this.Gui.AddProgress(Options, StartingValue)
        _Dark.SetWindowTheme(progress.hWnd, "Explorer")
        _Dark.ProgressControls[progress.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", progress.hWnd, "Ptr", 0, "Int", true)
        return progress
    }

    AddDarkDateTime(Options := "") {
        local dateTime
        dateTime := this.Gui.AddDateTime(Options)
        _Dark.SetWindowTheme(dateTime.hWnd, "Explorer")
        _Dark.DateTimeControls[dateTime.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", dateTime.hWnd, "Ptr", 0, "Int", true)
        return dateTime
    }

    AddDarkMonthCal(Options := "") {
        local monthCal
        monthCal := this.Gui.AddMonthCal(Options)
        _Dark.SetWindowTheme(monthCal.hWnd, "Explorer")
        _Dark.MonthCalControls[monthCal.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", monthCal.Hwnd, "Ptr", 0, "Int", true)
        return monthCal
    }

    AddDarkTab3(Options, Tabs) {
        local tab
        tab := this.Gui.AddTab3(Options, Tabs)
        _Dark.SetWindowTheme(tab.hWnd, "Explorer")
        _Dark.TabControls[tab.Hwnd] := true
        DllCall("InvalidateRect", "Ptr", tab.hWnd, "Ptr", 0, "Int", true)
        return tab
    }
}
