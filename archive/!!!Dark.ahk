#Requires AutoHotkey v2.1-alpha.14
#SingleInstance Force

DemoApp()

class DemoApp {
    __New() {
        this.gui := DarkModeGui2()
        SetDarkMode(this.gui)   
        this.gui.Add("Text", "y+10", "Name:")
        this.nameEdit := this.gui.Add("Edit", "w300")
        
        this.gui.Add("Text", "y+10", "Priority:")
        this.priority := this.gui.Add("DropDownList", "w300", ["High", "Medium", "Low"])
        
        saveBtn := this.gui.Add("Button", "y+20 w145", "Save")
        saveBtn.SetColor("0x2D5A27", 0xFFFFFF)
        
        clearBtn := this.gui.Add("Button", "x+10 w145", "Clear")
        clearBtn.SetColor("0x8B0000", 0xFFFFFF)

        this.listView := this.gui.Add("ListView", "y+20 x15 w300 h200", ["Name", "Priority"])
        
        saveBtn.OnEvent("Click", this.SaveTask.Bind(this))
        clearBtn.OnEvent("Click", this.ClearFields.Bind(this))
        
        this.gui.Show()
    }

    SaveTask(*) {
        if (this.nameEdit.Value = "")
            return
        this.listView.Add(, this.nameEdit.Value, this.priority.Text)
        this.ClearFields()
    }

    ClearFields(*) {
        this.nameEdit.Value := ""
        this.priority.Value := 1
    }
}

class DarkModeGui2 extends Gui {
    static Colors := Map(
        "Background", "0x202020",
        "Controls", "0x404040",
        "Font", "0xE0E0E0",
        "ButtonBg", "0x404040",
        "ButtonText", "0xFFFFFF",
        "BorderColor", "0x555555"
    )

    __New(Options := "", Title := A_ScriptName) {
        super.__New(Options, Title)
        this.SetFont("c" DarkModeGui2.Colors["Font"] " s10", "Segoe UI")
        this.BackColor := DarkModeGui2.Colors["Background"]
        
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
            newBtn.base := DarkButton.Prototype
            newBtn._Init()
            newBtn.SetColor(DarkModeGui2.Colors["ButtonBg"], DarkModeGui2.Colors["ButtonText"])
            return newBtn
        }

