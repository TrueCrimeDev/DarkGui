#Requires AutoHotkey v2.1-alpha.14
#SingleInstance Force
#Include <All>

; Initialize the GUI class
aDarkGui()

class aDarkGui {
	__New() {
		this.gui := DarkModeGui(, "Dark Mode GUI")
		this.gui.SetFont("s10", "Segoe UI")
		this.edit := this.gui.Add("Edit", "w400 h100", "Type here...")
		this.button := this.gui.Add("Button", "Default w200", "Submit")
		this.button.SetBackColor("0x000000")
		this.button.OnEvent("Click", this.Submit.Bind(this))
		this.SetupHotkeys()
		this.gui.Show()
	}

	Submit(*) {
		MsgBox(this.edit.Value, "Submitted Text")
	}

	CloseGui(*) {
		ExitApp()
	}

	Toggle(*) {
		if WinExist("ahk_id " this.gui.Hwnd) {
			this.gui.Hide()
		} else {
			this.gui.Show()
		}
	}

	SetupHotkeys() {
		HotKey("^m", this.Toggle.Bind(this))
	}
}

class DarkModeGui extends Gui {
	static Colors := Map(
		"Background", "0x1a1a1a",
		"Controls", "0x1f1f1f",
		"Font", "0xE0E0E0",
		"ButtonBg", "0x1f1f1f",
		"ButtonText", "0xFFFFFF",
		"BorderColor", "0x111111"
	)

	__New(Options := "", Title := A_ScriptName) {
		super.__New(Options, Title)
		this.SetFont("c" DarkModeGui.Colors["Font"] " s10", "Segoe UI")
		this.BackColor := DarkModeGui.Colors["Background"]
		
		this.SetDarkMode()
		this.SetDarkMenu()
		
		if (VerCompare(A_OSVersion, "10.0.22000") >= 0) {
			this.SetWindowAttribute(33, 2)
			if (VerCompare(A_OSVersion, "10.0.22621") >= 0)
				this.SetWindowAttribute(38, 4)
		}
	}

	Add(ControlType, Options := "", Text := "") {
		if (ControlType = "Button") {
			newBtn := super.Add("Button", Options, Text)
			; Properly set up the button as a DarkButton
			newBtn.base := DarkButton.Prototype
			newBtn._Init()
			newBtn.SetColor(DarkModeGui.Colors["ButtonBg"], DarkModeGui.Colors["ButtonText"])
			return newBtn
		}

		switch ControlType {
			case "Edit":
				Options .= " Background" DarkModeGui.Colors["Controls"] " c" DarkModeGui.Colors["Font"]
			case "Text":
				Options .= " c" DarkModeGui.Colors["Font"]
			case "ListView", "TreeView":
				Options .= " Background" DarkModeGui.Colors["Background"] " c" DarkModeGui.Colors["Font"]
			case "DropDownList", "ComboBox":
				Options .= " Background" DarkModeGui.Colors["Controls"] " c" DarkModeGui.Colors["Font"]
		}

		ctrl := super.Add(ControlType, Options, Text)

		switch ControlType {
			case "ListView", "TreeView":
				DllCall("uxtheme\SetWindowTheme", "ptr", ctrl.hwnd, "str", "DarkMode_Explorer", "ptr", 0)
			case "Edit", "ComboBox", "DropDownList":
				DllCall("uxtheme\SetWindowTheme", "ptr", ctrl.hwnd, "str", "DarkMode_CFD", "ptr", 0)
		}

		return ctrl
	}

	SetDarkMode() {
		if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
			attr := (VerCompare(A_OSVersion, "10.0.18985") >= 0) ? 20 : 19
			this.SetWindowAttribute(attr, true)
		}
	}

	SetDarkMenu() {
		uxtheme := DllCall("GetModuleHandle", "str", "uxtheme", "ptr")
		SetPreferredAppMode := DllCall("GetProcAddress", "ptr", uxtheme, "ptr", 135, "ptr")
		FlushMenuThemes := DllCall("GetProcAddress", "ptr", uxtheme, "ptr", 136, "ptr")
		DllCall(SetPreferredAppMode, "int", 1)
		DllCall(FlushMenuThemes)
	}

	SetWindowAttribute(dwAttribute, pvAttribute) {
		return DllCall("dwmapi\DwmSetWindowAttribute", "ptr", this.hwnd, "uint", dwAttribute, "int*", pvAttribute, "uint", 4)
	}
}

; Correctly inherit from Gui.Button
class DarkButton extends Gui.Button {
	; Properly define the __New method for a static class
	static __New() {
		; Correctly set up inheritance and property definitions
		super.Prototype.DefineProp("_Init", {Call: this.Prototype._Init})
		super.Prototype.DefineProp("SetBackColor", {Call: this.Prototype.SetBackColor})
		super.Prototype.DefineProp("SetColor", {Call: this.Prototype.SetColor})
	}

	_Init() {
		; Correctly bind the OnColor method to the current instance
		this.OnMessage(0x0135, this.OnColor.Bind(this))
		return this
	}

	SetColor(bgColor, textColor) {
		; Create the brush and set text color
		this._brush := DllCall("CreateSolidBrush", "uint", bgColor, "ptr")
		this._textColor := textColor
		this._isDark := ((bgColor >> 16 & 0xFF) / 255 * 0.2126 + 
			(bgColor >> 8 & 0xFF) / 255 * 0.7152 + 
			(bgColor & 0xFF) / 255 * 0.0722) < 0.5

		; Apply dark mode theme if necessary
		if this._isDark
			DllCall("uxtheme\SetWindowTheme", "ptr", this.hwnd, "ptr", StrPtr("DarkMode_Explorer"), "ptr", 0)
		return this
	}

	SetBackColor(color) {
		; Helper method to set background color with default white text
		return this.SetColor(color, 0xFFFFFF)
	}

	OnColor(wParam, lParam, msg, hwnd) {
		; Correctly handle the WM_CTLCOLORBTN message
		DllCall("SelectObject", "ptr", wParam, "ptr", this._brush)
		DllCall("SetBkMode", "ptr", wParam, "int", 1)
		DllCall("SetTextColor", "ptr", wParam, "uint", this._textColor)
		return this._brush
	}
}