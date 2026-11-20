MODULE strict;
  (* -strict: indexing a string constant and LEN of one are poc's, each
     reported, in a statement, a CONST, an array's length and a CASE
     label; passing one whole is the report's, as is LEN of an array *)
  IMPORT Lib;
  CONST s = "abc"; c = s[1]; n = LEN(Lib.name);
  VAR ch: CHAR; i: LONGINT; a: ARRAY LEN(s) OF CHAR;

  PROCEDURE P(x: ARRAY OF CHAR);
  END P;

BEGIN
  ch := s[0]; ch := Lib.name[i]; i := LEN(s); i := LEN(Lib.name, 0);
  CASE ch OF s[2]: END;
  P(s); i := LEN(a)
END strict.
