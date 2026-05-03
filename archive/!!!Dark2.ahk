#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

; Define prototype methods before using them
Gui.Prototype.DefineProp("DarkMode", { Call: DarkMode })
Gui.Prototype.DefineProp("LightMode", { Call: LightMode })
Gui.Prototype.DefineProp("NeverFocusWindow", { Call: NeverFocusWindow })
Gui.Prototype.DefineProp("ShowPos", { Call: ShowPos })

; Now we can use the custom GUI
CustomGUI.Info("Hello World!", "Dark", 2000)
; Show customized popup
CustomGUI.PopUp(
    "This is the main text", ; Text
    "TITLE",                 ; Title
    "Subtitle",             ; Subtitle
    "Dark",                 ; Theme
    "Center",               ; Position
    3000                    ; Duration (ms)
)

DarkMode(GuiObj) {
    GuiObj.BackColor := "171717"
    GuiObj.SetFont("cC5C5C5")
    return GuiObj
}

LightMode(GuiObj) {
    GuiObj.BackColor := "ffffff"
    GuiObj.SetFont("c000000")
    return GuiObj
}

NeverFocusWindow(GuiObj) {
    WinSetExStyle(0x08000000, "ahk_id " GuiObj.Hwnd)
    return GuiObj
}

ShowPos(GuiObj, Pos := "Center") {
    XPosLeft := " x" Round(A_ScreenWidth / 20 * 0.5)
    XPosRight := " x" Round(A_ScreenWidth / 20 * 15.5)
    YPosTop := " y" Round((A_ScreenHeight / 20 * 1))
    YPosBelow := " y" Round((A_ScreenHeight / 20 * 14.5))

    MapPos := Map()
    MapPos.CaseSense := 0
    MapPos := Map(
        "Top", "xCenter" YPosTop,
        "LTop", XPosLeft YPosTop,
        "RTop", XPosRight YPosTop,
        "Center", "xCenter yCenter",
        "LCenter", XPosLeft " yCenter",
        "RCenter", XPosRight " yCenter",
        "Below", "xCenter" YPosBelow,
        "LBelow", XPosLeft YPosBelow,
        "RBelow", XPosRight YPosBelow
    )

    _Position_Filter(Pos) {
        if (RegExMatch(Pos, "i)^(x(-?\d+|center) y(-?\d+|center)|y(-?\d+|center) x(-?\d+|center))$")) {
            return Pos
        } else {
            for Key, Value in MapPos {
                if (Key = Pos) {
                    return MapPos[Pos]
                }
            }
            throw ValueError(A_ThisFunc "Parameter #2 invalid: String Illegal", -1, Pos)
        }
    }

    NewPos := _Position_Filter(Pos)
    GuiObj.Show(NewPos)
    return GuiObj
}

class CustomGUI {
    static Info(Text, Theme?, TimeOut?) => CustomGUI.Set_Info(Text, Theme?, TimeOut ?? 2000)

    class Set_Info {
        static _FontSize := 20
        static _Distance := 3
        static _MaxNumberedHotkeys := 12
        static _MaxWidthInChars := 104
        static _unit := A_ScreenDPI / 93
        static _guiWidth := CustomGUI.Set_Info._FontSize * CustomGUI.Set_Info._unit * CustomGUI.Set_Info._Distance
        static _maximumInfos := Floor(A_ScreenHeight / CustomGUI.Set_Info._guiWidth)
        static _spots := CustomGUI.Set_Info._GeneratePlacesArray()
        static _foDestroyAll := (*) => CustomGUI.Set_Info.DestroyAll()

        static FontSize {
            get => CustomGUI.Set_Info._FontSize
            set {
                CustomGUI.Set_Info._FontSize := Value
                CustomGUI.Set_Info._UpdatePrivateProperties()
            }
        }

        static Distance {
            get => CustomGUI.Set_Info._Distance
            set {
                CustomGUI.Set_Info._Distance := Value
                CustomGUI.Set_Info._UpdatePrivateProperties()
            }
        }

        static MaxNumberedHotkeys {
            get => CustomGUI.Set_Info._MaxNumberedHotkeys
            set {
                CustomGUI.Set_Info._MaxNumberedHotkeys := Value
                CustomGUI.Set_Info._UpdatePrivateProperties()
            }
        }

        static MaxWidthInChars {
            get => CustomGUI.Set_Info._MaxWidthInChars
            set {
                CustomGUI.Set_Info._MaxWidthInChars := Value
                CustomGUI.Set_Info._UpdatePrivateProperties()
            }
        }

