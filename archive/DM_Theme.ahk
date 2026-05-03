#Requires AutoHotkey v2.0
#SingleInstance Force
#Include Lib/ImageHandler.ahk

; --- Configuration Classes ---
class Config {
    static VERSION := "1.0.0"
    static MIN_WIDTH := 400
    static MIN_HEIGHT := 300

    ; GUI Element dimensions
    static MARGIN := 20
    static IMAGE_MARGIN := 0  ; Marge spécifique pour les images, réduite à 0
    static BUTTON_HEIGHT := 30
    static TOP_BUTTON_SIZE := 24

    ; Image display specific settings
    static IMAGE_MODE := {
        MIN_WIDTH: 200,        ; Largeur minimale en mode image
        MIN_HEIGHT: 150,       ; Hauteur minimale en mode image
        MAX_SCREEN_RATIO: 0.8  ; Ratio maximum de l'écran qu'une image peut occuper
    }

    ; Supported file types
    static IMAGE_EXTENSIONS := ["jpg", "jpeg", "png", "gif", "bmp", "webp"]
    static VIDEO_EXTENSIONS := ["mp4", "avi", "mkv", "mov", "wmv"]
}

; --- Theme Configuration ---
class Theme {
    static Dark := {
        background: "0x2A2A2A",
        text: "0xE0E0E0",
        buttonBg: "0x404040",
        buttonText: "0xFFFFFF",
        markdownBg: "0x333333",
        imageBg: "0xFFFFFF",
        saveButtonUnsaved: "0xFF4444",
        saveButtonSaved: "0x4CAF50",
        statusText: "0xE0E0E0"
    }

    static Light := {
        background: "0xF8F8F8",
        text: "0x333333",
        buttonBg: "0xD4D4D4",
        buttonText: "0x000000",
        markdownBg: "0xEEEEEE",
        imageBg: "0xFFFFFF",
        saveButtonUnsaved: "0xFF6666",
        saveButtonSaved: "0x90EE90",
        statusText: "0x333333"
    }
}

class AppState {
    static Instance := AppState()

    __New() {
        this.currentFile := ""
        this.isDarkMode := true
        this.isMarkdownRendered := false
        this.hasUnsavedChanges := false
        this.markdownHandler := ""

        ; GUI elements
        this.previewGui := ""
        this.previewEdit := ""
        this.saveBtn := ""
        this.closeTextBtn := ""
        this.themeBtn := ""
        this.markdownBtn := ""
        this.markdownView := ""
        this.previewPic := ""
        this.previousThemeState := ""

        this.InitializeGUI()
    }

    InitializeGUI() {
        ; Création de la GUI principale
        this.previewGui := Gui("+Resize +MinSize" Config.MIN_WIDTH "x" Config.MIN_HEIGHT, "")

        ; Création des contrôles
        this.previewEdit := this.previewGui.Add("Edit", "x" Config.MARGIN " y40 w760 h560 +Multi +WantTab")
        this.saveBtn := this.previewGui.Add("Button", "x10 y610 w100 h" Config.BUTTON_HEIGHT, "Save")
        this.closeTextBtn := this.previewGui.Add("Button", "x120 y610 w100 h" Config.BUTTON_HEIGHT, "Close")
        this.themeBtn := this.previewGui.Add("Button", "x740 y10 w" Config.TOP_BUTTON_SIZE " h" Config.TOP_BUTTON_SIZE,
            "🌓")
        this.markdownBtn := this.previewGui.Add("Button", "x710 y10 w" Config.TOP_BUTTON_SIZE " h" Config.TOP_BUTTON_SIZE,
            "🔄")
        this.markdownView := this.previewGui.Add("Edit", "x" Config.MARGIN " y40 w760 h560 +ReadOnly +Multi Hidden")
        this.previewPic := this.previewGui.Add("Pic", "x" Config.MARGIN " y40 w760 h560 Hidden")

        ; Initialisation de l'image handler
        this.previewGui.imageHandler := ImageHandler(this.previewGui, this.previewPic)

        ; Initialisation du Markdown Handler
        this.markdownHandler := MarkdownHandlerx(this.previewGui, this.previewEdit, this.markdownView)

        ; Configuration des événements
        this.themeBtn.OnEvent("Click", this.ToggleTheme.Bind(this))
        this.markdownBtn.OnEvent("Click", this.ToggleMarkdownMode.Bind(this))
        this.saveBtn.OnEvent("Click", this.SaveFile.Bind(this))
        this.closeTextBtn.OnEvent("Click", this.ClosePreview.Bind(this))
        this.previewGui.OnEvent("Size", this.GuiResize.Bind(this))
        this.previewEdit.OnEvent("Change", this.TextChanged.Bind(this))

        ; Appliquer le thème initial
        this.ApplyTheme()

        HotIfWinActive("ahk_id " this.previewGui.Hwnd)
        Hotkey("^s", this.SaveFile.Bind(this))
        HotIf()
    }

