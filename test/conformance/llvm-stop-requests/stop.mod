MODULE stop;
  (* PLAN.md, "Ongoing library enhancements", 7: StopRequests. The program
     signals itself from a task with the least stack, 16 KiB, so that the
     handler and the notifier run on it: SIGINT wakes a task awaiting the
     event the notifier posts; SIGTERM is caught as well; Catch again
     catches the next SIGINT; and the SIGINT after that ends the program,
     as uncaught. *)
  IMPORT SYSTEM, StopRequests, Tasks, Out;
  CONST sigint = 2; sigterm = 15; (* the same on Linux and the BSDs *)
  TYPE
    Waiter = POINTER TO RECORD (Tasks.TaskDesc) END;
    Raiser = POINTER TO RECORD (Tasks.TaskDesc) END;
  VAR
    stopEvent: Tasks.Event;
    notified: INTEGER;
    w: Waiter; r: Raiser;

  PROCEDURE ["C", "raise"] Raise(signal: SYSTEM.INT32): SYSTEM.INT32;

  PROCEDURE Notify;
  BEGIN
    INC(notified); Tasks.Post(stopEvent)
  END Notify;

  (* notified, read as a signal handler's variable is *)
  PROCEDURE Notified(): INTEGER;
    VAR n: INTEGER;
  BEGIN
    SYSTEM.GET(SYSTEM.ADR(notified), n); RETURN n
  END Notified;

  PROCEDURE Report(what: ARRAY OF CHAR);
  BEGIN
    Out.String(what); Out.String(": latest "); Out.Int(StopRequests.Latest(), 0);
    Out.String(", notified "); Out.Int(Notified(), 0); Out.Ln
  END Report;

  PROCEDURE (w: Waiter) Run*;
  BEGIN
    Tasks.Await(stopEvent);
    Report("woken by SIGINT")
  END Run;

  PROCEDURE (r: Raiser) Run*;
  BEGIN
    IF Raise(sigint) # 0 THEN Out.String("raise failed"); Out.Ln END
  END Run;

  PROCEDURE Signal(signal: SYSTEM.INT32; what: ARRAY OF CHAR);
  BEGIN
    IF Raise(signal) # 0 THEN Out.String("raise failed"); Out.Ln END;
    Report(what)
  END Signal;

BEGIN
  notified := 0;
  Report("before Catch");
  StopRequests.SetNotifier(Notify);
  StopRequests.Catch;
  NEW(w); Tasks.Start(w, 16384);
  NEW(r); Tasks.Start(r, 16384);
  Tasks.Join(w); Tasks.Join(r);
  Signal(sigterm, "after SIGTERM");
  StopRequests.Catch;
  Signal(sigint, "after Catch and SIGINT");
  StopRequests.SetNotifier(NIL);
  StopRequests.Catch;
  Signal(sigint, "after SetNotifier(NIL), Catch and SIGINT");
  Signal(sigint, "after a second SIGINT (never printed)")
END stop.
