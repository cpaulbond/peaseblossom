MODULE StopRequests;

  (* PLAN.md, "Ongoing library enhancements", 7: the requests to stop that
     a program may catch, to finish what it is doing and stop cleanly, as
     a server finishes its connections. rtl/vax/StopRequests.Mod has the
     same interface.

     On Unix the requests are SIGINT (interrupt) and SIGTERM (terminate).
     Each is caught once: the next of the same kind ends the program at
     once, as if it had not been caught, so that whoever asked can insist.
     A system call a request interrupts is restarted. Catch replaces a
     handler Platform.SetInterruptHandler set for SIGINT, and a later
     SetInterruptHandler replaces Catch's.

     A request is caught by a signal handler, which may interrupt the
     program anywhere, so the notifier SetNotifier installs follows the
     rules of Platform's handlers ("Threads and signal handlers" in the
     Reference Guide): it may only set the program's own variables, or
     post a Tasks.Event (Tasks.Post only sets flags), never call NEW, Out,
     Err, In, Files, Texts or Oberon, nor Coroutines.Transfer, which traps
     there. Latest reads what the handler set every time it is called.

     A server running tasks has its notifier post an event that a task
     awaits, so that it learns of a request at once, even while every
     task waits:

         VAR stop: Tasks.Event;
         PROCEDURE Notify; BEGIN Tasks.Post(stop) END Notify;
         ...
         StopRequests.SetNotifier(Notify); StopRequests.Catch;
         ... (in a task) Tasks.Await(stop); stop accepting connections *)

  (* Platform is imported for Platform.c, whose count of the signal
     handlers running StopRequests.c keeps too *)
  IMPORT SYSTEM, Platform;

  CONST
    (* what Latest returns: no request yet, SIGINT (on VAX/VMS CTRL/C),
       SIGTERM *)
    none* = 0; interrupt* = 1; terminate* = 2;

  TYPE
    (* called when a request is caught, as a signal handler is *)
    Notifier* = PROCEDURE;

  PROCEDURE ["C", "StopRequests.-catch"] CCatch;
  PROCEDURE ["C", "StopRequests.-latest"] CLatest(): SYSTEM.INT32;
  PROCEDURE ["C", "StopRequests.-set-notifier"] CSetNotifier(notifier: SYSTEM.ADDRESS);

  (* Catches the next request of each kind, from now on; the one after it
     ends the program. Called again, it catches the next of each again. *)
  PROCEDURE Catch*;
  BEGIN
    CCatch
  END Catch;

  (* The kind of the last request caught: none, interrupt or terminate. *)
  PROCEDURE Latest*(): INTEGER;
    VAR kind: SYSTEM.INT32;
  BEGIN
    (* compared, not converted, so as to mean the same in both size
       models *)
    kind := CLatest();
    IF kind = interrupt THEN RETURN interrupt
    ELSIF kind = terminate THEN RETURN terminate
    ELSE RETURN none
    END
  END Latest;

  (* Makes notify the procedure called when a request is caught, after
     Latest has its kind; NIL for none. *)
  PROCEDURE SetNotifier*(notify: Notifier);
  BEGIN
    CSetNotifier(SYSTEM.VAL(SYSTEM.ADDRESS, notify))
  END SetNotifier;

END StopRequests.