    ToggleMarkdownMode(*) {
        if (this.currentFile = "") {
            return
        }

        this.markdownBtn.Text := this.markdownHandler.ToggleMode()
        this.ApplyTheme()
    }

    ToggleTheme(*) {
        this.isDarkMode := !this.isDarkMode
        this.ApplyTheme()
    }

    TextChanged(*) {
        if !this.hasUnsavedChanges {
            this.hasUnsavedChanges := true
            this.UpdateSaveButtonState()

            ; Mettre à jour le titre avec le point
            if this.currentFile {
                SplitPath(this.currentFile, &fileName)
                this.previewGui.Title := "● " fileName
            }
        }

        this.markdownHandler.UpdateContent()
    }

    UpdateSaveButtonState() {
        colors := this.isDarkMode ? Theme.Dark : Theme.Light
        this.saveBtn.Opt("Background" (this.hasUnsavedChanges ? colors.saveButtonUnsaved : colors.buttonBg))
    }

    ApplyTheme() {
        colors := this.isDarkMode ? Theme.Dark : Theme.Light

        if (this.previewPic.Visible) {
            return
        }

        this.previewGui.BackColor := colors.background

        if (!this.isMarkdownRendered) {
            this.previewEdit.Opt("Background" colors.background " c" colors.text)
        }
        else {
            this.markdownView.Opt("Background" colors.markdownBg " c" colors.text)
        }

        ; Style des boutons
        for btn in [this.themeBtn, this.markdownBtn, this.saveBtn, this.closeTextBtn] {
            btn.Opt("Background" colors.buttonBg " c" colors.buttonText)
        }

        this.UpdateSaveButtonState()
    }

    SaveFile(*) {
        if (this.currentFile = "") {
            return
        }

        try {
            if fileHandle := FileOpen(this.currentFile, "w", "UTF-8") {
                fileHandle.Write(this.previewEdit.Value)
                fileHandle.Close()

                this.hasUnsavedChanges := false
                this.UpdateSaveButtonState()

                ; Mettre à jour le titre sans le point
                SplitPath(this.currentFile, &fileName)
                this.previewGui.Title := fileName

                ; Feedback visuel temporaire
                colors := this.isDarkMode ? Theme.Dark : Theme.Light
                this.saveBtn.Opt("Background" colors.saveButtonSaved)
                SetTimer(() => this.UpdateSaveButtonState(), -2000)
            } else {
                throw Error("Impossible d'ouvrir le fichier en écriture")
            }
        } catch as err {
            MsgBox("Échec de la sauvegarde: " err.Message)
        }
    }

    ShowPreview(*) {
        files := FileHandler.GetSelectedFiles()

        if files.Length = 0 {
            return
        }

        this.currentFile := files[files.Length]
        SplitPath(this.currentFile, &fileName, &fileDir, &fileExt)
        fileExt := StrLower(fileExt)

        ; Cacher la GUI pendant les modifications pour éviter les artefacts visuels
        this.previewGui.Hide()

        if (FileHandler.IsImageFile(fileExt)) {
            this.OpenImageFile(this.currentFile, fileName)
        } else if (FileHandler.IsVideoFile(fileExt)) {
            Run(this.currentFile)
        } else {
            this.OpenTextFile(this.currentFile, fileName)
        }
    }

    OpenTextFile(filePath, fileName) {
        try {
            if fileHandle := FileOpen(filePath, "rw", "UTF-8") {
                content := fileHandle.Read()
                fileHandle.Close()

                this.ResetGUIForTextMode()

                this.previewEdit.Value := content
                this.previewGui.Title := fileName  ; Pas de point car fichier pas modifié

                this.hasUnsavedChanges := false
                this.UpdateSaveButtonState()

                this.previewGui.Show("Center")
            }
        } catch as err {
            MsgBox("Impossible d'ouvrir le fichier: " err.Message)
        }
    }

