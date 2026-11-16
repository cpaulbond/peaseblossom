MODULE twotasks;
  (* Two tasks that yield to each other: their stacks are next to each
     other, so memcheck, without them registered, took each switch for a
     push or a pop. *)
  IMPORT Tasks, Out;
  TYPE Yielder = POINTER TO RECORD (Tasks.TaskDesc) id: INTEGER END;
  VAR a, b: Yielder;
  PROCEDURE (y: Yielder) Run*;
    VAR i: INTEGER;
  BEGIN
    FOR i := 1 TO 3 DO Out.Int(y.id, 0); Out.Int(i, 2); Out.Ln; Tasks.Yield END
  END Run;
BEGIN
  NEW(a); a.id := 1; NEW(b); b.id := 2;
  Tasks.Start(a, 0); Tasks.Start(b, 0);
  Tasks.Join(a); Tasks.Join(b)
END twotasks.
