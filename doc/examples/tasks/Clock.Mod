MODULE Clock;  (* a stopwatch: ticks, typed commands, and a timeout *)

  IMPORT Tasks, TaskInput, Args, Out;

  CONST tick = 100;   (* milliseconds *)

  TYPE
    Ticker = POINTER TO TickerDesc;
    TickerDesc = RECORD (Tasks.TaskDesc) ticks: Tasks.Channel END;
    Reader = POINTER TO ReaderDesc;
    ReaderDesc = RECORD (Tasks.TaskDesc) commands: Tasks.Channel END;
    Command = POINTER TO CommandDesc;
    CommandDesc = RECORD (Tasks.MessageDesc) text: ARRAY 32 OF CHAR END;

  VAR
    ticker: Ticker;
    reader: Reader;
    from: ARRAY 3 OF Tasks.Channel;   (* ticks, commands, the timeout *)
    m: Tasks.Message;
    idle: LONGINT;     (* seconds a stopped clock waits for a command *)
    tenths: LONGINT;   (* the time the clock has run *)
    running, done: BOOLEAN;

  (* A tick, NIL, every tenth of a second, for ever *)
  PROCEDURE (t: Ticker) Run*;
  BEGIN
    LOOP Tasks.Sleep(tick); Tasks.Send(t.ticks, NIL) END
  END Run;

  (* Each line of the input as a command, then NIL *)
  PROCEDURE (r: Reader) Run*;
    VAR c: Command;
  BEGIN
    LOOP
      NEW(c); TaskInput.Line(c.text);
      IF ~TaskInput.Done THEN EXIT END;
      Tasks.Send(r.commands, c)
    END;
    Tasks.Send(r.commands, NIL)
  END Run;

  PROCEDURE ShowTime;
    VAR seconds: LONGINT;
  BEGIN
    seconds := tenths DIV 10;
    Out.Int(seconds DIV 60, 0); Out.Char(":");
    Out.Int(seconds MOD 60 DIV 10, 0); Out.Int(seconds MOD 10, 0)
  END ShowTime;

  (* A stopped clock waits idle seconds for a command; a running one
     waits for ever. *)
  PROCEDURE SetTimeout;
  BEGIN
    IF running THEN from[2] := NIL ELSE from[2] := Tasks.After(idle * 1000) END
  END SetTimeout;

  PROCEDURE Obey(command: ARRAY OF CHAR);
  BEGIN
    IF command = "start" THEN running := TRUE; Out.String("started")
    ELSIF command = "stop" THEN
      running := FALSE; Out.String("stopped at "); ShowTime
    ELSIF command = "lap" THEN Out.String("lap "); ShowTime
    ELSIF command = "reset" THEN tenths := 0; Out.String("reset")
    ELSIF command = "quit" THEN done := TRUE; Out.String("quit")
    ELSE Out.String("start, stop, lap, reset or quit")
    END;
    Out.Ln
  END Obey;

BEGIN
  idle := 60;
  IF Args.argc > 1 THEN Args.GetInt(1, idle) END;
  NEW(ticker); ticker.ticks := Tasks.NewChannel(1);
  Tasks.Start(ticker, Tasks.DefaultStackSize);
  NEW(reader); reader.commands := Tasks.NewChannel(0);
  Tasks.Start(reader, Tasks.DefaultStackSize);
  from[0] := ticker.ticks; from[1] := reader.commands;
  SetTimeout;
  REPEAT
    CASE Tasks.Select(from, m) OF
      0: IF running THEN
           INC(tenths);
           IF tenths MOD 10 = 0 THEN ShowTime; Out.Ln END
         END
    | 1: IF m = NIL THEN Out.String("end of input"); Out.Ln; done := TRUE
         ELSE Obey(m(Command).text); SetTimeout
         END
    | 2: Out.String("no command for "); Out.Int(idle, 0);
         Out.String(" seconds"); Out.Ln; done := TRUE
    END
  UNTIL done
END Clock.
