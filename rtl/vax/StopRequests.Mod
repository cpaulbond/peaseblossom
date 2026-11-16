MODULE StopRequests;

  (* PLAN.md, "Ongoing library enhancements", 7: the requests to stop that
     a program may catch, to finish what it is doing and stop cleanly, as
     a server finishes its connections. rtl/llvm/StopRequests.Mod has the
     same interface.

     On VAX/VMS the one request is CTRL/C at SYS$COMMAND (interrupt),
     caught through Platform.SetInterruptHandler, so by the terminal
     driver's CTRL/C AST. It is caught once: then the AST is disabled, and
     the next CTRL/C interrupts the program as CTRL/Y does, so that whoever
     asked can insist. Catch replaces a handler SetInterruptHandler set,
     and a later SetInterruptHandler replaces Catch's. With no terminal (a
     batch job) nothing is caught, and Latest stays none. Latest never
     returns terminate here.

     The notifier SetNotifier installs runs at AST level, so it follows
     Platform's rules for an interrupt handler: it may only set the
     program's own variables, or post a Tasks.Event (Tasks.Post only sets
     flags), never call Out, Err, In, Files, Texts or Oberon, nor NEW
     unless the program imports AsynchronousTraps.

     A server running tasks has its notifier post an event that a task
     awaits, so that it learns of a request at once, even while every
     task waits:

         VAR stop: Tasks.Event;
         PROCEDURE Notify; BEGIN Tasks.Post(stop) END Notify;
         ...
         StopRequests.SetNotifier(Notify); StopRequests.Catch;
         ... (in a task) Tasks.Await(stop); stop accepting connections *)

  IMPORT SYSTEM, Platform;

  CONST
    (* what Latest returns: no request yet, SIGINT (on VAX/VMS CTRL/C),
       SIGTERM *)
    none* = 0; interrupt* = 1; terminate* = 2;

  TYPE
    (* called when a request is caught, as a signal handler is *)
    Notifier* = PROCEDURE;

  VAR
    latest: INTEGER; (* set at AST level, so read by SYSTEM.GET *)
    notifier: Notifier;

  PROCEDURE Caught(signal: SYSTEM.INT32);
    VAR notify: Notifier;
  BEGIN
    latest := interrupt;
    (* once: CTRL/C acts as CTRL/Y again *)
    Platform.SetInterruptHandler(NIL);
    notify := notifier;
    IF notify # NIL THEN notify END
  END Caught;

  (* Catches the next request of each kind, from now on; the one after it
     ends the program. Called again, it catches the next of each again. *)
  PROCEDURE Catch*;
  BEGIN
    Platform.SetInterruptHandler(Caught)
  END Catch;

  (* The kind of the last request caught: none, interrupt or terminate. *)
  PROCEDURE Latest*(): INTEGER;
    VAR kind: INTEGER;
  BEGIN
    SYSTEM.GET(SYSTEM.ADR(latest), kind);
    RETURN kind
  END Latest;

  (* Makes notify the procedure called when a request is caught, after
     Latest has its kind; NIL for none. *)
  PROCEDURE SetNotifier*(notify: Notifier);
  BEGIN
    notifier := notify
  END SetNotifier;

BEGIN
  latest := none; notifier := NIL
END StopRequests.
