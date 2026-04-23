## Raw FFI bindings to Tcl 8.6 and Tk 8.6.
##
## We bind only what the high-level API needs: create/destroy an interpreter,
## evaluate Tcl scripts, register Nim procs as Tcl commands, and run the Tk
## event loop.
##
## Linking is configured via `{.passL.}` pragmas; the pixi environment's
## `$CONDA_PREFIX/lib` is already on `LIBRARY_PATH` through activation.

{.push cdecl.}

when defined(macosx):
  {.passL: "-ltcl8.6 -ltk8.6".}
elif defined(linux):
  {.passL: "-ltcl8.6 -ltk8.6 -lm".}
elif defined(windows):
  {.passL: "-ltcl86 -ltk86".}

type
  TclInterp* {.importc: "Tcl_Interp", header: "<tcl.h>", incompleteStruct.} = object
  TclInterpPtr* = ptr TclInterp

  TclObj* {.importc: "Tcl_Obj", header: "<tcl.h>", incompleteStruct.} = object
  TclObjPtr* = ptr TclObj

  ## Signature for Tcl commands implemented in Nim. The header types objv
  ## as `Tcl_Obj *const *`, which we can't express exactly in Nim — use a
  ## raw `pointer` and cast inside the trampoline with `tclObjAt`.
  TclObjCmdProc* = proc (clientData: pointer; interp: TclInterpPtr;
                         objc: cint; objv: pointer): cint {.cdecl.}

  TclCmdDeleteProc* = proc (clientData: pointer) {.cdecl.}

proc tclObjAt*(objv: pointer; i: int): TclObjPtr {.inline.} =
  ## Fetch element i from Tcl's objv array.
  let arr = cast[ptr UncheckedArray[TclObjPtr]](objv)
  arr[i]

## Tcl return codes (from tcl.h).
const
  TCL_OK*       = 0.cint
  TCL_ERROR*    = 1.cint
  TCL_RETURN*   = 2.cint
  TCL_BREAK*    = 3.cint
  TCL_CONTINUE* = 4.cint

## --- Interpreter lifecycle ---------------------------------------------------

proc Tcl_CreateInterp*(): TclInterpPtr
  {.importc, header: "<tcl.h>".}

proc Tcl_DeleteInterp*(interp: TclInterpPtr)
  {.importc, header: "<tcl.h>".}

proc Tcl_Init*(interp: TclInterpPtr): cint
  {.importc, header: "<tcl.h>".}

proc Tk_Init*(interp: TclInterpPtr): cint
  {.importc, header: "<tk.h>".}

## --- Evaluating Tcl scripts --------------------------------------------------

proc Tcl_Eval*(interp: TclInterpPtr; script: cstring): cint
  {.importc, header: "<tcl.h>".}

proc Tcl_EvalFile*(interp: TclInterpPtr; fileName: cstring): cint
  {.importc, header: "<tcl.h>".}

proc Tcl_GetStringResult*(interp: TclInterpPtr): cstring
  {.importc, header: "<tcl.h>".}

proc Tcl_SetResult*(interp: TclInterpPtr; msg: cstring; freeProc: pointer)
  {.importc, header: "<tcl.h>".}

proc Tcl_GetString*(objPtr: TclObjPtr): cstring
  {.importc, header: "<tcl.h>".}

proc Tcl_NewStringObj*(bytes: cstring; length: cint): TclObjPtr
  {.importc, header: "<tcl.h>".}

proc Tcl_SetObjResult*(interp: TclInterpPtr; objPtr: TclObjPtr)
  {.importc, header: "<tcl.h>".}

## --- Registering Nim callbacks as Tcl commands ------------------------------

proc Tcl_CreateObjCommand*(interp: TclInterpPtr; cmdName: cstring;
                           prc: pointer; clientData: pointer;
                           deleteProc: pointer): pointer
  {.importc, header: "<tcl.h>".}

proc Tcl_DeleteCommand*(interp: TclInterpPtr; cmdName: cstring): cint
  {.importc, header: "<tcl.h>".}

## --- Event loop -------------------------------------------------------------

proc Tk_MainLoop*()
  {.importc, header: "<tk.h>".}

proc Tcl_DoOneEvent*(flags: cint): cint
  {.importc, header: "<tcl.h>".}

const
  TCL_ALL_EVENTS* = (-1).cint
  TCL_DONT_WAIT*  = 2.cint

{.pop.}
