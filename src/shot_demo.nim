## Snap a screenshot of the full demo window.
import std/[os, osproc, parseopt, strformat, strutils]
import nim_tk_gtk

# Re-use the full demo construction by importing demo's builders. We can't
# easily import demo.nim (it's an application, not a module), so call the
# exact Tcl commands the demo runs.

proc main() =
  var style: GtkStyle = Gtk4
  var dark = false
  var outPath = "/tmp/nim_full.png"
  for kind, key, val in getopt(commandLineParams()):
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "style", "s": style = if val == "gtk3": Gtk3 else: Gtk4
      of "dark", "d":  dark = true
      of "out", "o":   outPath = val
    else: discard

  let app = newApp(style = style, dark = dark, width = 780, height = 620)

  # Build the same UI as demo.nim but inline.
  app.headerBar(".hb", title = "Preferences",
                subtitle = "Demo of the Nim Tk GTK skin")
  discard app.eval("""
    ttk::button .hb.inner.leading.menu -text "☰" -style Flat.TButton -width 3
    pack .hb.inner.leading.menu -side left
    ttk::button .hb.inner.trailing.search -text "⌕" -style Flat.TButton -width 3
    ttk::button .hb.inner.trailing.more   -text "⋮" -style Flat.TButton -width 3
    pack .hb.inner.trailing.search .hb.inner.trailing.more -side left -padx 2
    pack .hb -fill x

    ttk::notebook .nb
    pack .nb -fill both -expand 1 -padx 16 -pady 16

    ttk::frame .nb.ctl -padding 16
    .nb add .nb.ctl -text Controls

    ttk::label .nb.ctl.h1 -text Buttons -style Title.TLabel
    grid .nb.ctl.h1 -row 0 -column 0 -sticky w -pady {0 8} -columnspan 3

    ttk::frame .nb.ctl.bts
    grid .nb.ctl.bts -row 1 -column 0 -sticky w -columnspan 3 -pady {0 20}
    ttk::button .nb.ctl.bts.a -text Default
    ttk::button .nb.ctl.bts.b -text Save   -style Suggested.TButton
    ttk::button .nb.ctl.bts.c -text Delete -style Destructive.TButton
    ttk::button .nb.ctl.bts.d -text "Learn more" -style Link.TButton
    pack .nb.ctl.bts.a .nb.ctl.bts.b .nb.ctl.bts.c .nb.ctl.bts.d -side left -padx 4
  """)
  app.pillButton(".nb.ctl.bts.e", "Pill",    kind = "accent")
  app.pillButton(".nb.ctl.bts.f", "Neutral", kind = "flat")
  discard app.eval("""
    pack .nb.ctl.bts.e .nb.ctl.bts.f -side left -padx 4

    ttk::label .nb.ctl.h2 -text "Text input" -style Title.TLabel
    grid .nb.ctl.h2 -row 2 -column 0 -sticky w -pady {0 8} -columnspan 3

    ttk::label .nb.ctl.nl -text Name
    grid .nb.ctl.nl -row 3 -column 0 -sticky w -padx {0 8}
    ttk::entry .nb.ctl.ne -width 28
    .nb.ctl.ne insert 0 Kevin
    grid .nb.ctl.ne -row 3 -column 1 -sticky w -pady 3

    ttk::label .nb.ctl.pl -text Password
    grid .nb.ctl.pl -row 4 -column 0 -sticky w -padx {0 8}
    ttk::entry .nb.ctl.pe -width 28 -show "•"
    grid .nb.ctl.pe -row 4 -column 1 -sticky w -pady 3

    ttk::label .nb.ctl.ll -text Language
    grid .nb.ctl.ll -row 5 -column 0 -sticky w -padx {0 8}
    ttk::combobox .nb.ctl.le -values {English French German 日本語} -state readonly -width 26
    .nb.ctl.le current 0
    grid .nb.ctl.le -row 5 -column 1 -sticky w -pady 3

    ttk::separator .nb.ctl.sep -orient horizontal
    grid .nb.ctl.sep -row 6 -column 0 -columnspan 3 -sticky ew -pady 16

    ttk::label .nb.ctl.h3 -text Toggles -style Title.TLabel
    grid .nb.ctl.h3 -row 7 -column 0 -sticky w -pady {0 8} -columnspan 3

    set ::notif 1
    set ::updates 0
    set ::mode balanced
    set ::volume 60
  """)
  app.check(".nb.ctl.c1", "Enable notifications", variable = "notif")
  app.check(".nb.ctl.c2", "Auto-update apps",     variable = "updates")
  discard app.eval("""
    grid .nb.ctl.c1 -row 8 -column 0 -sticky w
    grid .nb.ctl.c2 -row 8 -column 1 -sticky w
  """)
  app.radio(".nb.ctl.r1", "Performance", variable = "mode", value = "perf")
  app.radio(".nb.ctl.r2", "Balanced",    variable = "mode", value = "balanced")
  app.radio(".nb.ctl.r3", "Power saver", variable = "mode", value = "power")
  discard app.eval("""
    grid .nb.ctl.r1 -row 9 -column 0 -sticky w -pady 4
    grid .nb.ctl.r2 -row 9 -column 1 -sticky w -pady 4
    grid .nb.ctl.r3 -row 9 -column 2 -sticky w -pady 4

    ttk::label .nb.ctl.vl -text Volume
    grid .nb.ctl.vl -row 10 -column 0 -sticky w -pady {12 0}
  """)
  app.scale(".nb.ctl.vs", fromVal = 0, toVal = 100, value = 60,
            length = 240, variable = "volume")
  discard app.eval("""
    grid .nb.ctl.vs -row 10 -column 1 -sticky w -columnspan 2 -pady {12 0}

    ttk::label .nb.ctl.sp -text "Sync progress"
    grid .nb.ctl.sp -row 11 -column 0 -sticky w -pady {8 0}
    ttk::progressbar .nb.ctl.sb -mode determinate -value 60 -length 240
    grid .nb.ctl.sb -row 11 -column 1 -sticky w -columnspan 2 -pady {8 0}
  """)

  discard app.eval("wm attributes . -topmost 1")
  discard app.eval("update idletasks")
  discard app.eval("update")

  let snapCmd = app.cmd("snap", proc(args: seq[string]): string =
    let rx = app.eval("winfo rootx .").parseInt
    let ry = app.eval("winfo rooty .").parseInt
    let w = app.eval("winfo width .").parseInt
    let h = app.eval("winfo height .").parseInt
    let rect = &"{rx-24},{ry-24},{w+48},{h+48}"
    discard execCmd(&"screencapture -x -R {rect} {outPath}")
    discard app.eval("destroy .")
    "")
  discard app.eval(&"after 900 {snapCmd}")
  app.run()
  echo "saved ", outPath

main()
