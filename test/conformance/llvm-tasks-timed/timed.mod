MODULE timed;
  (* Tasks' timed descriptor waits, AwaitReadableFor and AwaitWritableFor
     (doc/developer/tasks.md, decision 15): A, a wait on an empty pipe
     times out, no sooner than asked, and the pipe written afterwards wakes
     nothing; B, a wait the pipe ends first, its timer taken out of the
     list, beside a sleeper whose timer stays; C, timed waits of several
     lengths on one pipe end in the order of their lengths, and the
     longest is woken by the write; D, AwaitWritableFor of a full pipe
     times out, then succeeds once it is drained; E, a time that is not
     positive only looks, and yields. Elapsed times are printed only as
     "at least" or "sooner than", so that the output does not depend on
     the machine's speed. part/Pipes.c makes the pipes. *)
  IMPORT SYSTEM, Tasks, Platform, Pipes, Out;

  TYPE
    Waiter = POINTER TO RECORD (Tasks.TaskDesc) ms: LONGINT; ready: BOOLEAN END;
    Writer = POINTER TO RECORD (Tasks.TaskDesc) ms: LONGINT END;
    Sleeper = POINTER TO RECORD (Tasks.TaskDesc) ms: LONGINT END;
    Counter = POINTER TO RECORD (Tasks.TaskDesc) runs: LONGINT END;

  VAR
    r, w: SYSTEM.INT32;
    start, n: LONGINT;
    ok: BOOLEAN;
    waiters: ARRAY 4 OF Waiter;
    writer: Writer; sleeper: Sleeper; counter: Counter;
    i: LONGINT;

  PROCEDURE AtLeast(start, ms: LONGINT);
  BEGIN
    IF Platform.Time() - start >= ms THEN Out.String(" at least ")
    ELSE Out.String(" too soon: ")
    END;
    Out.Int(ms, 0); Out.String(" ms")
  END AtLeast;

  PROCEDURE SoonerThan(start, ms: LONGINT);
  BEGIN
    IF Platform.Time() - start < ms THEN Out.String(" sooner than ")
    ELSE Out.String(" too late: ")
    END;
    Out.Int(ms, 0); Out.String(" ms")
  END SoonerThan;

  PROCEDURE Result(ready: BOOLEAN);
  BEGIN
    IF ready THEN Out.String("ready") ELSE Out.String("timed out") END
  END Result;

  PROCEDURE (t: Waiter) Run*;
    VAR start: LONGINT;
  BEGIN
    start := Platform.Time();
    t.ready := Tasks.AwaitReadableFor(r, t.ms);
    Out.String("  "); Out.Int(t.ms, 0); Out.String(" ms: "); Result(t.ready);
    IF ~t.ready THEN AtLeast(start, t.ms) END;
    Out.Ln
  END Run;

  PROCEDURE (t: Writer) Run*;
  BEGIN
    Tasks.Sleep(t.ms);
    Out.String("  written"); Out.Ln;
    Pipes.Put(w)
  END Run;

  PROCEDURE (t: Sleeper) Run*;
    VAR start: LONGINT;
  BEGIN
    start := Platform.Time();
    Tasks.Sleep(t.ms);
    Out.String("  slept"); AtLeast(start, t.ms); Out.Ln
  END Run;

  PROCEDURE (t: Counter) Run*;
  BEGIN
    INC(t.runs)
  END Run;

BEGIN
  r := Pipes.Make(w);

  Out.String("A: an empty pipe"); Out.Ln;
  start := Platform.Time();
  ok := Tasks.AwaitReadableFor(r, 50);
  Out.String("  "); Result(ok); AtLeast(start, 50); Out.Ln;
  Pipes.Put(w);
  NEW(sleeper); sleeper.ms := 20;
  Tasks.Start(sleeper, Tasks.DefaultStackSize);
  Tasks.Join(sleeper);
  Out.String("  bytes "); Out.Int(Pipes.Drain(r), 0); Out.Ln;

  Out.String("B: the pipe first, beside a sleeper"); Out.Ln;
  NEW(writer); writer.ms := 20;
  NEW(sleeper); sleeper.ms := 100;
  Tasks.Start(writer, Tasks.DefaultStackSize);
  Tasks.Start(sleeper, Tasks.DefaultStackSize);
  start := Platform.Time();
  ok := Tasks.AwaitReadableFor(r, 5000);
  Out.String("  "); Result(ok); SoonerThan(start, 5000); Out.Ln;
  Tasks.Join(writer); Tasks.Join(sleeper);
  Out.String("  bytes "); Out.Int(Pipes.Drain(r), 0); Out.Ln;

  Out.String("C: waits of several lengths on one pipe"); Out.Ln;
  FOR i := 0 TO 3 DO NEW(waiters[i]) END;
  waiters[0].ms := 60; waiters[1].ms := 5000; waiters[2].ms := 20; waiters[3].ms := 40;
  NEW(writer); writer.ms := 100;
  start := Platform.Time();
  FOR i := 0 TO 3 DO Tasks.Start(waiters[i], Tasks.DefaultStackSize) END;
  Tasks.Start(writer, Tasks.DefaultStackSize);
  FOR i := 0 TO 3 DO Tasks.Join(waiters[i]) END;
  Tasks.Join(writer);
  Out.String("  all"); SoonerThan(start, 5000); Out.Ln;
  Out.String("  bytes "); Out.Int(Pipes.Drain(r), 0); Out.Ln;

  Out.String("D: a full pipe"); Out.Ln;
  n := Pipes.Fill(w);
  start := Platform.Time();
  ok := Tasks.AwaitWritableFor(w, 30);
  Out.String("  "); Result(ok); AtLeast(start, 30); Out.Ln;
  IF Pipes.Drain(r) = n THEN Out.String("  drained") ELSE Out.String("  not drained") END;
  Out.Ln;
  ok := Tasks.AwaitWritableFor(w, 5000);
  Out.String("  "); Result(ok); Out.Ln;

  Out.String("E: no time"); Out.Ln;
  NEW(counter);
  Tasks.Start(counter, Tasks.DefaultStackSize);
  ok := Tasks.AwaitReadableFor(r, 0);
  Out.String("  readable, empty: "); Result(ok);
  Out.String("; the other task ran "); Out.Int(counter.runs, 0); Out.Ln;
  Pipes.Put(w);
  ok := Tasks.AwaitReadableFor(r, -1);
  Out.String("  readable, a byte: "); Result(ok); Out.Ln;
  ok := Tasks.AwaitWritableFor(w, 0);
  Out.String("  writable: "); Result(ok); Out.Ln;
  Pipes.Close(r); Pipes.Close(w)
END timed.
