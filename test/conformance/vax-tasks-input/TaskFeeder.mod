MODULE TaskFeeder;
  (* vax-tasks-input's feeder: makes the mailbox TASKINPUT_MBX, spawns
     RUN TASKREADIN with the mailbox as its SYS$INPUT and TASKREADIN.LOG
     as its SYS$OUTPUT, writes it five messages 300 ms apart - one empty,
     one of 600 characters, longer than TaskInput's buffer of 512 - then
     an end of file, and waits for the subprocess to end. A second end of
     file is the subprocess's DCL's: once the program exits, DCL reads its
     next command from the same SYS$INPUT, the mailbox, and logs out only
     at an end of file there. Each write waits until it has been read. *)
  IMPORT SYSTEM, Out;

  CONST
    writeVirtualBlock = 30H; (* IO$_WRITEVBLK *)
    writeEndOfFile = 28H; (* IO$_WRITEOF *)
    spawnNoWait = 1; (* CLI$M_NOWAIT *)
    spawnEfn = 5; timerEfn = 6; writeEfn = 7;
    pauseMs = 300;

  TYPE
    Buffer = ARRAY 1024 OF CHAR;
    Iosb = RECORD status, count: SYSTEM.CARD16; info: SYSTEM.CARD32 END;

  VAR
    channel: SYSTEM.CARD16;
    iosb: Iosb; buffer: Buffer;
    pid, completion: SYSTEM.CARD32;
    status: SYSTEM.INT32;
    i: LONGINT;

  PROCEDURE ["VMS", "SYS$CREMBX"] CreateMailbox(permanent: SYSTEM.INT32; VAR chan: SYSTEM.CARD16;
    maxMessage, bufferQuota, protection, mode: SYSTEM.INT32; name-: ARRAY OF CHAR): SYSTEM.INT32;
  PROCEDURE ["VMS", "SYS$QIOW"] Qiow(efn, chan, function: SYSTEM.CARD32; VAR iosb: Iosb;
    routine: SYSTEM.ADDRESS; parameter: SYSTEM.CARD32; VAR p1: Buffer;
    p2, p3, p4, p5, p6: SYSTEM.INT32): SYSTEM.INT32;
  PROCEDURE ["VMS", "SYS$SETIMR"] SetTimer(efn: SYSTEM.CARD32; time-: HUGEINT;
    routine: SYSTEM.ADDRESS; request, flags: SYSTEM.CARD32): SYSTEM.INT32;
  PROCEDURE ["VMS", "SYS$WAITFR"] WaitFlag(efn: SYSTEM.CARD32): SYSTEM.INT32;
  PROCEDURE ["VMS", "SYS$CLREF"] ClearFlag(efn: SYSTEM.CARD32): SYSTEM.INT32;
  PROCEDURE ["VMS", "LIB$SPAWN"] Spawn(command-, input-, output-: ARRAY OF CHAR;
    flags-: SYSTEM.CARD32; name-: ARRAY OF CHAR; VAR id, completion: SYSTEM.CARD32;
    efn-: SYSTEM.CARD8): SYSTEM.INT32;

  PROCEDURE Check(what: ARRAY OF CHAR; s: SYSTEM.INT32);
  BEGIN
    IF ~ODD(s) THEN Out.String(what); Out.String(" failed "); Out.Int(s, 0); Out.Ln; HALT(1) END
  END Check;

  PROCEDURE Pause;
    VAR t: HUGEINT;
  BEGIN
    t := pauseMs; t := -t * 10000;
    Check("$SETIMR", SetTimer(timerEfn, t, 0, 0, 0));
    Check("$WAITFR", WaitFlag(timerEfn))
  END Pause;

  (* Writes the first n characters of buffer as one message *)
  PROCEDURE Write(n: LONGINT);
  BEGIN
    Check("$QIOW", Qiow(writeEfn, LONG(channel), writeVirtualBlock, iosb, 0, 0, buffer, n, 0, 0, 0, 0));
    Check("the write", SYSTEM.VAL(LONGINT, LONG(iosb.status)));
    Pause
  END Write;

  PROCEDURE WriteText(text: ARRAY OF CHAR);
    VAR n: LONGINT;
  BEGIN
    n := 0; WHILE text[n] # 0X DO buffer[n] := text[n]; INC(n) END;
    Write(n)
  END WriteText;

BEGIN
  Check("$CREMBX", CreateMailbox(0, channel, 1024, 2048, 0, 0, "TASKINPUT_MBX"));
  Check("$CLREF", ClearFlag(spawnEfn));
  Check("LIB$SPAWN", Spawn("RUN TASKREADIN", "TASKINPUT_MBX", "TASKREADIN.LOG", spawnNoWait,
    NIL, pid, completion, spawnEfn));
  WriteText("one");
  Write(0);
  FOR i := 0 TO 599 DO buffer[i] := CHR(ORD("a") + i MOD 26) END;
  Write(600);
  WriteText("two");
  WriteText("three");
  FOR i := 1 TO 2 DO
    Check("$QIOW", Qiow(writeEfn, LONG(channel), writeEndOfFile, iosb, 0, 0, buffer, 0, 0, 0, 0, 0))
  END;
  Check("$WAITFR", WaitFlag(spawnEfn));
  Out.String("subprocess ended, status odd: ");
  IF ODD(completion) THEN Out.String("yes") ELSE Out.String("no") END;
  Out.Ln
END TaskFeeder.
