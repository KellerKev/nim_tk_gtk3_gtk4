## High-level Nim API for Tk + the GTK skin.
##
## ```nim
## import nim_tk_gtk
## var app = newApp(style = Gtk4, dark = false)
## app.eval """
##   gtk_skin::headerbar .hb -title "Hello"
##   pack .hb -fill x
##   button .btn -text "Click me" -command "tk_messageBox -message Hi"
##   pack .btn -pady 20
## """
## app.run()
## ```
##
## `app.eval` raises on Tcl error and returns the string result. `app.cmd`
## registers a Nim proc as a Tcl command so the UI can call back into Nim.

import std/[os, strformat, tables]
import nim_tk_gtk/bindings
export bindings.TclInterpPtr, bindings.TclObjPtr

type
  GtkStyle* = enum
    Gtk3 = "gtk3"
    Gtk4 = "gtk4"

  TkError* = object of CatchableError

  App* = ref object
    interp*: TclInterpPtr
    callbacks: Table[string, proc (args: seq[string]): string]
    nextId: int

const skinResource = "resources/gtk_skin.tcl"

proc raiseTkError(interp: TclInterpPtr; prefix: string) {.noreturn.} =
  let msg = $Tcl_GetStringResult(interp)
  raise newException(TkError, prefix & ": " & msg)

proc eval*(app: App; script: string): string {.discardable.} =
  ## Evaluate a Tcl script. Raises TkError on failure, returns the string
  ## result otherwise.
  let rc = Tcl_Eval(app.interp, cstring(script))
  if rc != TCL_OK:
    raiseTkError(app.interp, "Tcl error in eval")
  result = $Tcl_GetStringResult(app.interp)

proc evalFile*(app: App; path: string) =
  if Tcl_EvalFile(app.interp, cstring(path)) != TCL_OK:
    raiseTkError(app.interp, &"Tcl error loading {path}")

# --- Callback plumbing -------------------------------------------------------

proc callbackTrampoline(clientData: pointer; interp: TclInterpPtr;
                        objc: cint; objv: pointer): cint {.cdecl.} =
  ## Called by Tcl when user invokes a registered Nim callback. We look up the
  ## original proc via the string name (objv[0]) in the App's callback table.
  let app = cast[App](clientData)
  var args = newSeq[string](objc)
  for i in 0 ..< objc.int:
    args[i] = $Tcl_GetString(tclObjAt(objv, i))
  let name = args[0]
  # Drop the command name itself before passing to user code.
  let userArgs = args[1 .. ^1]

  if name notin app.callbacks:
    Tcl_SetResult(interp, cstring(&"unknown Nim callback: {name}"), nil)
    return TCL_ERROR

  try:
    let ret = app.callbacks[name](userArgs)
    if ret.len > 0:
      Tcl_SetResult(interp, cstring(ret), nil)
    return TCL_OK
  except CatchableError as e:
    Tcl_SetResult(interp, cstring(&"Nim callback error: {e.msg}"), nil)
    return TCL_ERROR

proc cmd*(app: App; name: string; fn: proc (args: seq[string]): string): string =
  ## Register `fn` as a Tcl command named `name`. The returned string is the
  ## command name you can use from Tcl. If `name` is empty, a unique one is
  ## generated. Returns the actual command name.
  var actual = name
  if actual.len == 0:
    inc app.nextId
    actual = &"nim_cb_{app.nextId}"
  app.callbacks[actual] = fn
  # Cast smooths over Tcl's `Tcl_Obj *const *` objv, which Nim can't model
  # exactly. The actual call convention matches.
  discard Tcl_CreateObjCommand(app.interp, cstring(actual),
                               cast[TclObjCmdProc](callbackTrampoline),
                               cast[pointer](app), nil)
  return actual

# Shorthand for void callbacks with no args (e.g. -command handlers).
proc onClick*(app: App; fn: proc ()): string =
  app.cmd("", proc (_: seq[string]): string =
    fn()
    ""
  )

# --- Tcl variable helpers ---------------------------------------------------

proc setVar*(app: App; name, value: string) =
  discard app.eval(&"set ::{name} {{{value}}}")

proc getVar*(app: App; name: string): string =
  app.eval(&"set ::{name}")

# --- Skin integration --------------------------------------------------------

