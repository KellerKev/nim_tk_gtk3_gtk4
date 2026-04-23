## Nim port of the GTK-skin demo. Showcases every widget and lets you flip
## between GTK3/GTK4 and light/dark at runtime.

import std/[os, parseopt, strformat]
import nim_tk_gtk

type
  Options = object
    style: GtkStyle
    dark: bool

# Forward declarations — buildDemo calls the tab builders and rebuild() calls
# buildDemo in turn.
proc buildGeneralTab(app: App)
proc buildControlsTab(app: App)
proc buildAboutTab(app: App)
proc buildDemo(app: App; opts: Options)

proc parseArgs(): Options =
  result = Options(style: Gtk4, dark: false)
  for kind, key, val in getopt(commandLineParams()):
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "style", "s":
        result.style = if val == "gtk3": Gtk3 else: Gtk4
      of "dark", "d":
        result.dark = true
      of "light":
        result.dark = false
      of "help", "h":
        echo "usage: demo [--style:gtk3|gtk4] [--dark]"
        quit 0
    else: discard

proc rebuild(app: App; opts: Options) =
  ## Destroy every child of `.` and rebuild the UI with the new palette.
  discard app.eval("foreach w [winfo children .] { destroy $w }")
  app.applySkin(opts.style, opts.dark)
  buildDemo(app, opts)

proc buildDemo(app: App; opts: Options) =
  let paletteName = app.eval("gtk_skin::color name")
  discard app.eval(&"wm title . {{GTK Skin (Nim) — {paletteName}}}")

  # --- Header bar ----------------------------------------------------------
  app.headerBar(".hb", title = "Preferences",
                subtitle = "Demo of the Nim Tk GTK skin")
  discard app.eval("""
    ttk::button .hb.inner.leading.menu -text "☰" -style Flat.TButton -width 3
    pack .hb.inner.leading.menu -side left
    ttk::button .hb.inner.trailing.search -text "⌕" -style Flat.TButton -width 3
    ttk::button .hb.inner.trailing.more   -text "⋮" -style Flat.TButton -width 3
    pack .hb.inner.trailing.search .hb.inner.trailing.more -side left -padx 2
    pack .hb -fill x
  """)

  # --- Notebook ------------------------------------------------------------
  discard app.eval("""
    ttk::notebook .nb
    pack .nb -fill both -expand 1 -padx 16 -pady 16
  """)

  buildGeneralTab(app)
  buildControlsTab(app)
  buildAboutTab(app)

  # --- Footer with theme switcher -----------------------------------------
  discard app.eval("ttk::frame .foot")
  discard app.eval(&"ttk::label .foot.name -text {{Theme: {paletteName}}} -style Dim.TLabel")
  discard app.eval("pack .foot.name -side left")

  # Capture `opts` in the closure so Nim knows the target palette for each button.
  let curOpts = opts
  let toggleDark = app.onClick(proc () =
    rebuild(app, Options(style: curOpts.style, dark: not curOpts.dark)))
  let useGtk3 = app.onClick(proc () =
    rebuild(app, Options(style: Gtk3, dark: curOpts.dark)))
  let useGtk4 = app.onClick(proc () =
    rebuild(app, Options(style: Gtk4, dark: curOpts.dark)))

  let darkLabel = if opts.dark: "Light" else: "Dark"
  discard app.eval(&"""
    ttk::button .foot.gtk3  -text GTK3 -command {useGtk3}
    ttk::button .foot.gtk4  -text GTK4 -command {useGtk4}
    ttk::button .foot.theme -text {darkLabel} -style Suggested.TButton -command {toggleDark}
    pack .foot.gtk3  -side right -padx 4
    pack .foot.gtk4  -side right -padx 4
    pack .foot.theme -side right -padx 4
    pack .foot -fill x -side bottom -padx 16 -pady {{0 16}}
  """)