        __New(Text, Theme := "Dark", TimeOut := 0) {
            this.Text := Text
            this._Theme := Theme
            this._TimeOut := TimeOut
            this._bfDestroy := this.Destroy.Bind(this)

            ; Create GUI first
            this._CreateGui()
            
            ; Then access its properties
            this.hwnd := this.GUI_Info.hwnd
            
            if !this._GetAvailableSpace() {
                this._StopDueToNoSpace()
                return
            }
            
            this._SetupHotkeysAndEvents()
            this._SetupAutoclose()
            this._Show()
        }

        _CreateGui() {
            this.GUI_Info := Gui("AlwaysOnTop -Caption +ToolWindow")
            this.GUI_Info.NeverFocusWindow()
            this.GUI_Info.SetFont("s" CustomGUI.Set_Info._FontSize, "Consolas")
            
            switch this._Theme, 0 {
                case "Dark": this.GUI_Info.DarkMode()
                case "Light": this.GUI_Info.LightMode()
            }
            
            this.gcText := this.GUI_Info.AddText(, this._FormatText())
        }

        static _GeneratePlacesArray() {
            availablePlaces := []
            loop CustomGUI.Set_Info._maximumInfos {
                availablePlaces.Push(false)
            }
            return availablePlaces
        }

        static _UpdatePrivateProperties() {
            CustomGUI.Set_Info._unit := A_ScreenDPI / 93
            CustomGUI.Set_Info._guiWidth := CustomGUI.Set_Info._FontSize * CustomGUI.Set_Info._unit * CustomGUI.Set_Info._Distance
            CustomGUI.Set_Info._maximumInfos := Floor(A_ScreenHeight / CustomGUI.Set_Info._guiWidth)
            CustomGUI.Set_Info._spots := CustomGUI.Set_Info._GeneratePlacesArray()
            CustomGUI.Set_Info._foDestroyAll := (*) => CustomGUI.Set_Info.DestroyAll()
        }

        static DestroyAll() {
            for index, infoObj in CustomGUI.Set_Info._spots {
                if !infoObj
                    continue
                infoObj.Destroy()
            }
        }

        ReplaceText(NewText) {
            try WinExist(this.GUI_Info)
            catch
                return CustomGUI.Set_Info(NewText, this._Theme, this._TimeOut)

            if StrLen(NewText) = StrLen(this.gcText.Text) {
                this.gcText.Text := NewText
                this._SetupAutoclose()
                return this
            }

            CustomGUI.Set_Info._spots[this.spaceIndex] := false
            return CustomGUI.Set_Info(NewText, this._Theme, this._TimeOut)
        }

        Destroy(*) {
            try HotIfWinExist("ahk_id " this.GUI_Info.Hwnd)
            catch Any {
                return false
            }
            Hotkey("Escape", "Off")
            Hotkey("+Escape", "Off")
            if this.spaceIndex <= CustomGUI.Set_Info._MaxNumberedHotkeys
                Hotkey("F" this.spaceIndex, "Off")
            this.GUI_Info.Destroy()
            try CustomGUI.Set_Info._spots[this.spaceIndex] := false
            return true
        }

        _FormatText() {
            text := String(this.Text)
            lines := text.Split("`n")
            if lines.Length > 1 {
                text := this._FormatByLine(lines)
            }
            else {
                text := this._LimitWidth(text)
            }
            return text.Replace("&", "&&")
        }

        _FormatByLine(lines) {
            newLines := []
            for index, line in lines {
                newLines.Push(this._LimitWidth(line))
            }
            text := ""
            for index, line in newLines {
                if index = newLines.Length {
                    text .= line
                    break
                }
                text .= line "`n"
            }
            return text
        }

        _LimitWidth(text) {
            if StrLen(text) < CustomGUI.Set_Info._MaxWidthInChars {
                return text
            }
            insertions := 0
            while (insertions + 1) * CustomGUI.Set_Info._MaxWidthInChars + insertions < StrLen(text) {
                insertions++
                text := text.Insert("`n", insertions * CustomGUI.Set_Info._MaxWidthInChars + insertions)
            }
            return text
        }

        _GetAvailableSpace() {
            spaceIndex := unset
            for index, isOccupied in CustomGUI.Set_Info._spots {
                if isOccupied
                    continue
                spaceIndex := index
                CustomGUI.Set_Info._spots[spaceIndex] := this
                break
            }
            if !IsSet(spaceIndex)
                return false
            this.spaceIndex := spaceIndex
            return true
        }

