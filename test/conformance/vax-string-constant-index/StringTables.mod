MODULE StringTables;
  (* doc/developer/language-extensions.md, "Indexing a string constant",
     on the VAX: a string constant indexed with a constant, folded, and
     with a variable, from the constant's storage in POC_CONST *)
  CONST
    digits* = "0123456789ABCDEF";
    vowels* = "aeiou";
    empty* = "";

  (* the digit of value x, a variable index *)
  PROCEDURE Digit*(x: INTEGER): CHAR;
  BEGIN
    RETURN digits[x]
  END Digit;

  (* how many of text's characters are vowels, a variable index into a
     second constant *)
  PROCEDURE Vowels*(text: ARRAY OF CHAR): INTEGER;
    VAR i, k, n: INTEGER;
  BEGIN
    n := 0; i := 0;
    WHILE text[i] # 0X DO
      k := 0;
      WHILE (k < LEN(vowels) - 1) & (vowels[k] # text[i]) DO INC(k) END;
      IF k < LEN(vowels) - 1 THEN INC(n) END;
      INC(i)
    END;
    RETURN n
  END Vowels;

  (* constant indexes and LEN, folded *)
  PROCEDURE Folded*(): LONGINT;
  BEGIN
    RETURN ORD(digits[15]) + ORD(vowels[5]) + ORD(empty[0]) + LEN(digits) + LEN(empty)
  END Folded;
END StringTables.
