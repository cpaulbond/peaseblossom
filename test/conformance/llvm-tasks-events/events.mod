MODULE events;
  (* Tasks' events and descriptors on POSIX (doc/developer/tasks.md,
     Phase 10, from Phase 7.3's probe): A, a ticker, a reader of a pipe a
     child writes slowly, and an awaiter of an event a SIGINT handler
     posts, the signals sent at random moments by a child that waits for
     each to be acknowledged, so that a lost wake hangs the test; B, the
     awaiter alone, where only the signal can end the idle wait; C, a
     reader of a pipe that is ready at once beside a task that only
     yields, which must not starve it; D, AwaitWritable. Counts only, no
     times. part/ChildProcesses.c makes the child processes. *)
  IMPORT SYSTEM, Tasks, Platform, ChildProcesses, Out;

  CONST
    ticks = 100; tickMs = 5;
    lines = 50; lineMs = 10;
    signalsA = 1000; signalsB = 1000; maxPauseUs = 300;

  TYPE
    Ticker = POINTER TO RECORD (Tasks.TaskDesc) END;
    Reader = POINTER TO RECORD (Tasks.TaskDesc) fd: SYSTEM.INT32 END;
    Awaiter = POINTER TO RECORD (Tasks.TaskDesc) count, ackFd: SYSTEM.INT32 END;
    Busy = POINTER TO RECORD (Tasks.TaskDesc) END;
    Quick = POINTER TO RECORD (Tasks.TaskDesc) fd: SYSTEM.INT32 END;

  VAR
    signalled: Tasks.Event;
    caught: LONGINT;      (* by the handler *)
    ticked, wakes, bytes, eofs: LONGINT;
    quickDone: BOOLEAN; yields: LONGINT;
    ticker: Ticker; reader: Reader; awaiter: Awaiter; busy: Busy; quick: Quick;
    w: SYSTEM.INT32; r: SYSTEM.INT32;

  PROCEDURE Interrupt(signal: SYSTEM.INT32);
    VAR c: LONGINT;
  BEGIN
    SYSTEM.GET(SYSTEM.ADR(caught), c); SYSTEM.PUT(SYSTEM.ADR(caught), c + 1);
    Tasks.Post(signalled)
  END Interrupt;

  PROCEDURE (t: Ticker) Run*;
    VAR k: LONGINT;
  BEGIN
    FOR k := 1 TO ticks DO Tasks.Sleep(tickMs); INC(ticked) END
  END Run;

  PROCEDURE (r: Reader) Run*;
    VAR n: SYSTEM.INT32;
  BEGIN
    LOOP
      Tasks.AwaitReadable(r.fd);
      n := ChildProcesses.Drain(r.fd);
      IF n = 0 THEN EXIT ELSIF n > 0 THEN INC(bytes, n) END
    END;
    INC(eofs);
    ChildProcesses.Close(r.fd)
  END Run;

  PROCEDURE (a: Awaiter) Run*;
    VAR k: LONGINT;
  BEGIN
    FOR k := 1 TO a.count DO
      Tasks.Await(signalled);
      INC(wakes);
      ChildProcesses.Ack(a.ackFd)
    END;
    ChildProcesses.Close(a.ackFd)
  END Run;

  PROCEDURE (b: Busy) Run*;
  BEGIN
    WHILE ~quickDone & (yields < 100000000) DO Tasks.Yield; INC(yields) END
  END Run;

  PROCEDURE (q: Quick) Run*;
  BEGIN
    Tasks.AwaitReadable(q.fd);
    quickDone := TRUE;
    ChildProcesses.Close(q.fd)
  END Run;

  PROCEDURE Report(expected: LONGINT);
    VAR c: LONGINT;
  BEGIN
    SYSTEM.GET(SYSTEM.ADR(caught), c);
    Out.String("  signals caught "); Out.Int(c, 0);
    Out.String(", wakes "); Out.Int(wakes, 0);
    Out.String(" of "); Out.Int(expected, 0); Out.Ln
  END Report;

BEGIN
  Platform.SetInterruptHandler(Interrupt);

  Out.String("A: ticker, slow pipe, signals"); Out.Ln;
  NEW(ticker); NEW(reader); NEW(awaiter);
  reader.fd := ChildProcesses.Writer(lines, lineMs);
  awaiter.count := signalsA; awaiter.ackFd := ChildProcesses.Signaller(signalsA, maxPauseUs);
  Tasks.Start(ticker, Tasks.DefaultStackSize);
  Tasks.Start(reader, Tasks.DefaultStackSize);
  Tasks.Start(awaiter, Tasks.DefaultStackSize);
  Tasks.Join(ticker); Tasks.Join(reader); Tasks.Join(awaiter);
  ChildProcesses.Reap;
  Out.String("  ticks "); Out.Int(ticked, 0); Out.String(" of "); Out.Int(ticks, 0);
  Out.String("; bytes "); Out.Int(bytes, 0); Out.String(" of "); Out.Int(lines * 5, 0);
  Out.String(", ends "); Out.Int(eofs, 0); Out.Ln;
  Report(signalsA);

  Out.String("B: signals alone"); Out.Ln;
  caught := 0; wakes := 0;
  NEW(awaiter); awaiter.count := signalsB; awaiter.ackFd := ChildProcesses.Signaller(signalsB, maxPauseUs);
  Tasks.Start(awaiter, Tasks.DefaultStackSize);
  Tasks.Join(awaiter);
  ChildProcesses.Reap;
  Report(signalsB);

  Out.String("C: a ready pipe beside a task that only yields"); Out.Ln;
  NEW(busy); NEW(quick); quick.fd := ChildProcesses.FullPipe();
  Tasks.Start(busy, Tasks.DefaultStackSize);
  Tasks.Start(quick, Tasks.DefaultStackSize);
  Tasks.Join(busy); Tasks.Join(quick);
  IF quickDone THEN Out.String("  the reader ran while a task yielded")
  ELSE Out.String("  the reader starved")
  END;
  Out.Ln;

  Out.String("D: AwaitWritable of an empty pipe, AwaitReadable after a write"); Out.Ln;
  r := ChildProcesses.Pipe(w);
  Tasks.AwaitWritable(w);
  ChildProcesses.Ack(w);
  Tasks.AwaitReadable(r);
  Out.String("  bytes "); Out.Int(ChildProcesses.Drain(r), 0); Out.Ln;
  ChildProcesses.Close(r); ChildProcesses.Close(w)
END events.