        _CalculateYCoord() => Round(this.spaceIndex * CustomGUI.Set_Info._guiWidth - CustomGUI.Set_Info._guiWidth)

        _StopDueToNoSpace() => this.GUI_Info.Destroy()

        _SetupHotkeysAndEvents() {
            HotIfWinExist("ahk_id " this.GUI_Info.Hwnd)
            Hotkey("Escape", this._bfDestroy, "On")
            Hotkey("+Escape", CustomGUI.Set_Info._foDestroyAll, "On")
            if this.spaceIndex <= CustomGUI.Set_Info._MaxNumberedHotkeys
                Hotkey("F" this.spaceIndex, this._bfDestroy, "On")
            this.gcText.OnEvent("Click", this._bfDestroy)
            this.GUI_Info.OnEvent("Close", this._bfDestroy)
        }

        _SetupAutoclose() {
            if this._TimeOut {
                SetTimer(this._bfDestroy, -this._TimeOut)
            }
        }

        _Show() => this.GUI_Info.Show("AutoSize NA x0 y" this._CalculateYCoord())
    }

    static PopUp(Text?, Title?, SubTitle?, Theme?, Pos?, TimeOut?) => CustomGUI.Set_PopUp(Text?, Title?, SubTitle?, Theme?, Pos?, TimeOut ?? 2000)

    class Set_PopUp {
        static _FontSize := {
            Title: 60,
            _Title: 60,
            SubTitle: 50,
            _SubTitle: 50,
            Text: 15,
            _Text: 15,
        }

        static _MaxWidthInChars := {
            Title: 17,
            _Title: 17,
            SubTitle: 23,
            _SubTitle: 23,
            Text: 30,
            _Text: 30,
        }

        static _ElementsSize := {
            Title: { Width: 300, Height: 40 },
            _Title: { Width: 300, Height: 40 },
            SubTitle: { Width: 300, Height: 30 },
            _SubTitle: { Width: 300, Height: 30 },
            Text: { Width: 300, Height: 80 },
            _Text: { Width: 300, Height: 80 },
        }

        __New(Text := "", Title := "", SubTitle := "", Theme := "Dark", Pos := "Center", TimeOut := 0) {
            this._Text := String(Text)
            this._Title := String(Title)
            this._SubTitle := String(SubTitle)
            this._Theme := Theme
            this._Pos := Pos
            this._TimeOut := TimeOut

            this._FilterParameters()
            this._CreateGui()
        }

