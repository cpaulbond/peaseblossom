MODULE input;
  (* TaskInput on POSIX (doc/developer/tasks.md, Phase 11). The argument
     names what is read and how:
     - ticks: lines while a ticker task runs every 50 ms; after each line
       but the first, whether the ticker ran while the line was awaited.
     - lines: the lines alone, then the end.
     - short: the lines into an array of 8, so that a long one is cut.
     - chars: each character's code, line ends included.
     - two: two reader tasks taking lines at once; the lines in the order
       they were taken, each whole, and whether each reader took some.
     Orders and yes or no only, never counts that depend on timing. *)
  IMPORT Tasks, TaskInput, Args, Out;

  CONST maxLines = 20;

  TYPE
    Ticker = POINTER TO RECORD (Tasks.TaskDesc) END;
    Reader = POINTER TO RECORD (Tasks.TaskDesc) name: CHAR; count: LONGINT END;

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
    VAR line: ARRAY 64 OF CHAR; seen, n: LONGINT;
  BEGIN
    NEW(ticker); Tasks.Start(ticker, 0);
    n := 0;
    LOOP
      seen := ticked;
      TaskInput.Line(line);
      IF ~TaskInput.Done THEN EXIT END;
      INC(n);
      Out.String("line: "); Out.String(line);
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
    NEW(a); a.name := "A"; NEW(b); b.name := "B";
    Tasks.Start(a, 0); Tasks.Start(b, 0);
    Tasks.Join(a); Tasks.Join(b);
    FOR i := 0 TO takenCount - 1 DO Out.String("taken: "); Out.String(taken[i]); Out.Ln END;
    Out.String("both readers took lines: ");
    IF (a.count > 0) & (b.count > 0) THEN Out.String("yes") ELSE Out.String("no") END;
    Out.Ln
  END Two;

BEGIN
  Args.Get(1, mode);
  IF mode = "ticks" THEN Ticks
  ELSIF mode = "lines" THEN Lines
  ELSIF mode = "short" THEN Short
  ELSIF mode = "chars" THEN Chars
  ELSIF mode = "two" THEN Two
  ELSE Out.String("unknown mode "); Out.String(mode); Out.Ln
  END
END input.
