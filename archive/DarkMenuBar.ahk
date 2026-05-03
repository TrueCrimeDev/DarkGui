#Requires AutoHotkey v2.1-alpha.16

class DarkMenuBar {
    __New(parentGui, options) {
        this.gui := parentGui
        this.menuItems := []
        this.toolbarBtns := []
        this.hoveredMenu := ""
        
        this.layout := Map(
            "menuBarHeight", options.Has("menuBarHeight") ? options["menuBarHeight"] : 24,
            "toolbarHeight", options.Has("toolbarHeight") ? options["toolbarHeight"] : 32,
            "menuItemPadding", options.Has("menuItemPadding") ? options["menuItemPadding"] : 12,
            "menuFontSize", options.Has("menuFontSize") ? options["menuFontSize"] : 9,
            "toolbarIconSize", options.Has("toolbarIconSize") ? options["toolbarIconSize"] : 20,
            "toolbarButtonSpacing", options.Has("toolbarButtonSpacing") ? options["toolbarButtonSpacing"] : 4,
            "toolbarSeparatorWidth", options.Has("toolbarSeparatorWidth") ? options["toolbarSeparatorWidth"] : 1,
            "showToolbar", options.Has("showToolbar") ? options["showToolbar"] : true,
            "popupOffsetX", options.Has("popupOffsetX") ? options["popupOffsetX"] : 0,
            "popupOffsetY", options.Has("popupOffsetY") ? options["popupOffsetY"] : 0
        )
        
        this.colors := Map(
            "menuBarBg", options.Has("menuBarBg") ? options["menuBarBg"] : 0x2B2B2B,
            "menuBarText", options.Has("menuBarText") ? options["menuBarText"] : 0xFFFFFF,
            "menuBarHover", options.Has("menuBarHover") ? options["menuBarHover"] : 0x404040,
            "menuBarActive", options.Has("menuBarActive") ? options["menuBarActive"] : 0x0078D4,
            "popupBg", options.Has("popupBg") ? options["popupBg"] : 0x2B2B2B,
            "toolbarBg", options.Has("toolbarBg") ? options["toolbarBg"] : 0x2D2D2D,
            "toolbarBorder", options.Has("toolbarBorder") ? options["toolbarBorder"] : 0x3E3E42
        )
        
        this.totalHeight := this.layout["showToolbar"] ? 
            (this.layout["menuBarHeight"] + this.layout["toolbarHeight"] + 1) : 
            this.layout["menuBarHeight"]
        
        this.EnableDarkModeAPIs()
        this.CreateMenuBar()
        if this.layout["showToolbar"] {
            this.CreateToolbar()
        }
        
        OnMessage(0x200, this.OnMouseMove.Bind(this))
    }
    
    CreateMenuBar() {
        this.menuBar := this.gui.AddText("x0 y0 w800 h" . this.layout["menuBarHeight"] . " Background" . Format("{:06X}", this.colors["menuBarBg"]))
        
        this.popupMenus := Map()
        this.menuStructure := Map()
        
        x := 8
        this.menuBarStartX := x
    }
    
    AddMenu(menuName, menuItems) {
        hPopup := DllCall("CreatePopupMenu", "Ptr")
        
        for item in menuItems {
            if item.Has("separator") && item["separator"] {
                DllCall("AppendMenu", "Ptr", hPopup, "UInt", 0x0800, "Ptr", 0, "Ptr", 0)
            } else {
                itemText := item["text"]
                if item.Has("shortcut") {
                    itemText .= "`t" . item["shortcut"]
                }
                itemId := item.Has("id") ? item["id"] : 0
                DllCall("AppendMenu", "Ptr", hPopup, "UInt", 0x0000, "Ptr", itemId, "Str", itemText)
            }
        }
        
        this.ApplyDarkThemeToPopup(hPopup)
        
        itemWidth := StrLen(menuName) * 7 + this.layout["menuItemPadding"]

        ; Center label vertically in menu bar using SS_CENTERIMAGE (0x200)
        menuLabel := this.gui.AddText("x" . this.menuBarStartX . " y0 w" . itemWidth . " h" . this.layout["menuBarHeight"] . " +0x200 Center BackgroundTrans c" . Format("{:06X}", this.colors["menuBarText"]), menuName)
        menuLabel.SetFont("s" . this.layout["menuFontSize"], "Segoe UI")
        
        hitArea := this.gui.AddText("x" . this.menuBarStartX . " y0 w" . itemWidth . " h" . this.layout["menuBarHeight"] . " BackgroundTrans")
        hitArea.OnEvent("Click", this.ShowPopupMenu.Bind(this, hPopup, this.menuBarStartX))
        
        menuItemData := Map(
            "name", menuName,
            "label", menuLabel,
            "hitArea", hitArea,
            "popup", hPopup,
            "x", this.menuBarStartX,
            "width", itemWidth
        )
        
        this.menuItems.Push(menuItemData)
        this.popupMenus[menuName] := hPopup
        this.menuStructure[menuName] := menuItems
        
        this.menuBarStartX += itemWidth + 4
        
        return hPopup
    }
    