    OpenImageFile(filePath, fileName) {
        try {
            this.previousThemeState := this.isDarkMode

            ; Cacher les contrôles texte
            this.previewEdit.Visible := false
            this.markdownView.Visible := false
            this.saveBtn.Visible := false
            this.closeTextBtn.Visible := false
            this.themeBtn.Visible := false
            this.markdownBtn.Visible := false

            ; Nettoyer l'image précédente
            this.previewPic.Value := ""

            ; Configurer l'arrière-plan et afficher l'image
            this.previewGui.BackColor := Theme.Light.imageBg
            this.previewPic.Visible := true

            ; Charger et afficher l'image avec les nouvelles configurations
            dimensions := this.previewGui.imageHandler.LoadImage(filePath)
            if dimensions {
                ; Les marges sont maintenant gérées par ImageHandler
                this.previewGui.Move(, , dimensions.windowWidth, dimensions.windowHeight)
            }

            this.previewGui.Show("Center")
        } catch as err {
            MsgBox("Error loading image: " err.Message)
        }
    }

    ResetGUIForTextMode() {
        this.previewPic.Visible := false
        this.previewPic.Value := ""
        this.previewEdit.Visible := true
        this.saveBtn.Visible := true
        this.closeTextBtn.Visible := true
        this.themeBtn.Visible := true
        this.markdownBtn.Visible := true

        ; Restore theme
        this.ApplyTheme()

        this.previewGui.Move(, , 800, 680)
        this.previewEdit.Move(Config.MARGIN, 40, 760, 540)
        this.themeBtn.Move(740, 10)
        this.markdownBtn.Move(710, 10)
        this.saveBtn.Move(10, 610)
        this.closeTextBtn.Move(120, 610)
    }

    GuiResize(thisGui, minMax, width, height) {
        if (this.previewPic.Visible) {
            ; Calculate available space considering margins
            availableWidth := width - (Config.IMAGE_MARGIN * 2)
            availableHeight := height - (Config.IMAGE_MARGIN * 2)

            ; Update image position and size with margins
            thisGui.imageHandler.HandleResize(minMax, availableWidth, availableHeight)
        } else {
            if (minMax = -1)
                return

            buttonHeight := Config.BUTTON_HEIGHT
            padding := Config.MARGIN

            editHeight := height - (buttonHeight + padding * 3 + 20)

            this.previewEdit.Move(padding, 40, width - padding * 2, editHeight)
            this.markdownView.Move(padding, 40, width - padding * 2, editHeight)

            this.themeBtn.Move(width - 60, 10)
            this.markdownBtn.Move(width - 90, 10)
            this.saveBtn.Move(10, height - (buttonHeight + padding))
            this.closeTextBtn.Move(120, height - (buttonHeight + padding))
        }
    }

    ClosePreview(*) {
        this.previewGui.imageHandler.Cleanup()
        this.previewGui.Hide()
    }
}

