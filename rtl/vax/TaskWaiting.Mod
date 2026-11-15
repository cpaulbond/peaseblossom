MODULE TaskWaiting;
  (* What Tasks needs that differs between the systems (doc/developer/
     tasks.md, decision 1), here for VAX/VMS: the clock ($GETTIM), the
     idle wait ($HIBER, with a $SETIMR of its own for a timeout), the wake
     an AST gives ($WAKE), and the traps 19 and 20, through POC_TRAP, with
     their texts in PocRtl.mar. VMS has no descriptors to wait for: an I/O
     wait is a $QIO whose AST posts an event. rtl/llvm/TaskWaiting.Mod has
     the same interface for POSIX. For Tasks only. *)

  IMPORT SYSTEM;

  CONST
    (* misuse's cases, trap 20's texts in PocRtl.mar, in the code's high
       word *)
    unlockNotHeld* = 0; joinOfRunning* = 1; sendOnClosed* = 2;
    closeOfClosed* = 3; startOfStarted* = 4; negativeCapacity* = 5;
    descriptorOnVms = 7;
    deadlock = 19; misuse = 20;
    (* the request identifier of Wait's timer, "TASK", which $CANTIM
       cancels alone *)
    timerRequest = 5441534BH;

  TYPE
    (* AsynchronousTraps' AstRoutine, not imported, so that Tasks does
       not bring in AsynchronousTraps *)
    AstRoutine = PROCEDURE (parameter: SYSTEM.CARD32);

  (* POC_TRAP with no location: the message for code, then $EXIT *)
  PROCEDURE ["VMS", "POC_TRAP"] Trap(code, module, line, column: SYSTEM.INT32);
  PROCEDURE ["VMS", "SYS$GETTIM"] GetTime(VAR time: HUGEINT): SYSTEM.INT32;
  PROCEDURE ["VMS", "SYS$HIBER"] Hibernate(): SYSTEM.INT32;
  PROCEDURE ["VMS", "SYS$WAKE"] WakeProcess(VAR pid: SYSTEM.CARD32;
    name-: ARRAY OF CHAR): SYSTEM.INT32;
  PROCEDURE ["VMS", "SYS$SETIMR"] SetTimer(efn: SYSTEM.CARD32; time-: HUGEINT;
    routine: AstRoutine; request, flags: SYSTEM.CARD32): SYSTEM.INT32;
  PROCEDURE ["VMS", "SYS$CANTIM"] CancelTimer(request, mode: SYSTEM.CARD32): SYSTEM.INT32;

  (* Trap 19, "all tasks are blocked" *)
  PROCEDURE Deadlock*;
  BEGIN
    Trap(deadlock, 0, 0, 0)
  END Deadlock;

  (* Trap 20 with the text of case which, one of the constants above *)
  PROCEDURE Misuse*(which: SYSTEM.INT32);
  BEGIN
    Trap(misuse + which * 65536, 0, 0, 0)
  END Misuse;

  (* The system time in microseconds *)
  PROCEDURE Now*(): HUGEINT;
    VAR time: HUGEINT; status: SYSTEM.INT32;
  BEGIN
    status := GetTime(time);
    RETURN time DIV 10
  END Now;

  (* Ends a Wait that is going on or about to start: $WAKE, which VMS
     remembers when the process is not hibernating yet; safe in an AST *)
  PROCEDURE Wake*;
    VAR status: SYSTEM.INT32;
  BEGIN
    status := WakeProcess(NIL, NIL)
  END Wake;

  (* No descriptor: -1 *)
  PROCEDURE WakeDescriptor*(): LONGINT;
  BEGIN
    RETURN -1
  END WakeDescriptor;

  (* Traps (20): VMS has no descriptors to wait for *)
  PROCEDURE CheckDescriptor*(fd: LONGINT);
  BEGIN
    Misuse(descriptorOnVms)
  END CheckDescriptor;

  (* Starts a list of descriptors for Wait: none on VMS *)
  PROCEDURE Clear*;
  END Clear;

  (* Never called: CheckDescriptor traps first *)
  PROCEDURE Add*(fd: LONGINT; forWriting: BOOLEAN);
  BEGIN
    Misuse(descriptorOnVms)
  END Add;

  (* The AST of Wait's timer *)
  PROCEDURE TimerAst(parameter: SYSTEM.CARD32);
  BEGIN
    Wake
  END TimerAst;

  (* Waits up to timeout ms (-1: no limit, 0: not at all) for a Wake.
     A wake that comes for another reason, a timer's that fired after
     the $HIBER ended among them, ends a later Wait early, which Tasks
     accepts: it looks again. When the timer cannot be set, it does not
     wait, and Tasks looks again at once. *)
  PROCEDURE Wait*(timeout: LONGINT);
    VAR delta: HUGEINT; status: SYSTEM.INT32;
  BEGIN
    IF timeout > 0 THEN
      delta := timeout; delta := -delta * 10000;
      IF ODD(SetTimer(0, delta, TimerAst, timerRequest, 0)) THEN
        status := Hibernate();
        status := CancelTimer(timerRequest, 0)
      END
    ELSIF timeout < 0 THEN
      status := Hibernate()
    END
  END Wait;

  (* No descriptor is ever ready *)
  PROCEDURE Ready*(i: LONGINT): BOOLEAN;
  BEGIN
    RETURN FALSE
  END Ready;

END TaskWaiting.