    CreateToolbar() {
        toolbarY := this.layout["menuBarHeight"]
        
        this.toolbar := this.gui.AddText("x0 y" . toolbarY . " w800 h" . this.layout["toolbarHeight"] . " Background" . Format("{:06X}", this.colors["toolbarBg"]))
        this.toolbarBorder := this.gui.AddText("x0 y" . (toolbarY + this.layout["toolbarHeight"]) . " w800 h1 Background" . Format("{:06X}", this.colors["toolbarBorder"]))
        
        this.toolbarStartX := 6
        this.toolbarY := toolbarY + Integer((this.layout["toolbarHeight"] - this.layout["toolbarIconSize"]) / 2)
    }
    
    AddToolbarButton(icon, tooltip, callback) {
        btnX := this.toolbarStartX
        btnY := this.toolbarY
        btnSize := this.layout["toolbarIconSize"]
        
        btnBg := this.gui.AddText("x" . btnX . " y" . btnY . " w" . btnSize . " h" . btnSize . " BackgroundTrans")
        btnIcon := this.gui.AddText("x" . btnX . " y" . btnY . " w" . btnSize . " h" . btnSize . " Center BackgroundTrans c" . Format("{:06X}", this.colors["menuBarText"]), icon)
        btnIcon.SetFont("s10")
        
        btnHit := this.gui.AddText("x" . btnX . " y" . btnY . " w" . btnSize . " h" . btnSize . " BackgroundTrans")
        btnHit.OnEvent("Click", (*) => callback())
        btnHit.ToolTip := tooltip
        
        btnData := Map(
            "bg", btnBg,
            "icon", btnIcon,
            "hit", btnHit,
            "x", btnX,
            "y", btnY,
            "tooltip", tooltip
        )
        
        this.toolbarBtns.Push(btnData)
        
        this.toolbarStartX += btnSize + this.layout["toolbarButtonSpacing"]
    }
    
    AddToolbarSeparator() {
        btnX := this.toolbarStartX
        btnY := this.toolbarY
        btnSize := this.layout["toolbarIconSize"]
        
        this.gui.AddText("x" . btnX . " y" . (btnY + 1) . " w" . this.layout["toolbarSeparatorWidth"] . " h" . (btnSize - 2) . " Background" . Format("{:06X}", this.colors["toolbarBorder"]))
        this.toolbarStartX += 6
    }
    
    ShowPopupMenu(hPopup, x, *) {
        ; Find the menu item and get its hitArea control for precise positioning
        popupX := 0
        popupY := 0

        for item in this.menuItems {
            if item["popup"] = hPopup {
                ; Get the actual screen rect of the hitArea control
                ctrlRect := Buffer(16, 0)
                DllCall("GetWindowRect", "Ptr", item["hitArea"].Hwnd, "Ptr", ctrlRect)

                ; Use bottom-left corner of the hitArea (left edge, bottom edge)
                popupX := NumGet(ctrlRect, 0, "Int")   ; Left
                popupY := NumGet(ctrlRect, 12, "Int")  ; Bottom

                ; Highlight the menu item
                item["label"].Opt("Background" . Format("{:06X}", this.colors["menuBarActive"]))
                labelRef := item["label"]
                SetTimer(() => labelRef.Opt("BackgroundTrans"), -200)
                break
            }
        }

        ; Apply any fine-tuning offsets
        popupX += this.layout["popupOffsetX"]
        popupY += this.layout["popupOffsetY"]

        DllCall("TrackPopupMenu", "Ptr", hPopup, "UInt", 0x0000, "Int", popupX, "Int", popupY, "Int", 0, "Ptr", this.gui.Hwnd, "Ptr", 0)
    }
    
