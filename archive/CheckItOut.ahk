#Requires AutoHotkey v2.1-alpha.17 64-bit
#SingleInstance Force

#Include Lib\cJson.ahk
#Include Lib\_Dark.ahk

^Esc::ExitApp

Lg()

class Lg {
    static PADDING := 10
    static LABEL_WIDTH := 80
    static INPUT_WIDTH := 460
    static INPUT_HEIGHT := 24
    static TEXTAREA_HEIGHT := 100
    static CODE_HEIGHT := 200
    static BUTTON_WIDTH := 130
    static BUTTON_HEIGHT := 30

    static COL_DATE := 1
    static COL_COMPANY := 2
    static COL_MODEL := 3
    static COL_TITLE := 4
    static COL_NOTES := 5

    __New() {
        this.logFile := A_ScriptDir "\test_log.json"
        this.entries := []
        this.running := false
        this.runScriptPath := A_Temp "\LLMLoggerRun.ahk"
        this.outputBuffer := ""
        this.monitorTimerCallback := this.MonitorRunningProcess.Bind(this)
        
        this.LoadData()
        this.InitGui()
        this.RefreshList()
        this.gui.Show()
    }

    InitGui() {
        this.gui := Gui("+Resize", "LLM Test Logger")
        this.gui.SetFont("s10")
        this.gui.BackColor := 0x1E1E1E

        _Dark.Apply(this.gui)

        this.CreateFormControls()
        this.CreateListView()
        this.CreateButtons()

        this.gui.OnEvent("Close", (*) => ExitApp())
    }