proc locateSkinFile(): string =
  ## Find the gtk_skin.tcl resource relative to the executable or CWD.
  let exeDir = getAppDir()
  for candidate in [
    exeDir / skinResource,
    exeDir / ".." / skinResource,
    getCurrentDir() / skinResource,
    exeDir / "gtk_skin.tcl",
  ]:
    if fileExists(candidate):
      return candidate
  raise newException(IOError,
    "Could not find gtk_skin.tcl; expected one of: " &
    (exeDir / skinResource) & " or " & (getCurrentDir() / skinResource))

proc loadSkin*(app: App) =
  ## Source the Tcl skin file into the interpreter. Call once per app.
  app.evalFile(locateSkinFile())

proc applySkin*(app: App; style: GtkStyle = Gtk4; dark = false) =
  ## Activate a specific GTK palette. Re-callable at runtime to flip themes.
  let darkArg = if dark: "1" else: "0"
  discard app.eval(&"gtk_skin::apply . {$style} {darkArg}")

# --- App lifecycle -----------------------------------------------------------

proc newApp*(style: GtkStyle = Gtk4; dark = false;
             title = "Nim Tk GTK"; width = 780; height = 620): App =
  ## Create a Tk application with the GTK skin already applied.
  let interp = Tcl_CreateInterp()
  if interp.isNil:
    raise newException(TkError, "Tcl_CreateInterp failed")
  if Tcl_Init(interp) != TCL_OK:
    raiseTkError(interp, "Tcl_Init failed")
  if Tk_Init(interp) != TCL_OK:
    raiseTkError(interp, "Tk_Init failed")

  result = App(interp: interp, callbacks: initTable[string, proc (args: seq[string]): string](),
               nextId: 0)
  result.loadSkin()
  result.applySkin(style, dark)

  discard result.eval(&"wm title . {{{title}}}")
  discard result.eval(&"wm geometry . {width}x{height}")

proc destroy*(app: App) =
  if not app.interp.isNil:
    Tcl_DeleteInterp(app.interp)
    app.interp = nil

proc run*(app: App) =
  ## Enter the Tk event loop. Returns when all windows are destroyed.
  Tk_MainLoop()
  # Tk_MainLoop returns when tk_main ends; clean up the interp.
  app.destroy()

# --- Convenience wrappers ----------------------------------------------------

proc headerBar*(app: App; path: string; title = ""; subtitle = "") =
  ## Create a GTK-style header bar at `path`.
  discard app.eval(
    &"gtk_skin::headerbar {path} -title {{{title}}} -subtitle {{{subtitle}}}")

proc switch*(app: App; path: string; variable = "";
             command = "") =
  ## Create a GTK-style toggle switch at `path`.
  var opts = ""
  if variable.len > 0: opts.add &" -variable {variable}"
  if command.len > 0:  opts.add &" -command {command}"
  discard app.eval(&"gtk_skin::switch {path}{opts}")

proc pillButton*(app: App; path: string; text: string; kind = "accent";
                 command = "") =
  var opts = &" -kind {kind}"
  if command.len > 0: opts.add &" -command {command}"
  discard app.eval(&"gtk_skin::pill_button {path} {{{text}}}{opts}")

proc radio*(app: App; path: string; text: string; variable: string;
            value: string; command = "") =
  var opts = &" -variable {variable} -value {{{value}}}"
  if command.len > 0: opts.add &" -command {command}"
  discard app.eval(&"gtk_skin::radio {path} {{{text}}}{opts}")

proc check*(app: App; path: string; text: string; variable: string;
            command = "") =
  var opts = &" -variable {variable}"
  if command.len > 0: opts.add &" -command {command}"
  discard app.eval(&"gtk_skin::check {path} {{{text}}}{opts}")

proc scale*(app: App; path: string; fromVal, toVal, value: float;
            length = 220; variable = ""; command = "") =
  var opts = &" -from {fromVal} -to {toVal} -value {value} -length {length}"
  if variable.len > 0: opts.add &" -variable {variable}"
  if command.len > 0:  opts.add &" -command {command}"
  discard app.eval(&"gtk_skin::scale {path}{opts}")

proc avatar*(app: App; path: string; text: string; size = 40; color = "") =
  var opts = &" -size {size}"
  if color.len > 0: opts.add &" -color {color}"
  discard app.eval(&"gtk_skin::avatar {path} {{{text}}}{opts}")

proc separator*(app: App; path: string; orient = "horizontal") =
  discard app.eval(&"gtk_skin::separator {path} -orient {orient}")
