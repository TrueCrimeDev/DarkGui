#Requires AutoHotkey v2.1-alpha.23

/**
 * Layout helper for DarkGui — eliminates manual pixel positioning.
 *
 * Usage:
 *   lay := Layout(400, 15, 10)         ; winW, margin, gap
 *   g.Add("Edit", lay.Row(26), "text") ; full-width row, h=26
 *   for pos in lay.Columns(2, 32)      ; two equal columns, h=32
 *       g.Add("Button", pos, "btn")
 */
class Layout {
    /**
     * @param {Integer} winW - Window content width
     * @param {Integer} margin - Left/right/top margin
     * @param {Integer} gap - Spacing between controls and rows
     */
    __New(winW, margin := 15, gap := 10) {
        this.winW := winW
        this.margin := margin
        this.gap := gap
        this.y := margin
        this.contentW := winW - margin * 2
    }

    /**
     * Full-width row. Returns options string and advances Y.
     * @param {Integer} h - Control height
     * @param {String} extra - Additional options (e.g. "+Multi", "Center")
     * @returns {String} Options string like "x15 y10 w370 h26"
     */
    Row(h := 26, extra := "") {
        opts := Format("x{} y{} w{} h{}", this.margin, this.y, this.contentW, h)
        if extra
            opts .= " " extra
        this.y += h + this.gap
        return opts
    }

    /**
     * Full-width row with custom width (less than full). Returns options string and advances Y.
     * @param {Integer} w - Control width
     * @param {Integer} h - Control height
     * @param {String} align - "left", "center", or "right"
     * @param {String} extra - Additional options
     * @returns {String} Options string
     */
    RowSized(w, h := 26, align := "left", extra := "") {
        switch align, false {
            case "center": x := this.margin + (this.contentW - w) // 2
            case "right":  x := this.margin + this.contentW - w
            default:       x := this.margin
        }
        opts := Format("x{} y{} w{} h{}", x, this.y, w, h)
        if extra
            opts .= " " extra
        this.y += h + this.gap
        return opts
    }

    /**
     * Split row into N equal columns. Returns array of options strings.
     * Does NOT advance Y — call Advance(h) after adding controls.
     * @param {Integer} n - Number of columns
     * @param {Integer} h - Control height
     * @param {String} extra - Additional options applied to all columns
     * @returns {Array} Array of options strings, one per column
     */
    Columns(n, h := 26, extra := "") {
        colW := (this.contentW - (n - 1) * this.gap) // n
        result := []
        loop n {
            x := this.margin + (A_Index - 1) * (colW + this.gap)
            opts := Format("x{} y{} w{} h{}", x, this.y, colW, h)
            if extra
                opts .= " " extra
            result.Push(opts)
        }
        return result
    }

    /**
     * Two-column row with explicit left/right widths. Returns [leftOpts, rightOpts].
     * Does NOT advance Y — call Advance(h) after adding controls.
     * @param {Integer} leftW - Left column width
     * @param {Integer} h - Control height
     * @param {String} extra - Additional options
     * @returns {Array} [leftOpts, rightOpts]
     */
    Split(leftW, h := 26, extra := "") {
        rightW := this.contentW - leftW - this.gap
        leftOpts := Format("x{} y{} w{} h{}", this.margin, this.y, leftW, h)
        rightOpts := Format("x{} y{} w{} h{}", this.margin + leftW + this.gap, this.y, rightW, h)
        if extra {
            leftOpts .= " " extra
            rightOpts .= " " extra
        }
        return [leftOpts, rightOpts]
    }

    /**
     * Label + control row. Returns [labelOpts, controlOpts] and advances Y.
     * @param {Integer} labelW - Label width
     * @param {Integer} h - Control height
     * @param {String} extra - Additional options for the control (not the label)
     * @returns {Array} [labelOpts, controlOpts]
     */
    LabelRow(labelW := 80, h := 26, extra := "") {
        controlW := this.contentW - labelW - this.gap
        labelOpts := Format("x{} y{} w{} h{}", this.margin, this.y, labelW, h)
        controlOpts := Format("x{} y{} w{} h{}", this.margin + labelW + this.gap, this.y, controlW, h)
        if extra
            controlOpts .= " " extra
        this.y += h + this.gap
        return [labelOpts, controlOpts]
    }

    /**
     * Right-aligned button row. Returns array of options strings and advances Y.
     * @param {Integer|Array} widths - Single width for all buttons, or array of widths
     * @param {Integer} n - Number of buttons (ignored if widths is array)
     * @param {Integer} h - Button height
     * @returns {Array} Array of options strings, right-aligned
     */
    ButtonRow(widths, n := 2, h := 32) {
        if widths is Integer {
            ws := []
            loop n
                ws.Push(widths)
            widths := ws
        }
        n := widths.Length
        totalW := 0
        for w in widths
            totalW += w
        totalW += (n - 1) * this.gap

        x := this.margin + this.contentW - totalW
        result := []
        for w in widths {
            result.Push(Format("x{} y{} w{} h{}", x, this.y, w, h))
            x += w + this.gap
        }
        this.y += h + this.gap
        return result
    }

    /**
     * Advance Y by height + gap without emitting a control.
     * @param {Integer} h - Height to advance
     */
    Advance(h) {
        this.y += h + this.gap
    }

    /**
     * Add vertical spacing without a control.
     * @param {Integer} px - Extra pixels to add (default: gap)
     */
    Space(px?) {
        this.y += px ?? this.gap
    }

    /**
     * Section header — returns a full-width text options string with small top spacing.
     * @param {Integer} h - Text height
     * @returns {String} Options string
     */
    Section(h := 20) {
        opts := Format("x{} y{} w{} h{}", this.margin, this.y, this.contentW, h)
        this.y += h + this.gap // 2
        return opts
    }

    /**
     * Returns the current Y position (read-only peek).
     */
    CurrentY => this.y

    /**
     * Returns remaining height given a total window height.
     * @param {Integer} winH - Total window height
     * @returns {Integer} Pixels remaining from current Y to bottom margin
     */
    Remaining(winH) => winH - this.y - this.margin
}
