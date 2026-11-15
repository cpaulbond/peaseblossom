MODULE Primes;  (* the first n primes, by a chain of filter tasks *)

  IMPORT Tasks, Args, Out;

  CONST stackSize = 16384;   (* each task's; Coroutines raises it to its least *)

  TYPE
    Number = POINTER TO NumberDesc;
    NumberDesc = RECORD (Tasks.MessageDesc) value: LONGINT END;
    Generator = POINTER TO GeneratorDesc;
    GeneratorDesc = RECORD (Tasks.TaskDesc) out: Tasks.Channel END;
    Filter = POINTER TO FilterDesc;
    FilterDesc = RECORD (Tasks.TaskDesc)
      in, out: Tasks.Channel;
      prime: LONGINT
    END;

  VAR
    count, i: LONGINT;
    channel: Tasks.Channel;
    generator: Generator;
    filter: Filter;
    m: Tasks.Message;

  (* Sends 2, 3, 4, ... for ever *)
  PROCEDURE (g: Generator) Run*;
    VAR n: Number; i: LONGINT;
  BEGIN
    i := 2;
    LOOP NEW(n); n.value := i; Tasks.Send(g.out, n); INC(i) END
  END Run;

  (* Passes on the numbers its prime does not divide *)
  PROCEDURE (f: Filter) Run*;
    VAR m: Tasks.Message;
  BEGIN
    WHILE Tasks.Receive(f.in, m) DO
      IF m(Number).value MOD f.prime # 0 THEN Tasks.Send(f.out, m) END
    END
  END Run;

BEGIN
  count := 10;
  IF Args.argc > 1 THEN Args.GetInt(1, count) END;
  channel := Tasks.NewChannel(0);
  NEW(generator); generator.out := channel;
  Tasks.Start(generator, stackSize);
  (* The first number out of the chain is a prime; it gets a filter of
     its own at the chain's end. *)
  FOR i := 1 TO count DO
    IF Tasks.Receive(channel, m) THEN
      Out.Int(m(Number).value, 0); Out.Ln;
      NEW(filter); filter.in := channel; filter.prime := m(Number).value;
      channel := Tasks.NewChannel(0); filter.out := channel;
      Tasks.Start(filter, stackSize)
    END
  END
END Primes.
