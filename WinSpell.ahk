/*
WinSpell.ahk — native Windows Spell Checking API wrapper for AutoHotkey v2.1

Wraps the in-box COM spell-check engine (MsSpellCheckingFacility.dll,
spellcheck.h) that ships with Windows 8 and later. Zero external
dependencies: no Hunspell, no Word automation, no bundled DLLs or
dictionary files.

Usage:
  #Include WinSpell.ahk
  spell := WinSpell("en-US")
  for err in spell.Check("I recieved teh mesage")
      MsgBox(err.word " -> " (err.replacement != "" ? err.replacement : spell.Suggest(err.word)[1]))

Public API:
  WinSpell(lang := "en-US")
  .Check(text)               -> Array of {word, start, len, action, replacement}
  .ComprehensiveCheck(text)  -> same shape as Check (heavier engine pass)
  .Suggest(word)             -> Array of suggestion strings
  .Add(word), .Ignore(word), .AutoCorrect(from, to)
  .Remove(word)              -> ISpellChecker2 (Windows 10+)
  .SupportedLanguages()      -> Array of BCP-47 tags
  .RegisterDictionary(path, lang), .UnregisterDictionary(path, lang)

Notes:
  The calling thread must have COM initialized (AutoHotkey's main thread
  already initializes STA, so no CoInitializeEx is needed there).
  All interface methods are invoked through ComCall by zero-based vtable
  index; Microsoft's docs list methods alphabetically, not in vtable order.
*/
#Requires AutoHotkey v2.1-alpha.30

/**
 * Wrapper around ISpellCheckerFactory / ISpellChecker from spellcheck.h.
 * Interface pointers are held as ComValue(0xD, ptr) (VT_UNKNOWN) wrappers,
 * so AutoHotkey releases each reference exactly once when the wrapper is
 * freed — never call ObjRelease on them manually.
 */
class WinSpell {
    ; COM identifiers (spellcheck.h)
    static CLSID_SpellCheckerFactory      := "{7AB36653-1796-484B-BDFA-E74F1DB7C1DC}"
    static IID_ISpellCheckerFactory       := "{8E018A9D-2415-4677-BF08-794EA61F94BB}"
    static IID_ISpellChecker              := "{B6FD0B71-E2BC-4653-8D05-F197E412770B}"
    static IID_ISpellChecker2             := "{E7ED1C71-87F7-4378-A840-C9200DACEE47}"
    static IID_IEnumSpellingError         := "{803E3BD4-2828-4410-8290-418D1D73C762}"
    static IID_ISpellingError             := "{B7C82D61-FBE8-4B47-9B27-6C0D2E0DE0A3}"
    static IID_IUserDictionariesRegistrar := "{AA176B85-0E12-4844-8E1A-EEF1DA77F586}"

    ; CORRECTIVE_ACTION values reported in the `action` field of Check results
    static ACTION_NONE            := 0
    static ACTION_GET_SUGGESTIONS := 1
    static ACTION_REPLACE         := 2
    static ACTION_DELETE          := 3

    /** @type {String} BCP-47 tag the checker was created for */
    Lang := ""

    _factory := ""
    _checker := ""

    /**
     * Creates the spell-checker factory and an ISpellChecker for `lang`.
     * @param {String} lang BCP-47 language tag, e.g. "en-US"
     * @throws {ValueError} if no dictionary for `lang` is installed
     */
    __New(lang := "en-US") {
        ; ComObject(CLSID, IID) with a non-IDispatch IID returns a VT_UNKNOWN
        ; ComValue wrapper; the reference is released when the wrapper is freed.
        this._factory := ComObject(WinSpell.CLSID_SpellCheckerFactory, WinSpell.IID_ISpellCheckerFactory)

        ComCall(4, this._factory, "wstr", lang, "int*", &supported := 0)    ; ISpellCheckerFactory::IsSupported
        if !supported
            throw ValueError("No spell-checking dictionary is installed for this language tag.", -1, lang)

        ComCall(5, this._factory, "wstr", lang, "ptr*", &pChecker := 0)     ; ISpellCheckerFactory::CreateSpellChecker
        if !pChecker
            throw Error("CreateSpellChecker succeeded but returned a null ISpellChecker.", -1)
        this._checker := ComValue(0xD, pChecker)
        this.Lang := lang
    }

    /** Releases the held ISpellChecker and ISpellCheckerFactory references. */
    __Delete() {
        ; Dropping each ComValue wrapper releases its interface exactly once.
        this._checker := ""
        this._factory := ""
    }

    /**
     * Spell-checks `text`.
     * @returns {Array} objects with word, start (0-based), len, action
     *   (CORRECTIVE_ACTION), replacement ("" unless action = ACTION_REPLACE)
     */
    Check(text) => this._RunCheck(4, text)                                  ; ISpellChecker::Check

    /**
     * Spell-checks `text` with the engine's heavier, more thorough pass.
     * Same result shape as Check().
     */
    ComprehensiveCheck(text) => this._RunCheck(16, text)                    ; ISpellChecker::ComprehensiveCheck

    /**
     * Retrieves spelling suggestions for a single word.
     * @returns {Array} suggestion strings, best first (may be empty)
     */
    Suggest(word) {
        ComCall(5, this._checker, "wstr", word, "ptr*", &pEnum := 0)        ; ISpellChecker::Suggest
        if !pEnum
            return []
        return WinSpell._CollectStrings(ComValue(0xD, pEnum))
    }

