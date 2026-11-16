MODULE clock;
  (* PLAN.md, "Ongoing bug fixing", 24: the first Platform.GetClock of
     the program, made in a task with the least stack, 16 KiB. libc loads
     the local time zone there, which overran it on NetBSD and OpenBSD
     until Coroutines loaded the zones before making the first stack. *)
  IMPORT Platform, Tasks, Out;
  TYPE T = POINTER TO RECORD (Tasks.TaskDesc) END;
  VAR t: T;
  PROCEDURE (t: T) Run*;
    VAR c, d: LONGINT;
  BEGIN
    Platform.GetClock(c, d);
    Out.String("the clock read in a 16 KiB task"); Out.Ln
  END Run;
BEGIN
  NEW(t); Tasks.Start(t, 16384); Tasks.Join(t);
  Out.String("done"); Out.Ln
END clock.
