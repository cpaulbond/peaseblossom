MODULE ClockFeeder;
  (* vax-tasks-examples' feeder: makes the mailbox CLOCK_MBX, spawns the
     foreign command CLOCK 2 with the mailbox as its SYS$INPUT and
     CLOCK.LOG as its SYS$OUTPUT, and writes it the User's Guide's
     commands at the guide's times: start, lap 2.5 s later, stop 1 s after
     that. Clock ends 2 s after the stop, with no command; 3 s after the
     stop an end of file ends the subprocess's DCL, which reads its next
     command from the same mailbox. Each write waits until it has been
     read; the feeder then waits for the subprocess to end. The mailbox's
     messages may be as long as TaskInput's read of 512 bytes: with a
     smaller maximum that read fails, TaskInput takes it as the end, and
     the subprocess's DCL reads the commands, STOP among them. *)
  IMPORT SYSTEM, Out;

  CONST
    writeVirtualBlock = 30H; (* IO$_WRITEVBLK *)
    writeEndOfFile = 28H; (* IO$_WRITEOF *)
    spawnNoWait = 1; (* CLI$M_NOWAIT *)
    spawnEfn = 5; timerEfn = 6; writeEfn = 7;

  TYPE
    Buffer = ARRAY 1024 OF CHAR;
    Iosb = RECORD status, count: SYSTEM.CARD16; info: SYSTEM.CARD32 END;

  VAR
    channel: SYSTEM.CARD16;
    iosb: Iosb; buffer: Buffer;
    pid, completion: SYSTEM.CARD32;

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

  PROCEDURE Pause(milliseconds: LONGINT);
    VAR t: HUGEINT;
  BEGIN
    t := milliseconds; t := -t * 10000;
    Check("$SETIMR", SetTimer(timerEfn, t, 0, 0, 0));
    Check("$WAITFR", WaitFlag(timerEfn))
  END Pause;

  (* Writes text as one message *)
  PROCEDURE Write(text: ARRAY OF CHAR);
    VAR n: LONGINT;
  BEGIN
    n := 0; WHILE text[n] # 0X DO buffer[n] := text[n]; INC(n) END;
    Check("$QIOW", Qiow(writeEfn, LONG(channel), writeVirtualBlock, iosb, 0, 0, buffer, n, 0, 0, 0, 0));
    Check("the write", SYSTEM.VAL(LONGINT, LONG(iosb.status)))
  END Write;

BEGIN
  Check("$CREMBX", CreateMailbox(0, channel, 1024, 2048, 0, 0, "CLOCK_MBX"));
  Check("$CLREF", ClearFlag(spawnEfn));
  Check("LIB$SPAWN", Spawn("CLOCK 2", "CLOCK_MBX", "CLOCK.LOG", spawnNoWait,
    NIL, pid, completion, spawnEfn));
  Write("start"); Pause(2500);
  Write("lap"); Pause(1000);
  Write("stop"); Pause(3000);
  Check("$QIOW", Qiow(writeEfn, LONG(channel), writeEndOfFile, iosb, 0, 0, buffer, 0, 0, 0, 0, 0));
  Check("$WAITFR", WaitFlag(spawnEfn));
  Out.String("subprocess ended, status odd: ");
  IF ODD(completion) THEN Out.String("yes") ELSE Out.String("no") END;
  Out.Ln
END ClockFeeder.
