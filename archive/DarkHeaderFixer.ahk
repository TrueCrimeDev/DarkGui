#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force
#Include ../ClautoHotkey/_Dark.ahk

; This test GUI uses a custom approach to explicitly set header colors
MakeTestGui()

MakeTestGui() {
    ; Create our test GUI
    testGui := Gui("+Resize", "Dark Mode ListView Header Test")
    
    ; Apply the Dark theme
    darkMode := _Dark(testGui)
    
    ; Add title text
    darkMode.AddDarkText("w400", "Testing ListView with WHITE header text")
    
    ; Add the ListView with several columns
    lv := darkMode.AddListView("r10 w400 h200", ["Column 1", "Column 2", "Column 3"])
    
    ; Add sample data
    Loop 5 {
        lv.Add(, "Item " A_Index, "Data " Chr(64 + A_Index), "Example " A_Index)
    }
    
    ; Get the header control handle
    hHeader := SendMessage(0x101F, 0, 0, lv.Hwnd)
    
    ; Apply custom header subclass
    global HeaderProc := CallbackCreate(HeaderCustomDraw, "Fast")
    originalHeaderProc := DllCall("SetWindowLongPtr", "Ptr", hHeader, "Int", -4, "Ptr", HeaderProc, "Ptr")
    
    ; Store the original procedure pointer for reference
    global OriginalHeaderProc := originalHeaderProc
    
    ; Add close button
    closeBtn := darkMode.AddDarkButton("w100 h30 xm y+20", "Close")
    closeBtn.OnEvent("Click", (*) => testGui.Destroy())
    
    ; Show the GUI
    testGui.Show()
}

; Custom window procedure for header control to force white text
HeaderCustomDraw(hwnd, msg, wParam, lParam) {
    static WM_NOTIFY := 0x004E
    static NM_CUSTOMDRAW := -12
    static CDDS_PREPAINT := 0x00000001
    static CDDS_ITEMPREPAINT := 0x00010001
    static CDRF_DODEFAULT := 0x0
    static CDRF_NOTIFYITEMDRAW := 0x00000020
    
    if (msg = WM_NOTIFY) {
        ; Check if notification code is NM_CUSTOMDRAW
        if (NumGet(lParam, A_PtrSize * 2, "Int") = NM_CUSTOMDRAW) {
            ; Get drawing stage
            dwDrawStage := NumGet(lParam, A_PtrSize * 3, "UInt")
            
            if (dwDrawStage = CDDS_PREPAINT)
                return CDRF_NOTIFYITEMDRAW
                
            if (dwDrawStage = CDDS_ITEMPREPAINT) {
                ; Get device context for drawing
                hdc := NumGet(lParam, A_PtrSize * 3 + 4, "UPtr")
                
                ; Force WHITE text
                DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt", 0xFFFFFF)
                DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int", 1)
                
                return CDRF_DODEFAULT
            }
        }
    }
    
    ; Call original procedure for other messages
    return DllCall("CallWindowProc", "Ptr", OriginalHeaderProc, "Ptr", hwnd, "UInt", msg, "Ptr", wParam, "Ptr", lParam, "Ptr")
}