        static Set_FontSize(Element := "", Value := "") {
            try {
                if (IsSet(Element)) {
                    if (!CustomGUI.Set_PopUp._FontSize.HasOwnProp(Element) or (Element[1] = "_")) {
                        throw ValueError("Parameter #1 invalid: Property not valid", -1, Element)
                    }
                }
                if (IsSet(Value)) {
                    if (!IsInteger(Value)) {
                        throw ValueError("Parameter #2 invalid: Value is not an integer", -1, Value)
                    }
                }
                if (IsSet(Element)) {
                    if (IsSet(Value)) {
                        CustomGUI.Set_PopUp._FontSize.%Element% := Value
                    } else {
                        CustomGUI.Set_PopUp._FontSize.%Element% := CustomGUI.Set_PopUp._FontSize._%Element%
                    }
                } else if (!IsSet(Element)) {
                    if (!IsSet(Value)) {
                        CustomGUI.Set_PopUp._RestoreStaticVariablesStaticDefault(CustomGUI.Set_PopUp._FontSize)
                    } else if (IsSet(Value)) {
                        CustomGUI.Set_PopUp._RestoreStaticVariablesStaticDefault(CustomGUI.Set_PopUp._FontSize, Value)
                    }
                }
            } catch as e {
                MsgBox("Error in [ " e.what " ]`n`n" e.message "`nLine: " e.line "`nSpecifically: `"" e.extra "`"", , 16)
            }
        }

        static Set_MaxWidthInChars(Element := "", Value := "") {
            try {
                if (IsSet(Element)) {
                    if (!CustomGUI.Set_PopUp._FontSize.HasOwnProp(Element) or (Element[1] = "_")) {
                        throw ValueError("Parameter #1 invalid: Property not valid", -1, Element)
                    }
                }
                if (IsSet(Value)) {
                    if (!IsInteger(Value)) {
                        throw ValueError("Parameter #2 invalid: Value is not an integer", -1, Value)
                    }
                }
                if (IsSet(Element)) {
                    if (IsSet(Value)) {
                        CustomGUI.Set_PopUp._MaxWidthInChars.%Element% := Value
                    } else {
                        CustomGUI.Set_PopUp._MaxWidthInChars.%Element% := CustomGUI.Set_PopUp._MaxWidthInChars._%Element%
                    }
                } else if (!IsSet(Element)) {
                    if (!IsSet(Value)) {
                        CustomGUI.Set_PopUp._RestoreStaticVariablesStaticDefault(CustomGUI.Set_PopUp._MaxWidthInChars)
                    } else if (IsSet(Value)) {
                        CustomGUI.Set_PopUp._RestoreStaticVariablesStaticDefault(CustomGUI.Set_PopUp._MaxWidthInChars, Value)
                    }
                }
            } catch as e {
                MsgBox("Error in [ " e.what " ]`n`n" e.message "`nLine: " e.line "`nSpecifically: `"" e.extra "`"", , 16)
            }
        }

        static _RestoreStaticVariablesStaticDefault(StaticVar, Value := "") {
            try {
                for Element, Val in StaticVar.OwnProps() {
                    if (Element[1] = "_") {
                        OriginalProp := Element[2, -1]
                        if (!IsSet(Value)) {
                            if (StaticVar.HasOwnProp(OriginalProp)) {
                                StaticVar.%OriginalProp% := StaticVar.%Element%
                            }
                        } else {
                            StaticVar.%OriginalProp% := Value
                        }
                    }
                }
            } catch as e {
                MsgBox("Error in [ " e.what " ]`n`n" e.message "`nLine: " e.line "`nSpecifically: `"" e.extra "`"", , 16)
            }
        }

        _FilterParameters() {
            if !(RegExMatch(this._Theme, "^[A-Za-z]+$")) {
                throw ValueError(A_ThisFunc "Parameter #4 invalid: String Illegal", -1, this._Theme)
            }
        }

        _CreateGui() {
            FontSize := {
                Title: CustomGUI.Set_PopUp._FontSize.Title,
                SubTitle: CustomGUI.Set_PopUp._FontSize.SubTitle,
                Text: CustomGUI.Set_PopUp._FontSize.Text,
            }

            MaxWidthInChars := {
                Title: CustomGUI.Set_PopUp._MaxWidthInChars.Title,
                SubTitle: CustomGUI.Set_PopUp._MaxWidthInChars.SubTitle,
                Text: CustomGUI.Set_PopUp._MaxWidthInChars.Text,
            }

            ElementsSize := {
                Title: { Width: CustomGUI.Set_PopUp._ElementsSize.Title.Width, Height: CustomGUI.Set_PopUp._ElementsSize.Title.Height },
                SubTitle: { Width: CustomGUI.Set_PopUp._ElementsSize.SubTitle.Width, Height: CustomGUI.Set_PopUp._ElementsSize.SubTitle.Height },
                Text: { Width: CustomGUI.Set_PopUp._ElementsSize.Text.Width, Height: CustomGUI.Set_PopUp._ElementsSize.Text.Height },
            }

            GUI_Main := Gui("+LastFound +AlwaysOnTop -Caption +ToolWindow")
            GUI_Main.NeverFocusWindow()

            switch this._Theme, 0 {
                case "Dark": GUI_Main.DarkMode()
                case "Light": GUI_Main.LightMode()
            }

            ElementsFontSize := {}

            if (this._Title != "") {
                ; Fix string slicing syntax
                this._Title := SubStr(this._Title, 1, MaxWidthInChars.Title)
                ElementsFontSize.Title := Min(Max((ElementsSize.Title.Width * ElementsSize.Title.Height * FontSize.Title) / (StrLen(this._Title) * MaxWidthInChars.Title * 100), 10), ElementsSize.Title.Height / 1.75)

                GUI_Main_Title := GUI_Main.Add("Text", "w" ElementsSize.Title.Width " h" ElementsSize.Title.Height " Center", this._Title)
                GUI_Main_Title.SetFont("w200 s" ElementsFontSize.Title, "Consolas")
                GUI_Main_Title.OnEvent("Click", _Destruction)
            }

            if (this._SubTitle != "") {
                ; Fix string slicing syntax
                this._SubTitle := SubStr(this._SubTitle, 1, MaxWidthInChars.SubTitle)
                ElementsFontSize.SubTitle := Min(Max((ElementsSize.SubTitle.Width * ElementsSize.SubTitle.Height * FontSize.SubTitle) / (StrLen(this._SubTitle) * MaxWidthInChars.SubTitle * 100), 10), ElementsSize.SubTitle.Height / 1.5)

                GUI_Main_SubTitle := GUI_Main.Add("Text", "w" ElementsSize.SubTitle.Width " h" ElementsSize.SubTitle.Height " Center", this._SubTitle)
                GUI_Main_SubTitle.SetFont("w100 s" ElementsFontSize.SubTitle, "Nyala")
                GUI_Main_SubTitle.OnEvent("Click", _Destruction)
            }

            if (this._Text != "") {
                MaxWidthInCharsTotal := 180
                ; Fix string slicing syntax
                this._Text := SubStr(this._Text, 1, MaxWidthInCharsTotal)
                Lines := Ceil(StrLen(this._Text) / MaxWidthInChars.Text)
                ElementsFontSize.Text := Min(Max((ElementsSize.Text.Width * ElementsSize.Text.Height * FontSize.Text) / (StrLen(this._Text) * MaxWidthInChars.Text * 100), 10), ElementsSize.Text.Height / (MaxWidthInCharsTotal / FontSize.Text) * 3)

                GUI_Main_Text := GUI_Main.Add("Text", "w" ElementsSize.Text.Width " h" ElementsSize.Text.Height " Center", _FormatText(this._Text))
                GUI_Main_Text.SetFont("w50 s" ElementsFontSize.Text, "NSimSun")
                GUI_Main_Text.OnEvent("Click", _Destruction)
            }

            GUI_Main.OnEvent("Escape", _Destruction)

            try {
                WinSetTransparent(0, GUI_Main.hwnd)
                if (this._SubTitle != "")
                    WinSetTransparent(150, "ahk_id " GUI_Main_SubTitle.hwnd)
                if (this._Text != "")
                    WinSetTransparent(105, "ahk_id " GUI_Main_Text.hwnd)

                GUI_Main.ShowPos(this._Pos)

                GUI_Main.Opt("+Disabled")
                TransDegree := 0
                while TransDegree <= 255 {
                    TransDegree += 30
                    if !(TransDegree > 255)
                        TransDegree++
                    try WinSetTransparent(TransDegree, GUI_Main.hwnd)
                    Sleep 10
                }
                GUI_Main.Opt("-Disabled")
            }
            _SetupAutoclose()

            _SetupAutoclose() {
                if this._TimeOut {
                    SetTimer(_Destruction, -this._TimeOut)
                }
            }

            _Destruction(*) {
                try {
                    if (IsObject(GUI_Main)) {
                        GUI_Main.Opt("+Disabled")
                        TransDegree := (WinGetTransparent(GUI_Main.hwnd) = "") ? 255 : WinGetTransparent(GUI_Main.hwnd)
                        while TransDegree > 0 {
                            TransDegree -= 30
                            if !(TransDegree < 0)
                                WinSetTransparent(TransDegree, GUI_Main.hwnd)
                            Sleep 10
                        }
                        GUI_Main.Destroy()
                    } else {
                        MsgBox("GUI_Main No es un objeto GUI NO LO ¡¡ENTIENDO!! " GUI_Main)
                    }
                }
            }

            _FormatText(_text_) {
                _text_ := String(_text_)
                _lines_ := _text_.Split("`n")
                if _lines_.Length > 1 {
                    _text_ := _FormatByLine(_lines_)
                }
                else {
                    _text_ := _LimitWidth(_text_)
                }
                return _text_.Replace("&", "&&")
            }

            _FormatByLine(_lines_) {
                newLines := []
                for index, line in _lines_ {
                    newLines.Push(_LimitWidth(line))
                }
                _text_ := ""
                for index, line in newLines {
                    if index = newLines.Length {
                        _text_ .= line
                        break
                    }
                    _text_ .= line "`n"
                }
                return _text_
            }

            _LimitWidth(_text_) {
                _MaxWidthInChars_ := CustomGUI.Set_PopUp._MaxWidthInChars.Text
                if StrLen(_text_) < _MaxWidthInChars_ {
                    return _text_
                }
                _LineBreak() {
                    insertions := 0
                    while (insertions + 1) * _MaxWidthInChars_ + insertions < StrLen(_text_) {
                        insertions++
                        _text_ := _text_.Insert("`n", insertions * _MaxWidthInChars_ + insertions)
                    }
                    return _text_
                }
                _text_ := _LineBreak()
                return _text_
            }
        }
    }
}