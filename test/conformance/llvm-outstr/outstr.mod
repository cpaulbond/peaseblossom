MODULE outstr;
  (* OutStr (Phase 15's "Ongoing library enhancements" 1): each case is
     written by Out, then by OutStr into a string that Out writes; the two
     lines must be the same (test.sh checks). Then appending to a string
     that holds text, and truncation at every length of a short one. Last,
     the twins with At: each kind of text appended at pos, as the others
     append it, and pos where it starts and after. *)
  IMPORT SYSTEM, Out, OutStr;
  VAR
    s: ARRAY 128 OF CHAR;
    bits32: SYSTEM.INT32; bits64: HUGEINT; r: REAL; x: LONGREAL;
    s1: ARRAY 1 OF CHAR; s2: ARRAY 2 OF CHAR; s3: ARRAY 3 OF CHAR; s4: ARRAY 4 OF CHAR;
    s5: ARRAY 5 OF CHAR; s6: ARRAY 6 OF CHAR; s7: ARRAY 7 OF CHAR; s8: ARRAY 8 OF CHAR;
    full: ARRAY 4 OF CHAR;
    t, u: ARRAY 64 OF CHAR; pos: LONGINT;

  (* t's text, then pos and whether it is where t's first 0X is *)
  PROCEDURE ShowPos(VAR t: ARRAY OF CHAR; pos: LONGINT);
    VAR k: LONGINT;
  BEGIN
    k := 0; WHILE (k < LEN(t)) & (t[k] # 0X) DO INC(k) END;
    Out.String("["); Out.String(t); Out.String("] pos"); Out.Int(pos, 3);
    IF pos # k THEN Out.String(", but the 0X is at"); Out.Int(k, 3) END;
    Out.Ln
  END ShowPos;

  PROCEDURE Show; BEGIN Out.Char("|"); Out.Ln; Out.String(s); Out.Char("|"); Out.Ln; s := "" END Show;

  PROCEDURE Int(x, n: HUGEINT); BEGIN Out.Int(x, n); OutStr.Int(x, n, s); Show END Int;
  PROCEDURE Hex(x, n: HUGEINT); BEGIN Out.Hex(x, n); OutStr.Hex(x, n, s); Show END Hex;
  PROCEDURE Real(x: REAL; n: INTEGER); BEGIN Out.Real(x, n); OutStr.Real(x, n, s); Show END Real;
  PROCEDURE LongReal(x: LONGREAL; n: INTEGER); BEGIN Out.LongReal(x, n); OutStr.LongReal(x, n, s); Show END LongReal;

  (* -12345 appended to "ab" in t, its text then shown with its length *)
  PROCEDURE Cut(VAR t: ARRAY OF CHAR);
    VAR k: LONGINT;
  BEGIN
    COPY("ab", t); OutStr.Int(-12345, 0, t);
    k := 0; WHILE t[k] # 0X DO INC(k) END;
    Out.Int(LEN(t), 0); Out.String(": "); Out.String(t); Out.Int(k, 2); Out.Ln
  END Cut;

BEGIN
  s := "";
  Out.Char("a"); OutStr.Char("a", s); Show;
  Out.String("a string"); OutStr.String("a string", s); Show;
  Out.String(""); OutStr.String("", s); Show;
  Int(0, 0); Int(7, 1); Int(-7, 2); Int(123, 2); Int(123, 3); Int(123, 6); Int(-5, -3);
  Int(MAX(HUGEINT), 0); Int(MIN(HUGEINT), 0); Int(MIN(HUGEINT), 25); Int(2147483647, 12);
  Hex(0, 1); Hex(255, 0); Hex(255, 4); Hex(-1, 4); Hex(-1, 16); Hex(-1, 20); Hex(MIN(HUGEINT), 16); Hex(4096, 2);
  Real(0.0, 0); Real(1.0, 0); Real(3.14159, 12); Real(-3.14159, 12); Real(1.0E30, 15); Real(-2.5E-10, 3);
  Real(123456789.0, 20);
  bits32 := 1; r := SYSTEM.VAL(REAL, bits32); Real(r, 14); (* the smallest subnormal *)
  bits32 := 7F800000H; r := SYSTEM.VAL(REAL, bits32); Real(r, 10); Real(-r, 10); (* infinities *)
  bits32 := 7FC00000H; r := SYSTEM.VAL(REAL, bits32); Real(r, 6); (* NaN *)
  LongReal(0.0D0, 0); LongReal(1.0D0, 0); LongReal(-2.5D-300, 0); LongReal(1.0D0 / 3.0D0, 25);
  LongReal(6.02214076D23, 30);
  bits64 := 1; x := SYSTEM.VAL(LONGREAL, bits64); LongReal(x, 24);
  bits64 := 7FF0000000000000H; x := SYSTEM.VAL(LONGREAL, bits64); LongReal(x, 10); LongReal(-x, 10);
  bits64 := 7FF8000000000000H; x := SYSTEM.VAL(LONGREAL, bits64); LongReal(x, 6);
  Out.String("x="); Out.Int(42, 5); Out.Hex(42, 2);
  OutStr.String("x=", s); OutStr.Int(42, 5, s); OutStr.Hex(42, 2, s); Show;
  (* Ln appends a line feed, as Out.Ln writes one *)
  s := "line"; OutStr.Ln(s); Out.Int(ORD(s[4]), 0); Out.Int(ORD(s[5]), 3); Out.Ln;

  (* appending to a string that already holds text *)
  s := "count: "; OutStr.Int(3, 0, s); OutStr.Char(";", s); OutStr.Real(0.5, 10, s);
  Out.String(s); Out.Ln;
  (* a string onto itself *)
  s := "echo "; OutStr.String(s, s); Out.String(s); Out.Ln;
  (* cut short at every length *)
  Cut(s1); Cut(s2); Cut(s3); Cut(s4); Cut(s5); Cut(s6); Cut(s7); Cut(s8);
  (* a string with no 0X: its last character gives way to one *)
  full[0] := "w"; full[1] := "x"; full[2] := "y"; full[3] := "z";
  OutStr.Char("!", full); Out.String(full); Out.Ln;
  s := "pad"; OutStr.Int(1, 200, s); s[20] := 0X; Out.String(s); Out.Char("|"); Out.Ln;

  (* every At twin, from pos 0, against the others *)
  t := ""; OutStr.String("x=", t); OutStr.Int(-42, 5, t); OutStr.Hex(42, 4, t);
  OutStr.Card(7, 3, t); OutStr.CardHex(255, 4, t); OutStr.Char(";", t);
  OutStr.Real(0.5, 10, t); OutStr.LongReal(0.25D0, 12, t); OutStr.Ln(t);
  u := ""; pos := 0; OutStr.StringAt("x=", u, pos); OutStr.IntAt(-42, 5, u, pos);
  OutStr.HexAt(42, 4, u, pos); OutStr.CardAt(7, 3, u, pos); OutStr.CardHexAt(255, 4, u, pos);
  OutStr.CharAt(";", u, pos); OutStr.RealAt(0.5, 10, u, pos); OutStr.LongRealAt(0.25D0, 12, u, pos);
  OutStr.LnAt(u, pos);
  IF u = t THEN Out.String("At the same") ELSE Out.String("At differs") END; Out.Ln;
  u[pos - 1] := 0X; DEC(pos); ShowPos(u, pos);
  (* pos before the 0X: the next 0X after it *)
  u := "abc"; pos := 1; OutStr.CharAt("d", u, pos); ShowPos(u, pos);
  (* pos outside u: from u's start *)
  u := "abc"; pos := -5; OutStr.StringAt("de", u, pos); ShowPos(u, pos);
  u := "abc"; pos := LEN(u); OutStr.IntAt(12, 0, u, pos); ShowPos(u, pos);
  (* no 0X after pos: from u's start *)
  COPY("abc", s4); pos := 3; s4[3] := "z"; OutStr.CharAt("!", s4, pos); ShowPos(s4, pos);
  COPY("a", s4); s4[2] := "q"; s4[3] := "q"; pos := 2; OutStr.CharAt("b", s4, pos); ShowPos(s4, pos);
  (* a 0X at pos is the end, without a look before it *)
  u := "abcdef"; u[2] := 0X; pos := 6; OutStr.CharAt("!", u, pos);
  Out.String("trusted:"); Out.Int(pos, 2); Out.Char(" "); Out.Char(u[6]); Out.Ln;
  (* cut short: pos stays at the last character *)
  pos := 0; s6 := ""; OutStr.StringAt("abcdefgh", s6, pos); ShowPos(s6, pos);
  OutStr.IntAt(1, 0, s6, pos); OutStr.LnAt(s6, pos); ShowPos(s6, pos);
  (* a string onto itself *)
  u := "echo "; pos := 5; OutStr.StringAt(u, u, pos); ShowPos(u, pos)
END outstr.
