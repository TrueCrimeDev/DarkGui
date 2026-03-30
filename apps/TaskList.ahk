#Requires AutoHotkey v2.1-alpha.23
#SingleInstance Force
#Include ..\DarkModeModular.ahk
#Include ..\Layout.ahk

TaskListApp()

class TaskListApp {
    controls := Map()
    dataFile := A_ScriptDir "\tasks.json"
    tasks := []
    static winW := 500
    static winH := 450
    static margin := 12
    static gap := 8

    __New() {
        this.LoadTasks()
        this.gui := DarkGui("+Resize +MinSize400x300", "Task List")
        this.gui.SetFont("s10", "Segoe UI")
        this.BuildLayout()
        this.BindEvents()
        this.RefreshList()
        this.gui.Show("w" TaskListApp.winW " h" TaskListApp.winH)
    }

    BuildLayout() {
        g := this.gui
        m := TaskListApp.margin
        lay := Layout(TaskListApp.winW, m, TaskListApp.gap)

        g.Add("Text", lay.Section(), "TASKS")

        sp := lay.Split(TaskListApp.winW - m * 2 - 90 - TaskListApp.gap, 28)
        this.controls["input"] := g.Add("Edit", sp[1])
        SendMessage(0x1501, 1, StrPtr("Add a new task..."), this.controls["input"])
        this.controls["addBtn"] := g.Add("Button", "+Accent " sp[2], "Add")
        lay.Advance(28)

        this.controls["lv"] := g.Add("ListView", lay.Row(310, "+Grid -Multi Checked"), ["Task", "Created"])
        this.controls["lv"].ModifyCol(1, 330)
        this.controls["lv"].ModifyCol(2, 120)

        cols := lay.Columns(3, 32)
        this.controls["deleteBtn"] := g.Add("Button", cols[1], "Delete")
        this.controls["clearBtn"] := g.Add("Button", cols[2], "Clear Done")
        this.controls["status"] := g.Add("Text", cols[3] " cA0A0A0 Right +0x200", "0/0 done")
    }

    BindEvents() {
        this.controls["addBtn"].OnEvent("Click", this.OnAdd.Bind(this))
        this.controls["deleteBtn"].OnEvent("Click", this.OnDelete.Bind(this))
        this.controls["clearBtn"].OnEvent("Click", this.OnClearDone.Bind(this))
        this.controls["lv"].OnEvent("ItemCheck", this.OnCheck.Bind(this))

        this.gui.OnEvent("Size", this.OnSize.Bind(this))
        this.gui.OnEvent("Close", (*) => ExitApp())

        HotIfWinActive("ahk_id " this.gui.Hwnd)
        Hotkey("Enter", (*) => this.OnAdd())
    }

    OnAdd(*) {
        text := Trim(this.controls["input"].Value)
        if (text = "")
            return
        this.tasks.Push(Map(
            "text", text,
            "done", false,
            "created", FormatTime(, "yyyy-MM-dd HH:mm")
        ))
        this.controls["input"].Value := ""
        this.controls["input"].Focus()
        this.SaveTasks()
        this.RefreshList()
    }

    OnDelete(*) {
        row := this.controls["lv"].GetNext(0, "Focused")
        if !row || row > this.tasks.Length
            return
        this.tasks.RemoveAt(row)
        this.SaveTasks()
        this.RefreshList()
    }

    OnClearDone(*) {
        i := this.tasks.Length
        while (i >= 1) {
            if this.tasks[i]["done"]
                this.tasks.RemoveAt(i)
            i--
        }
        this.SaveTasks()
        this.RefreshList()
    }

    OnCheck(lv, row, checked) {
        if row < 1 || row > this.tasks.Length
            return
        this.tasks[row]["done"] := checked ? true : false
        this.SaveTasks()
        this.UpdateStatus()
    }

    RefreshList() {
        lv := this.controls["lv"]
        lv.Delete()
        for task in this.tasks {
            opts := task["done"] ? "+Check" : ""
            lv.Add(opts, task["text"], task["created"])
        }
        this.UpdateStatus()
    }

    UpdateStatus() {
        total := this.tasks.Length
        done := 0
        for task in this.tasks
            if task["done"]
                done++
        this.controls["status"].Text := done "/" total " done"
    }

    OnSize(guiObj, minMax, w, h) {
        if minMax = -1
            return
        m := TaskListApp.margin
        gap := TaskListApp.gap
        inputW := w - m * 2 - 90 - gap
        this.controls["input"].Move(m, , inputW, 28)
        this.controls["addBtn"].Move(m + inputW + gap, , 90, 28)

        lvY := 68
        lvH := h - lvY - 52
        this.controls["lv"].Move(m, lvY, w - m * 2, lvH)

        btnY := h - 44
        colW := (w - m * 2 - gap * 2) // 3
        this.controls["deleteBtn"].Move(m, btnY, colW, 32)
        this.controls["clearBtn"].Move(m + colW + gap, btnY, colW, 32)
        this.controls["status"].Move(m + (colW + gap) * 2, btnY, colW, 32)
    }

    SaveTasks() {
        json := "["
        for i, task in this.tasks {
            if i > 1
                json .= ","
            json .= '`n  {"text":' this.JsonStr(task["text"])
                . ',"done":' (task["done"] ? "true" : "false")
                . ',"created":' this.JsonStr(task["created"]) '}'
        }
        json .= "`n]"
        try FileOpen(this.dataFile, "w", "UTF-8").Write(json)
    }

    LoadTasks() {
        this.tasks := []
        if !FileExist(this.dataFile)
            return
        try {
            raw := FileRead(this.dataFile, "UTF-8")
            pos := 1
            while RegExMatch(raw, '\{"text":\s*"((?:[^"\\]|\\.)*)"\s*,\s*"done":\s*(true|false)\s*,\s*"created":\s*"((?:[^"\\]|\\.)*)"\s*\}', &m, pos) {
                this.tasks.Push(Map(
                    "text", StrReplace(StrReplace(m[1], "\\", "\"), '\\"', '"'),
                    "done", m[2] = "true",
                    "created", m[3]
                ))
                pos := m.Pos + m.Len
            }
        }
    }

    JsonStr(s) {
        s := StrReplace(s, "\", "\\")
        s := StrReplace(s, '"', '\"')
        s := StrReplace(s, "`n", "\n")
        s := StrReplace(s, "`r", "\r")
        s := StrReplace(s, "`t", "\t")
        return '"' s '"'
    }
}
