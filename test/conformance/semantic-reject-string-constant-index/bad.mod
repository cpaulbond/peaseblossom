MODULE bad;
  (* doc/developer/language-extensions.md, "Indexing a string constant":
     a string constant is read-only, one-dimensional and ends at its 0X;
     a CHAR constant is no string *)
  IMPORT SYSTEM;
  CONST s = "abc"; c = 41X; past = s[4];
  VAR ch: CHAR; i: INTEGER; a: SYSTEM.ADDRESS;

  PROCEDURE P(VAR x: CHAR);
  END P;

BEGIN
  s[0] := "z";
  P(s[1]);
  a := SYSTEM.ADR(s[0]);
  INC(s[1]);
  ch := c[0];
  i := SHORT(LEN(s, 1));
  ch := s[4];
  ch := s[-1];
  ch := s[1, 0];
  ch := s.x;
  ch := s^;
  CASE ch OF s[5]: END
END bad.
