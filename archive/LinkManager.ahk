#Requires AutoHotkey v2.1-alpha.16
#SingleInstance Force
#Include Lib\_Dark.ahk

LinkManager()

class LinkManager {
    static Config := Map(
        "title", "Link Manager",
        "width", 600,
        "height", 400,
        "defaultLinks", "www.google.com`nwww.amazon.com`nhttps://github.com/TrueCrimeAudit/ClautoHotkey`nhttps://www.autohotkey.com/boards/viewtopic.php?f=96&t=120588"
    )

    __New() {
        this.links := []
        this.InitializeGui()
        this.ParseLinks(LinkManager.Config["defaultLinks"])
        this.PopulateListBox()
        this.SetupHotkeys()
    }

    InitializeGui() {
        this.gui := Gui("+Resize +MinSize600x300", LinkManager.Config["title"])
        this.gui.BackColor := "1F1F1F"
        this.gui.SetFont("s10 cFFFFFF", "Segoe UI")
        this.darkMode := _Dark(this.gui)
        
        this.gui.OnEvent("Size", this.GuiSize.Bind(this))
        this.gui.OnEvent("Close", this.GuiClose.Bind(this))
        this.gui.OnEvent("Escape", this.GuiEscape.Bind(this))
        
        this.gui.AddText("xm y10", "Links:")
        this.linkListBox := this.gui.AddListBox("xm y+5 w580 h340 vLinkList")
        this.linkListBox.OnEvent("DoubleClick", this.OpenLink.Bind(this))
        
        this.openButton := this.darkMode.AddDarkButton("xm y+10 w120", "Open Link")
        this.openButton.OnEvent("Click", this.OpenLink.Bind(this))
        
        this.refreshButton := this.darkMode.AddDarkButton("x+10 yp w120", "Refresh Links")
        this.refreshButton.OnEvent("Click", this.RefreshLinks.Bind(this))
        
        this.gui.Show("w" LinkManager.Config["width"] " h" LinkManager.Config["height"])
    }
    
    GuiSize(thisGui, minMax, width, height) {
        if (minMax = -1)
            return
        
        leftMargin := 10
        rightMargin := 10
        topMargin := 40
        bottomMargin := 60
        
        listBoxWidth := width - leftMargin - rightMargin
        listBoxHeight := height - topMargin - bottomMargin
        
        this.linkListBox.Move(leftMargin, topMargin, listBoxWidth, listBoxHeight)
        
        buttonY := topMargin + listBoxHeight + 10
        this.openButton.Move(leftMargin, buttonY)
        this.refreshButton.Move(leftMargin + 130, buttonY)
    }
    
    GuiClose(*) {
        this.gui.Hide()
    }
    
    GuiEscape(*) {
        this.gui.Hide()
    }
    
    SetupHotkeys() {
        HotIfWinActive("ahk_id " this.gui.Hwnd)
        Hotkey("Enter", this.EnterPressed.Bind(this))
        HotIfWinActive()
    }
    
    EnterPressed(*) {
        this.OpenLink()
    }
    
    ParseLinks(linksText) {
        this.links := []
        
        urlRegex := "i)^(https?://)?(www\.)?[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,}(:[0-9]{1,5})?(/.*)?"
        
        lines := StrSplit(linksText, "`n", "`r")
        
        for line in lines {
            line := Trim(line)
            if (line = "")
                continue
                
            if RegExMatch(line, urlRegex) {
                if (!InStr(line, "://"))
                    line := "https://" line
                    
                this.links.Push(line)
            }
        }
    }
    
    PopulateListBox() {
        this.linkListBox.Delete()
        
        for link in this.links
            this.linkListBox.Add([link])
            
        if (this.links.Length > 0)
            this.linkListBox.Choose(1)
    }
    
    RefreshLinks(*) {
        this.ParseLinks(LinkManager.Config["defaultLinks"])
        this.PopulateListBox()
    }
    
    OpenLink(*) {
        selectedIndex := this.linkListBox.Value
        
        if (selectedIndex < 1 || selectedIndex > this.links.Length) {
            MsgBox("Please select a link first.", "No Link Selected", "Icon!")
            return
        }
        
        selectedLink := this.links[selectedIndex]
        
        try {
            this.OpenInEdge(selectedLink)
        } catch as err {
            this.FallbackBrowserOpen(selectedLink, err)
        }
    }
    
    OpenInEdge(url) {
        edgePath := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
        if !FileExist(edgePath)
            edgePath := "msedge.exe"
            
        Run(edgePath " " url)
    }
    
    FallbackBrowserOpen(url, err) {
        try {
            Run(url)
        } catch as fallbackErr {
            MsgBox("Failed to open link: " url "`n`nError: " fallbackErr.Message, 
                   "Browser Error", "Icon!")
        }
    }
}