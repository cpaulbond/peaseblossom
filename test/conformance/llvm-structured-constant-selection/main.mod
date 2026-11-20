MODULE main;
(* PLAN.md, "Ongoing bug fixing", 32: a selection from a structured
   constant whose selectors are all constant is a constant, so the LLVM
   back end gives its value, as the VAX back end does, rather than loading
   it from the module's copy of the constant behind index checks. Every
   such selection is in Folded, whose IR test.sh checks; Copied has the
   ones that still use the copy: an array result, an array field, a
   variable index. *)
IMPORT Inner, Relay, Out;
TYPE
  Mixed = RECORD
    r: REAL; l: LONGREAL; c: CHAR; b: BOOLEAN; s: SET; h: HUGEINT;
    name: ARRAY 8 OF CHAR
  END;
  Squares = ARRAY 5 OF INTEGER;
  Table = ARRAY 2, 3 OF LONGINT;
CONST
  squares = Squares{0, 1, 4, 9, 16};
  table = Table{{1, 2, 3}, {40, 50, 60}};
  mixed = Mixed{r := 1.5, l := 2.25D0, c := "q", b := TRUE, s := {1, 3}, h := 12345678901, name := "in"};

PROCEDURE Folded;
BEGIN
  Out.Int(squares[3], 0); Out.Char(" ");
  Out.Int(table[1, 2], 0); Out.Char(" ");
  Out.Int(table[0][1], 0); Out.Char(" ");
  Out.Real(mixed.r, 0); Out.Char(" ");
  Out.LongReal(mixed.l, 0); Out.Char(" ");
  Out.Char(mixed.c); Out.Char(" ");
  IF mixed.b THEN Out.String("TRUE") ELSE Out.String("FALSE") END; Out.Char(" ");
  IF 3 IN mixed.s THEN Out.String("3 in") ELSE Out.String("3 out") END; Out.Char(" ");
  Out.Int(mixed.h, 0); Out.Ln;
  Out.Int(Inner.origin.x, 0); Out.Char(" ");
  Out.Int(Inner.identity[1, 1], 0); Out.Char(" ");
  Out.Int(Relay.origin.y, 0); Out.Char(" ");
  Out.Int(Relay.identity[0, 1], 0); Out.Ln
END Folded;

PROCEDURE Copied;
  VAR row: ARRAY 2 OF INTEGER; k: INTEGER;
BEGIN
  row := Relay.identity[1];
  Out.Int(row[0], 0); Out.Int(row[1], 0); Out.Char(" ");
  Out.String(mixed.name); Out.Char(" ");
  FOR k := 0 TO 4 DO Out.Int(squares[k], 0) END; Out.Ln
END Copied;

BEGIN
  Folded; Copied
END main.
