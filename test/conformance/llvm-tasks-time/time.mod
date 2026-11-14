MODULE time;
  (* Tasks' time (doc/developer/tasks.md, Phase 10): sleeps of several
     lengths end in the order of their lengths, each at least as long as
     asked; a sleeper wakes while another task only yields (the early
     look at the clock); Sleep(0) is Yield; After in a Select, After(0),
     and an After whose channel is closed first. Elapsed times are
     printed only as "at least as long as asked", so that the output does
     not depend on the machine's speed. *)
  IMPORT Tasks, Platform, Out;

  TYPE
    Sleeper = POINTER TO RECORD (Tasks.TaskDesc) ms: LONGINT END;
    Spinner = POINTER TO RECORD (Tasks.TaskDesc) END;
    Waker = POINTER TO RECORD (Tasks.TaskDesc) END;
    Alternator = POINTER TO RECORD (Tasks.TaskDesc) name: CHAR END;

  VAR
    sleepers: ARRAY 4 OF Sleeper;
    spinner: Spinner; waker: Waker;
    alternators: ARRAY 2 OF Alternator;
    woken: BOOLEAN;
    channels: ARRAY 2 OF Tasks.Channel;
    ch: Tasks.Channel;
    m: Tasks.Message;
    i, index, start: LONGINT;

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
    WHILE ~woken & (yields < 100000000) DO Tasks.Yield; INC(yields) END;
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

BEGIN
  FOR i := 0 TO 3 DO NEW(sleepers[i]) END;
  sleepers[0].ms := 50; sleepers[1].ms := 10;
  sleepers[2].ms := 30; sleepers[3].ms := 20;
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
  Tasks.Sleep(15);
  Out.String("main slept"); AtLeast(start, 15); Out.Ln;

  start := Platform.Time();
  channels[0] := Tasks.NewChannel(0);
  channels[1] := Tasks.After(30);
  index := Tasks.Select(channels, m);
  Out.String("Select: "); Out.Int(index, 0);
  IF m = NIL THEN Out.String(", NIL,") ELSE Out.String(", not NIL,") END;
  AtLeast(start, 30); Out.Ln;
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

  ch := Tasks.After(10);
  Tasks.Close(ch);
  Tasks.Sleep(30);
  IF Tasks.Receive(ch, m) THEN Out.String("a closed After got a message")
  ELSE Out.String("a closed After got nothing")
  END;
  Out.Ln;

  (* a timer still pending at the end does not hold the program *)
  ch := Tasks.After(100000);
  Out.String("done"); Out.Ln
END time.
