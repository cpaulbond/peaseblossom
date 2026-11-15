MODULE idle;
  (* Tasks' replaced idle step (doc/developer/tasks.md, Phase 10,
     decision 10): called with the time to the nearest timer, with -1
     when no timer is pending, and never with 0 (while a task is ready);
     a Post from the step wakes the task awaiting; NIL restores Tasks'
     own wait. *)
  IMPORT Tasks, Platform, Out;

  TYPE
    Spinner = POINTER TO RECORD (Tasks.TaskDesc) END;
    Waker = POINTER TO RECORD (Tasks.TaskDesc) END;

  VAR
    calls, first, last: LONGINT;
    posting: BOOLEAN;
    event: Tasks.Event;
    spinner: Spinner; waker: Waker;
    woken: BOOLEAN;
    start: LONGINT;

  PROCEDURE Step(timeout: LONGINT);
  BEGIN
    INC(calls);
    IF calls = 1 THEN first := timeout END;
    last := timeout;
    IF posting THEN Tasks.Post(event)
    ELSIF timeout > 0 THEN Platform.Delay(timeout)
    END
  END Step;

  PROCEDURE Reset;
  BEGIN
    calls := 0; first := 0; last := 0
  END Reset;

  PROCEDURE (s: Spinner) Run*;
    VAR yields: LONGINT;
  BEGIN
    yields := 0;
    WHILE ~woken & (yields < 100000000) DO Tasks.Yield; INC(yields) END;
    IF woken THEN Out.String("the spinner saw the waker") ELSE Out.String("the waker starved") END;
    Out.Ln
  END Run;

  PROCEDURE (w: Waker) Run*;
  BEGIN
    Tasks.Sleep(20);
    woken := TRUE
  END Run;

BEGIN
  IF Tasks.WakeDescriptor() >= 0 THEN Out.String("a wake descriptor") ELSE Out.String("no wake descriptor") END;
  Out.Ln;
  Tasks.SetIdleStep(Step);

  Reset;
  start := Platform.Time();
  Tasks.Sleep(50);
  Out.String("Sleep(50): the step called, first timeout ");
  IF (first > 40) & (first <= 50) THEN Out.String("41 to 50") ELSE Out.Int(first, 0) END;
  IF Platform.Time() - start >= 50 THEN Out.String(", slept at least 50 ms") END;
  Out.Ln;

  Reset;
  posting := TRUE;
  Tasks.Await(event);
  posting := FALSE;
  Out.String("Await: "); Out.Int(calls, 0); Out.String(" call, timeout ");
  Out.Int(first, 0); Out.Ln;

  Reset;
  Tasks.Post(event);
  Tasks.Await(event);
  Out.String("Await after a Post: "); Out.Int(calls, 0); Out.String(" calls"); Out.Ln;

  Reset;
  NEW(spinner); NEW(waker);
  Tasks.Start(spinner, Tasks.DefaultStackSize);
  Tasks.Start(waker, Tasks.DefaultStackSize);
  Tasks.Join(spinner); Tasks.Join(waker);
  Out.String("while a task was ready: "); Out.Int(calls, 0); Out.String(" calls"); Out.Ln;

  Tasks.SetIdleStep(NIL);
  Reset;
  start := Platform.Time();
  Tasks.Sleep(20);
  Out.String("with no step: "); Out.Int(calls, 0); Out.String(" calls");
  IF Platform.Time() - start >= 20 THEN Out.String(", slept at least 20 ms") END;
  Out.Ln
END idle.
