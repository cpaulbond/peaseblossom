MODULE probe;
  (* Copies and conversions that clang does with SSE2 for a CPU that has
     it, as pentium4 and every x86-64 CPU do *)
  TYPE Vector = ARRAY 64 OF LONGREAL; Block = RECORD a: ARRAY 40 OF LONGINT END;
  VAR v, w: Vector; b, c: Block; i: LONGINT; s: LONGREAL; r: REAL;
BEGIN
  FOR i := 0 TO 63 DO v[i] := i * 1.5D0 END;
  w := v; c := b;
  s := 0; FOR i := 0 TO 63 DO s := s + w[i] * v[i] END;
  r := SHORT(s); i := ENTIER(s)
END probe.
