MODULE TaskInput;

  (* doc/developer/tasks.md, Phase 11: standard input read by a task
     without stopping the others, for VAX/VMS. rtl/llvm/TaskInput.Mod has
     the same interface for POSIX.

     Char and Line mean what In's do, read through a FormattedInput.Source
     of this module's own with In's read-ahead rule: past a line end the
     next character is not read until it is wanted, so that a line is
     returned without waiting for the next one. A Tasks.Mutex holds each
     call, so that two tasks reading at once take whole lines. A program
     reads standard input through In or through TaskInput, not both: each
     reads ahead of what it returns, and each reads on its own channel.

     How SYS$INPUT is read is decided at the first read, by its device
     class ($GETDVIW, DVI$_DEVCLASS; proposal 3):
     - A terminal or a mailbox is $ASSIGNed, and each record is read by a
       $QIO into a buffer of 512 bytes, whose AST posts an event the
       reading task awaits, so other tasks run meanwhile. A mailbox is
       read at most its largest message at a time (DVI$_DEVBUFSIZ), since
       a $QIO asking for more fails at once with SS$_MBTOOSML, before
       anything is read (PLAN.md, bug 20). A record gets a
       line feed after it, except a terminal read that a full buffer ended
       (terminator size 0, I/O manual 8.5): the rest of that line comes
       with the next read. The end of the input is SS$_ENDOFFILE (a
       mailbox's IO$_WRITEOF), or a terminal read ended by Ctrl/Z, which
       RMS takes as the end too; what was typed before it is dropped, as
       RMS drops it. A longer mailbox message is cut short (SS$_BUFFEROVF).
       Any other failure is the end of the input too, as an error is on
       Unix.
     - A terminal read goes through PocRtl's POC_TASK_READ, which makes
       Out's unfinished line the read's prompt, as In's is, and has lines
       written while it is pending break through it (proposals 4 and 5).
     - Anything else (a disk file, a batch job's input, NL:) is read by
       Platform.Read, a character at a time, as In reads: every task waits
       while RMS reads. *)

  IMPORT SYSTEM, Platform, FormattedInput, Tasks;

  CONST
    (* what the reader knows about nextch *)
    pending = 0; (* at the start or a line end: nextch is not read yet *)
    ready = 1; (* nextch is the next character of the line *)
    eof = 2; (* there is no more *)

    (* how SYS$INPUT is read *)
    unknown = 0; (* not yet decided *)
    byQio = 1; (* a terminal or a mailbox, by $QIO *)
    synchronous = 2; (* anything else, by Platform.Read *)

    bufferSize = 512;
    readVirtualBlock = 31H; (* IO$_READVBLK *)
    deviceClass = 4; (* DVI$_DEVCLASS *)
    deviceBufferSize = 8; (* DVI$_DEVBUFSIZ: a mailbox's largest message *)
    terminalClass = 66; (* DC$_TERM *)
    mailboxClass = 160; (* DC$_MAILBOX *)
    bufferOverflow = 1537; (* SS$_BUFFEROVF *)
    controlZ = 1AX;

  TYPE
    AstRoutine = PROCEDURE (parameter: SYSTEM.CARD32);

    (* a read's I/O status block: a terminal's has the terminator and
       its size (I/O manual 8.5), a mailbox's the sender's PID there *)
    Iosb = RECORD
      status, count, terminator, terminatorSize: SYSTEM.CARD16
    END;

    ItemList = RECORD
      length, code: SYSTEM.CARD16;
      address, returnLength: SYSTEM.ADDRESS;
      end: SYSTEM.CARD32
    END;

    Buffer = ARRAY bufferSize + 1 OF CHAR;

    (* standard input as FormattedInput reads it *)
    TaskSource = RECORD (FormattedInput.Source) END;

  VAR
    (* whether the last operation succeeded *)
    Done-: BOOLEAN;
    nextch: CHAR;
    readstate: INTEGER;
    input: TaskSource;
    lock: Tasks.Mutex;
    mode: INTEGER;
    terminal: BOOLEAN; (* by $QIO from a terminal, not a mailbox *)
    atEnd: BOOLEAN; (* the end of the input has been read *)
    channel: SYSTEM.CARD16;
    iosb: Iosb;
    readDone: Tasks.Event; (* posted by the read's AST *)
    buffer: Buffer;
    length, position: LONGINT; (* the buffer's characters, the next one's *)
    readSize: SYSTEM.INT32; (* the most a mailbox read asks for *)

  PROCEDURE ["VMS", "SYS$GETDVIW"] GetDeviceInformation(efn, chan: SYSTEM.CARD32;
    name-: ARRAY OF CHAR; VAR items: ItemList; VAR status: Iosb;
    routine, parameter, unused: SYSTEM.ADDRESS): SYSTEM.INT32;
  PROCEDURE ["VMS", "SYS$ASSIGN"] Assign(name-: ARRAY OF CHAR; VAR chan: SYSTEM.CARD16;
    mode: SYSTEM.INT32; mailbox: SYSTEM.ADDRESS): SYSTEM.INT32;
  PROCEDURE ["VMS", "SYS$QIO"] Qio(efn, chan, function: SYSTEM.CARD32; VAR status: Iosb;
    routine: AstRoutine; parameter: SYSTEM.CARD32; VAR p1: Buffer;
    p2, p3, p4, p5, p6: SYSTEM.INT32): SYSTEM.INT32;
  PROCEDURE ["VMS", "POC_TASK_READ"] TaskRead(chan: SYSTEM.CARD32; VAR into: Buffer;
    size: SYSTEM.INT32; VAR status: Iosb; routine: AstRoutine;
    parameter: SYSTEM.CARD32): SYSTEM.INT32;
  PROCEDURE ["VMS", "POC_TASK_READ_DONE"] TaskReadDone;

  PROCEDURE ReadAst(parameter: SYSTEM.CARD32);
  BEGIN
    Tasks.Post(readDone)
  END ReadAst;

  (* Decides how SYS$INPUT is read *)
  PROCEDURE Choose;
    VAR class, size: SYSTEM.CARD32; items: ItemList; status: Iosb;
  BEGIN
    mode := synchronous;
    class := 0;
    items.length := 4; items.code := deviceClass;
    items.address := SYSTEM.ADR(class); items.returnLength := 0; items.end := 0;
    IF ODD(GetDeviceInformation(0, 0, "SYS$INPUT", items, status, 0, 0, 0))
        & ODD(status.status)
        & ((class = terminalClass) OR (class = mailboxClass))
        & ODD(Assign("SYS$INPUT", channel, 0, 0)) THEN
      mode := byQio;
      terminal := class = terminalClass;
      readSize := bufferSize;
      IF ~terminal THEN
        size := 0;
        items.length := 4; items.code := deviceBufferSize;
        items.address := SYSTEM.ADR(size); items.returnLength := 0; items.end := 0;
        IF ODD(GetDeviceInformation(0, LONG(channel), "", items, status, 0, 0, 0))
            & ODD(status.status) & (size > 0) & (size < bufferSize) THEN
          readSize := SYSTEM.VAL(SYSTEM.INT32, size)
        END
      END
    END
  END Choose;

  (* The next record into the buffer, by $QIO, the task waiting for it *)
  PROCEDURE ReadRecord;
    VAR status: SYSTEM.INT32; result, n: LONGINT;
  BEGIN
    IF terminal THEN status := TaskRead(channel, buffer, bufferSize, iosb, ReadAst, 0)
    ELSE
      status := Qio(0, channel, readVirtualBlock, iosb, ReadAst, 0, buffer, readSize, 0, 0, 0, 0)
    END;
    IF ~ODD(status) THEN atEnd := TRUE
    ELSE
      Tasks.Await(readDone);
      IF terminal THEN TaskReadDone END;
      result := SYSTEM.VAL(LONGINT, LONG(iosb.status));
      n := SYSTEM.VAL(LONGINT, LONG(iosb.count));
      IF ~ODD(result) & (result # bufferOverflow) THEN atEnd := TRUE
      ELSIF terminal & (iosb.terminatorSize # 0) & (iosb.terminator = ORD(controlZ)) THEN
        atEnd := TRUE
      ELSE
        length := n;
        IF ~terminal OR (iosb.terminatorSize # 0) THEN
          buffer[length] := 0AX; INC(length)
        END
      END
    END
  END ReadRecord;

  (* Refills the buffer; it stays empty at the end of the input *)
  PROCEDURE Fill;
    VAR n: LONGINT;
  BEGIN
    length := 0; position := 0;
    IF ~atEnd THEN
      IF mode = unknown THEN Choose END;
      IF mode = byQio THEN ReadRecord
      ELSIF (Platform.Read(Platform.StdIn, SYSTEM.ADR(buffer), 1, n) = 0) & (n = 1) THEN
        length := 1
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
  mode := unknown;
  Done := TRUE
END TaskInput.