    CreateFormControls() {
        
;#region LLM Info
        this.gui.AddText(
            GuiFormat(
                Lg.PADDING,
                Lg.PADDING,
                Lg.LABEL_WIDTH,
                Lg.INPUT_HEIGHT,
                "cFFFFFF"
            ),
            "Company:"
        )

        this.editCompany := this.gui.AddEdit(
            GuiFormat(
                Lg.PADDING + Lg.LABEL_WIDTH + Lg.PADDING,
                Lg.PADDING,
                Lg.INPUT_WIDTH,
                Lg.INPUT_HEIGHT
            )
        )

        this.gui.AddText(
            GuiFormat(
                Lg.PADDING,
                Lg.PADDING * 2 + Lg.INPUT_HEIGHT,
                Lg.LABEL_WIDTH,
                Lg.INPUT_HEIGHT,
                "cFFFFFF"
            ),
            "Model:"
        )

        this.editModel := this.gui.AddEdit(
            GuiFormat(
                Lg.PADDING + Lg.LABEL_WIDTH + Lg.PADDING,
                Lg.PADDING * 2 + Lg.INPUT_HEIGHT,
                Lg.INPUT_WIDTH,
                Lg.INPUT_HEIGHT
            )
        )
;#endregion

;#region Prompt Controls
        this.gui.AddText(
            GuiFormat(
                Lg.PADDING,
                Lg.PADDING * 3 + Lg.INPUT_HEIGHT * 2,
                Lg.LABEL_WIDTH,
                Lg.INPUT_HEIGHT,
                "cFFFFFF"
            ),
            "Prompt:"
        )

        this.editPromptTitle := this.gui.AddEdit(
            GuiFormat(
                Lg.PADDING + Lg.LABEL_WIDTH + Lg.PADDING,
                Lg.PADDING * 3 + Lg.INPUT_HEIGHT * 2,
                Lg.INPUT_WIDTH,
                Lg.INPUT_HEIGHT
            )
        )

        this.gui.AddText(
            GuiFormat(
                Lg.PADDING,
                Lg.PADDING * 4 + Lg.INPUT_HEIGHT * 3,
                Lg.LABEL_WIDTH,
                Lg.INPUT_HEIGHT,
                "cFFFFFF"
            ),
            "Body:"
        )


        this.editPromptBody := this.gui.AddEdit(
            GuiFormat(
                Lg.PADDING + Lg.LABEL_WIDTH + Lg.PADDING,
                Lg.PADDING * 4 + Lg.INPUT_HEIGHT * 3,
                Lg.INPUT_WIDTH,
                Lg.TEXTAREA_HEIGHT,
                "Multi VScroll"
            )
        )
;#endregion

;#region Code
        this.gui.AddText(
            GuiFormat(
                Lg.PADDING,
                Lg.PADDING * 5 + Lg.INPUT_HEIGHT * 3 + Lg.TEXTAREA_HEIGHT,
                Lg.LABEL_WIDTH,
                Lg.INPUT_HEIGHT,
                "cFFFFFF"
            ),
            "Code:"
        )

        this.btnRunCode := this.gui.AddButton(
            GuiFormat(
                Lg.PADDING + Lg.LABEL_WIDTH - Lg.PADDING - Lg.PADDING - Lg.PADDING,
                Lg.PADDING * 5 + Lg.INPUT_HEIGHT * 3 + Lg.TEXTAREA_HEIGHT,
                Lg.BUTTON_HEIGHT,
                Lg.BUTTON_HEIGHT,
                "Background303030 cFFFFFF"
            ), 
            "⏵︎"
        )
        this.btnRunCode.OnEvent("Click", this.RunCode.Bind(this))
        
        this.editCode := this.gui.AddEdit(
            GuiFormat(
                Lg.PADDING + Lg.LABEL_WIDTH + Lg.PADDING,
                Lg.PADDING * 5 + Lg.INPUT_HEIGHT * 3 + Lg.TEXTAREA_HEIGHT,
                Lg.INPUT_WIDTH,
                Lg.CODE_HEIGHT,
                "Multi VScroll"
            )
        )
        this.editCode.Value := 'MsgBox("LOL")'
;#endregion

;#region Errors
        this.gui.AddText(
            GuiFormat(
                Lg.PADDING,
                Lg.PADDING * 6 + Lg.INPUT_HEIGHT * 3 + Lg.TEXTAREA_HEIGHT + Lg.CODE_HEIGHT,
                Lg.LABEL_WIDTH,
                Lg.INPUT_HEIGHT,
                "cFFFFFF"
            ),
            "Errors:"
        )

        this.editErrors := this.gui.AddEdit(
            GuiFormat(
                Lg.PADDING + Lg.LABEL_WIDTH + Lg.PADDING,
                Lg.PADDING * 6 + Lg.INPUT_HEIGHT * 3 + Lg.TEXTAREA_HEIGHT + Lg.CODE_HEIGHT,
                Lg.INPUT_WIDTH,
                Lg.TEXTAREA_HEIGHT,
                "Multi VScroll"
            )
        )
;#endregion

;#region Notes
        this.gui.AddText(
            GuiFormat(
                Lg.PADDING,
                Lg.PADDING * 7 + Lg.INPUT_HEIGHT * 3 + Lg.TEXTAREA_HEIGHT * 2 + Lg.CODE_HEIGHT,
                Lg.LABEL_WIDTH,
                Lg.INPUT_HEIGHT,
                "cFFFFFF"
            ),
            "Notes:"
        )

        this.editNotes := this.gui.AddEdit(
            GuiFormat(
                Lg.PADDING + Lg.LABEL_WIDTH + Lg.PADDING,
                Lg.PADDING * 7 + Lg.INPUT_HEIGHT * 3 + Lg.TEXTAREA_HEIGHT * 2 + Lg.CODE_HEIGHT,
                Lg.INPUT_WIDTH,
                Lg.TEXTAREA_HEIGHT,
                "Multi VScroll"
            )
        )

        HotKey("F5", this.RunCode.Bind(this))
    }
;#endregion

;#region Methods
    RunCode(*) {
        if (this.running) {
            this.StopRunningCode()
            return
        }

        code := this.editCode.Value
        if (!code) {
            MsgBox("No code to run.", "Run Code", "Icon!")
            return
        }

        this.editErrors.Value := ""
        this.outputBuffer := ""
        
        try {
            this.PrepareScriptFile(code)
            this.ExecuteScript()
            
            this.running := true
            this.btnRunCode.Text := "⏸︎"
            this.btnRunCode.Opt("BackgroundCC3030")
            
            SetTimer(this.monitorTimerCallback, 100)
        } catch Error as err {
            this.editErrors.Value := "Error: " err.Message
            MsgBox("Error: " err.Message, "Code Execution Failed", "Icon!")
        }
    }

