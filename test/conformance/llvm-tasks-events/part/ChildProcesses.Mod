MODULE ChildProcesses;
  (* llvm-tasks-events' child processes, from ChildProcesses.c beside
     this module: one that writes a pipe slowly, one that sends SIGINT at
     random moments, each signal waiting for an acknowledgement before the
     next, and the pipes they and the test use. *)
  IMPORT SYSTEM;

  (* A child writing lines lines of 5 bytes, one every interval ms; the
     read end, non-blocking *)
  PROCEDURE ["C", "ChildProcesses.-writer"] Writer*(lines, interval: SYSTEM.INT32): SYSTEM.INT32;
  (* A child sending SIGINT count times, each after a random pause of up
     to maxPause us, waiting for a byte on the acknowledgement pipe
     before the next; that pipe's write end *)
  PROCEDURE ["C", "ChildProcesses.-signaller"] Signaller*(count, maxPause: SYSTEM.INT32): SYSTEM.INT32;
  (* One byte to fd *)
  PROCEDURE ["C", "ChildProcesses.-ack"] Ack*(fd: SYSTEM.INT32);
  (* What read returns: bytes, 0 at the end, -1 for none yet *)
  PROCEDURE ["C", "ChildProcesses.-drain"] Drain*(fd: SYSTEM.INT32): SYSTEM.INT32;
  (* A pipe with a byte already in it; its read end, non-blocking *)
  PROCEDURE ["C", "ChildProcesses.-full-pipe"] FullPipe*(): SYSTEM.INT32;
  (* A pipe's read end, non-blocking, and its write end in w *)
  PROCEDURE ["C", "ChildProcesses.-pipe"] Pipe*(VAR w: SYSTEM.INT32): SYSTEM.INT32;
  PROCEDURE ["C", "ChildProcesses.-close"] Close*(fd: SYSTEM.INT32);
  (* Waits for every child to end *)
  PROCEDURE ["C", "ChildProcesses.-reap"] Reap*;

END ChildProcesses.
