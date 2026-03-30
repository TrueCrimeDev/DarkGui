#Requires AutoHotkey v2.1-alpha.23
#SingleInstance Force
#Include ..\DarkModeModular.ahk

SpellCorrectApp()

class SpellEngine {
    __New(lang := "en-US") {
        clsid := Buffer(16)
        iid := Buffer(16)
        DllCall("ole32\CLSIDFromString", "Str", "{7AB36653-1796-484B-BDFA-E74F1DB7C1DC}", "Ptr", clsid, "HRESULT")
        DllCall("ole32\CLSIDFromString", "Str", "{8E018A9D-2415-4677-BF08-794EA61F94BB}", "Ptr", iid, "HRESULT")
        DllCall("ole32\CoCreateInstance", "Ptr", clsid, "Ptr", 0, "UInt", 1, "Ptr", iid, "Ptr*", &pFactory := 0, "HRESULT")
        this.factory := ComValue(13, pFactory)
        ComCall(5, this.factory, "WStr", lang, "Ptr*", &pChecker := 0)
        if !pChecker
            throw Error("Failed to create spell checker for: " lang)
        this.checker := ComValue(13, pChecker)
        this.checker2 := ""
        try {
            iid2 := Buffer(16)
            DllCall("ole32\CLSIDFromString", "Str", "{E7ED1C71-87F7-4571-A0D8-F955B271E5AE}", "Ptr", iid2, "HRESULT")
            ComCall(0, this.checker, "Ptr", iid2, "Ptr*", &pChecker2 := 0)
            if pChecker2
                this.checker2 := ComValue(13, pChecker2)
        }
    }

    Check(text) {
        errors := []
        ComCall(4, this.checker, "WStr", text, "Ptr*", &pEnum := 0)
        if !pEnum
            return errors
        enumObj := ComValue(13, pEnum)
        Loop {
            ComCall(3, enumObj, "Ptr*", &pErr := 0)
            if !pErr
                break
            errObj := ComValue(13, pErr)
            start := 0, len := 0, action := 0
            ComCall(3, errObj, "UInt*", &start)
            ComCall(4, errObj, "UInt*", &len)
            ComCall(5, errObj, "Int*", &action)
            replacement := ""
            if (action = 2) {
                ComCall(6, errObj, "Ptr*", &pStr := 0)
                if pStr {
                    replacement := StrGet(pStr, "UTF-16")
                    DllCall("ole32\CoTaskMemFree", "Ptr", pStr)
                }
            }
            errors.Push(Map(
                "word", SubStr(text, start + 1, len),
                "start", start,
                "length", len,
                "action", action,
                "replacement", replacement
            ))
        }
        return errors
    }

    Suggest(word, max := 10) {
        result := []
        ComCall(5, this.checker, "WStr", word, "Ptr*", &pEnum := 0)
        if !pEnum
            return result
        enumObj := ComValue(13, pEnum)
        Loop max {
            ComCall(3, enumObj, "UInt", 1, "Ptr*", &pStr := 0, "UInt*", &fetched := 0, "Int")
            if !fetched
                break
            result.Push(StrGet(pStr, "UTF-16"))
            DllCall("ole32\CoTaskMemFree", "Ptr", pStr)
        }
        return result
    }

    Add(word) => ComCall(6, this.checker, "WStr", word)
    Ignore(word) => ComCall(7, this.checker, "WStr", word)

    Remove(word) {
        if this.checker2 {
            try {
                ComCall(15, this.checker2, "WStr", word)
                return true
            }
        }
        return this._RemoveFromFile(word)
    }

    _RemoveFromFile(word) {
        basePath := A_AppData "\Microsoft\Spelling"
        for dicPath in [basePath "\neutral\default.dic", basePath "\en-US\default.dic", basePath "\en-CA\default.dic"] {
            if !FileExist(dicPath)
                continue
            try {
                content := FileRead(dicPath, "UTF-16")
                newContent := StrReplace(content, word "`r`n", "", true, &count)
                if count {
                    FileOpen(dicPath, "w", "UTF-16").Write(newContent)
                    return true
                }
            }
        }
        return false
    }
}

