#Requires AutoHotkey v2.1-alpha.17
#SingleInstance Force

/**
 * DarkModeGUI_TaskManager.ahk - Task Manager with Dark Mode GUI
 *
 * A comprehensive task management application featuring:
 * - Dark mode theming using DarkGui framework
 * - Task CRUD operations (Create, Read, Update, Delete)
 * - Priority-based color coding
 * - Search and filtering capabilities
 * - Progress tracking and status display
 * - In-memory data storage
 */

; ═══════════════════════════════════════════════════════════════════════════════
; DarkMode Framework Integration
; ═══════════════════════════════════════════════════════════════════════════════

#Include DarkMode.ahk

; ═══════════════════════════════════════════════════════════════════════════════
; Task Data Model
; ═══════════════════════════════════════════════════════════════════════════════

class TaskItem {
    __New(title, description := "", category := "General", priority := "Medium", dueDate := "") {
        this.id := this.GenerateId()
        this.title := title
        this.description := description
        this.category := category
        this.priority := priority
        this.dueDate := dueDate
        this.completed := false
        this.createdAt := A_Now
        this.completedAt := ""
    }

    GenerateId() {
        static counter := 0
        return ++counter
    }

    ToggleComplete() {
        this.completed := !this.completed
        this.completedAt := this.completed ? A_Now : ""
        return this.completed
    }

    IsOverdue() {
        return this.dueDate && !this.completed && (this.dueDate < A_Now)
    }

