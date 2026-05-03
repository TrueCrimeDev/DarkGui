#Requires Autohotkey v2.1-alpha.8
#SingleInstance Force
#include <All> 

SendMode "Input"

Padding     := 10
Height      := 500
Width       := 300
EH          := 50
EW          := 280
XP          := 10
YP          := 10
C2          := 90 + Padding * 2
B1w         := 150
B2w         := 90
RW          := 280
RH          := 30
Option      := " Background303030 0x200 Center"
Bg 			:= " Background303030" 

~Numlock::
{
    static g := Pop("POP UP EDITOR")
    KeyWait("NumLock")
    CoordMode("Mouse")
    MouseGetPos(&xm, &ym)
    if GetKeyState("Numlock", "T")
        g.Show("NoActivate w" Width " h" 290 " x" (xm + 150) " y" (ym - 200))
    else if WinExist(g)
        g.Hide()
}

Pop(TreeText)
{    
	R1 := 10
	R2 := 70
	R3 := 120
    g := Gui("+AlwaysOnTop -Caption +ToolWindow 0x200 +0x1", "POP UP EDITOR")
	g.BackColor := "0x2B2B2B"
	g.Opt("+AlwaysOnTop -Caption +ToolWindow 0x200 +0x1")
	g.SetFont("s12  Ce5e5e5", "Segue UI")
    g.AddText("x" YP " y" R1 " w" RW " h" 40 Option, TreeText)
	g.SetFont("s9 Ce5e5e5", "Segue UI")
    g.AddEdit("x" XP " y" 60 " w" EW " h" 80 " -E0x200 vscroll" Bg).Value := A_Clipboard
    g.AddEdit("x" XP " y" 150 " w" EW " h" 80 " -E0x200 vscroll" Bg)
	g.SetFont("s11 Ce5e5e5", "Segue UI")
	g.AddText(Option " x10  y240 w" (EW/2)-5 " h" 40, "Cancel").OnEvent("Click", Escaper)
    g.AddText(Option " x155 y240  w" (EW/2)-5 " h" 40, "Apply").OnEvent("Click", Options)
    g.OnEvent "Escape", (*) => g.Hide()
    return g
}

Options(KeyStroke, *)
{
    KeyStroke.Gui.Hide()
    Send KeyStroke.text
	MsgBox(KeyStroke.text)
}

Escaper(KeyStroke, *)
{
    Send '{Esc}'
}

; GetClipboard(*)
; {
; 	DefaultText := A_Clipboard
; }

; g.AddButton("x" XP " y" 240 " w" (EW/2)-10 " h" 50 " -E0x200 -vscroll" Bg)
; g.AddButton("x" XP+150 " y" 240 " w" (EW/2)-10 " h" 50 " -E0x200 -vscroll" Bg)

; DarkMode(guiObj) {
; 	guiObj.BackColor := "171717"
; 	return guiObj
; }
; Gui.Prototype.DefineProp("DarkMode", {Call: DarkMode})

; MakeFontNicer(guiObj, fontSize := 20) {
; 	guiObj.SetFont("s" fontSize " cC5C5C5", "Consolas")
; 	return guiObj
; }
; Gui.Prototype.DefineProp("MakeFontNicer", {Call: MakeFontNicer})

; PressTitleBar(guiObj) {
; 	PostMessage(0xA1, 2,,, guiObj)
; 	return guiObj
; }
; Gui.Prototype.DefineProp("PressTitleBar", {Call: PressTitleBar})

; NeverFocusWindow(guiObj) {
; 	WinSetExStyle("0x08000000L", guiObj)
; 	return guiObj
; }
; Gui.Prototype.DefineProp("NeverFocusWindow", {Call: NeverFocusWindow})

; MakeClickthrough(guiObj) {
; 	WinSetTransparent(255, guiObj)
; 	guiObj.Opt("+E0x20")
; 	return guiObj
; }
; Gui.Prototype.DefineProp("MakeClickthrough", {Call: MakeClickthrough})