    StopRunningCode() {
        try {
            if this.process {
                try {
                    ProcessClose(this.process.ProcessID)
                } catch {
                }
            }
        } catch Error as err {
            this.editErrors.Value := "Error stopping code: " err.Message
        }

        this.running := false
        this.btnRunCode.Text := "⏵︎"
        this.btnRunCode.Opt("Background303030")
        SetTimer(this.monitorTimerCallback, 0)
    }

PrepareScriptFile(code) {
    try {
        if FileExist(this.runScriptPath)
            FileDelete(this.runScriptPath)
            
        scriptHeader := "#Requires AutoHotkey v2.1-alpha.17 64-bit`n"
        scriptHeader .= "#SingleInstance Force`n"
        scriptHeader .= "#Warn All`n`n"
        scriptHeader .= "Esc::ExitApp`n`n"
        
        
        FileAppend(scriptHeader . code, this.runScriptPath)
    } catch Error as err {
        throw Error("Failed to prepare script file: " err.Message, "PrepareScriptFile")
    }
}

ExecuteScript() {
    try {
        this.process := ComObject("WScript.Shell").Exec(Format('"{}" "{}"', A_AhkPath, this.runScriptPath))
        
    } catch Error as err {
        throw Error("Failed to execute script: " err.Message, "ExecuteScript")
    }
}

    MonitorRunningProcess() {
        if (!this.process || !this.running) {
            SetTimer(this.monitorTimerCallback, 0)
            return
        }
        
        hasExited := this.process.Status != 0
        
        this.ReadProcessOutput()
        
        if (hasExited) {
            this.ReadProcessOutput()
            
            this.running := false
            this.btnRunCode.Text := "⏵︎"
            this.btnRunCode.Opt("Background303030")
            
            SetTimer(this.monitorTimerCallback, 0)
        }
    }

    ReadProcessOutput() {
        if (!this.process || this.process.StdOut.AtEndOfStream)
            return
            
        try {
            while (!this.process.StdOut.AtEndOfStream) {
                this.outputBuffer .= this.process.StdOut.ReadLine() "`n"
            }
            
            if (this.outputBuffer) {
                this.editErrors.Value := RTrim(this.outputBuffer, "`n")
            }
        } catch {
            ; Ignore read errors
        }
    }
    
    CreateListView() {
        static LVM_SETTEXTCOLOR := 0x1024
        static LVM_SETTEXTBKCOLOR := 0x1026
        static LVM_SETBKCOLOR := 0x1001

        formBottom := Lg.PADDING * 8 + Lg.INPUT_HEIGHT * 3 + Lg.TEXTAREA_HEIGHT * 3 + Lg.CODE_HEIGHT

        this.listView := this.gui.AddListView(
            GuiFormat(Lg.PADDING, formBottom + Lg.PADDING
                , Lg.LABEL_WIDTH + Lg.PADDING + Lg.INPUT_WIDTH
                , 200, "Grid cWhite")
            , [
                "Date"
                , "Company"
                , "Model"
                , "Prompt"
                , "Notes"
            ])

        this.listView.Opt("-Redraw")

        SendMessage(LVM_SETTEXTCOLOR, 0, 0xFFFFFF, this.listView.Hwnd)
        SendMessage(LVM_SETTEXTBKCOLOR, 0, 0x202020, this.listView.Hwnd)
        SendMessage(LVM_SETBKCOLOR, 0, 0x202020, this.listView.Hwnd)

        this.listView.Opt("+Redraw")

        this.listView.ModifyCol(Lg.COL_DATE, 70)
        this.listView.ModifyCol(Lg.COL_COMPANY, 70)
        this.listView.ModifyCol(Lg.COL_MODEL, 50)
        this.listView.ModifyCol(Lg.COL_TITLE, 125)
        this.listView.ModifyCol(Lg.COL_NOTES, 250)
    }