class SpellCorrectApp {
    __New() {
        this.engine := SpellEngine()
        this.gui := ""
        this.ctrl := Map()
        this.targetHwnd := 0
        this.text := ""
        this.errors := []
        this.currentError := Map()
        this._tipTimer := ""
        this.dictGui := ""
        this.dictCtrl := Map()
        this.dictWords := []
        A_IconTip := "Spell Checker (Ctrl+Shift+S)"
        Hotkey("^+s", this.OnHotkey.Bind(this))
        Hotkey("#!s", (*) => this.ShowDictManager())
        A_TrayMenu.Add()
        A_TrayMenu.Add("Dictionary Manager", (*) => this.ShowDictManager())
    }

    ShowTip(msg, duration := 1500) {
        if this._tipTimer
            SetTimer(this._tipTimer, 0)
        ToolTip(msg,,, 20)
        this._tipTimer := (*) => (ToolTip(,,, 20), this._tipTimer := "")
        SetTimer(this._tipTimer, -duration)
    }

    OnHotkey(*) {
        this.Dismiss()
        this.targetHwnd := WinGetID("A")
        saved := ClipboardAll()
        A_Clipboard := ""
        Send("^c")
        if !ClipWait(0.3) {
            A_Clipboard := saved
            return
        }
        this.text := Trim(A_Clipboard)
        A_Clipboard := saved
        if (this.text = "")
            return

        this.errors := this.engine.Check(this.text)
        if !this.errors.Length {
            this.ShowTip("Correct", 1200)
            return
        }

        if (!InStr(this.text, " ") && this.errors.Length = 1) {
            err := this.errors[1]
            if (err["replacement"] != "") {
                fixed := SubStr(this.text, 1, err["start"]) err["replacement"] SubStr(this.text, err["start"] + err["length"] + 1)
                this.ReplaceInTarget(fixed)
                this.ShowTip("-> " err["replacement"])
                return
            }
            suggestions := this.engine.Suggest(err["word"])
            if !suggestions.Length {
                this.ShowTip("No suggestions for: " err["word"])
                return
            }
            this.currentError := err
            this.ShowSinglePopup(err["word"], suggestions)
        } else {
            this.ShowErrorPanel()
        }
    }

    ShowSinglePopup(word, suggestions) {
        margin := 8, spacing := 6, winW := 260
        contentW := winW - margin * 2, btnH := 28
        currentY := margin

        this.gui := DarkGui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", "SpellCheck")
        this.gui.SetFont("s10", "Segoe UI")

        this.gui.Add("Text", Format("x{} y{} w{} h20 cFF6B6B", margin, currentY, contentW), "X  " word)
        currentY += 20 + spacing

        rows := Min(suggestions.Length, 8)
        listH := rows * 18 + 4
        this.ctrl["list"] := this.gui.Add("ListBox", Format("x{} y{} w{} h{} Choose1", margin, currentY, contentW, listH), suggestions)
        this.ctrl["list"].OnEvent("DoubleClick", this.OnApplySingle.Bind(this))
        currentY += listH + spacing

        gap := 4
        b1w := 90, b2w := 98, b3w := contentW - b1w - b2w - gap * 2
        applyBtn := this.gui.Add("Button", Format("+Default +Accent x{} y{} w{} h{}", margin, currentY, b1w, btnH), "Apply")
        applyBtn.OnEvent("Click", this.OnApplySingle.Bind(this))
        addBtn := this.gui.Add("Button", Format("x{} y{} w{} h{}", margin + b1w + gap, currentY, b2w, btnH), "Add to Dict")
        addBtn.OnEvent("Click", this.OnAddSingle.Bind(this))
        closeBtn := this.gui.Add("Button", Format("x{} y{} w{} h{}", margin + b1w + gap + b2w + gap, currentY, b3w, btnH), "X")
        closeBtn.OnEvent("Click", (*) => this.Dismiss())
        currentY += btnH + margin

        this.gui.OnEvent("Escape", (*) => this.Dismiss())
        this.gui.OnEvent("Close", (*) => this.Dismiss())

        px := 0, py := 0
        this.GetPopupPos(winW, currentY, &px, &py)
        this.gui.Show("x" px " y" py " w" winW " h" currentY)
        this.ctrl["list"].Focus()
    }

