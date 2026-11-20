MODULE StringOut;
  (* prints what StringTables' procedures give, on both backends, and
     indexes its constants from here, another module, with a variable *)
  IMPORT Out, S := StringTables;
  VAR i: INTEGER;
BEGIN
  FOR i := 15 TO 0 BY -1 DO Out.Char(S.Digit(i)); Out.Char(S.digits[i]) END; Out.Ln;
  Out.Int(S.Vowels("Peaseblossom"), 0); Out.Char(" "); Out.Int(S.Folded(), 0); Out.Char(" ");
  FOR i := 0 TO SHORT(LEN(S.vowels)) - 2 DO Out.Char(S.vowels[i]) END;
  Out.Int(ORD(S.vowels[LEN(S.vowels) - 1]), 2); Out.Ln
END StringOut.