    GetPriorityColor() {
        switch this.priority {
            case "High": return 0xFF6B6B    ; Red
            case "Medium": return 0xFFD93D  ; Yellow/Orange
            case "Low": return 0x6BCF7F    ; Green
            default: return 0xA0A0A0      ; Gray
        }
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; Task Store - In-Memory Data Management
; ═══════════════════════════════════════════════════════════════════════════════

class TaskStore {
    __New() {
        this.tasks := Map()
        this.nextId := 1
    }

    Add(task) {
        task.id := this.nextId++
        this.tasks[task.id] := task
        return task.id
    }

    Get(id) {
        return this.tasks.Has(id) ? this.tasks[id] : false
    }

    Update(id, updates) {
        if !this.tasks.Has(id)
            return false

        task := this.tasks[id]
        for prop, value in updates.OwnProps()
            task.%prop% := value
        return true
    }

    Remove(id) {
        return this.tasks.Delete(id)
    }

    GetAll() {
        tasks := []
        for id, task in this.tasks
            tasks.Push(task)
        return tasks
    }

    GetFiltered(filterType := "All", filterValue := "") {
        tasks := this.GetAll()

        switch filterType {
            case "Completed":
                tasks := tasks.Filter(task => task.completed)
            case "Pending":
                tasks := tasks.Filter(task => !task.completed)
            case "Overdue":
                tasks := tasks.Filter(task => task.IsOverdue())
            case "Category":
                if filterValue
                    tasks := tasks.Filter(task => task.category = filterValue)
            case "Priority":
                if filterValue
                    tasks := tasks.Filter(task => task.priority = filterValue)
            case "Search":
                if filterValue
                    tasks := tasks.Filter(task => InStr(task.title, filterValue) || InStr(task.description, filterValue))
        }

        return tasks
    }

    GetStats() {
        all := this.GetAll()
        stats := {
            total: all.Length,
            completed: 0,
            pending: 0,
            overdue: 0,
            high: 0,
            medium: 0,
            low: 0
        }

        for task in all {
            if task.completed
                stats.completed++
            else
                stats.pending++

            if task.IsOverdue()
                stats.overdue++

            switch task.priority {
                case "High": stats.high++
                case "Medium": stats.medium++
                case "Low": stats.low++
            }
        }

        return stats
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; Main Task Manager GUI
; ═══════════════════════════════════════════════════════════════════════════════

class DarkModeTaskManager {
    __New() {
        this.store := TaskStore()
        this.currentFilter := {type: "All", value: ""}
        this.selectedTaskId := 0

        this.gui := DarkGui("+Resize", "Dark Mode Task Manager")
        this.gui.MarginX := 20
        this.gui.MarginY := 15

        this.BuildLayout()
        this.BindEvents()
        this.LoadSampleData()
        this.RefreshTaskList()
        this.UpdateStatus()

        this.gui.Show("w900 h700")
    }

    BuildLayout() {
        ; Task Form Section
        this.AddTaskForm()

        ; Task List Section
        this.AddTaskList()

        ; Filters and Search
        this.AddFiltersSection()

        ; Progress and Status
        this.AddProgressSection()
        this.AddStatusBar()
    }

    AddTaskForm() {
        y := 15

        ; Section header
        this.gui.Add("Text", "x20 y" y " w400", "TASK FORM")
        y += 25

        ; Title input
        this.gui.Add("Text", "x20 y" y " w100 cA0A0A0", "Title:")
        y += 20
        this.controls["taskTitle"] := this.gui.Add("Edit", "x20 y" y " w400 h28", "")
        y += 40

        ; Description input
        this.gui.Add("Text", "x20 y" y " w100 cA0A0A0", "Description:")
        y += 20
        this.controls["taskDesc"] := this.gui.Add("Edit", "x20 y" y " w400 h60 +Multi", "")
        y += 75

        ; Priority radios
        this.gui.Add("Text", "x20 y" y " w100 cA0A0A0", "Priority:")
        y += 20
        this.controls["priorityHigh"] := this.gui.Add("Radio", "x20 y" y " w80 +Checked", "High")
        this.controls["priorityMedium"] := this.gui.Add("Radio", "x120 y" y " w80", "Medium")
        this.controls["priorityLow"] := this.gui.Add("Radio", "x220 y" y " w80", "Low")
        y += 30

        ; Category dropdown
        this.gui.Add("Text", "x20 y" y " w100 cA0A0A0", "Category:")
        y += 20
        this.controls["taskCategory"] := this.gui.Add("ComboBox", "x20 y" y " w200",
            ["General", "Work", "Personal", "Shopping", "Health", "Education"])
        y += 40

        ; Due date
        this.gui.Add("Text", "x20 y" y " w100 cA0A0A0", "Due Date:")
        y += 20
        this.controls["taskDueDate"] := this.gui.Add("Edit", "x20 y" y " w150 h28", "")
        this.controls["dueDateBtn"] := this.gui.Add("Button", "x180 y" y " w60 h28", "Set")
        y += 40

        ; Action buttons
        this.controls["addBtn"] := this.gui.Add("Button", "+Accent x20 y" y " w90 h32", "Add Task")
        this.controls["updateBtn"] := this.gui.Add("Button", "+Accent x120 y" y " w90 h32", "Update")
        this.controls["clearBtn"] := this.gui.Add("Button", "x220 y" y " w90 h32", "Clear")
        this.controls["deleteBtn"] := this.gui.Add("Button", "x320 y" y " w90 h32", "Delete")
    }

    AddTaskList() {
        y := 15

        ; Section header
        this.gui.Add("Text", "x450 y" y " w430", "TASK LIST")
        y += 25

        ; ListView for tasks
        this.controls["taskList"] := this.gui.Add("ListView", "x450 y" y " w430 h350 +Grid",
            ["ID", "Title", "Priority", "Category", "Due Date", "Status"])
        this.controls["taskList"].ModifyCol(1, 0)  ; Hide ID column
        this.controls["taskList"].ModifyCol(2, 200)
        this.controls["taskList"].ModifyCol(3, 80)
        this.controls["taskList"].ModifyCol(4, 100)
        this.controls["taskList"].ModifyCol(5, 120)
        this.controls["taskList"].ModifyCol(6, 80)
    }

    AddFiltersSection() {
        y := 400

        ; Section header
        this.gui.Add("Text", "x20 y" y " w400", "FILTERS & SEARCH")
        y += 25

        ; Search input
        this.gui.Add("Text", "x20 y" y " w100 cA0A0A0", "Search:")
        y += 20
        this.controls["searchInput"] := this.gui.Add("Edit", "x20 y" y " w200 h28", "")
        this.controls["searchBtn"] := this.gui.Add("Button", "x230 y" y " w80 h28", "Search")
        y += 40

        ; Filter dropdowns
        this.gui.Add("Text", "x20 y" y " w100 cA0A0A0", "Status:")
        y += 20
        this.controls["filterStatus"] := this.gui.Add("ComboBox", "x20 y" y " w150",
            ["All", "Pending", "Completed", "Overdue"])
        y += 40

        this.gui.Add("Text", "x200 y" (y-40) " w100 cA0A0A0", "Category:")
        this.controls["filterCategory"] := this.gui.Add("ComboBox", "x200 y" y " w150",
            ["All", "General", "Work", "Personal", "Shopping", "Health", "Education"])
        y += 40

        this.gui.Add("Text", "x380 y" (y-40) " w100 cA0A0A0", "Priority:")
        this.controls["filterPriority"] := this.gui.Add("ComboBox", "x380 y" y " w150",
            ["All", "High", "Medium", "Low"])
        y += 40

        ; Apply filters button
        this.controls["applyFiltersBtn"] := this.gui.Add("Button", "+Accent x20 y" y " w120 h32", "Apply Filters")
        this.controls["clearFiltersBtn"] := this.gui.Add("Button", "x150 y" y " w120 h32", "Clear Filters")
    }

    AddProgressSection() {
        y := 400

        ; Progress section
        this.gui.Add("Text", "x650 y" y " w230", "PROGRESS")
        y += 25

        ; Progress bar
        this.controls["progressBar"] := this.gui.Add("Progress", "x650 y" y " w230 h25", 0)
        y += 35

        ; Progress label
        this.controls["progressLabel"] := this.gui.Add("Text", "x650 y" y " w230 cA0A0A0", "Completion: 0%")
    }

    AddStatusBar() {
        ; Status bar at bottom
        this.gui.Add("Text", "x0 y650 w900 h40 +0x4 BackgroundTrans", "")
        this.controls["statusBar"] := this.gui.Add("Text", "x20 y655 w860",
            "Ready | Total: 0 | Completed: 0 | Pending: 0 | Overdue: 0")
    }

    BindEvents() {
        ; Task form buttons
        this.controls["addBtn"].OnEvent("Click", (*) => this.AddTask())
        this.controls["updateBtn"].OnEvent("Click", (*) => this.UpdateTask())
        this.controls["clearBtn"].OnEvent("Click", (*) => this.ClearForm())
        this.controls["deleteBtn"].OnEvent("Click", (*) => this.DeleteTask())
        this.controls["dueDateBtn"].OnEvent("Click", (*) => this.SetDueDate())

        ; Task list
        this.controls["taskList"].OnEvent("ItemSelect", (*) => this.OnTaskSelect())
        this.controls["taskList"].OnEvent("DoubleClick", (*) => this.OnTaskDoubleClick())

        ; Filters and search
        this.controls["searchBtn"].OnEvent("Click", (*) => this.ApplySearch())
        this.controls["applyFiltersBtn"].OnEvent("Click", (*) => this.ApplyFilters())
        this.controls["clearFiltersBtn"].OnEvent("Click", (*) => this.ClearFilters())

        ; GUI events
        this.gui.OnEvent("Close", (*) => ExitApp())
        this.gui.OnEvent("Escape", (*) => this.gui.Hide())
    }

    ; ═══════════════════════════════════════════════════════════════════════════════
    ; Event Handlers
    ; ═══════════════════════════════════════════════════════════════════════════════

    AddTask() {
        title := Trim(this.controls["taskTitle"].Text)
        if !title {
            this.ShowStatus("Please enter a task title")
            return
        }

        desc := this.controls["taskDesc"].Text
        category := this.controls["taskCategory"].Text || "General"

        ; Get priority
        priority := "Medium"
        if this.controls["priorityHigh"].Value
            priority := "High"
        else if this.controls["priorityLow"].Value
            priority := "Low"

        dueDate := this.controls["taskDueDate"].Text

        task := TaskItem(title, desc, category, priority, dueDate)
        this.store.Add(task)

        this.ClearForm()
        this.RefreshTaskList()
        this.UpdateStatus()
        this.ShowStatus("Task added successfully")
    }

    UpdateTask() {
        if !this.selectedTaskId {
            this.ShowStatus("Please select a task to update")
            return
        }

        title := Trim(this.controls["taskTitle"].Text)
        if !title {
            this.ShowStatus("Please enter a task title")
            return
        }

        task := this.store.Get(this.selectedTaskId)
        if !task
            return

        task.title := title
        task.description := this.controls["taskDesc"].Text
        task.category := this.controls["taskCategory"].Text || "General"

        ; Get priority
        if this.controls["priorityHigh"].Value
            task.priority := "High"
        else if this.controls["priorityLow"].Value
            task.priority := "Medium"
        else
            task.priority := "Low"

        task.dueDate := this.controls["taskDueDate"].Text

        this.RefreshTaskList()
        this.UpdateStatus()
        this.ShowStatus("Task updated successfully")
    }

    DeleteTask() {
        if !this.selectedTaskId {
            this.ShowStatus("Please select a task to delete")
            return
        }

        result := MsgBox("Are you sure you want to delete this task?", "Confirm Delete", "YesNo Icon!")
        if result = "No"
            return

        this.store.Remove(this.selectedTaskId)
        this.selectedTaskId := 0
        this.ClearForm()
        this.RefreshTaskList()
        this.UpdateStatus()
        this.ShowStatus("Task deleted successfully")
    }

    ClearForm() {
        this.controls["taskTitle"].Text := ""
        this.controls["taskDesc"].Text := ""
        this.controls["taskCategory"].Text := "General"
        this.controls["taskDueDate"].Text := ""
        this.controls["priorityMedium"].Value := 1
        this.selectedTaskId := 0
    }

    OnTaskSelect() {
        row := this.controls["taskList"].GetNext()
        if !row
            return

        this.selectedTaskId := this.controls["taskList"].GetText(row, 1)
        task := this.store.Get(this.selectedTaskId)
        if !task
            return

        ; Populate form
        this.controls["taskTitle"].Text := task.title
        this.controls["taskDesc"].Text := task.description
        this.controls["taskCategory"].Text := task.category
        this.controls["taskDueDate"].Text := task.dueDate

        ; Set priority radio
        switch task.priority {
            case "High": this.controls["priorityHigh"].Value := 1
            case "Medium": this.controls["priorityMedium"].Value := 1
            case "Low": this.controls["priorityLow"].Value := 1
        }
    }

    OnTaskDoubleClick() {
        if !this.selectedTaskId
            return

        task := this.store.Get(this.selectedTaskId)
        if !task
            return

        ; Toggle completion status
        task.ToggleComplete()
        this.RefreshTaskList()
        this.UpdateStatus()
        status := task.completed ? "completed" : "marked as pending"
        this.ShowStatus("Task " . status)
    }

    SetDueDate() {
        ; Simple date input - in a real app you'd use a date picker
        current := this.controls["taskDueDate"].Text
        if !current
            current := FormatTime(A_Now, "yyyy-MM-dd")

        newDate := InputBox("Enter due date (YYYY-MM-DD):", "Set Due Date", , current)
        if newDate.Result = "OK" && newDate.Value
            this.controls["taskDueDate"].Text := newDate.Value
    }

    ApplySearch() {
        searchTerm := Trim(this.controls["searchInput"].Text)
        this.currentFilter := {type: "Search", value: searchTerm}
        this.RefreshTaskList()
        this.ShowStatus("Search applied")
    }

    ApplyFilters() {
        status := this.controls["filterStatus"].Text
        category := this.controls["filterCategory"].Text
        priority := this.controls["filterPriority"].Text

        ; Determine primary filter
        if status != "All"
            this.currentFilter := {type: status, value: ""}
        else if category != "All"
            this.currentFilter := {type: "Category", value: category}
        else if priority != "All"
            this.currentFilter := {type: "Priority", value: priority}
        else
            this.currentFilter := {type: "All", value: ""}

        this.RefreshTaskList()
        this.ShowStatus("Filters applied")
    }

    ClearFilters() {
        this.controls["searchInput"].Text := ""
        this.controls["filterStatus"].Text := "All"
        this.controls["filterCategory"].Text := "All"
        this.controls["filterPriority"].Text := "All"
        this.currentFilter := {type: "All", value: ""}
        this.RefreshTaskList()
        this.ShowStatus("Filters cleared")
    }

    ; ═══════════════════════════════════════════════════════════════════════════════
    ; UI Update Methods
    ; ═══════════════════════════════════════════════════════════════════════════════

    RefreshTaskList() {
        this.controls["taskList"].Delete()

        tasks := this.store.GetFiltered(this.currentFilter.type, this.currentFilter.value)

        for task in tasks {
            status := task.completed ? "✓ Complete" : (task.IsOverdue() ? "⚠ Overdue" : "Pending")
            dueDate := task.dueDate ? FormatTime(task.dueDate, "yyyy-MM-dd") : ""

            row := this.controls["taskList"].Add("",
                task.id,
                task.title,
                task.priority,
                task.category,
                dueDate,
                status)

            ; Color code priority column
            if task.priority = "High"
                this.controls["taskList"].Add("", , , "cFF6B6B")
            else if task.priority = "Medium"
                this.controls["taskList"].Add("", , , "cFFD93D")
            else if task.priority = "Low"
                this.controls["taskList"].Add("", , , "c6BCF7F")
        }
    }

    UpdateStatus() {
        stats := this.store.GetStats()

        ; Update progress bar
        if stats.total > 0 {
            percentage := Round((stats.completed / stats.total) * 100)
            this.controls["progressBar"].Value := percentage
            this.controls["progressLabel"].Text := "Completion: " . percentage . "%"
        } else {
            this.controls["progressBar"].Value := 0
            this.controls["progressLabel"].Text := "Completion: 0%"
        }

        ; Update status bar
        statusText := Format("Total: {1} | Completed: {2} | Pending: {3} | Overdue: {4}",
            stats.total, stats.completed, stats.pending, stats.overdue)
        this.controls["statusBar"].Text := statusText
    }

    ShowStatus(message) {
        timestamp := FormatTime(A_Now, "HH:mm:ss")
        this.controls["statusBar"].Text := timestamp . " | " . message

        ; Auto-clear status after 3 seconds
        SetTimer(() => this.UpdateStatus(), -3000)
    }

    ; ═══════════════════════════════════════════════════════════════════════════════
    ; Data Management
    ; ═══════════════════════════════════════════════════════════════════════════════

    LoadSampleData() {
        ; Add some sample tasks for demonstration
        tomorrow := DateAdd(A_Now, 1, "Days")
        nextWeek := DateAdd(A_Now, 7, "Days")
        yesterday := DateAdd(A_Now, -1, "Days")

        this.store.Add(TaskItem("Complete project documentation", "Write comprehensive API docs", "Work", "High", tomorrow))
        this.store.Add(TaskItem("Buy groceries", "Milk, eggs, bread, vegetables", "Shopping", "Medium", tomorrow))
        this.store.Add(TaskItem("Schedule dentist appointment", "Annual checkup needed", "Health", "Low", nextWeek))
        this.store.Add(TaskItem("Review code changes", "Check team's pull requests", "Work", "High", A_Now))
        this.store.Add(TaskItem("Call family", "Weekly catch-up call", "Personal", "Medium", yesterday))
    }
}

; ═══════════════════════════════════════════════════════════════════════════════
; Application Entry Point
; ═══════════════════════════════════════════════════════════════════════════════

DarkModeTaskManager()