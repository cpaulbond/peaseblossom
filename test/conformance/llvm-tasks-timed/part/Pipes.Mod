MODULE Pipes;
  (* llvm-tasks-timed's pipes, from Pipes.c beside this module: both
     ends non-blocking. *)
  IMPORT SYSTEM;

  (* A pipe's read end, and its write end in w; -1 if it could not be made *)
  PROCEDURE ["C", "Pipes.-make"] Make*(VAR w: SYSTEM.INT32): SYSTEM.INT32;
  (* One byte to fd *)
  PROCEDURE ["C", "Pipes.-put"] Put*(fd: SYSTEM.INT32);
  (* Writes to fd until it is full; how many bytes *)
  PROCEDURE ["C", "Pipes.-fill"] Fill*(fd: SYSTEM.INT32): SYSTEM.INT32;
  (* Reads fd until nothing is left; how many bytes *)
  PROCEDURE ["C", "Pipes.-drain"] Drain*(fd: SYSTEM.INT32): SYSTEM.INT32;
  PROCEDURE ["C", "Pipes.-close"] Close*(fd: SYSTEM.INT32);

END Pipes.
