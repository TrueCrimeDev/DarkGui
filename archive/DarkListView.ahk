#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force

class DarkListView {
    static HeaderCallbacks := Map()
    static NotifyCallbacks := Map()
    static ThemeChangedCallbacks := Map()
    static ListViews := Map()

    class RECT {
        left := 0
        top := 0
        right := 0
        bottom := 0
    }
    class NMHDR {
        hwndFrom := 0
        idFrom := 0
        code := 0
    }
    class NMCUSTOMDRAW {
        hdr := 0
        dwDrawStage := 0
        hdc := 0
        rc := 0
        dwItemSpec := 0
        uItemState := 0
        lItemlParam := 0
        __New() {
            this.hdr := DarkListView.NMHDR()
            this.rc := DarkListView.RECT()
        }
    }
    static StructFromPtr(StructClass, ptr) {
        obj := StructClass()
        if (StructClass.Prototype.__Class = "NMHDR") {
            obj.hwndFrom := NumGet(ptr, 0, "UPtr")
            obj.idFrom := NumGet(ptr, A_PtrSize, "UPtr")
            obj.code := NumGet(ptr, A_PtrSize * 2, "Int")
        }
        else if (StructClass.Prototype.__Class = "NMCUSTOMDRAW") {
            obj.hdr := DarkListView.NMHDR()
            obj.hdr.hwndFrom := NumGet(ptr, 0, "UPtr")
            obj.hdr.idFrom := NumGet(ptr, A_PtrSize, "UPtr")
            obj.hdr.code := NumGet(ptr, A_PtrSize * 2, "Int")
            obj.dwDrawStage := NumGet(ptr, A_PtrSize * 3, "UInt")
            obj.hdc := NumGet(ptr, A_PtrSize * 3 + 4, "UPtr")
            obj.rc := DarkListView.RECT()
            rectOffset := A_PtrSize * 3 + 4 + A_PtrSize
            obj.rc.left := NumGet(ptr, rectOffset, "Int")
            obj.rc.top := NumGet(ptr, rectOffset + 4, "Int")
            obj.rc.right := NumGet(ptr, rectOffset + 8, "Int")
            obj.rc.bottom := NumGet(ptr, rectOffset + 12, "Int")
            obj.dwItemSpec := NumGet(ptr, rectOffset + 16, "UPtr")
            obj.uItemState := NumGet(ptr, rectOffset + 16 + A_PtrSize, "UInt")
            obj.lItemlParam := NumGet(ptr, rectOffset + 16 + A_PtrSize + 4, "IPtr")
        }
        return obj
    }

    static NotifyHandler(wParam, lParam, msg, hwnd) {
        static NM_CUSTOMDRAW := -12
        static CDDS_PREPAINT := 0x1
        static CDDS_ITEMPREPAINT := 0x10001
        static CDRF_DODEFAULT := 0x0
        static CDRF_NOTIFYITEMDRAW := 0x20
        if !DarkListView.ListViews.Has(hwnd)
            return

        listView := DarkListView.ListViews[hwnd]
        if !lParam
            return
        try {
            nmCode := NumGet(lParam, 8, "Int")
            if (nmCode != NM_CUSTOMDRAW)
                return
            hwndFrom := NumGet(lParam, 0, "Ptr")
            if (hwndFrom != listView.Header)
                return
            drawStage := NumGet(lParam, 16, "UInt")

            if (drawStage = CDDS_PREPAINT)
                return CDRF_NOTIFYITEMDRAW

            if (drawStage = CDDS_ITEMPREPAINT) {

                hdc := NumGet(lParam, 20, "Ptr")

                DllCall("SetTextColor", "Ptr", hdc, "UInt", 0xFFFFFF)
            }

            return CDRF_DODEFAULT
        } catch Error as e {

            return CDRF_DODEFAULT
        }
    }

    static ThemeChangedHandler(wParam, lParam, msg, hwnd) {
        return 0
    }
    static SetWhiteText(listView) {
        static LVM_SETTEXTCOLOR := 0x1033
        static LVM_SETBKCOLOR := 0x1026
        static LVM_SETTEXTBKCOLOR := 0x1043
        static LVM_GETHEADER := 0x101F
        static LVS_EX_DOUBLEBUFFER := 0x10000
        static UIS_SET := 1
        static UISF_HIDEFOCUS := 0x1
        static WM_CHANGEUISTATE := 0x0127
        static WM_NOTIFY := 0x4E
        static WM_THEMECHANGED := 0x031A

        SendMessage(LVM_SETTEXTCOLOR, 0, 0xFFFFFF, listView.hWnd)
        SendMessage(LVM_SETBKCOLOR, 0, 0x1F1F1F, listView.hWnd)
        SendMessage(LVM_SETTEXTBKCOLOR, 0, 0x1F1F1F, listView.hWnd)
        DllCall("uxtheme\SetWindowTheme", "Ptr", listView.hWnd, "Str", "DarkMode_Explorer", "Ptr", 0)
        headerHwnd := SendMessage(LVM_GETHEADER, 0, 0, listView.hWnd)
        listView.DefineProp("Header", {Value: headerHwnd})
        DarkListView.ListViews[listView.Hwnd] := listView
        if !DarkListView.NotifyCallbacks.Has("registered") {
            OnMessage(WM_NOTIFY, DarkListView.NotifyHandler)
            OnMessage(WM_THEMECHANGED, DarkListView.ThemeChangedHandler)
            DarkListView.NotifyCallbacks["registered"] := true
        }
        listView.Opt("+LV" LVS_EX_DOUBLEBUFFER)
        SendMessage(WM_CHANGEUISTATE, (UIS_SET << 8) | UISF_HIDEFOCUS, 0, listView)
        DllCall("uxtheme\SetWindowTheme", "Ptr", headerHwnd, "Str", "DarkMode_ItemsView", "Ptr", 0)
        DllCall("InvalidateRect", "Ptr", headerHwnd, "Ptr", 0, "Int", true)
        DllCall("InvalidateRect", "Ptr", listView.hWnd, "Ptr", 0, "Int", true)

        return listView
    }
}