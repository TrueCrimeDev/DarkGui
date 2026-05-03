#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force
#Include _Dark.ahk ; Include the dark mode library

LinkManagerEx()

class LinkManagerEx {
    static Config := Map(
        "minWidth", 500,
        "minHeight", 400,
        "defaultTitle", "Link Manager",
        "urlValidationPattern", "i)^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,})([\/\w \.-]*)*\/?$"
    )

    static LinkData := "
    (
        www.google.com 
        www.amazon.com 
        https://github.com/TrueCrimeAudit/ClautoHotkey 
        https://www.autohotkey.com/boards/viewtopic.php?f=96&t=120588
    )"

    __New() {
        this.state := Map(
            "isVisible", false,
            "selectedIndex", 0
        )

        this.links := this.ParseAndValidateLinks(LinkManagerEx.LinkData)

        ; Create GUI
        this.gui := Gui("+Resize +MinSize" LinkManagerEx.Config["minWidth"] "x" LinkManagerEx.Config["minHeight"], LinkManagerEx.Config["defaultTitle"])

        ; Apply dark mode using the _Dark library
        this.darkMode := DarkMode(this.gui)

        ; Add controls
        this.gui.AddText("w" LinkManagerEx.Config["minWidth"] - 20, "Select a link to open in Microsoft Edge:")
        this.listBox := this.gui.AddListBox("w" LinkManagerEx.Config["minWidth"] - 20 " h" LinkManagerEx.Config["minHeight"] - 150, this.GetLinkDisplayArray())
        this.btnOpen := this.gui.AddButton("w" (LinkManagerEx.Config["minWidth"] - 40) / 2, "Open in Edge").OnEvent("Click", this.OpenLink.Bind(this))
        this.btnClose := this.gui.AddButton("x+20 w" (LinkManagerEx.Config["minWidth"] - 40) / 2, "Close").OnEvent("Click", this.Hide.Bind(this))

        ; Status bar for messages
        this.statusBar := this.gui.AddText("w" LinkManagerEx.Config["minWidth"] - 20 " h20 y+" LinkManagerEx.Config["minHeight"] - 100, "Ready")

        ; Set up events
        this.gui.OnEvent("Close", this.Hide.Bind(this))
        this.gui.OnEvent("Escape", this.Hide.Bind(this))
        this.listBox.OnEvent("DoubleClick", this.OpenLink.Bind(this))
        this.listBox.OnEvent("Change", this.HandleSelectionChange.Bind(this))

        ; Set up hotkeys
        this.SetupHotkeys()

        ; Show GUI
        this.Show()
    }

    SetupHotkeys() {
        ; When the GUI is active
        HotIfWinActive("ahk_id " this.gui.Hwnd)
        Hotkey("Enter", this.OpenLink.Bind(this))
        Hotkey("Escape", this.Hide.Bind(this))
        HotIfWinActive()
    }

    Show(*) {
        this.gui.Show()
        this.state["isVisible"] := true
    }

    Hide(*) {
        this.gui.Hide()
        this.state["isVisible"] := false
    }

    Toggle(*) {
        if this.state["isVisible"]
            this.Hide()
        else
            this.Show()
    }

    HandleSelectionChange(*) {
        selectedIndex := this.listBox.Value
        if selectedIndex {
            this.state["selectedIndex"] := selectedIndex
            link := this.links[selectedIndex]
            if link.Has("isValid") && link["isValid"]
                this.SetStatus("Ready to open: " link["url"])
            else
                this.SetStatus("Warning: This URL may be invalid", "warning")
        }
    }

    SetStatus(message, type := "info") {
        if (type = "info")
            this.statusBar.Value := message
        else if (type = "warning")
            this.statusBar.Value := "⚠️ " message
        else if (type = "error")
            this.statusBar.Value := "❌ " message
        else if (type = "success")
            this.statusBar.Value := "✓ " message
    }

    ParseAndValidateLinks(linkData) {
        ; Parse multiline string to array of maps with link info
        links := []
        validUrlPattern := LinkManagerEx.Config["urlValidationPattern"]

        for line in StrSplit(linkData, "`n", "`r") {
            line := Trim(line)
            if (line != "") {
                ; Create a Map for each link with metadata
                linkInfo := Map(
                    "url", line,
                    "isValid", RegExMatch(line, validUrlPattern) > 0,
                    "hasProtocol", RegExMatch(line, "i)^https?://") > 0
                )
                links.Push(linkInfo)
            }
        }
        return links
    }

    GetLinkDisplayArray() {
        ; Create a display array for the listbox with formatting
        displayArray := []

        for index, link in this.links {
            ; Format: show (invalid) for invalid links
            if (link["isValid"])
                displayArray.Push(link["url"])
            else
                displayArray.Push(link["url"] " (invalid)")
        }

        return displayArray
    }

    OpenLink(*) {
        ; Get selected link
        selectedIndex := this.listBox.Value
        if (!selectedIndex) {
            this.SetStatus("No link selected", "warning")
            return
        }

        linkInfo := this.links[selectedIndex]
        link := linkInfo["url"]

        ; Validate URL and add https:// if missing
        if (!linkInfo["hasProtocol"]) {
            link := "https://" link
        }

        ; Display status
        this.SetStatus("Opening link...", "info")

        ; Try to open link in Edge
        try {
            Run("msedge.exe " link)
            this.SetStatus("Link opened successfully", "success")
        } catch {
            ; Fallback to default browser
            try {
                Run(link)
                this.SetStatus("Link opened in default browser", "info")
            } catch Error as e {
                this.SetStatus("Failed to open link: " e.Message, "error")
                MsgBox("Failed to open link: " e.Message, "Error", 16)
            }
        }
    }
}