MODULE AddressBounds;
  (* MAX(SYSTEM.ADDRESS) and MIN(SYSTEM.ADDRESS) (bug 27), as constants
     and exported, against the bounds reached by doubling *)
  IMPORT SYSTEM;
  CONST max* = MAX(SYSTEM.ADDRESS); min* = MIN(SYSTEM.ADDRESS);
END AddressBounds.
