MODULE Hole;
  (* The C part of the fixture: Hole.c. *)
  IMPORT SYSTEM;

  TYPE Collect* = PROCEDURE;

  (* fills a frame's slots with word and returns *)
  PROCEDURE ["C", "Hole.-smear"] Smear*(word: SYSTEM.ADDRESS);
  (* calls collect from a frame whose slots it never writes *)
  PROCEDURE ["C", "Hole.-call"] Call*(collect: Collect);
END Hole.
