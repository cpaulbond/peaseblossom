MODULE EmptyRecords;
(* PLAN.md bug 28: on 64-bit targets the collector freed a reachable
   object of a record with no fields, since its data address was the next
   block's start (or the bump), which marking took for it. *)
IMPORT SYSTEM, Out, GarbageCollectedHeap;

CONST count = 100;

TYPE
  Empty = POINTER TO EmptyDesc;
  EmptyDesc = RECORD END;
  Filled = POINTER TO FilledDesc;
  FilledDesc = RECORD x: LONGINT END;

VAR
  lastEmpty: Empty;
  afterLast: Filled;
  empties: ARRAY count OF Empty;
  filleds: ARRAY count OF Filled;
  index, freed: LONGINT;
  header: SYSTEM.ADDRESS;

PROCEDURE (e: Empty) Answer(): INTEGER;
BEGIN RETURN 42
END Answer;

(* allocated from below the current stack, so no stale copy of the
   pointer is left where the collector scans *)
PROCEDURE MakeLastEmpty(depth: INTEGER);
BEGIN
  IF depth = 0 THEN NEW(lastEmpty) ELSE MakeLastEmpty(depth - 1) END
END MakeLastEmpty;

PROCEDURE MakePairs;
  VAR i: LONGINT;
BEGIN
  FOR i := 0 TO count - 1 DO NEW(empties[i]); NEW(filleds[i]) END
END MakePairs;

(* overwrites the stack the allocations used, then collects *)
PROCEDURE ClobberAndCollect(depth: INTEGER);
  VAR words: ARRAY 512 OF LONGINT; i: LONGINT;
BEGIN
  FOR i := 0 TO LEN(words) - 1 DO words[i] := i END;
  IF depth > 0 THEN ClobberAndCollect(depth - 1) ELSE GarbageCollectedHeap.Collect END;
  IF words[100] # 100 THEN Out.Ln END
END ClobberAndCollect;

BEGIN
  (* the last block allocated: its data address was the bump *)
  MakeLastEmpty(20);
  ClobberAndCollect(30);
  NEW(afterLast);
  Out.String("last empty object's block reused: ");
  IF SYSTEM.VAL(SYSTEM.ADDRESS, afterLast) = SYSTEM.VAL(SYSTEM.ADDRESS, lastEmpty) THEN
    Out.String("yes")
  ELSE
    Out.String("no")
  END;
  Out.Ln;
  (* each followed by another block: its data address was that block's *)
  MakePairs;
  ClobberAndCollect(30);
  freed := 0;
  FOR index := 0 TO count - 1 DO
    SYSTEM.GET(SYSTEM.VAL(SYSTEM.ADDRESS, empties[index]) - 2 * SIZE(SYSTEM.ADDRESS), header);
    IF ~ODD(header DIV 2) THEN INC(freed) END
  END;
  Out.String("empty objects freed while reachable: "); Out.Int(freed, 0); Out.Ln;
  Out.String("method call on the last one: "); Out.Int(lastEmpty.Answer(), 0); Out.Ln;
  Out.String("method call on a paired one: "); Out.Int(empties[count - 1].Answer(), 0); Out.Ln
END EmptyRecords.
