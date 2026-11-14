MODULE TaskReadIn;
  (* TaskInput on VAX/VMS (doc/developer/tasks.md, Phase 11). The DCL
     symbol TASKINPUT_MODE names what is read and how:
     - TICKS: lines while a ticker task runs every 50 ms; after each line
       but the first, whether the ticker ran while the line was awaited;
       a line longer than 40 characters by its length alone.
     - LINES: the lines alone, then the end.
     - SHORT: the lines into an array of 8, so that a long one is cut.
     - CHARS: each character's code, line ends included.
     - TWO: two reader tasks taking lines at once; the lines in the order
       they were taken, and whether each reader took some.
     Orders and yes or no only, never counts that depend on timing. *)
  IMPORT Platform, Tasks, TaskInput, Out;

  CONST maxLines = 20;

  TYPE
    Ticker = POINTER TO RECORD (Tasks.TaskDesc) END;
    Reader = POINTER TO RECORD (Tasks.TaskDesc) count: LONGINT END;

  VAR
    mode: ARRAY 16 OF CHAR;
    ticked: LONGINT; finished: BOOLEAN;
    ticker: Ticker; a, b: Reader;
    taken: ARRAY maxLines, 64 OF CHAR; takenCount: LONGINT;

  PROCEDURE (t: Ticker) Run*;
  BEGIN
    WHILE ~finished DO Tasks.Sleep(50); INC(ticked) END
  END Run;

  PROCEDURE (r: Reader) Run*;
    VAR line: ARRAY 64 OF CHAR;
  BEGIN
    LOOP
      TaskInput.Line(line);
      IF ~TaskInput.Done THEN EXIT END;
      IF takenCount < maxLines THEN COPY(line, taken[takenCount]); INC(takenCount) END;
      INC(r.count);
      Tasks.Yield
    END
  END Run;

  PROCEDURE Ticks;
    VAR line: ARRAY 1024 OF CHAR; seen, n, length: LONGINT;
  BEGIN
    NEW(ticker); Tasks.Start(ticker, 0);
    n := 0;
    LOOP
      seen := ticked;
      TaskInput.Line(line);
      IF ~TaskInput.Done THEN EXIT END;
      INC(n);
      length := 0; WHILE line[length] # 0X DO INC(length) END;
      IF length > 40 THEN
        Out.String("a line of "); Out.Int(length, 0); Out.String(" characters")
      ELSE
        Out.String("line: "); Out.String(line)
      END;
      IF n > 1 THEN
        Out.String("; ticks while awaited: ");
        IF ticked > seen THEN Out.String("yes") ELSE Out.String("no") END
      END;
      Out.Ln
    END;
    Out.String("end"); Out.Ln;
    finished := TRUE; Tasks.Join(ticker)
  END Ticks;

  PROCEDURE Lines;
    VAR line: ARRAY 64 OF CHAR;
  BEGIN
    LOOP
      TaskInput.Line(line);
      IF ~TaskInput.Done THEN EXIT END;
      Out.String("line: "); Out.String(line); Out.Ln
    END;
    Out.String("end"); Out.Ln
  END Lines;

  PROCEDURE Short;
    VAR line: ARRAY 8 OF CHAR;
  BEGIN
    LOOP
      TaskInput.Line(line);
      IF ~TaskInput.Done THEN EXIT END;
      Out.String("piece: "); Out.String(line); Out.Ln
    END;
    Out.String("end"); Out.Ln
  END Short;

  PROCEDURE Chars;
    VAR ch: CHAR;
  BEGIN
    LOOP
      TaskInput.Char(ch);
      IF ~TaskInput.Done THEN EXIT END;
      Out.Int(ORD(ch), 0); Out.Char(" ")
    END;
    Out.Ln; Out.String("end, ch "); Out.Int(ORD(ch), 0); Out.Ln
  END Chars;

  PROCEDURE Two;
    VAR i: LONGINT;
  BEGIN
    NEW(a); NEW(b);
    Tasks.Start(a, 0); Tasks.Start(b, 0);
    Tasks.Join(a); Tasks.Join(b);
    FOR i := 0 TO takenCount - 1 DO Out.String("taken: "); Out.String(taken[i]); Out.Ln END;
    Out.String("both readers took lines: ");
    IF (a.count > 0) & (b.count > 0) THEN Out.String("yes") ELSE Out.String("no") END;
    Out.Ln
  END Two;

BEGIN
  Platform.GetEnv("TASKINPUT_MODE", mode);
  IF mode = "TICKS" THEN Ticks
  ELSIF mode = "LINES" THEN Lines
  ELSIF mode = "SHORT" THEN Short
  ELSIF mode = "CHARS" THEN Chars
  ELSIF mode = "TWO" THEN Two
  ELSE Out.String("unknown mode "); Out.String(mode); Out.Ln
  END
END TaskReadIn.
