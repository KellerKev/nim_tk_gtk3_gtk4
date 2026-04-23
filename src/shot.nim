## Launch the demo, bring the window to front, screenshot it, quit. Useful
## for CI / doc generation. Invoke like: `./build/shot --style:gtk4 --out:/tmp/x.png`
import std/[os, osproc, parseopt, strformat, strutils]
import nim_tk_gtk

proc main() =
  var style: GtkStyle = Gtk4
  var dark = false
  var outPath = "/tmp/nim_tk_gtk.png"
  for kind, key, val in getopt(commandLineParams()):
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "style", "s": style = if val == "gtk3": Gtk3 else: Gtk4
      of "dark", "d":  dark = true
      of "out", "o":   outPath = val
    else: discard

  let app = newApp(style = style, dark = dark,
                   title = "GTK Skin (Nim)", width = 780, height = 620)
  # Minimal UI — a single tab is enough to show the skin works from Nim.
  app.headerBar(".hb", title = "Hello from Nim", subtitle = "Tk + GTK skin")
  discard app.eval("""
    ttk::button .hb.inner.trailing.menu -text "⋮" -style Flat.TButton -width 3
    pack .hb.inner.trailing.menu -side right -padx 4
    pack .hb -fill x
    ttk::frame .body -padding 24
    pack .body -fill both -expand 1

    ttk::label .body.title -text "It works." -style LargeTitle.TLabel
    pack .body.title -pady {12 4}
    ttk::label .body.body -justify center -style TLabel \
      -text "This window is rendered by Nim-compiled code calling into\nTcl/Tk directly, themed by the shared gtk_skin.tcl resource."
    pack .body.body -pady {0 20}

    ttk::frame .body.row
    pack .body.row -pady 10
    ttk::button .body.row.ok -text "Got it" -style Suggested.TButton
    ttk::button .body.row.more -text "Tell me more" -style Link.TButton
    pack .body.row.ok .body.row.more -side left -padx 6

    set ::notifications 1
  """)
  app.check(".body.c1", "Enable notifications", variable = "notifications")
  discard app.eval("pack .body.c1 -pady 6")
  app.scale(".body.s1", fromVal = 0, toVal = 100, value = 60, length = 320,
            variable = "volume")
  discard app.eval("pack .body.s1 -pady 10")

  # Raise to front so it's on top when we snap.
  discard app.eval("wm attributes . -topmost 1")
  discard app.eval("update idletasks")
  discard app.eval("update")
  # Schedule a screenshot + quit after a short delay.
  let snapCmd = app.cmd("snap", proc(args: seq[string]): string =
    let rootx = app.eval("winfo rootx .").parseInt
    let rooty = app.eval("winfo rooty .").parseInt
    let w = app.eval("winfo width .").parseInt
    let h = app.eval("winfo height .").parseInt
    let rect = &"{rootx-24},{rooty-24},{w+48},{h+48}"
    discard execCmd(&"screencapture -x -R {rect} {outPath}")
    discard app.eval("destroy .")
    "")
  discard app.eval(&"after 700 {snapCmd}")
  app.run()
  echo "saved ", outPath

main()