        switch ControlType {
            case "Edit":
                Options .= " Background" DarkModeGui2.Colors["Controls"] " c" DarkModeGui2.Colors["Font"]
            case "Text":
                Options .= " c" DarkModeGui2.Colors["Font"]
            case "ListView", "TreeView":
                Options .= " Background" DarkModeGui2.Colors["Background"] " c" DarkModeGui2.Colors["Font"]
            case "DropDownList", "ComboBox":
                Options .= " Background" DarkModeGui2.Colors["Controls"] " c" DarkModeGui2.Colors["Font"]
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

class DarkButton extends Gui.Button {
    static __New() {
        super.Prototype.DefineProp("_Init", {Call: this.Prototype._Init})
        super.Prototype.DefineProp("SetBackColor", {Call: this.Prototype.SetBackColor})
        super.Prototype.DefineProp("SetColor", {Call: this.Prototype.SetColor})
    }

    _Init() {
        this.OnMessage(0x0135, this.OnColor.Bind(this))
        return this
    }

    SetColor(bgColor, textColor) {
        this._brush := DllCall("CreateSolidBrush", "uint", bgColor, "ptr")
        this._textColor := textColor
        this._isDark := ((bgColor >> 16 & 0xFF) / 255 * 0.2126 + 
                        (bgColor >> 8 & 0xFF) / 255 * 0.7152 + 
                        (bgColor & 0xFF) / 255 * 0.0722) < 0.5

        if this._isDark
            DllCall("uxtheme\SetWindowTheme", "ptr", this.hwnd, "ptr", StrPtr("DarkMode_Explorer"), "ptr", 0)
        return this
    }

    SetBackColor(color) {
        return this.SetColor(color, 0xFFFFFF)
    }

    OnColor(wParam, lParam, msg, hwnd) {
        DllCall("SelectObject", "ptr", wParam, "ptr", this._brush)
        DllCall("SetBkMode", "ptr", wParam, "int", 1)
        DllCall("SetTextColor", "ptr", wParam, "uint", this._textColor)
        return this._brush
    }
}

SetDarkMode(_obj) {
    For v in [135, 136]
        DllCall(DllCall("GetProcAddress", "ptr", DllCall("GetModuleHandle", "str", "uxtheme", "ptr"), "ptr", v, "ptr"), "int", 2)
    if !(attr := VerCompare(A_OSVersion, "10.0.18985") >= 0 ? 20 : VerCompare(A_OSVersion, "10.0.17763") >= 0 ? 19 : 0)
        return false
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", _obj.hwnd, "int", attr, "int*", true, "int", 4)
}

; SetCtrlTheme(Ctr) {
; 	Theme:=Themes.%App.ThemeSelected%
; 	IsCtrDark:=Theme.CtrDark
; 	Mode_Explorer  := (IsCtrDark ? "DarkMode_Explorer"  : "Explorer" )
; 	Mode_CFD       := (IsCtrDark ? "DarkMode_CFD"       : "CFD"      )
; 	Mode_ItemsView := (IsCtrDark ? "DarkMode_ItemsView" : "ItemsView")
; 	Mode:=""
	
; 	If Ctr.Type="Text" && (InStr(Ctr.Name, "NavHRText_")=1) {
; 		Ctr.Opt("BackgroundTrans c" Theme.HrColor)
; 	} Else If Ctr.Type="Text" && (InStr(Ctr.Name, "HRLine_")=1) {
; 		Ctr.Opt("Background" Theme.HrColor " c" Theme.HrColor)
; 	} Else If Ctr.Type="Text" || Ctr.Type="PicSwitch" {
; 		Ctr.Opt("BackgroundTrans c" Theme.TextColor)
; 	} Else If Ctr.Type="DDL" {
; 		Mode:=Mode_CFD
; 	} Else If Ctr.Type!="Pic" {
; 		Ctr.Opt("Background" Theme.BackColorPanelRGB " c" Theme.TextColor)
; 		If Ctr.Type!="CheckBox"
; 			Mode:=Mode_Explorer
; 		Else If Ctr.Type="ListView"
; 			Mode:=Mode_ItemsView
; 	}
; 	If Mode
; 		DllCall("uxtheme\SetWindowTheme", "ptr", Ctr.hwnd, "str", Mode, "ptr", 0)
; }

; SetMenuTheme() {
; 	; "Default": 0, "AllowDark": 1, "ForceDark": 2, "ForceLight": 3, "Max": 4
; 	uxtheme := DllCall("kernel32\GetModuleHandle", "Str", "uxtheme", "Ptr")
; 	SetPreferredAppMode := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
; 	FlushMenuThemes     := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")
; 	DllCall(SetPreferredAppMode, "Int", Themes.%App.ThemeSelected%.CtrDark?2:3)
; 	DllCall(FlushMenuThemes)
; }

; BtnSys_Theme:=g.AddText('vBtnSys_Theme BackgroundTrans x' (BtnSysX+=35) ' ym w30 h20 0x200 Center Border',Chr(0xE2B1))
; BtnSys_Theme.Opt("-Border")
; BtnSys_Theme.OnEvent("Click",CreatePopupTheme)



#Include <Array>
#Include <String>


;todo---MARK: Custom Attributes

/**
 * * Activa el modo oscuro para una ventana.
 * 
 * @param {Object} GuiObj - El objeto de la ventana en el que se activará el modo oscuro.
 * @returns {Object} - Devuelve el objeto de la ventana con el modo oscuro activado.
 */
DarkMode(GuiObj) {
    ;; Establece el color de fondo en modo oscuro
    GuiObj.BackColor := "171717"

    ;; Establece el color de fuente en modo oscuro
    GuiObj.SetFont("cC5C5C5")

    ;; Devuelve el objeto de la ventana con el modo oscuro activado
    return GuiObj
}

;; Define la función DarkMode como una propiedad de la clase Gui.Prototype
Gui.Prototype.DefineProp("DarkMode", { Call: DarkMode })

/**
 * * Activa el modo claro para una ventana.
 * 
 * @param {Object} GuiObj - El objeto de la ventana en el que se activará el modo claro.
 * @returns {Object} - Devuelve el objeto de la ventana con el modo claro activado.
 */
LightMode(GuiObj) {
    ;; Establece el color de fondo en modo claro
    GuiObj.BackColor := "ffffff"

    ;; Establece el color de fuente en modo claro
    GuiObj.SetFont("c000000")

    ;; Devuelve el objeto de la ventana con el modo claro activado
    return GuiObj
}

;;;; Define la función LightMode como una propiedad de la clase Gui.Prototype
Gui.Prototype.DefineProp("LightMode", { Call: LightMode })


;? Styles:

/**
 * * Desactiva el enfoque automático de una ventana.
 * 
 * @param {Object} GuiObj - El objeto de la ventana en el que se desactivará el enfoque automático.
 * @returns {Object} - Devuelve el objeto de la ventana con el enfoque automático desactivado.
 */
NeverFocusWindow(GuiObj) {
    ;; Desactiva el estilo extendido WS_EX_NOACTIVATE para evitar el enfoque automático
    WinSetExStyle("0x08000000L", GuiObj)

    ;; Devuelve el objeto de la ventana con el enfoque automático desactivado
    return GuiObj
}

;; Define la función NeverFocusWindow como una propiedad de la clase Gui.Prototype
Gui.Prototype.DefineProp("NeverFocusWindow", { Call: NeverFocusWindow })


;;MARK:*
;^----------------Methods----------------^;


;? ShowPos:

/**
 * * Muestra una ventana emergente con la configuración especificada.
 * 
 * @param {Object} GuiObj - Objeto de la ventana que se mostrará.
 * @param {String} [Pos="Center"] - La posición inicial donde se mostrará la ventana. Puede ser una de las siguientes opciones: "x{n} y{n}", "Top", "LTop", "RTop", "Center", "LCenter", "RCenter", "Below", "LBelow", "RBelow". Por ejemplo, "x0 y0", "Center".
 * 
 * @throws {ValueError} - Se lanza un ValueError si la cadena proporcionada para la posición no es válida.
 * 
 * @returns {Object} - Devuelve el objeto de la ventana mostrada.
 * 
 * @example
 * // Mostrar la ventana en el centro
 * GUI_Main.ShowPos()
 */
ShowPos(GuiObj, Pos := "Center") {
    ;; Define variables para las posiciones predeterminadas
    XPosLeft := " x" Round(A_ScreenWidth / 20 * 0.5)
    XPosRight := " x" Round(A_ScreenWidth / 20 * 15.5)

    YPosTop := " y" Round((A_ScreenHeight / 20 * 1))
    YPosBelow := " y" Round((A_ScreenHeight / 20 * 14.5))

    ;; Define un mapa de posiciones para simplificar la lógica
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

    ;; Función interna para filtrar la posición proporcionada
    _Position_Filter(Pos) {
        if (RegExMatch(Pos, "i)^(x(-?\d+|center) y(-?\d+|center)|y(-?\d+|center) x(-?\d+|center))$")) {
            return Pos
        } else {
            for Key, Value in MapPos {
                if (Key = Pos) {
                    NewPos := MapPos[Pos]
                    return NewPos
                }
            }
            throw ValueError(A_ThisFunc "Parameter #2 invalid: String Illegal", -1, Pos)
        }
        return NewPos
    }

    ;; Filtra la posición y obtiene la nueva posición
    NewPos := _Position_Filter(Pos)

    ;; Muestra la ventana en la posición especificada
    GuiObj.Show(NewPos)

    ;; Devuelve el objeto de la ventana mostrada
    return GuiObj
}

;; Define la función ShowPos como una propiedad de la clase Gui.Prototype
Gui.Prototype.DefineProp("ShowPos", { Call: ShowPos })

CustomGUI()
;todo---MARK: class CustomGUI

class CustomGUI {

    /**
     * * Muestra una ventana emergente dinámica automáticamente en la esquina inferior derecha de la pantalla que se puede configurar con los siguientes parámetros.
     * @example CustomGUI.Info("texto", "Light", 2000)
     * @param Text (*String*) El texto de la ventana; Ejemplo: "texto".
     * @param Theme (*String*) El tema de la ventana; Opciones: "Light", "Dark".
     * @param TimeOut (*Integer*) El tiempo en milisegundos que la ventana estará presente, el valor predeterminado es 2000 (2 segundos); Ejemplo: 1000 (1 segundo).
     * 
     * @remarks
     * `Info` es un método alias de la clase `Set_Info`, y la clase `Set_Info` se puede configurar con las siguientes variables personalizadas:
     * 
     * Variables Personalizadas:
     * - `FontSize`: Tamaño de fuente predeterminado para la ventana emergente; Valor predeterminado: 20.
     * - `Distance`: Distancia predeterminada entre elementos de la ventana emergente; Valor predeterminado: 3.
     * - `MaxNumberedHotkeys`: Número máximo de hotkeys numéricos asociados con las ventanas emergentes; Valor predeterminado: 12.
     * - `MaxWidthInChars`: Ancho máximo en caracteres para el texto de la ventana emergente; Valor predeterminado: 104.
     * 
     * Puede configurar estas variables utilizando la notación de puntos, por ejemplo:
     * @example CustomGUI.Set_Info.FontSize := 30
     */
    static Info(Text, Theme?, TimeOut?) => CustomGUI.Set_Info(Text, Theme?, TimeOut ?? 2000)


    class Set_Info {

        /**
         * Muestra una ventana emergente dinamica automatica en la parte suberior derecha de la pantalla que puedes configurar con los siguientes parametros.
         * @example CustomGUI.Set_Info("text", "Light", 2000)
         * @param Text (*String*) El texto de la ventana; Ejem "texto".
         * @param Theme (*String*) The theme of the window; Options: "Light", "Dark".
         * @param TimeOut (*Integer*) El tiempo en milisegundos que estara presente la ventana, si no se especifica ningun valor la ventana no desaparecera hasta que se presione escape en ella o se haga click en esta; Ejem 1000 (1 Segundo)
         */
        __New(Text, Theme := "Dark", TimeOut := 0) {
            this.Text := Text
            this._Theme := Theme
            this._TimeOut := TimeOut

            this._CreateGui()
            this.hwnd := this.GUI_Info.hwnd
            if !this._GetAvailableSpace() {
                this._StopDueToNoSpace()
                return
            }
            this._SetupHotkeysAndEvents()
            this._SetupAutoclose()
            this._Show()
        }


        static _FontSize := 20
        static _Distance := 3
        static _MaxNumberedHotkeys := 12
        static _MaxWidthInChars := 104

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

        static _unit := A_ScreenDPI / 93
        static _guiWidth := CustomGUI.Set_Info._FontSize * CustomGUI.Set_Info._unit * CustomGUI.Set_Info._Distance
        static _maximumInfos := Floor(A_ScreenHeight / CustomGUI.Set_Info._guiWidth)
        static _spots := CustomGUI.Set_Info._GeneratePlacesArray()
        static _foDestroyAll := (*) => CustomGUI.Set_Info.DestroyAll()

        _TimeOut := 0
        _bfDestroy := this.Destroy.Bind(this)


        static DestroyAll() {
            for index, infoObj in CustomGUI.Set_Info._spots {
                if !infoObj
                    continue
                infoObj.Destroy()
            }
        }

        static _UpdatePrivateProperties() {
            CustomGUI.Set_Info._unit := A_ScreenDPI / 93
            CustomGUI.Set_Info._guiWidth := CustomGUI.Set_Info._FontSize * CustomGUI.Set_Info._unit * CustomGUI.Set_Info._Distance
            CustomGUI.Set_Info._maximumInfos := Floor(A_ScreenHeight / CustomGUI.Set_Info._guiWidth)
            CustomGUI.Set_Info._spots := CustomGUI.Set_Info._GeneratePlacesArray()
            CustomGUI.Set_Info._foDestroyAll := (*) => CustomGUI.Set_Info.DestroyAll()
        }

        static _GeneratePlacesArray() {
            availablePlaces := []
            loop CustomGUI.Set_Info._maximumInfos {
                availablePlaces.Push(false)
            }
            return availablePlaces
        }


        /**
         * * Reemplazará el texto en la Información
         * Si la ventana se destruye, simplemente crea una nueva Información. De lo contrario:
         * Si el texto tiene la misma longitud, simplemente reemplazará el texto sin recrear la interfaz gráfica de usuario.
         * Si el texto tiene diferente longitud, se recreará la interfaz gráfica de usuario en el mismo lugar
         * (una vez más, sólo si la ventana no se destruye)
         * @param NewText (*String*)
         * @returns {CustomGUI.Set_Info} el objeto de clase
         */
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

        _CreateGui() {
            ; this.GUI_Info  := Gui("AlwaysOnTop -Caption +ToolWindow").DarkMode().MakeFontNicer(CustomGUI.Set_Info._FontSize).NeverFocusWindow()
            this.GUI_Info := Gui("AlwaysOnTop -Caption +ToolWindow").NeverFocusWindow()
            this.GUI_Info.SetFont("s" CustomGUI.Set_Info._FontSize, "Consolas")
            switch this._Theme, 0 {
                case "Dark": this.GUI_Info.DarkMode
                case "Light": this.GUI_Info.LightMode
            }
            this.gcText := this.GUI_Info.AddText(, this._FormatText())
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


    /**
     * * Muestra una ventana emergente personalizable con los siguientes parámetros.
     * @example CustomGUI.PopUp("texto", "TÍTULO", "Subtítulo", "Light", "Top", 2000)
     * @param Text (*String*) El texto de la ventana; Ejemplo: "texto".
     * @param Title (*String*) El título de la ventana; Ejemplo: "TÍTULO".
     * @param SubTitle (*String*) El subtítulo de la ventana; Ejemplo: "Subtítulo".
     * @param Theme (*String*) El tema de la ventana; Opciones: "Light", "Dark".
     * @param Pos (*String*) La posición inicial donde se mostrará la ventana; Opciones: "x{n} y{n}", "Top", "LTop", "RTop", "Center", "LCenter", "RCenter", "Below", "LBelow", "RBelow"; Ejemplo: "x0 y0", "Center".
     * @param TimeOut (*Integer*) El tiempo en milisegundos que la ventana estará presente; Ejemplo: 1000 (1 segundo). Si TimeOut es 0, la ventana no desaparecerá hasta que se haga clic o se presione la tecla Escape.
     */
    static PopUp(Text?, Title?, SubTitle?, Theme?, Pos?, TimeOut?) => CustomGUI.Set_PopUp(Text?, Title?, SubTitle?, Theme?, Pos?, TimeOut ?? 2000)

    class Set_PopUp {

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


        ;;MARK:*
        ;^----------------Set Variables----------------^;

        /**
         * * Establece el tamaño de la fuente para una propiedad específica en la clase CustomGUI.
         * 
         * @param {String} [Element=""] - El nombre de la propiedad para la cual se está estableciendo el tamaño de la fuente. Si se omite, restablece todos los tamaños de fuente a sus valores predeterminados.
         * @param {Integer} [Value=""] - El valor del tamaño de la fuente que se va a establecer. Si se omite, se usa el tamaño de fuente predeterminado para la propiedad.
         * 
         * @throws {ValueError} Lanza un ValueError si la propiedad proporcionada no es válida o si el valor no es un entero.
         */
        static Set_FontSize(Element := "", Value := "") {
            try {
                if (IsSet(Element)) {
                    ;; Compruebe si la propiedad es válida.
                    if (!CustomGUI.Set_PopUp._FontSize.HasOwnProp(Element) or (Element[1] = "_")) {
                        throw ValueError("Parameter #1 invalid: Property not valid", -1, Element)
                    }
                }
                if (IsSet(Value)) {
                    ;; Compruebe si el valor es un número entero.
                    if (!IsInteger(Value)) {
                        throw ValueError("Parameter #2 invalid: Value is not an integer", -1, Value)
                    }
                }
                if (IsSet(Element)) {
                    ;; Establezca el tamaño de fuente en el valor proporcionado o el valor predeterminado.
                    if (IsSet(Value)) {
                        CustomGUI.Set_PopUp._FontSize.%Element% := Value
                    } else {
                        CustomGUI.Set_PopUp._FontSize.%Element% := CustomGUI.Set_PopUp._FontSize._%Element%
                    }
                } else if (!IsSet(Element)) {
                    if (!IsSet(Value)) {
                        ;; Restablezca todos los tamaños de fuente a sus valores predeterminados.
                        CustomGUI.Set_PopUp._RestoreStaticVariablesStaticDefault(CustomGUI.Set_PopUp._FontSize)
                    } else if (IsSet(Value)) {
                        ;; Establezca todos los tamaños de fuente en el valor especificado.
                        CustomGUI.Set_PopUp._RestoreStaticVariablesStaticDefault(CustomGUI.Set_PopUp._FontSize, Value)
                    }
                }
            } catch as e {
                ;; Mostrar mensaje de error.
                MsgBox("Error in [ " e.what " ]`n`n" e.message "`nLine: " e.line "`nSpecifically: `"" e.extra "`"", , 16)
            }
        }


        /**
         * * Establece el ancho máximo en caracteres para una propiedad específica en la clase CustomGUI.
         * 
         * @param {String} [Element=""] - El nombre de la propiedad para la cual se está estableciendo el ancho máximo en caracteres. Si se omite, restablece todos los anchos máximos a sus valores predeterminados.
         * @param {Integer} [Value=""] - El valor del ancho máximo en caracteres que se va a establecer. Si se omite, se usa el ancho máximo predeterminado para la propiedad.
         * 
         * @throws {ValueError} Lanza un ValueError si la propiedad proporcionada no es válida o si el valor no es un entero.
         */
        static Set_MaxWidthInChars(Element := "", Value := "") {
            try {
                if (IsSet(Element)) {
                    ;; Compruebe si la propiedad es válida.
                    if (!CustomGUI.Set_PopUp._FontSize.HasOwnProp(Element) or (Element[1] = "_")) {
                        throw ValueError("Parameter #1 invalid: Property not valid", -1, Element)
                    }
                }
                if (IsSet(Value)) {
                    ;; Compruebe si el valor es un número entero.
                    if (!IsInteger(Value)) {
                        throw ValueError("Parameter #2 invalid: Value is not an integer", -1, Value)
                    }
                }
                if (IsSet(Element)) {
                    ;; Establezca el ancho máximo en caracteres en el valor proporcionado o el valor predeterminado.
                    if (IsSet(Value)) {
                        CustomGUI.Set_PopUp._MaxWidthInChars.%Element% := Value
                    } else {
                        CustomGUI.Set_PopUp._MaxWidthInChars.%Element% := CustomGUI.Set_PopUp._MaxWidthInChars._%Element%
                    }
                } else if (!IsSet(Element)) {
                    if (!IsSet(Value)) {
                        ;; Restablezca todos los anchos máximos a sus valores predeterminados.
                        CustomGUI.Set_PopUp._RestoreStaticVariablesStaticDefault(CustomGUI.Set_PopUp._MaxWidthInChars)
                    } else if (IsSet(Value)) {
                        ;; Establezca todos los anchos máximos en el valor especificado.
                        CustomGUI.Set_PopUp._RestoreStaticVariablesStaticDefault(CustomGUI.Set_PopUp._MaxWidthInChars, Value)
                    }
                }
            } catch as e {
                ;; Mostrar mensaje de error.
                MsgBox("Error in [ " e.what " ]`n`n" e.message "`nLine: " e.line "`nSpecifically: `"" e.extra "`"", , 16)
            }
        }


        ; static Set_ElementsSize(Element?, Width?, Height?) {
        ;     try {
        ;         if (!IsSet(Element)) {
        ;             ; Restablecer todos los anchos máximos a sus valores predeterminados
        ;             CustomGUI.Set_PopUp._RestoreStaticVariablesStaticDefault(CustomGUI.Set_PopUp._ElementsSize)
        ;         } else {
        ;             ; Establezca todos los anchos máximos al valor especificado
        ;             CustomGUI.Set_PopUp._RestoreStaticVariablesStaticDefault(CustomGUI.Set_PopUp._ElementsSize, Value)
        ;         }

        ;         ; Compruebe si la propiedad es válida.
        ;         if (!CustomGUI.Set_PopUp._ElementsSize.HasOwnProp(Element) or (Element[1] = "_")) {
        ;             throw ValueError("Parameter #1 invalid: Property not valid", -1, Element)
        ;         }

        ;         ; Set the maximum width in characters to the provided value or the default value
        ;         if (IsSet(Value)) {
        ;             if (!IsInteger(Value)) {
        ;                 throw ValueError("Parameter #2 invalid: Value is not an integer", -1, Value)
        ;             }
        ;             CustomGUI.Set_PopUp._ElementsSize.%Element% := Value
        ;         } else {
        ;             CustomGUI.Set_PopUp._ElementsSize.%Element% := CustomGUI.Set_PopUp._ElementsSize._%Element%
        ;         }
        ;     } catch as e {
        ;         ; Mostrar mensaje de error
        ;         MsgBox("Error in [ " e.what " ]`n`n" e.message "`nLine: " e.line "`nSpecifically: `"" e.extra "`"",, 16)
        ;     }
        ; }


        /**
         * * Restablece las variables estáticas a sus valores predeterminados en la clase CustomGUI.
         * 
         * @param {Object} StaticVar - El objeto que contiene las variables estáticas.
         * @param {Any} [Value] - Valor opcional para establecer en las propiedades. Si se omite, las propiedades se restablecen a sus valores predeterminados.
         */
        static _RestoreStaticVariablesStaticDefault(StaticVar, Value := "") {
            try {
                ;; Iterar sobre todas las propiedades propias del objeto StaticVar
                for Element, Val in StaticVar.OwnProps() {
                    ;; Compruebe si el nombre de la propiedad comienza con "_"
                    if (Element[1] = "_") {
                        ;; Extraiga el nombre de la propiedad original sin el prefijo "_"
                        OriginalProp := Element[2, -1]
                        ;; Si no se proporciona ningún valor, restaure la propiedad a su valor original
                        if (!IsSet(Value)) {
                            ;; Compruebe si la propiedad original existe en el objeto StaticVar
                            if (StaticVar.HasOwnProp(OriginalProp)) {
                                ;; Restaurar el valor de propiedad actual al valor original
                                StaticVar.%OriginalProp% := StaticVar.%Element%
                            }
                        } else {
                            ;; Establecer la propiedad al valor proporcionado
                            StaticVar.%OriginalProp% := Value
                        }
                    }
                }
            } catch as e {
                ;; Mostrar mensaje de error
                MsgBox("Error in [ " e.what " ]`n`n" e.message "`nLine: " e.line "`nSpecifically: `"" e.extra "`"", , 16)
            }
        }


        ; static _WindowsFonts := ["Aharoni", "Aldhabi", "Andalus", "Angsana New", "AngsanaUPC", "Aparajita", "Arabic Typesetting", "Arial", "Arial Black", "Arial Nova", "Bahnschrift", "Batang", "BatangChe", "BIZ UDGothic", "BIZ UDMincho Medium", "BIZ UDPGothic", "Browallia New", "BrowalliaUPC", "Calibri", "Calibri Light", "Cambria", "Cambria Math", "Candara", "Cascadia Code", "Cascadia Mono", "Comic Sans MS", "Consolas", "Constantia", "Corbel", "Cordia New", "CordiaUPC", "Courier", "Courier New", "DaunPenh", "David", "DengXian", "DFKai-SB", "DilleniaUPC", "DokChampa", "Dotum", "DotumChe", "Ebrima", "Estrangelo Edessa", "EucrosiaUPC", "Euphemia", "FangSong", "Fixedsys", "Franklin Gothic Medium", "FrankRuehl", "FreesiaUPC", "Gabriola", "Gadugi", "Gautami", "Georgia", "Georgia Pro", "Gill Sans Nova", "Gisha", "Gulim", "GulimChe", "Gungsuh", "GungsuhChe", "HoloLens MDL2 Assets", "Impact", "Ink Free", "IrisUPC", "Iskoola Pota", "JasmineUPC", "Javanese Text", "KaiTi", "Kalinga", "Kartika", "Khmer UI", "KodchiangUPC", "Kokila", "Lao UI", "Latha", "Leelawadee", "Leelawadee UI", "Levenim MT", "LilyUPC", "Lucida Console", "Lucida Sans", "Lucida Sans Unicode", "Malgun Gothic", "Mangal", "Marlett", "Meiryo", "Meiryo UI", "Microsoft Himalaya", "Microsoft JhengHei", "Microsoft JhengHei UI", "Microsoft New Tai Lue", "Microsoft PhagsPa", "Microsoft Sans Serif", "Microsoft Tai Le", "Microsoft Uighur", "Microsoft YaHei", "Microsoft YaHei UI", "Microsoft Yi Baiti", "MingLiU", "MingLiU_HKSCS", "MingLiU_HKSCS-ExtB", "MingLiU-ExtB", "Miriam", "Miriam Fixed", "Modern", "Mongolian Baiti", "MoolBoran", "MS Gothic", "MS Mincho", "MS PGothic", "MS PMincho", "MS Serif", "MS Sans Serif", "MS UI Gothic", "MV Boli", "Myanmar Text", "Narkisim", "Neue Haas Grotesk Text Pro", "Nirmala UI", "NSimSun", "Nyala", "Palatino Linotype", "Plantagenet Cherokee", "PMingLiU", "PMingLiU-ExtB", "Raavi", "Rockwell Nova", "Rod", "Roman", "Sakkal Majalla", "Sanskrit Text", "Script", "Segoe Fluent Icons", "Segoe MDL2 Assets", "Segoe Print", "Segoe Script", "Segoe UI", "Segoe UI Emoji", "Segoe UI Historic", "Segoe UI Variable", "Segoe UI Symbol", "Shonar Bangla", "Shruti", "SimHei", "Simplified Arabic", "Simplified Arabic Fixed", "SimSun", "SimSun-ExtB", "Sitka Banner", "Sitka Display", "Sitka Heading", "Sitka Small", "Sitka Subheading", "Sitka Text", "Small Fonts", "Sylfaen", "Symbol", "System", "Tahoma", "Terminal", "Times New Roman", "Traditional Arabic", "Trebuchet MS", "Tunga", "UD Digi Kyokasho N-B", "UD Digi Kyokasho NK-B", "UD Digi Kyokasho NK-R", "UD Digi Kyokasho NP-B", "UD Digi Kyokasho NP-R", "UD Digi Kyokasho N-R", "Urdu Typesetting", "Utsaah", "Vani", "Verdana", "Verdana Pro", "Vijaya", "Vrinda", "Webdings", "Wingdings", "Yu Gothic", "Yu Gothic UI", "Yu Mincho"]


        /**
         * * Especifica los tamaños de fuente predeterminados y personalizables para diferentes elementos.
         * 
         * Información: El prefijo "_" denota valores predeterminados y privados.
         */
        static _FontSize := {
            Title: 60,
            _Title: 60,
            SubTitle: 50,
            _SubTitle: 50,
            Text: 15,
            _Text: 15,
        }

        /**
         * * Configuración del ancho máximo en caracteres para textos.
         * 
         * Información: El prefijo "_" denota valores predeterminados y privados.
         */
        static _MaxWidthInChars := {
            Title: 17,
            _Title: 17,
            SubTitle: 23,
            _SubTitle: 23,
            Text: 30,
            _Text: 30,
        }

        /**
         * * Configuración del tamaño máximo de los elementos en píxeles.
         * 
         * Información: El prefijo "_" denota valores predeterminados y privados.
         */
        static _ElementsSize := {
            Title: { Width: 300, Height: 40 },
            _Title: { Width: 300, Height: 40 },
            SubTitle: { Width: 300, Height: 30 },
            _SubTitle: { Width: 300, Height: 30 },
            Text: { Width: 300, Height: 80 },
            _Text: { Width: 300, Height: 80 },
        }


        _TimeOut := 0
        ; _bfDestroy := this.Destroy.Bind(this)


        ;;MARK:*
        ;^----------------Params Filter----------------^;

        _FilterParameters() {

            ;? Param: Theme

            ; Filtro:
            if !(RegExMatch(this._Theme, "^[A-Za-z]+$")) {
                throw ValueError(A_ThisFunc "Parameter #4 invalid: String Illegal", -1, this._Theme)
            }

            ;? Param: Pos (Position)

            ; for Key, Value in _GUIs_Properties.Pos.Init {

            ;     if (Value == _GUI_Properties__Pos_Init) {
            ;         GUI__Pos_Init := MapPos[Pos]
            ;         return GUI__Pos_Init
            ;     }


            ; }

            ; static GUI__Position

            ; Temp_GUI__Position := _GUI__Position_Filter()


            ; if (GUI__Position = Temp_GUI__Position) {
            ;     MsgBox("La posición: " "`"" Temp_GUI__Position "`""  " Esta ocupada")
            ;     return "Process Cancelled"
            ; } else {
            ;     GUI__Position := Temp_GUI__Position
            ; }

            ;? Param: TimeOut

        }


        ;;MARK:*
        ;^----------------GUI_Main----------------^;

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

            ;^ Create
            GUI_Main := Gui("+LastFound +AlwaysOnTop -Caption +ToolWindow").NeverFocusWindow()

            switch this._Theme, 0 {
                case "Dark": GUI_Main.DarkMode
                case "Light": GUI_Main.LightMode
            }


            ;? GuiControls:
            ElementsFontSize := {}

            if (this._Title != "") {
                this._Title := this._Title[1, MaxWidthInChars.Title]
                ElementsFontSize.Title := Min(Max((ElementsSize.Title.Width * ElementsSize.Title.Height * FontSize.Title) / (StrLen(this._Title) * MaxWidthInChars.Title * 100), 10), ElementsSize.Title.Height / 1.75)

                GUI_Main_Title := GUI_Main.Add("Text", "w" ElementsSize.Title.Width " h" ElementsSize.Title.Height " Center", this._Title)
                GUI_Main_Title.SetFont("w200 s" ElementsFontSize.Title, "Consolas")
                GUI_Main_Title.OnEvent("Click", _Destruction)
            }

            if (this._SubTitle != "") {
                this._SubTitle := this._SubTitle[1, MaxWidthInChars.SubTitle]
                ElementsFontSize.SubTitle := Min(Max((ElementsSize.SubTitle.Width * ElementsSize.SubTitle.Height * FontSize.SubTitle) / (StrLen(this._SubTitle) * MaxWidthInChars.SubTitle * 100), 10), ElementsSize.SubTitle.Height / 1.5)

                GUI_Main_SubTitle := GUI_Main.Add("Text", "w" ElementsSize.SubTitle.Width " h" ElementsSize.SubTitle.Height " Center", this._SubTitle)
                GUI_Main_SubTitle.SetFont("w100 s" ElementsFontSize.SubTitle, "Nyala")
                GUI_Main_SubTitle.OnEvent("Click", _Destruction)
            }

            if (this._Text != "") {
                MaxWidthInCharsTotal := 180
                this._Text := this._Text[1, MaxWidthInCharsTotal]
                Lines := Ceil(StrLen(this._Text) / MaxWidthInChars.Text)
                ElementsFontSize.Text := Min(Max((ElementsSize.Text.Width * ElementsSize.Text.Height * FontSize.Text) / (StrLen(this._Text) * MaxWidthInChars.Text * 100), 10), ElementsSize.Text.Height / (MaxWidthInCharsTotal / FontSize.Text) * 3)

                GUI_Main_Text := GUI_Main.Add("Text", "w" ElementsSize.Text.Width " h" ElementsSize.Text.Height " Center", _FormatText(this._Text))
                ; GUI_Main_Text.SetFont("w50 s" ElementsFontSize.Text, "Microsoft Yi Baiti")
                GUI_Main_Text.SetFont("w50 s" ElementsFontSize.Text, "NSimSun")
                GUI_Main_Text.OnEvent("Click", _Destruction)
            }


            ;? OnEvent:
            GUI_Main.OnEvent("Escape", _Destruction)


            ;? Show:
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
                    ; ToolTip("TransDegree: " TransDegree "`n" "WinGetTransparent(): " WinGetTransparent(GUI_Main.hwnd))
                    if !(TransDegree > 255)
                        TransDegree++
                    try WinSetTransparent(TransDegree, GUI_Main.hwnd)
                    Sleep 10
                }
                GUI_Main.Opt("-Disabled")
            }
            _SetupAutoclose()

            ; MsgBox(
            ;     "Width:`n"
            ;     " Title: " ElementsSize.Title.Width "`n"
            ;     " SubTitle: " ElementsSize.SubTitle.Width "`n"
            ;     " Text: " ElementsSize.Text.Width "`n"

            ;     "`nHeight:`n"
            ;     " Title: " ElementsSize.Title.Height "`n"
            ;     " SubTitle: " ElementsSize.SubTitle.Height "`n"
            ;     " Text: " ElementsSize.Text.Height "`n"

            ;     "`n`nFontSize:`n"
            ;     " Title: " CustomGUI.Set_PopUp._FontSize.Title "`n"
            ;     " SubTitle: " CustomGUI.Set_PopUp._FontSize.SubTitle "`n"
            ;     " Text: " CustomGUI.Set_PopUp._FontSize.Text "`n"

            ;     "`nNewSizeText:`n"
            ;     " Title: " ElementsFontSize.Title "`n"
            ;     " SubTitle: " ElementsFontSize.SubTitle "`n"
            ;     " Text: " ElementsFontSize.Text "`n"
            ; )


            ;? Funtions:

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
                            ; ToolTip("TransDegree: " TransDegree "`n" "WinGetTransparent(): " WinGetTransparent(GUI_Main.hwnd))
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