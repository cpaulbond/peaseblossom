MODULE main;
  (* doc/developer/language-extensions.md, "Indexing a string constant":
     a string constant of m characters is a read-only ARRAY m+1 OF CHAR,
     here and imported (Words); a constant index folds to a CHAR constant
     (Folded, a CONST, a CASE label), a variable one is checked (Copied,
     and the last statement, which traps) *)
  IMPORT Out, W := Words;
  CONST
    digits = "0123456789ABCDEF";
    first = W.greeting[0]; (* "H" *)
    count = LEN(W.vowels); (* 6 *)
  VAR
    buffer: ARRAY LEN(digits) OF CHAR;
    i: INTEGER; n: LONGINT;

  PROCEDURE Folded;
  BEGIN
    Out.Char(digits[10]); Out.Char(W.greeting[4]); Out.Char(first);
    Out.Int(ORD(W.empty[0]), 2); Out.Int(ORD(W.one[1]), 2); Out.Int(ORD(digits[16]), 2);
    Out.Ln
  END Folded;

  PROCEDURE Copied(k: INTEGER);
  BEGIN
    Out.Char(digits[k]); Out.Char(W.greeting[k]); Out.Char(W.vowels[k MOD 5])
  END Copied;

  (* whether ch is a vowel, by CASE labels from the constant *)
  PROCEDURE IsVowel(ch: CHAR): BOOLEAN;
  BEGIN
    CASE ch OF
      W.vowels[0], W.vowels[1], W.vowels[2], W.vowels[3], W.vowels[4]: RETURN TRUE
    ELSE RETURN FALSE
    END
  END IsVowel;

  (* the hexadecimal digits of x, by a variable index *)
  PROCEDURE Hex(x: LONGINT);
    VAR text: ARRAY 9 OF CHAR; k: INTEGER;
  BEGIN
    text[8] := 0X;
    FOR k := 7 TO 0 BY -1 DO text[k] := digits[x MOD 16]; x := x DIV 16 END;
    Out.String(text)
  END Hex;

BEGIN
  Folded;
  FOR i := 0 TO 11 DO Copied(i) END; Out.Ln;
  Out.Int(LEN(digits), 0); Out.Char(" "); Out.Int(LEN(W.greeting, 0), 0); Out.Char(" ");
  Out.Int(LEN(W.empty), 0); Out.Char(" "); Out.Int(count, 0); Out.Char(" ");
  Out.Int(LEN(buffer), 0); Out.Ln;
  n := 0;
  FOR i := 0 TO LEN(W.greeting) - 2 DO IF IsVowel(W.greeting[i]) THEN INC(n) END END;
  Out.Int(n, 0); Out.Ln;
  FOR i := 0 TO LEN(digits) - 1 DO buffer[i] := digits[i] END;
  Out.String(buffer); Out.Ln;
  Hex(48879); Out.Ln;
  i := LEN(W.vowels);
  Out.Char(W.vowels[i]) (* past its 0X: traps, exit 2 *)
END main.