; --- File Handler Class ---
class FileHandler {
    static GetSelectedFiles() {
        selection := []
        activeHwnd := WinExist("A")
        winClass := WinGetClass("ahk_id " activeHwnd)
        
        ; Vérifie si nous sommes sur le Bureau ou dans l'Explorateur
        if !(winClass ~= "((Cabinet|Explore)WClass|WorkerW|Progman)")
            return selection

        try {
            ; Gestion du Bureau
            if (winClass = "WorkerW" || winClass = "Progman") {
                root := (SubStr(A_Desktop, -1) == "\") ? SubStr(A_Desktop, 1, -1) : A_Desktop
                items := ListViewGetContent("Selected", "SysListView321", activeHwnd)
                if (items) {
                    loop parse items, "`n", "`r" {
                        fileName := SubStr(A_LoopField, 1, InStr(A_LoopField, Chr(9)) - 1)
                        if (fileName) {
                            fullPath := root "\" fileName
                            ; Vérifie si c'est un fichier et non un dossier
                            if !DirExist(fullPath)
                                selection.Push(fullPath)
                        }
                    }
                }
            }
            ; Gestion de l'Explorateur Windows
            else {
                try {
                    ; Obtient la fenêtre de l'onglet actif
                    activeWindow := this.GetActiveExplorerTab(activeHwnd)
                    if (activeWindow && activeWindow.Document) {
                        ; Obtient tous les éléments sélectionnés dans l'onglet actif
                        for item in activeWindow.Document.SelectedItems {
                            ; Vérifie si c'est un fichier et non un dossier
                            if !DirExist(item.Path) {
                                fileExt := this.GetFileExtension(item.Path)
                                selection.Push(item.Path)
                            }
                        }
                    }
                }
            }
        } catch Error as err {
            ; Gestion silencieuse des erreurs
            ; MsgBox("Erreur : " err.Message)  ; Décommenter pour le débug
        }
        return selection
    }

    ; https://www.autohotkey.com/boards/viewtopic.php?f=82&t=133219&p=585245&hilit=Explorer+tabs+SelectedItems#p585245
    static GetActiveExplorerTab(hwnd) {
        try {
            ; Try to get the active tab control handle for Windows 11
            activeTab := ControlGetHwnd("ShellTabWindowClass1", hwnd)
        } catch {
            try {
                ; Fallback for earlier Windows versions
                activeTab := ControlGetHwnd("TabWindowClass1", hwnd)
            }
        }
    
        ; Create a Shell.Application COM object to interact with Explorer windows
        shell := ComObject("Shell.Application")
    
        ; Iterate through all open Explorer windows
        for window in shell.Windows {
            ; Skip if this is not our target window
            if (window.hwnd != hwnd)
                continue
                
            ; If we found tabs in the window
            if IsSet(activeTab) {
                ; GUID for IShellBrowser interface - allows us to interact with Explorer window
                static IID_IShellBrowser := "{000214E2-0000-0000-C000-000000000046}"
                
                ; Get the IShellBrowser interface of the current window
                ; This gives us access to low-level Explorer window functionality
                IShellBrowser := ComObjQuery(window, IID_IShellBrowser, IID_IShellBrowser)
                
                ; Call the GetWindow method (index 3) of IShellBrowser
                ; This gets us the handle of the current tab being examined
                ComCall(3, IShellBrowser, "uint*", &thisTab := 0)  ; GetWindow
                
                ; If this tab is not the active one we detected earlier,
                ; skip to the next window
                if (thisTab != activeTab)
                    continue
            }
            ; Return the window object when we found the right one
            return window
        }
        ; Return empty string if no matching window was found
        return ""
    }

    static GetFileExtension(filePath) {
        SplitPath(filePath,, &dir,, &nameNoExt, &ext)
        return ext
    }

    static IsImageFile(ext) {
        return HasVal(Config.IMAGE_EXTENSIONS, ext)
    }

    static IsVideoFile(ext) {
        return HasVal(Config.VIDEO_EXTENSIONS, ext)
    }
}

class MarkdownHandlerx {
    __New(gui, editControl, markdownView) {
        this.gui := gui
        this.editControl := editControl
        this.markdownView := markdownView
        this.isRendered := false
    }

    ToggleMode() {
        this.isRendered := !this.isRendered

        if (this.isRendered) {
            renderedContent := this.RenderMarkdown(this.editControl.Value)
            this.markdownView.Value := renderedContent
            this.editControl.Visible := false
            this.markdownView.Visible := true
            return "📝"  ; Icon for raw mode
        } else {
            this.editControl.Visible := true
            this.markdownView.Visible := false
            return "🔄"  ; Icon for rendered mode
        }
    }

    RenderMarkdown(content) {
        ; Basic markdown rendering implementation
        renderedContent := content

        ; Headers
        renderedContent := RegExReplace(renderedContent, "m)^# (.+)$",
            "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n$1`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        renderedContent := RegExReplace(renderedContent, "m)^## (.+)$", "▶ $1")
        renderedContent := RegExReplace(renderedContent, "m)^### (.+)$", "→ $1")

        ; Bold and Italic
        renderedContent := RegExReplace(renderedContent, "\*\*(.+?)\*\*", "【$1】")
        renderedContent := RegExReplace(renderedContent, "\*(.+?)\*", "「$1」")

        ; Lists
        renderedContent := RegExReplace(renderedContent, "m)^- (.+)$", "• $1")
        renderedContent := RegExReplace(renderedContent, "m)^\d\. (.+)$", "○ $1")

        return renderedContent
    }

    GetCurrentMode() {
        return this.isRendered
    }

    UpdateContent() {
        if (this.isRendered) {
            this.markdownView.Value := this.RenderMarkdown(this.editControl.Value)
        }
    }
}

; --- Utility Functions ---
HasVal(arr, val) {
    for index, value in arr {
        if (value = val)
            return true
    }
    return false
}

; Modifier le hotkey p5our inclure le bureau
#HotIf WinActive("ahk_class CabinetWClass") or WinActive("ahk_class ExploreWClass") or WinActive("ahk_class WorkerW") or
WinActive("ahk_class Progman")
5::AppState.Instance.ShowPreview()
#HotIf