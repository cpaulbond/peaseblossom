MODULE TaskEvents;
  (* Tasks' events on VAX/VMS (doc/developer/tasks.md, Phase 10), Phase
     7.3's probe made to compare output. A: a ticker; a reader of a
     mailbox a subprocess (TASKWRITER.COM) writes slowly, each read a $QIO
     whose AST posts an event; and an awaiter of events an AST posts, from
     a $SETIMR or, one time in five, a $DCLAST, made at a random point of
     the main line's work. B: the awaiter alone. A watchdog timer for each
     wait counts a lost wake instead of hanging. *)
  IMPORT SYSTEM, Tasks, Out;

  CONST
    ticks = 100; tickMs = 20;
    signalsA = 200; signalsB = 500;
    lineCount = 50;
    signalRequest = 5349474EH; watchdogRequest = 57444F47H;
    watchdogMs = 3000;
    readVirtualBlock = 31H; (* IO$_READVBLK *)

  TYPE
    AstRoutine = PROCEDURE (parameter: SYSTEM.CARD32);
    Buffer = ARRAY 256 OF CHAR;
    Iosb = RECORD status, count: SYSTEM.CARD16; info: SYSTEM.CARD32 END;
    Ticker = POINTER TO RECORD (Tasks.TaskDesc) END;
    Reader = POINTER TO RECORD (Tasks.TaskDesc) END;
    Awaiter = POINTER TO RECORD (Tasks.TaskDesc) count: LONGINT END;

  VAR
    signalled, mailboxRead: Tasks.Event;
    caught, lost: LONGINT;   (* by ASTs *)
    ticked, wakes, lines, ends, seed, sink: LONGINT;
    channel: SYSTEM.CARD16;
    iosb: Iosb; buffer: Buffer;
    ticker: Ticker; reader: Reader; awaiter: Awaiter;
    status: SYSTEM.INT32;

  PROCEDURE ["VMS", "SYS$SETIMR"] SetTimer(efn: SYSTEM.CARD32; time-: HUGEINT;
    routine: AstRoutine; request, flags: SYSTEM.CARD32): SYSTEM.INT32;
  PROCEDURE ["VMS", "SYS$CANTIM"] CancelTimer(request, mode: SYSTEM.CARD32): SYSTEM.INT32;
  PROCEDURE ["VMS", "SYS$DCLAST"] DeclareAst(routine: AstRoutine; parameter: SYSTEM.CARD32;
    mode: SYSTEM.INT32): SYSTEM.INT32;
  PROCEDURE ["VMS", "SYS$CREMBX"] CreateMailbox(permanent: SYSTEM.INT32; VAR chan: SYSTEM.CARD16;
    maxMessage, bufferQuota, protection, mode: SYSTEM.INT32; name-: ARRAY OF CHAR): SYSTEM.INT32;
  PROCEDURE ["VMS", "SYS$QIO"] Qio(efn, chan, function: SYSTEM.CARD32; VAR iosb: Iosb;
    routine: AstRoutine; parameter: SYSTEM.CARD32; VAR p1: Buffer;
    p2, p3, p4, p5, p6: SYSTEM.INT32): SYSTEM.INT32;
  PROCEDURE ["VMS", "LIB$SPAWN"] Spawn(command-, input-, output-: ARRAY OF CHAR;
    flags-: SYSTEM.CARD32): SYSTEM.INT32;

  PROCEDURE Random(n: LONGINT): LONGINT;
  BEGIN
    seed := seed * 69069 + 1;
    RETURN ASH(seed, -8) MOD n
  END Random;

  PROCEDURE Spin(n: LONGINT);
    VAR i: LONGINT;
  BEGIN
    FOR i := 1 TO n DO INC(sink) END
  END Spin;

  PROCEDURE Delta(milliseconds: LONGINT): HUGEINT;
    VAR t: HUGEINT;
  BEGIN
    t := milliseconds; RETURN -t * 10000
  END Delta;

  PROCEDURE SignalAst(parameter: SYSTEM.CARD32);
  BEGIN
    INC(caught);
    Tasks.Post(signalled)
  END SignalAst;

  PROCEDURE WatchdogAst(parameter: SYSTEM.CARD32);
  BEGIN
    INC(lost);
    Tasks.Post(signalled)
  END WatchdogAst;

  PROCEDURE ReadAst(parameter: SYSTEM.CARD32);
  BEGIN
    Tasks.Post(mailboxRead)
  END ReadAst;

  PROCEDURE (t: Ticker) Run*;
    VAR k: LONGINT;
  BEGIN
    FOR k := 1 TO ticks DO Tasks.Sleep(tickMs); INC(ticked) END
  END Run;

  PROCEDURE (r: Reader) Run*;
  BEGIN
    LOOP
      status := Qio(0, LONG(channel), readVirtualBlock, iosb, ReadAst, 0, buffer,
        LEN(buffer), 0, 0, 0, 0);
      IF ~ODD(status) THEN Out.String("  $QIO failed "); Out.Int(status, 0); Out.Ln; EXIT END;
      Tasks.Await(mailboxRead);
      IF ~ODD(iosb.status) THEN Out.String("  read failed "); Out.Card(iosb.status, 0); Out.Ln; EXIT END;
      IF (iosb.count = 3) & (buffer[0] = "E") & (buffer[1] = "N") & (buffer[2] = "D") THEN
        INC(ends); EXIT
      END;
      INC(lines)
    END
  END Run;

  PROCEDURE (a: Awaiter) Run*;
    VAR k, before: LONGINT; s: SYSTEM.INT32;
  BEGIN
    FOR k := 1 TO a.count DO
      before := lost;
      s := SetTimer(0, Delta(watchdogMs), WatchdogAst, watchdogRequest, 0);
      IF Random(5) = 0 THEN s := DeclareAst(SignalAst, 0, 0)
      ELSE s := SetTimer(0, Delta(10 + Random(20)), SignalAst, signalRequest, 0)
      END;
      IF ~ODD(s) THEN Out.String("  request failed "); Out.Int(s, 0); Out.Ln END;
      Spin(Random(3000));
      Tasks.Await(signalled);
      s := CancelTimer(watchdogRequest, 0);
      IF lost # before THEN
        (* the watchdog's post woke it: wait for the signal still due *)
        Tasks.Await(signalled)
      END;
      INC(wakes)
    END
  END Run;

  PROCEDURE Report(count: LONGINT);
  BEGIN
    Out.String("  signals caught "); Out.Int(caught, 0);
    Out.String(", wakes "); Out.Int(wakes, 0); Out.String(" of "); Out.Int(count, 0);
    Out.String(", lost "); Out.Int(lost, 0); Out.Ln
  END Report;

BEGIN
  seed := 12345;
  status := CreateMailbox(0, channel, 256, 0, 0, 0, "TASKEVENTS_MBX");
  IF ~ODD(status) THEN Out.String("$CREMBX failed "); Out.Int(status, 0); Out.Ln; HALT(1) END;
  status := Spawn("@TASKWRITER", "NLA0:", "NLA0:", 1);
  IF ~ODD(status) THEN Out.String("LIB$SPAWN failed "); Out.Int(status, 0); Out.Ln; HALT(1) END;

  Out.String("A: ticker, a mailbox a subprocess writes, AST signals"); Out.Ln;
  NEW(ticker); NEW(reader); NEW(awaiter); awaiter.count := signalsA;
  Tasks.Start(ticker, Tasks.DefaultStackSize);
  Tasks.Start(reader, Tasks.DefaultStackSize);
  Tasks.Start(awaiter, Tasks.DefaultStackSize);
  Tasks.Join(ticker); Tasks.Join(reader); Tasks.Join(awaiter);
  Out.String("  ticks "); Out.Int(ticked, 0); Out.String(" of "); Out.Int(ticks, 0);
  Out.String("; mailbox lines "); Out.Int(lines, 0); Out.String(" of "); Out.Int(lineCount, 0);
  Out.String(", ends "); Out.Int(ends, 0); Out.Ln;
  Report(signalsA);

  Out.String("B: AST signals alone"); Out.Ln;
  caught := 0; wakes := 0;
  NEW(awaiter); awaiter.count := signalsB;
  Tasks.Start(awaiter, Tasks.DefaultStackSize);
  Tasks.Join(awaiter);
  Report(signalsB)
END TaskEvents.
