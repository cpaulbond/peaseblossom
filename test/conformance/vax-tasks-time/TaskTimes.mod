MODULE TaskTimes;
  (* Tasks' time on VAX/VMS (doc/developer/tasks.md, Phase 10), the program
     of llvm-tasks-time, renamed, and an AST from Timers.After that posts
     an event a task awaits while another sleeps. Elapsed times are printed
     only as "at least as long as asked". *)
  IMPORT SYSTEM, Tasks, Timers, Platform, Out;

  CONST
    posts = 20;

  TYPE
    Sleeper = POINTER TO RECORD (Tasks.TaskDesc) ms: LONGINT END;
    Spinner = POINTER TO RECORD (Tasks.TaskDesc) END;
    Waker = POINTER TO RECORD (Tasks.TaskDesc) END;
    Alternator = POINTER TO RECORD (Tasks.TaskDesc) name: CHAR END;
    Awaiter = POINTER TO RECORD (Tasks.TaskDesc) END;

  VAR
    sleepers: ARRAY 4 OF Sleeper;
    spinner: Spinner; waker: Waker;
    alternators: ARRAY 2 OF Alternator;
    awaiter: Awaiter;
    woken: BOOLEAN;
    channels: ARRAY 2 OF Tasks.Channel;
    ch: Tasks.Channel;
    m: Tasks.Message;
    timedOut: Tasks.Event;
    astsCaught: LONGINT;  (* by the AST *)
    i, index, start: LONGINT;
    status: SYSTEM.INT32;

  PROCEDURE AtLeast(start, ms: LONGINT);
  BEGIN
    IF Platform.Time() - start >= ms THEN Out.String(" at least ")
    ELSE Out.String(" too soon: ")
    END;
    Out.Int(ms, 0); Out.String(" ms")
  END AtLeast;

  PROCEDURE (s: Sleeper) Run*;
    VAR start: LONGINT;
  BEGIN
    start := Platform.Time();
    Tasks.Sleep(s.ms);
    Out.String("slept"); AtLeast(start, s.ms); Out.Ln
  END Run;

  (* Yields until the waker has slept, never blocking *)
  PROCEDURE (s: Spinner) Run*;
    VAR yields: LONGINT;
  BEGIN
    yields := 0;
    WHILE ~woken & (yields < 10000000) DO Tasks.Yield; INC(yields) END;
    IF woken THEN Out.String("the spinner saw the waker") ELSE Out.String("the waker starved") END;
    Out.Ln
  END Run;

  PROCEDURE (w: Waker) Run*;
  BEGIN
    Tasks.Sleep(20);
    woken := TRUE
  END Run;

  PROCEDURE (a: Alternator) Run*;
    VAR i: INTEGER;
  BEGIN
    FOR i := 1 TO 3 DO
      Out.Char(a.name); Out.Int(i, 0); Out.Char(" ");
      Tasks.Sleep(0)
    END
  END Run;

  (* The AST of Timers.After: posts the event *)
  PROCEDURE TimerAst(parameter: SYSTEM.CARD32);
  BEGIN
    INC(astsCaught);
    Tasks.Post(timedOut)
  END TimerAst;

  (* Awaits posts events, each posted by a timer's AST *)
  PROCEDURE (a: Awaiter) Run*;
    VAR k, woke: LONGINT;
  BEGIN
    woke := 0;
    FOR k := 1 TO posts DO
      status := Timers.After(10 + k MOD 3 * 10, TimerAst, 0);
      IF ~ODD(status) THEN Out.String("Timers.After failed "); Out.Int(status, 0); Out.Ln END;
      Tasks.Await(timedOut);
      INC(woke)
    END;
    Out.String("awaited "); Out.Int(woke, 0); Out.String(" posts, ASTs ");
    Out.Int(astsCaught, 0); Out.Ln
  END Run;

BEGIN
  FOR i := 0 TO 3 DO NEW(sleepers[i]) END;
  sleepers[0].ms := 500; sleepers[1].ms := 100;
  sleepers[2].ms := 300; sleepers[3].ms := 200;
  FOR i := 0 TO 3 DO Tasks.Start(sleepers[i], Tasks.DefaultStackSize) END;
  FOR i := 0 TO 3 DO Tasks.Join(sleepers[i]) END;

  NEW(spinner); NEW(waker);
  Tasks.Start(spinner, Tasks.DefaultStackSize);
  Tasks.Start(waker, Tasks.DefaultStackSize);
  Tasks.Join(spinner); Tasks.Join(waker);

  NEW(alternators[0]); alternators[0].name := "a";
  NEW(alternators[1]); alternators[1].name := "b";
  Tasks.Start(alternators[0], Tasks.DefaultStackSize);
  Tasks.Start(alternators[1], Tasks.DefaultStackSize);
  Tasks.Join(alternators[0]); Tasks.Join(alternators[1]);
  Out.Ln;

  start := Platform.Time();
  Tasks.Sleep(150);
  Out.String("main slept"); AtLeast(start, 150); Out.Ln;

  start := Platform.Time();
  channels[0] := Tasks.NewChannel(0);
  channels[1] := Tasks.After(300);
  index := Tasks.Select(channels, m);
  Out.String("Select: "); Out.Int(index, 0);
  IF m = NIL THEN Out.String(", NIL,") ELSE Out.String(", not NIL,") END;
  AtLeast(start, 300); Out.Ln;
  IF Tasks.TryReceive(channels[1], m) THEN Out.String("After sent twice")
  ELSE Out.String("After sent once")
  END;
  Out.Ln;

  channels[1] := Tasks.After(0);
  IF Tasks.TryReceive(channels[1], m) & (m = NIL) THEN Out.String("After(0) at once")
  ELSE Out.String("After(0) not at once")
  END;
  Out.Ln;
  channels[1] := Tasks.After(-5);
  index := Tasks.Select(channels, m);
  Out.String("After(-5) in Select: "); Out.Int(index, 0); Out.Ln;

  ch := Tasks.After(100);
  Tasks.Close(ch);
  Tasks.Sleep(300);
  IF Tasks.Receive(ch, m) THEN Out.String("a closed After got a message")
  ELSE Out.String("a closed After got nothing")
  END;
  Out.Ln;

  (* a sleeper beside the awaiter of the timers' ASTs *)
  NEW(sleepers[0]); sleepers[0].ms := 200;
  NEW(awaiter);
  Tasks.Start(awaiter, Tasks.DefaultStackSize);
  Tasks.Start(sleepers[0], Tasks.DefaultStackSize);
  Tasks.Join(awaiter); Tasks.Join(sleepers[0]);

  (* a timer still pending at the end does not hold the program *)
  ch := Tasks.After(100000);
  Out.String("done"); Out.Ln
END TaskTimes.