proc buildGeneralTab(app: App) =
  discard app.eval("""
    ttk::frame .nb.general -style TFrame -padding {4 12}
    .nb add .nb.general -text General

    ttk::label .nb.general.h1 -text Appearance -style Title.TLabel
    pack .nb.general.h1 -anchor w -pady {0 8}

    ttk::frame .nb.general.appearance -style Card.TFrame
    pack .nb.general.appearance -fill x -pady {0 20}

    set ::darkMode 0
    set ::reduceMotion 0

    ttk::frame .nb.general.appearance.r1 -style View.TFrame
    pack .nb.general.appearance.r1 -fill x
    ttk::frame .nb.general.appearance.r1.lbls -style View.TFrame
    pack .nb.general.appearance.r1.lbls -side left -padx 14 -pady 10 -fill x -expand 1
    ttk::label .nb.general.appearance.r1.lbls.t -text "Dark mode" -style View.TLabel -font {TkDefaultFont 11 bold}
    ttk::label .nb.general.appearance.r1.lbls.s -text "Use a dark color palette throughout the app" -style DimView.TLabel
    pack .nb.general.appearance.r1.lbls.t -anchor w
    pack .nb.general.appearance.r1.lbls.s -anchor w
  """)
  app.switch(".nb.general.appearance.r1.sw", variable = "darkMode")
  discard app.eval("pack .nb.general.appearance.r1.sw -side right -padx 14 -pady 10")

  discard app.eval("""
    frame .nb.general.appearance.sep1 -background [gtk_skin::color border] -height 1
    pack .nb.general.appearance.sep1 -fill x

    ttk::frame .nb.general.appearance.r2 -style View.TFrame
    pack .nb.general.appearance.r2 -fill x
    ttk::frame .nb.general.appearance.r2.lbls -style View.TFrame
    pack .nb.general.appearance.r2.lbls -side left -padx 14 -pady 10 -fill x -expand 1
    ttk::label .nb.general.appearance.r2.lbls.t -text "Reduce animations" -style View.TLabel -font {TkDefaultFont 11 bold}
    ttk::label .nb.general.appearance.r2.lbls.s -text "Turn off non-essential motion" -style DimView.TLabel
    pack .nb.general.appearance.r2.lbls.t -anchor w
    pack .nb.general.appearance.r2.lbls.s -anchor w
  """)
  app.switch(".nb.general.appearance.r2.sw", variable = "reduceMotion")
  discard app.eval("pack .nb.general.appearance.r2.sw -side right -padx 14 -pady 10")

  # Account section
  discard app.eval("""
    ttk::label .nb.general.h2 -text Account -style Title.TLabel
    pack .nb.general.h2 -anchor w -pady {0 8}

    ttk::frame .nb.general.account -style Card.TFrame
    pack .nb.general.account -fill x
    ttk::frame .nb.general.account.me -style View.TFrame
    pack .nb.general.account.me -fill x
  """)
  app.avatar(".nb.general.account.me.av", "KK", size = 44)
  discard app.eval("""
    pack .nb.general.account.me.av -side left -padx {14 12} -pady 12
    ttk::button .nb.general.account.me.out -text "Sign out" -style Flat.TButton
    pack .nb.general.account.me.out -side right -padx {8 14} -pady 12
    ttk::frame .nb.general.account.me.meta -style View.TFrame
    pack .nb.general.account.me.meta -side left -fill x -expand 1 -pady 12
    ttk::label .nb.general.account.me.meta.n -text "Kevin Keller" -style View.TLabel -font {TkDefaultFont 12 bold}
    ttk::label .nb.general.account.me.meta.e -text "kevin@fineupp.com" -style DimView.TLabel
    pack .nb.general.account.me.meta.n -anchor w
    pack .nb.general.account.me.meta.e -anchor w
  """)

proc buildControlsTab(app: App) =
  discard app.eval("""
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
  discard app.eval("pack .nb.ctl.bts.e .nb.ctl.bts.f -side left -padx 4")

  discard app.eval("""
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

proc buildAboutTab(app: App) =
  discard app.eval("""
    ttk::frame .nb.about -padding 32
    .nb add .nb.about -text About
  """)
  app.avatar(".nb.about.av", "GS", size = 72)
  discard app.eval("""
    pack .nb.about.av -pady {12 12}
    ttk::label .nb.about.t -text "GTK Skin for Nim + Tk" -style LargeTitle.TLabel
    pack .nb.about.t
    ttk::label .nb.about.v -text "Version 0.1.0" -style Dim.TLabel
    pack .nb.about.v -pady {0 16}
    ttk::label .nb.about.body -justify center \
      -text "Tcl/Tk bindings for Nim plus a shared GTK3/GTK4 skin.\nThe .tcl skin file is the same one the Python demo uses."
    pack .nb.about.body -pady {0 20}
    ttk::frame .nb.about.row
    pack .nb.about.row
    ttk::button .nb.about.row.w -text Website        -style Link.TButton
    ttk::button .nb.about.row.r -text "Report issue" -style Link.TButton
    ttk::button .nb.about.row.c -text Credits        -style Link.TButton
    pack .nb.about.row.w .nb.about.row.r .nb.about.row.c -side left -padx 6
  """)

proc main() =
  let opts = parseArgs()
  let app = newApp(style = opts.style, dark = opts.dark,
                   title = "GTK Skin (Nim)", width = 780, height = 620)
  buildDemo(app, opts)
  app.run()

when isMainModule:
  main()