    /** Adds `word` to the user's default dictionary for this language. */
    Add(word) => ComCall(6, this._checker, "wstr", word)                    ; ISpellChecker::Add

    /** Ignores `word` for the lifetime of this checker instance. */
    Ignore(word) => ComCall(7, this._checker, "wstr", word)                 ; ISpellChecker::Ignore

    /** Registers a persistent autocorrect pair: `from` is always replaced by `to`. */
    AutoCorrect(from, to) => ComCall(8, this._checker, "wstr", from, "wstr", to)    ; ISpellChecker::AutoCorrect

    /**
     * Removes a previously added word from the user's default dictionary.
     * Requires ISpellChecker2 (Windows 10+).
     * @throws {Error} on Windows 8/8.1, where the interface is unavailable
     */
    Remove(word) {
        checker2 := ComObjQuery(this._checker, WinSpell.IID_ISpellChecker2)
        ComCall(17, checker2, "wstr", word)                                 ; ISpellChecker2::Remove
    }

    /**
     * Lists every language the local engine can spell-check.
     * @returns {Array} BCP-47 tags, e.g. ["en-US", "fr-FR", ...]
     */
    SupportedLanguages() {
        ComCall(3, this._factory, "ptr*", &pEnum := 0)                      ; ISpellCheckerFactory::get_SupportedLanguages
        if !pEnum
            return []
        return WinSpell._CollectStrings(ComValue(0xD, pEnum))
    }

    /**
     * Registers a plain-text UTF-16LE .dic word list (one word per line) as
     * a persistent user dictionary for `lang`. Unlike per-word Add(), the
     * registration survives restarts and applies system-wide for this user.
     */
    RegisterDictionary(path, lang) {
        registrar := ComObjQuery(this._factory, WinSpell.IID_IUserDictionariesRegistrar)
        ComCall(3, registrar, "wstr", path, "wstr", lang)                   ; IUserDictionariesRegistrar::RegisterUserDictionary
    }

    /** Undoes RegisterDictionary for the same path and language tag. */
    UnregisterDictionary(path, lang) {
        registrar := ComObjQuery(this._factory, WinSpell.IID_IUserDictionariesRegistrar)
        ComCall(4, registrar, "wstr", path, "wstr", lang)                   ; IUserDictionariesRegistrar::UnregisterUserDictionary
    }

    /**
     * Runs Check (vtable 4) or ComprehensiveCheck (vtable 16) and drains the
     * resulting IEnumSpellingError. Correct text yields an empty (not null)
     * enumeration, so this returns [] for clean input.
     */
    _RunCheck(vtableIndex, text) {
        results := []
        ComCall(vtableIndex, this._checker, "wstr", text, "ptr*", &pEnum := 0)
        if !pEnum
            return results
        enum := ComValue(0xD, pEnum)
        ; IEnumSpellingError::Next — S_OK (0) delivered an error object,
        ; S_FALSE (1) is the normal end-of-enumeration terminator.
        while ComCall(3, enum, "ptr*", &pError := 0) = 0 && pError {
            spellingError := ComValue(0xD, pError)
            ComCall(3, spellingError, "uint*", &start := 0)                 ; ISpellingError::get_StartIndex
            ComCall(4, spellingError, "uint*", &len := 0)                   ; ISpellingError::get_Length
            ComCall(5, spellingError, "int*", &action := 0)                 ; ISpellingError::get_CorrectiveAction
            replacement := ""
            if action = WinSpell.ACTION_REPLACE {
                ComCall(6, spellingError, "ptr*", &pReplacement := 0)       ; ISpellingError::get_Replacement
                replacement := WinSpell._TakeCoTaskString(pReplacement)
            }
            results.Push({
                word: SubStr(text, start + 1, len),
                start: start,
                len: len,
                action: action,
                replacement: replacement
            })
        }
        return results
    }

    /**
     * Drains an IEnumString into an Array, one element per Next(celt = 1)
     * call, freeing each returned LPOLESTR with CoTaskMemFree.
     */
    static _CollectStrings(enum) {
        results := []
        ; IEnumString::Next — S_OK (0) fetched one string, S_FALSE (1) ends.
        while ComCall(3, enum, "uint", 1, "ptr*", &pStr := 0, "uint*", &fetched := 0) = 0 {
            if !fetched || !pStr
                break
            results.Push(WinSpell._TakeCoTaskString(pStr))
        }
        return results
    }

    /** Reads a caller-freed LPWSTR/LPOLESTR and releases it with CoTaskMemFree. */
    static _TakeCoTaskString(ptr) {
        if !ptr
            return ""
        str := StrGet(ptr, "UTF-16")
        DllCall("ole32\CoTaskMemFree", "ptr", ptr)
        return str
    }
}

; ---------------------------------------------------------------------------
; Demo — runs only when this file is executed directly, not when #Included.
; ---------------------------------------------------------------------------
if A_ScriptFullPath = A_LineFile
    WinSpell_Demo()

WinSpell_Demo() {
    text := "I recieved teh mesage"
    spell := WinSpell("en-US")
    lines := ""
    for err in spell.Check(text) {
        fix := err.replacement
        if fix = "" {
            suggestions := spell.Suggest(err.word)
            fix := suggestions.Length ? suggestions[1] : "(no suggestion)"
        }
        lines .= err.word " -> " fix "`n"
    }
    if lines = ""
        lines := "No spelling errors found.`n"
    try FileAppend(lines, "*")      ; stdout, when a console is attached
    MsgBox(RTrim(lines, "`n"), "WinSpell demo")
}