    CreateButtons() {
        formBottom := Lg.PADDING * 8 + Lg.INPUT_HEIGHT * 3 + Lg.TEXTAREA_HEIGHT * 3 + Lg.CODE_HEIGHT
        listViewBottom := formBottom + Lg.PADDING + 200
        buttonY := listViewBottom + Lg.PADDING

        this.btnSave := this.gui.AddButton(
            GuiFormat(
                Lg.PADDING * 4 + Lg.BUTTON_WIDTH * 3,
                buttonY,
                Lg.BUTTON_WIDTH,
                Lg.BUTTON_HEIGHT,
                "Background303030 cFFFFFF"
            ),
            "Save Entry"
        )
        this.btnSave.OnEvent("Click", this.SaveEntry.Bind(this))

        this.btnLoad := this.gui.AddButton(
            GuiFormat(
                Lg.PADDING * 2 + Lg.BUTTON_WIDTH,
                buttonY,
                Lg.BUTTON_WIDTH,
                Lg.BUTTON_HEIGHT,
                "Background303030 cFFFFFF"
            ),
            "Load Entry"
        )
        this.btnLoad.OnEvent("Click", this.LoadEntry.Bind(this))

        this.btnDelete := this.gui.AddButton(
            GuiFormat(
                Lg.PADDING * 3 + Lg.BUTTON_WIDTH * 2,
                buttonY,
                Lg.BUTTON_WIDTH,
                Lg.BUTTON_HEIGHT,
                "Background303030 cFFFFFF"
            ),
            "Delete Entry"
        )
        this.btnDelete.OnEvent("Click", this.DeleteEntry.Bind(this))

        this.btnClear := this.gui.AddButton(
            GuiFormat(
                Lg.PADDING,
                buttonY,
                Lg.BUTTON_WIDTH,
                Lg.BUTTON_HEIGHT,
                "Background303030 cFFFFFF"
            ),
            "Clear Form"
        )
        this.btnClear.OnEvent("Click", this.ClearForm.Bind(this))
    }

    LoadData() {
        if FileExist(this.logFile) {
            try {
                jsonText := FileRead(this.logFile)
                if (jsonText = "" || RegExMatch(jsonText, "^\s*$")) {
                    this.entries := []
                    return
                }

                this.entries := JSON.Load(jsonText)

                if (!IsObject(this.entries) || !HasMethod(this.entries, "Push")) {
                    this.entries := []
                }
            } catch Error as err {
                MsgBox("Error loading data: " err.Message, "Error", "Icon!")
                this.entries := []
            }
        } else {
            try {
                FileAppend("[]", this.logFile)
                this.entries := []
            } catch Error as err {
                MsgBox("Error creating log file: " err.Message, "Error", "Icon!")
                this.entries := []
            }
        }
    }

    SaveData() {
        try {
            if (!IsObject(this.entries) || !HasMethod(this.entries, "Push")) {
                this.entries := []
            }

            jsonText := JSON.Dump(this.entries, 1)

            FileDelete(this.logFile)
            FileAppend(jsonText, this.logFile)
        } catch Error as err {
            MsgBox("Error saving data: " err.Message, "Error", "Icon!")
        }
    }

    RefreshList() {
        this.listView.Delete()
        for entry in this.entries {
            company := entry.Has("Company") ? entry["Company"] : ""
            model := entry.Has("Model") ? entry["Model"] : ""
            title := entry.Has("PromptTitle") ? entry["PromptTitle"]
                : entry.Has("Prompt") ? entry["Prompt"] : ""
            dateStr := entry.Has("Timestamp") ? SubStr(entry["Timestamp"], 1, 10) : ""
            notes := entry.Has("Notes") ? entry["Notes"] : ""

            this.listView.Add(
                , dateStr
                , company
                , model
                , title
                , notes)
        }
    }

