#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force
#Include Lib/LinkManagerEx.ahk

; Start the Link Manager
if A_ScriptFullPath = A_LineFile
    TestLinkManager()

TestLinkManager() {
    ; Create the link manager instance
    linkManager := LinkManagerEx()
    
    ; Setup a global hotkey to toggle the Link Manager
    Hotkey("^l", linkManager.Toggle.Bind(linkManager))
    
    ; Display instructions
    MsgBox("Link Manager is running!`n`nUse Ctrl+L to toggle the interface.`n`nSelect a link and press Enter to open it in Edge.", "Link Manager Test", "Icon i")
}

MonitorActiveWindow() {
  SetTimer(() 
  {
    hwnd := WinGetID("A")
    if (hwnd != this.gui.Hwnd)
        this.activeWinID := hwnd
  }, 1000)
}