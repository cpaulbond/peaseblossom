MODULE TaskMailbox;
  IMPORT SYSTEM, Out, Tasks, STARLET, IODEF, VmsArguments;

  TYPE
    Reader = POINTER TO RECORD (Tasks.TaskDesc) END;

  VAR
    channel: SYSTEM.CARD16;
    readStatus: VmsArguments.IOStatusBlock;
    received: ARRAY 64 OF CHAR;
    readDone: Tasks.Event; (* posted by ReadDone *)
    reader: Reader;

  (* an AST routine, a read's completion: it only posts *)
  PROCEDURE ReadDone(parameter: SYSTEM.CARD32);
  BEGIN
    Tasks.Post(readDone)
  END ReadDone;

  (* reads the mailbox a message at a time, to its end of file *)
  PROCEDURE (r: Reader) Run*;
    VAR status: SYSTEM.INT32;
  BEGIN
    LOOP
      status := STARLET.SYS$QIO(0, channel, IODEF.IO$_READVBLK, readStatus,
        ReadDone, 0, received, LEN(received) - 1, 0, 0, 0, 0);
      Tasks.Await(readDone);
      IF ~ODD(readStatus.status) THEN EXIT END;
      received[readStatus.count] := 0X;
      Out.String("  read: "); Out.String(received); Out.Ln
    END;
    Out.String("  the end of file"); Out.Ln
  END Run;

  (* writes a message, or with function IO$_WRITEOF an end of file,
     without waiting for it to be read *)
  PROCEDURE Write(function: SYSTEM.CARD16; text: ARRAY OF CHAR);
    VAR status: SYSTEM.INT32; writeStatus: VmsArguments.IOStatusBlock;
      message: ARRAY 64 OF CHAR; length: LONGINT;
  BEGIN
    message := text; length := 0;
    WHILE message[length] # 0X DO INC(length) END;
    status := STARLET.SYS$QIOW(0, channel, function + IODEF.IO$M_NOW,
      writeStatus, NIL, 0, message, length, 0, 0, 0, 0)
  END Write;

  PROCEDURE Run;
    VAR status: SYSTEM.INT32;
  BEGIN
    status := STARLET.SYS$CREMBX(0, channel, 64, 128, 0, 0, NIL, 0);
    NEW(reader); Tasks.Start(reader, Tasks.DefaultStackSize);
    Out.String("the reader waits"); Out.Ln;
    Tasks.Sleep(100);
    Out.String("sending one"); Out.Ln;
    Write(IODEF.IO$_WRITEVBLK, "one"); Tasks.Sleep(100);
    Out.String("sending two"); Out.Ln;
    Write(IODEF.IO$_WRITEVBLK, "two"); Tasks.Sleep(100);
    Out.String("sending the end of file"); Out.Ln;
    Write(IODEF.IO$_WRITEOF, "");
    Tasks.Join(reader);
    status := STARLET.SYS$DASSGN(channel)
  END Run;

BEGIN
  Run
END TaskMailbox.