    SaveEntry(*) {
        company := this.editCompany.Value
        model := this.editModel.Value
        promptTitle := this.editPromptTitle.Value
        promptBody := this.editPromptBody.Value
        code := this.editCode.Value
        errors := this.editErrors.Value
        notes := this.editNotes.Value

        if (company = "" || model = "") {
            MsgBox("Company and Model are required.", "Validation Error", "Icon!")
            return
        }

        formatted := FormatTime(A_Now, "MM/dd/yy")

        entry := Map(
            "Company", company,
            "Model", model,
            "PromptTitle", promptTitle,
            "PromptBody", promptBody,
            "Code", code,
            "Errors", errors,
            "Notes", notes,
            "Timestamp", formatted
        )

        this.entries.Push(entry)

        this.SaveData()
        this.RefreshList()
        this.ClearForm()
    }

    LoadEntry(*) {
        row := this.listView.GetNext()
        if (!row) {
            MsgBox("Please select an entry to load.", "Information", "Icon!")
            return
        }

        dateStr := this.listView.GetText(row, Lg.COL_DATE)
        company := this.listView.GetText(row, Lg.COL_COMPANY)
        model := this.listView.GetText(row, Lg.COL_MODEL)
        promptTitle := this.listView.GetText(row, Lg.COL_TITLE)

        for i, entry in this.entries {
            try {
                entryMatch := false

                if (IsObject(entry)) {
                    if (HasMethod(entry, "Get")) {
                        entryCompany := entry.Has("Company") ? entry["Company"] : ""
                        entryModel := entry.Has("Model") ? entry["Model"] : ""
                        entryPromptTitle := ""
                        entryDate := ""

                        if (entry.Has("PromptTitle"))
                            entryPromptTitle := entry["PromptTitle"]
                        else if (entry.Has("Prompt"))
                            entryPromptTitle := entry["Prompt"]

                        if (entry.Has("Timestamp")) {
                            fullTimestamp := entry["Timestamp"]
                            entryDate := SubStr(fullTimestamp, 1, 10)
                        }

                        if (entryCompany = company && entryModel = model &&
                            entryPromptTitle = promptTitle && entryDate = dateStr) {
                            this.editCompany.Value := entryCompany
                            this.editModel.Value := entryModel
                            this.editPromptTitle.Value := entryPromptTitle

                            if (entry.Has("PromptBody"))
                                this.editPromptBody.Value := entry["PromptBody"]
                            else if (entry.Has("Prompt"))
                                this.editPromptBody.Value := entry["Prompt"]
                            else
                                this.editPromptBody.Value := ""

                            this.editCode.Value := entry.Has("Code") ? entry["Code"] : ""
                            this.editErrors.Value := entry.Has("Errors") ? entry["Errors"] : ""
                            this.editNotes.Value := entry.Has("Notes") ? entry["Notes"] : ""
                            entryMatch := true
                        }
                    } else {
                        entryCompany := entry.HasOwnProp("Company") ? entry.Company : ""
                        entryModel := entry.HasOwnProp("Model") ? entry.Model : ""
                        entryPromptTitle := ""
                        entryDate := ""

                        if (entry.HasOwnProp("PromptTitle"))
                            entryPromptTitle := entry.PromptTitle
                        else if (entry.HasOwnProp("Prompt"))
                            entryPromptTitle := entry.Prompt

                        if (entry.HasOwnProp("Timestamp")) {
                            fullTimestamp := entry.Timestamp
                            entryDate := SubStr(fullTimestamp, 1, 10)
                        }

                        if (entryCompany = company && entryModel = model &&
                            entryPromptTitle = promptTitle && entryDate = dateStr) {
                            this.editCompany.Value := entryCompany
                            this.editModel.Value := entryModel
                            this.editPromptTitle.Value := entryPromptTitle

                            if (entry.HasOwnProp("PromptBody"))
                                this.editPromptBody.Value := entry.PromptBody
                            else if (entry.HasOwnProp("Prompt"))
                                this.editPromptBody.Value := entry.Prompt
                            else
                                this.editPromptBody.Value := ""

                            this.editCode.Value := entry.HasOwnProp("Code") ? entry.Code : ""
                            this.editErrors.Value := entry.HasOwnProp("Errors") ? entry.Errors : ""
                            this.editNotes.Value := entry.HasOwnProp("Notes") ? entry.Notes : ""
                            entryMatch := true
                        }
                    }

                    if (entryMatch) {
                        return
                    }
                }
            } catch Error as err {
                continue
            }
        }

        MsgBox("Entry not found.", "Information", "Icon!")
    }