    ShowErrorPanel() {
        margin := 10, spacing := 8, winW := 420
        contentW := winW - margin * 2, btnH := 30
        currentY := margin

        this.gui := DarkGui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", "SpellCheck")
        this.gui.SetFont("s10", "Segoe UI")

        this.gui.Add("Text", Format("x{} y{} w{} h22 cFF6B6B", margin, currentY, contentW), this.errors.Length " errors found")
        currentY += 22 + spacing

        lvH := Min(this.errors.Length, 6) * 22 + 28
        this.ctrl["errorLV"] := this.gui.Add("ListView", Format("x{} y{} w{} h{} -Multi", margin, currentY, contentW, lvH), ["Word", "Suggestion"])
        for err in this.errors {
            sug := err["replacement"]
            if (sug = "") {
                sl := this.engine.Suggest(err["word"], 1)
                sug := sl.Length ? sl[1] : "--"
            }
            this.ctrl["errorLV"].Add("", err["word"], sug)
        }
        this.ctrl["errorLV"].ModifyCol(1, contentW // 2)
        this.ctrl["errorLV"].ModifyCol(2, contentW // 2)
        this.ctrl["errorLV"].Modify(1, "+Select +Focus")
        this.ctrl["errorLV"].OnEvent("ItemSelect", this.OnErrorSelect.Bind(this))
        currentY += lvH + spacing

        this.ctrl["sugLabel"] := this.gui.Add("Text", Format("x{} y{} w{} h20 cA0A0A0", margin, currentY, contentW), "Suggestions:")
        currentY += 20 + 4

        this.ctrl["sugList"] := this.gui.Add("ListBox", Format("x{} y{} w{} h90 Choose1", margin, currentY, contentW), [])
        this.ctrl["sugList"].OnEvent("DoubleClick", this.OnApplyFromPanel.Bind(this))
        currentY += 90 + spacing

        gap := 4, btnCount := 4
        btnW := (contentW - (btnCount - 1) * gap) // btnCount

        fixBtn := this.gui.Add("Button", Format("+Accent x{} y{} w{} h{}", margin, currentY, btnW, btnH), "Fix Selected")
        fixBtn.OnEvent("Click", this.OnApplyFromPanel.Bind(this))
        fixAllBtn := this.gui.Add("Button", Format("x{} y{} w{} h{}", margin + btnW + gap, currentY, btnW, btnH), "Fix All")
        fixAllBtn.OnEvent("Click", this.OnFixAll.Bind(this))
        addBtn := this.gui.Add("Button", Format("x{} y{} w{} h{}", margin + (btnW + gap) * 2, currentY, btnW, btnH), "Add to Dict")
        addBtn.OnEvent("Click", this.OnAddFromPanel.Bind(this))
        closeBtn := this.gui.Add("Button", Format("x{} y{} w{} h{}", margin + (btnW + gap) * 3, currentY, btnW, btnH), "Close")
        closeBtn.OnEvent("Click", (*) => this.Dismiss())
        currentY += btnH + margin

        this.gui.OnEvent("Escape", (*) => this.Dismiss())
        this.gui.OnEvent("Close", (*) => this.Dismiss())

        this.LoadSuggestions(1)

        px := 0, py := 0
        this.GetPopupPos(winW, currentY, &px, &py)
        this.gui.Show("x" px " y" py " w" winW " h" currentY)
    }

    OnErrorSelect(lv, item, selected) {
        if !selected || !item
            return
        this.LoadSuggestions(item)
    }

    LoadSuggestions(index) {
        if (index < 1 || index > this.errors.Length)
            return
        word := this.errors[index]["word"]
        this.ctrl["sugLabel"].Text := "Suggestions for '" word "':"
        suggestions := this.engine.Suggest(word)
        this.ctrl["sugList"].Delete()
        this.ctrl["sugList"].Add(suggestions)
        if suggestions.Length
            this.ctrl["sugList"].Choose(1)
    }

    OnApplySingle(*) {
        lb := this.ctrl["list"]
        if !lb.Value
            return
        selected := lb.Text
        err := this.currentError
        fixed := SubStr(this.text, 1, err["start"]) selected SubStr(this.text, err["start"] + err["length"] + 1)
        this.Dismiss()
        this.ReplaceInTarget(fixed)
    }

    OnApplyFromPanel(*) {
        lv := this.ctrl["errorLV"]
        row := lv.GetNext(0, "Focused")
        if !row
            return
        lb := this.ctrl["sugList"]
        if !lb.Value
            return
        replacement := lb.Text
        err := this.errors[row]
        this.text := SubStr(this.text, 1, err["start"]) replacement SubStr(this.text, err["start"] + err["length"] + 1)
        delta := StrLen(replacement) - err["length"]
        i := row + 1
        while (i <= this.errors.Length) {
            this.errors[i]["start"] += delta
            i++
        }
        this.errors.RemoveAt(row)
        lv.Delete(row)
        if !this.errors.Length {
            this.Dismiss()
            this.ReplaceInTarget(this.text)
            this.ShowTip("All fixed")
        } else {
            next := Min(row, this.errors.Length)
            lv.Modify(next, "+Select +Focus")
            this.LoadSuggestions(next)
        }
    }

    OnFixAll(*) {
        fixed := this.text
        i := this.errors.Length
        while (i >= 1) {
            err := this.errors[i]
            sug := err["replacement"]
            if (sug = "") {
                sl := this.engine.Suggest(err["word"], 1)
                sug := sl.Length ? sl[1] : ""
            }
            if (sug != "")
                fixed := SubStr(fixed, 1, err["start"]) sug SubStr(fixed, err["start"] + err["length"] + 1)
            i--
        }
        count := this.errors.Length
        this.Dismiss()
        this.ReplaceInTarget(fixed)
        this.ShowTip("Fixed " count " errors")
    }

    OnAddSingle(*) {
        word := this.currentError["word"]
        this.engine.Add(word)
        this.Dismiss()
        this.ShowTip("Added: " word)
    }

    OnAddFromPanel(*) {
        lv := this.ctrl["errorLV"]
        row := lv.GetNext(0, "Focused")
        if !row
            return
        word := this.errors[row]["word"]
        this.engine.Add(word)
        this.errors.RemoveAt(row)
        lv.Delete(row)
        this.ShowTip("Added: " word)
        if !this.errors.Length
            this.Dismiss()
        else {
            next := Min(row, this.errors.Length)
            lv.Modify(next, "+Select +Focus")
            this.LoadSuggestions(next)
        }
    }

    GetPopupPos(pw, ph, &x, &y) {
        CoordMode("Caret", "Screen")
        if CaretGetPos(&cx, &cy)
            x := cx, y := cy + 25
        else {
            CoordMode("Mouse", "Screen")
            MouseGetPos(&mx, &my)
            x := mx, y := my + 20
        }
        sw := SysGet(0), sh := SysGet(1)
        if (x + pw > sw)
            x := sw - pw - 10
        if (y + ph > sh)
            y := Max(0, y - ph - 50)
        if (x < 0)
            x := 10
    }

    ReplaceInTarget(text) {
        saved := ClipboardAll()
        A_Clipboard := text
        if !ClipWait(1) {
            A_Clipboard := saved
            return
        }
        if WinExist("ahk_id " this.targetHwnd) {
            WinActivate("ahk_id " this.targetHwnd)
            WinWaitActive("ahk_id " this.targetHwnd,, 0.5)
        }
        Send("^v")
        SetTimer((*) => (A_Clipboard := saved), -150)
    }

    Dismiss(*) {
        if this.gui {
            this.gui.Destroy()
            this.gui := ""
            this.ctrl := Map()
        }
    }

    ShowDictManager() {
        if this.dictGui {
            try WinActivate(this.dictGui)
            return
        }
        this.dictWords := this.ReadDictWords()
        this.dictCtrl := Map()

        margin := 10, spacing := 8, winW := 340
        contentW := winW - margin * 2, btnH := 30, editH := 26
        currentY := margin

        this.dictGui := DarkGui("+AlwaysOnTop -DPIScale", "Dictionary Manager")
        this.dictGui.SetFont("s10", "Segoe UI")

        this.dictCtrl["filter"] := this.dictGui.Add("Edit", Format("x{} y{} w{} h{}", margin, currentY, contentW, editH))
        SendMessage(0x1501, 1, StrPtr("Filter..."), this.dictCtrl["filter"])
        this.dictCtrl["filter"].OnEvent("Change", this.OnDictFilter.Bind(this))
        currentY += editH + spacing

        lvH := 300
        this.dictCtrl["lv"] := this.dictGui.Add("ListView", Format("x{} y{} w{} h{} -Multi Sort", margin, currentY, contentW, lvH), ["Word"])
        this.dictCtrl["lv"].ModifyCol(1, contentW - 4)
        this.PopulateDictList()
        currentY += lvH + spacing

        this.dictCtrl["status"] := this.dictGui.Add("Text", Format("x{} y{} w{} h18 cA0A0A0", margin, currentY, contentW), this.dictWords.Length . " words")
        currentY += 18 + spacing

        addBtnW := 60
        editW := contentW - addBtnW - 4
        this.dictCtrl["newWord"] := this.dictGui.Add("Edit", Format("x{} y{} w{} h{}", margin, currentY, editW, btnH))
        SendMessage(0x1501, 1, StrPtr("Add word..."), this.dictCtrl["newWord"])
        addBtn := this.dictGui.Add("Button", Format("+Accent x{} y{} w{} h{}", margin + editW + 4, currentY, addBtnW, btnH), "Add")
        addBtn.OnEvent("Click", this.OnDictAdd.Bind(this))
        currentY += btnH + spacing

        removeBtn := this.dictGui.Add("Button", Format("x{} y{} w{} h{}", margin, currentY, contentW, btnH), "Remove Selected")
        removeBtn.OnEvent("Click", this.OnDictRemove.Bind(this))
        currentY += btnH + margin

        this.dictGui.OnEvent("Escape", (*) => this.DismissDict())
        this.dictGui.OnEvent("Close", (*) => this.DismissDict())
        this.dictGui.Show("w" winW " h" currentY)
    }

    ReadDictWords() {
        seen := Map()
        words := []
        basePath := A_AppData "\Microsoft\Spelling"
        for dicPath in [basePath "\neutral\default.dic", basePath "\en-US\default.dic", basePath "\en-CA\default.dic"] {
            if !FileExist(dicPath)
                continue
            try {
                content := FileRead(dicPath, "UTF-16")
                for line in StrSplit(content, "`n") {
                    word := Trim(line, " `t`r`n")
                    if (word != "" && SubStr(word, 1, 1) != "#" && !seen.Has(word)) {
                        seen[word] := true
                        words.Push(word)
                    }
                }
            }
        }
        return words
    }

    PopulateDictList(filter := "") {
        lv := this.dictCtrl["lv"]
        lv.Delete()
        count := 0
        for word in this.dictWords {
            if (filter != "" && !InStr(word, filter))
                continue
            lv.Add("", word)
            count++
        }
        txt := count . " words"
        if (filter != "")
            txt .= " (filtered)"
        this.dictCtrl["status"].Text := txt
    }

    OnDictFilter(ctrl, *) {
        this.PopulateDictList(ctrl.Value)
    }

    OnDictAdd(*) {
        word := Trim(this.dictCtrl["newWord"].Value)
        if (word = "")
            return
        this.engine.Add(word)
        this.dictWords.Push(word)
        this.dictCtrl["newWord"].Value := ""
        this.PopulateDictList(this.dictCtrl["filter"].Value)
        this.ShowTip("Added: " word)
    }

    OnDictRemove(*) {
        lv := this.dictCtrl["lv"]
        row := lv.GetNext(0, "Focused")
        if !row
            return
        word := lv.GetText(row, 1)
        if !this.engine.Remove(word) {
            this.ShowTip("Could not remove: " word)
            return
        }
        for i, w in this.dictWords {
            if (w = word) {
                this.dictWords.RemoveAt(i)
                break
            }
        }
        this.PopulateDictList(this.dictCtrl["filter"].Value)
        this.ShowTip("Removed: " word)
    }

    DismissDict(*) {
        if this.dictGui {
            this.dictGui.Destroy()
            this.dictGui := ""
            this.dictCtrl := Map()
        }
    }
}
