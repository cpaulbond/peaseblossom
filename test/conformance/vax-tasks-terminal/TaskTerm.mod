MODULE TaskTerm;

  (* vax-tasks-terminal (doc/developer/tasks.md, Phase 11): TaskInput reads
     lines from the terminal while a ticker task writes a line every 700 ms;
     each tick's line breaks through the pending read, and the read's
     prompt and what was typed so far are redrawn after it. Reads until
     the end of the input (Ctrl/Z). terminal.exp types the lines. *)

  IMPORT Tasks, TaskInput, Out;

  TYPE
    Ticker = POINTER TO RECORD (Tasks.TaskDesc) END;

  VAR
    ticker: Ticker;
    finished: BOOLEAN;
    line: ARRAY 80 OF CHAR;

  PROCEDURE (t: Ticker) Run*;
  BEGIN
    LOOP
      Tasks.Sleep(700);
      IF finished THEN EXIT END;
      Out.String("tick"); Out.Ln
    END
  END Run;

BEGIN
  NEW(ticker); Tasks.Start(ticker, 0);
  Out.String("TASKTERM START"); Out.Ln;
  LOOP
    Out.String("Text? ");
    TaskInput.Line(line);
    IF ~TaskInput.Done THEN EXIT END;
    Out.String("line: "); Out.String(line); Out.Ln
  END;
  Out.Ln; Out.String("end of input"); Out.Ln;
  finished := TRUE; Tasks.Join(ticker)
END TaskTerm.
