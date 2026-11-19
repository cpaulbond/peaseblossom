MODULE stale;
  (* Collections under valgrind's memcheck while the stack holds slots no
     one has written since their frame was made, with a stale pointer to a
     chain of blocks nothing else reaches, which the scan keeps and traces
     (doc/developer/collector-under-valgrind.md). *)
  IMPORT SYSTEM, GarbageCollectedHeap, Out, Hole;

  CONST nodes = 100;

  TYPE
    Node = POINTER TO NodeRecord;
    NodeRecord = RECORD next: Node; value: LONGINT END;

  VAR
    list, x, chain: Node;
    k, sum: LONGINT;
    collect: Hole.Collect;

  PROCEDURE Collect;
  BEGIN
    GarbageCollectedHeap.Collect
  END Collect;

BEGIN
  collect := Collect;
  FOR k := 1 TO nodes DO NEW(x); x.next := list; x.value := k; list := x END;
  x := NIL;
  FOR k := 1 TO 10 DO
    NEW(chain); NEW(chain.next); NEW(chain.next.next);
    Hole.Smear(SYSTEM.VAL(SYSTEM.ADDRESS, chain));
    chain := NIL;
    Hole.Call(collect)
  END;
  sum := 0; x := list;
  WHILE x # NIL DO sum := sum + x.value; x := x.next END;
  Out.String("sum "); Out.Int(sum, 0); Out.Ln;
  Out.String("collections "); Out.Int(GarbageCollectedHeap.CollectionCount(), 0); Out.Ln
END stale.
