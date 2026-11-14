MODULE TaskWaiting;
  (* What Tasks needs that differs between the systems (doc/developer/
     tasks.md, decision 1), here for POSIX: the clock, the idle wait
     (poll on the descriptors tasks wait for and a self-pipe), the wake a
     signal handler gives through the self-pipe, and the traps 19 and 20,
     with their texts in TaskWaiting.c. rtl/vax/TaskWaiting.Mod has the
     same interface for VAX/VMS. For Tasks only. *)

  IMPORT SYSTEM;

  CONST
    (* misuse's cases, trap 20's texts in TaskWaiting.c *)
    unlockNotHeld* = 0; joinOfRunning* = 1; sendOnClosed* = 2;
    closeOfClosed* = 3; startOfStarted* = 4; negativeCapacity* = 5;
    negativeDescriptor = 6;
    (* poll's events, checked in TaskWaiting.c *)
    readable = 1; writable = 4;
    (* the wait's longest timeout, in ms, when the self-pipe could not be
       made, so that a post is seen that soon *)
    withoutPipe = 10;

  TYPE
    (* struct pollfd, its layout checked in TaskWaiting.c *)
    PollEntry = RECORD
      fd: SYSTEM.INT32;
      events, revents: SYSTEM.INT16
    END;
    PollEntries = POINTER TO ARRAY OF PollEntry;

  VAR
    (* entry 0 is the self-pipe's read end; Add's i-th is entry i + 1 *)
    entries: PollEntries;
    count: LONGINT;
    wakeDescriptor: SYSTEM.INT32;  (* -2 until the pipe is tried *)

  PROCEDURE ["C", "TaskWaiting.-deadlock"] DeadlockTrap;
  PROCEDURE ["C", "TaskWaiting.-misuse"] MisuseTrap(which: SYSTEM.INT32);
  PROCEDURE ["C", "TaskWaiting.-now"] CNow(): SYSTEM.INT64;
  PROCEDURE ["C", "TaskWaiting.-pipe"] CPipe(): SYSTEM.INT32;
  PROCEDURE ["C", "TaskWaiting.-wake"] CWake;
  PROCEDURE ["C", "TaskWaiting.-poll"] CPoll(entries: SYSTEM.ADDRESS;
    count, timeout: SYSTEM.INT32): SYSTEM.INT32;

  (* Trap 19, "all tasks are blocked" *)
  PROCEDURE Deadlock*;
  BEGIN
    DeadlockTrap
  END Deadlock;

  (* Trap 20 with the text of case which, one of the constants above *)
  PROCEDURE Misuse*(which: SYSTEM.INT32);
  BEGIN
    MisuseTrap(which)
  END Misuse;

  (* A monotonic clock, in microseconds *)
  PROCEDURE Now*(): HUGEINT;
  BEGIN
    RETURN CNow()
  END Now;

  (* Ends a Wait that is going on or about to start; safe in a signal
     handler (write is async-signal-safe) *)
  PROCEDURE Wake*;
  BEGIN
    CWake
  END Wake;

  (* The self-pipe's read end, which is readable after a Wake; -1 when
     it could not be made *)
  PROCEDURE WakeDescriptor*(): LONGINT;
  BEGIN
    IF wakeDescriptor = -2 THEN wakeDescriptor := CPipe() END;
    RETURN wakeDescriptor
  END WakeDescriptor;

  (* Traps (20) unless fd can be waited for *)
  PROCEDURE CheckDescriptor*(fd: LONGINT);
  BEGIN
    IF fd < 0 THEN MisuseTrap(negativeDescriptor) END
  END CheckDescriptor;

  (* Starts a list of descriptors for Wait *)
  PROCEDURE Clear*;
  BEGIN
    IF entries = NIL THEN NEW(entries, 16) END;
    entries[0].fd := SYSTEM.VAL(SYSTEM.INT32, WakeDescriptor());
    entries[0].events := readable; entries[0].revents := 0;
    count := 1
  END Clear;

  (* Adds fd to the list, waited for until it can be written to (forWriting)
     or read *)
  PROCEDURE Add*(fd: LONGINT; forWriting: BOOLEAN);
    VAR larger: PollEntries; i: LONGINT;
  BEGIN
    IF count = LEN(entries^) THEN
      NEW(larger, 2 * count);
      FOR i := 0 TO count - 1 DO larger[i] := entries[i] END;
      entries := larger
    END;
    entries[count].fd := SYSTEM.VAL(SYSTEM.INT32, fd);
    IF forWriting THEN entries[count].events := writable
    ELSE entries[count].events := readable
    END;
    entries[count].revents := 0;
    INC(count)
  END Add;

  (* Waits up to timeout ms (-1: no limit, 0: not at all) for a
     descriptor of the list to be ready or a Wake; empties the self-pipe *)
  PROCEDURE Wait*(timeout: LONGINT);
    VAR result: SYSTEM.INT32;
  BEGIN
    IF (entries[0].fd < 0) & ((timeout < 0) OR (timeout > withoutPipe)) THEN
      timeout := withoutPipe
    END;
    result := CPoll(SYSTEM.ADR(entries[0]), SYSTEM.VAL(SYSTEM.INT32, count),
      SYSTEM.VAL(SYSTEM.INT32, timeout))
  END Wait;

  (* Whether the i-th descriptor Added since Clear was found ready by Wait *)
  PROCEDURE Ready*(i: LONGINT): BOOLEAN;
  BEGIN
    RETURN entries[i + 1].revents # 0
  END Ready;

BEGIN
  wakeDescriptor := -2
END TaskWaiting.
