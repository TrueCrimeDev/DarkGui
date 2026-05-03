#requires AutoHotkey v2.1-alpha.12

class MARGINS {
    cxLeftWidth   : i32
    cxRightWidth  : i32
    cyTopHeight   : i32
    cyBottomHeight: i32
}

DWMWA_SYSTEMBACKDROP_TYPE := 38
DWMSBT_TABBEDWINDOW       := 4

DllCall("dwmapi\DwmExtendFrameIntoClientArea", "ptr", myGui.hwnd, MARGINS, {
    cxLeftWidth: 1000, cxRightWidth  : 1000, 
    cyTopHeight: 500 , cyBottomHeight: 500
})
myGui.SetWindowAttribute(DWMWA_SYSTEMBACKDROP_TYPE, DWMSBT_TABBEDWINDOW)