    DeleteEntry(*) {
        row := this.listView.GetNext()
        if (!row) {
            MsgBox("Please select an entry to delete.", "Information", "Icon!")
            return
        }

        dateStr := this.listView.GetText(row, Lg.COL_DATE)
        company := this.listView.GetText(row, Lg.COL_COMPANY)
        model := this.listView.GetText(row, Lg.COL_MODEL)
        promptTitle := this.listView.GetText(row, Lg.COL_TITLE)

        for i, entry in this.entries {
            try {
                entryMatch := false

                if (IsObject(entry)) {
                    if (HasMethod(entry, "Get")) {
                        entryCompany := entry.Has("Company") ? entry["Company"] : ""
                        entryModel := entry.Has("Model") ? entry["Model"] : ""
                        entryPromptTitle := ""
                        entryDate := ""

                        if (entry.Has("PromptTitle"))
                            entryPromptTitle := entry["PromptTitle"]
                        else if (entry.Has("Prompt"))
                            entryPromptTitle := entry["Prompt"]

                        if (entry.Has("Timestamp")) {
                            fullTimestamp := entry["Timestamp"]
                            entryDate := SubStr(fullTimestamp, 1, 10)
                        }

                        if (entryCompany = company && entryModel = model &&
                            entryPromptTitle = promptTitle && entryDate = dateStr) {
                            this.entries.RemoveAt(i)
                            entryMatch := true
                        }
                    } else {
                        entryCompany := entry.HasOwnProp("Company") ? entry.Company : ""
                        entryModel := entry.HasOwnProp("Model") ? entry.Model : ""
                        entryPromptTitle := ""
                        entryDate := ""

                        if (entry.HasOwnProp("PromptTitle"))
                            entryPromptTitle := entry.PromptTitle
                        else if (entry.HasOwnProp("Prompt"))
                            entryPromptTitle := entry.Prompt

                        if (entry.HasOwnProp("Timestamp")) {
                            fullTimestamp := entry.Timestamp
                            entryDate := SubStr(fullTimestamp, 1, 10)
                        }

                        if (entryCompany = company && entryModel = model &&
                            entryPromptTitle = promptTitle && entryDate = dateStr) {
                            this.entries.RemoveAt(i)
                            entryMatch := true
                        }
                    }

                    if (entryMatch) {
                        this.SaveData()
                        this.RefreshList()
                        this.ClearForm()
                        return
                    }
                }
            } catch Error as err {
                continue
            }
        }

        MsgBox("Entry not found.", "Information", "Icon!")
    }

    ClearForm(*) {
        this.editCompany.Value := ""
        this.editModel.Value := ""
        this.editPromptTitle.Value := ""
        this.editPromptBody.Value := ""
        this.editCode.Value := ""
        this.editErrors.Value := ""
        this.editNotes.Value := ""
    }
}

GuiFormat(x, y, w, h, extraParams := "") {
    return GuiFormatBuilder().Position(x, y).Size(w, h).ExtraParams(extraParams).Build()
}

class GuiFormatBuilder {
    _x := 0
    _y := 0
    _w := 0
    _h := 0
    _extraParams := ""

    Position(x, y) {
        this._x := x
        this._y := y
        return this
    }

    Size(w, h) {
        this._w := w
        this._h := h
        return this
    }

    ExtraParams(value) {
        this._extraParams := value
        return this
    }

    Build() {
        params := Format("x{} y{} w{} h{}", this._x, this._y, this._w, this._h)
        if this._extraParams {
            params .= " " this._extraParams
        }
        return params
    }
}