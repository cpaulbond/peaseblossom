MODULE TaskInput;

  (* doc/developer/tasks.md, Phase 11: standard input read by a task
     without stopping the others, for POSIX. rtl/vax/TaskInput.Mod has the
     same interface for VAX/VMS.

     Char and Line mean what In's do, read through a FormattedInput.Source
     of this module's own with In's read-ahead rule: past a line end the
     next character is not read until it is wanted, so that a line is
     returned without waiting for the next one. A Tasks.Mutex holds each
     call, so that two tasks reading at once take whole lines. A program
     reads standard input through In or through TaskInput, not both: each
     reads ahead of what it returns (In through C's getchar).

     The module keeps a buffer of 4 KiB. When it is empty, the task waits
     by Tasks.AwaitReadable(0) while the others run, then reads up to 4 KiB
     by one Platform.Read; a count of 0, or an error, is the end of the
     input, for good - but not EINTR, a signal caught during the read,
     after which it waits and reads again (PLAN.md, "Ongoing bug fixing",
     23). O_NONBLOCK is never set: descriptor 0 is shared with
     the shell, and the flag would outlive the program. A terminal in
     canonical mode is readable once a line is complete, a pipe once data
     is there, and a regular file or /dev/null always, so the read does
     not block - unless another process reading the same descriptor takes
     the data between the poll and the read, which blocks every task. *)

  IMPORT SYSTEM, Platform, FormattedInput, Tasks;

  CONST
    (* what the reader knows about nextch *)
    pending = 0; (* at the start or a line end: nextch is not read yet *)
    ready = 1; (* nextch is the next character of the line *)
    eof = 2; (* there is no more *)

    bufferSize = 4096;

  TYPE
    (* standard input as FormattedInput reads it *)
    TaskSource = RECORD (FormattedInput.Source) END;

  VAR
    (* whether the last operation succeeded *)
    Done-: BOOLEAN;
    nextch: CHAR;
    readstate: INTEGER;
    input: TaskSource;
    lock: Tasks.Mutex;
    atEnd: BOOLEAN; (* the end of the input has been read *)
    buffer: ARRAY bufferSize OF CHAR;
    length, position: LONGINT; (* the buffer's characters, the next one's *)

  (* Refills the buffer; it stays empty at the end of the input *)
  PROCEDURE Fill;
    VAR n: LONGINT; e: Platform.ErrorCode;
  BEGIN
    length := 0; position := 0;
    IF ~atEnd THEN
      REPEAT
        Tasks.AwaitReadable(Platform.StdIn);
        e := Platform.Read(Platform.StdIn, SYSTEM.ADR(buffer), bufferSize, n)
      UNTIL ~Platform.Interrupted(e);
      IF (e = 0) & (n > 0) THEN
        length := n
      ELSE
        atEnd := TRUE
      END
    END
  END Fill;

  PROCEDURE ReadChar;
  BEGIN
    IF position >= length THEN Fill END;
    IF position < length THEN
      nextch := buffer[position]; INC(position);
      readstate := ready
    ELSE
      readstate := eof
    END
  END ReadChar;

  (* Whether there is a next character: nextch, read now if it was not yet.
     *)
  PROCEDURE (VAR source: TaskSource) Ready*(): BOOLEAN;
  BEGIN
    IF readstate = pending THEN ReadChar END;
    RETURN readstate = ready
  END Ready;

  PROCEDURE (VAR source: TaskSource) Current*(): CHAR;
  BEGIN
    IF source.Ready() THEN RETURN nextch ELSE RETURN 0X END
  END Current;

  (* Moves past nextch. Past a line end the next character is not read
     until it is wanted. *)
  PROCEDURE (VAR source: TaskSource) Advance*;
  BEGIN
    IF source.Ready() THEN
      IF nextch = 0AX THEN readstate := pending ELSE ReadChar END
    END
  END Advance;

  (* The next character, line end (0AX) included. Done is FALSE, and ch 0X,
     at the end of the input. *)
  PROCEDURE Char*(VAR ch: CHAR);
    VAR found: BOOLEAN;
  BEGIN
    Tasks.Lock(lock);
    found := FormattedInput.Char(input, ch);
    Tasks.Unlock(lock);
    Done := found
  END Char;

  (* The rest of the line - up to a line feed, and without the carriage
     return before it - cut short if line cannot hold it all (the rest is
     then left for the next read). Done is FALSE at the end of the input. *)
  PROCEDURE Line*(VAR line: ARRAY OF CHAR);
    VAR found: BOOLEAN;
  BEGIN
    Tasks.Lock(lock);
    found := FormattedInput.Line(input, line);
    Tasks.Unlock(lock);
    Done := found
  END Line;

BEGIN
  nextch := 0X;
  readstate := pending;
  Done := TRUE
END TaskInput.