    OnMouseMove(wParam, lParam, msg, hwnd) {
        if hwnd != this.gui.Hwnd
            return
        
        x := lParam & 0xFFFF
        y := (lParam >> 16) & 0xFFFF
        
        if this.layout["showToolbar"] && y > this.layout["menuBarHeight"] && y <= (this.layout["menuBarHeight"] + this.layout["toolbarHeight"]) {
            this.HandleToolbarHover(x, y)
            return
        }
        
        if y > this.layout["menuBarHeight"] {
            if this.hoveredMenu != "" {
                this.ClearHover()
            }
            return
        }
        
        hoveredItem := ""
        for item in this.menuItems {
            if x >= item["x"] && x <= item["x"] + item["width"] {
                hoveredItem := item["name"]
                break
            }
        }
        
        if hoveredItem != this.hoveredMenu {
            this.ClearHover()
            if hoveredItem != "" {
                for item in this.menuItems {
                    if item["name"] = hoveredItem {
                        item["label"].Opt("Background" . Format("{:06X}", this.colors["menuBarHover"]))
                        this.hoveredMenu := hoveredItem
                        break
                    }
                }
            }
        }
    }
    
    HandleToolbarHover(x, y) {
        static lastHovered := ""
        
        hoveredBtn := ""
        for btn in this.toolbarBtns {
            btnSize := this.layout["toolbarIconSize"]
            if x >= btn["x"] && x <= btn["x"] + btnSize && y >= btn["y"] && y <= btn["y"] + btnSize {
                hoveredBtn := btn
                break
            }
        }
        
        if hoveredBtn != lastHovered {
            for btn in this.toolbarBtns {
                btn["bg"].Opt("BackgroundTrans")
            }
            
            if hoveredBtn != "" {
                hoveredBtn["bg"].Opt("Background" . Format("{:06X}", this.colors["menuBarHover"]))
            }
            
            lastHovered := hoveredBtn
        }
    }
    
    ClearHover() {
        for item in this.menuItems {
            item["label"].Opt("BackgroundTrans")
        }
        this.hoveredMenu := ""
    }
    
    ApplyDarkThemeToPopup(hPopup) {
        darkBrush := DllCall("CreateSolidBrush", "UInt", this.SwapRGB(this.colors["popupBg"]), "Ptr")
        
        mi := Buffer(28, 0)
        NumPut("UInt", mi.Size, mi, 0)
        NumPut("UInt", 0x10, mi, 4)
        NumPut("Ptr", darkBrush, mi, 16)
        DllCall("SetMenuInfo", "Ptr", hPopup, "Ptr", mi)
    }
    
    SwapRGB(color) {
        return ((color & 0xFF) << 16) | (color & 0xFF00) | ((color & 0xFF0000) >> 16)
    }
    
    EnableDarkModeAPIs() {
        try {
            uxtheme := DllCall("GetModuleHandle", "Str", "uxtheme", "Ptr")
            if !uxtheme
                uxtheme := DllCall("LoadLibrary", "Str", "uxtheme", "Ptr")
            
            if uxtheme {
                SetPreferredAppMode := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
                AllowDarkModeForWindow := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 133, "Ptr")
                FlushMenuThemes := DllCall("GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")
                
                if SetPreferredAppMode && AllowDarkModeForWindow && FlushMenuThemes {
                    DllCall(SetPreferredAppMode, "Int", 1)
                    DllCall(AllowDarkModeForWindow, "Ptr", this.gui.Hwnd, "Int", 1)
                    DllCall(FlushMenuThemes)
                }
            }
        }
    }
    
    SetDarkWindowFrame() {
        if VerCompare(A_OSVersion, "10.0.17763") >= 0 {
            attr := VerCompare(A_OSVersion, "10.0.18985") >= 0 ? 20 : 19
            DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", this.gui.Hwnd, "Int", attr, "Int*", 1, "Int", 4)
        }
    }
    
    GetContentY() {
        return this.totalHeight
    }
}
