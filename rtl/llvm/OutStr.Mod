MODULE OutStr;

  (* Out's output procedures - Char, String, Int, Hex, Card, CardHex, Ln,
     Real, LongReal -
     appending to a string instead of writing to standard output (Phase 15's
     "Ongoing library enhancements" 1). Each takes Out's parameters followed
     by s, and adds its text at s's first 0X, so a run of calls builds a
     line as a run of Out calls writes one; start with s := "".

     The text is exactly Out's: FormattedText makes it for both, and the
     field widths are padded with blanks the same way. Ln appends 0AX, the
     line feed Out.Ln writes.

     Text that does not fit is cut short, silently, and s always ends in a
     0X: a call never writes beyond s. If s has no 0X, its last character
     is replaced by one before anything is appended.

     Each has a twin, its name with At added (CharAt, StringAt, LnAt,
     IntAt, HexAt, CardAt, CardHexAt, RealAt, LongRealAt), whose last
     parameter, VAR pos, says where s's text ends, so that a run of calls
     does not search s for its end each time: start with s := "" and
     pos := 0. If s[pos] is 0X, the text goes there; if not, at the next
     0X after pos; and if pos is outside s or no 0X follows it, at s's
     first 0X, as the others put it. On return pos is where s's 0X now
     is, the text cut short or not. A 0X at pos is taken for the end
     without a look before it, so a program that shortens s itself sets
     pos too (s := ""; pos := 0).

     poc's own: voc has no OutStr, and String's read-only parameter, str-,
     takes a string constant, which voc's would not. *)

  IMPORT SYSTEM, FormattedText;

  (* Where s's text ends: its first 0X, made the last character if it has
     none *)
  PROCEDURE End(VAR s: ARRAY OF CHAR): LONGINT;
    VAR e: LONGINT;
  BEGIN
    e := 0;
    WHILE (e < LEN(s)) & (s[e] # 0X) DO INC(e) END;
    IF e = LEN(s) THEN e := LEN(s) - 1; s[e] := 0X END;
    RETURN e
  END End;

  (* count blanks at s[e], as many as fit; e moves past them *)
  PROCEDURE Blanks(count: HUGEINT; VAR s: ARRAY OF CHAR; VAR e: LONGINT);
  BEGIN
    WHILE (count > 0) & (e < LEN(s) - 1) DO s[e] := " "; INC(e); DEC(count) END;
    s[e] := 0X
  END Blanks;

  (* text's characters before its 0X at s[e], as many as fit *)
  PROCEDURE Put(VAR text: ARRAY OF CHAR; VAR s: ARRAY OF CHAR; VAR e: LONGINT);
    VAR k: LONGINT;
  BEGIN
    k := 0;
    WHILE (k < LEN(text)) & (text[k] # 0X) & (e < LEN(s) - 1) DO s[e] := text[k]; INC(e); INC(k) END;
    s[e] := 0X
  END Put;

  (* Where s's text ends, from pos: s[pos] if that is 0X, else the next 0X
     after it; End(s) if pos is outside s or no 0X follows it *)
  PROCEDURE EndFrom(VAR s: ARRAY OF CHAR; pos: LONGINT): LONGINT;
    VAR e: LONGINT;
  BEGIN
    IF (pos < 0) OR (pos >= LEN(s)) THEN
      e := End(s)
    ELSE
      e := pos;
      WHILE (e < LEN(s)) & (s[e] # 0X) DO INC(e) END;
      IF e = LEN(s) THEN e := End(s) END
    END;
    RETURN e
  END EndFrom;

  (* text, right-aligned in a field of n characters, at s[e] *)
  PROCEDURE PutField(VAR text: ARRAY OF CHAR; n: HUGEINT; VAR s: ARRAY OF CHAR; VAR e: LONGINT);
  BEGIN
    Blanks(n - FormattedText.Length(text), s, e);
    Put(text, s, e)
  END PutField;

  (* Each of the following appends at s's first 0X, and its twin with At
     at pos (above). *)

  (* ch *)
  PROCEDURE CharAt*(ch: CHAR; VAR s: ARRAY OF CHAR; VAR pos: LONGINT);
    VAR e: LONGINT;
  BEGIN
    e := EndFrom(s, pos);
    IF e < LEN(s) - 1 THEN s[e] := ch; INC(e); s[e] := 0X END;
    pos := e
  END CharAt;

  PROCEDURE Char*(ch: CHAR; VAR s: ARRAY OF CHAR);
    VAR e: LONGINT;
  BEGIN
    e := End(s); CharAt(ch, s, e)
  END Char;

  (* The characters of str up to its 0X (all of it if it has none), without
     the 0X. str may be s itself: its length is taken first. *)
  PROCEDURE StringAt*(str-: ARRAY OF CHAR; VAR s: ARRAY OF CHAR; VAR pos: LONGINT);
    VAR e, length, k: LONGINT;
  BEGIN
    length := 0;
    WHILE (length < LEN(str)) & (str[length] # 0X) DO INC(length) END;
    e := EndFrom(s, pos);
    k := 0;
    WHILE (k < length) & (e < LEN(s) - 1) DO s[e] := str[k]; INC(e); INC(k) END;
    s[e] := 0X;
    pos := e
  END StringAt;

  PROCEDURE String*(str-: ARRAY OF CHAR; VAR s: ARRAY OF CHAR);
    VAR e: LONGINT;
  BEGIN
    e := End(s); StringAt(str, s, e)
  END String;

  (* A line feed, 0AX *)
  PROCEDURE LnAt*(VAR s: ARRAY OF CHAR; VAR pos: LONGINT);
  BEGIN
    CharAt(0AX, s, pos)
  END LnAt;

  PROCEDURE Ln*(VAR s: ARRAY OF CHAR);
  BEGIN
    Char(0AX, s)
  END Ln;

  (* x in decimal, right-aligned in a field n characters wide: padded with
     blanks on the left if it takes fewer, whole if it takes more. No plus
     sign. *)
  PROCEDURE IntAt*(x, n: HUGEINT; VAR s: ARRAY OF CHAR; VAR pos: LONGINT);
    VAR text: ARRAY FormattedText.maxText OF CHAR; e: LONGINT;
  BEGIN
    FormattedText.Int(x, text);
    e := EndFrom(s, pos); PutField(text, n, s, e); pos := e
  END IntAt;

  PROCEDURE Int*(x, n: HUGEINT; VAR s: ARRAY OF CHAR);
    VAR e: LONGINT;
  BEGIN
    e := End(s); IntAt(x, n, s, e)
  END Int;

  (* x as hexadecimal digits, upper case, at least n of them (n is taken to
     be within 1..16): as many as x needs if that is more - but a negative
     x gets exactly n, the low ones of its two's complement, as in voc. *)
  PROCEDURE HexAt*(x, n: HUGEINT; VAR s: ARRAY OF CHAR; VAR pos: LONGINT);
    VAR text: ARRAY FormattedText.maxText OF CHAR; e: LONGINT;
  BEGIN
    FormattedText.Hex(x, n, text);
    e := EndFrom(s, pos); Put(text, s, e); pos := e
  END HexAt;

  PROCEDURE Hex*(x, n: HUGEINT; VAR s: ARRAY OF CHAR);
    VAR e: LONGINT;
  BEGIN
    e := End(s); HexAt(x, n, s, e)
  END Hex;

  (* x, of any CARD type, in decimal, right-aligned in a field n characters
     wide, as Int (AGENTS.md, "Unsigned integer types") *)
  PROCEDURE CardAt*(x: SYSTEM.CARD64; n: HUGEINT; VAR s: ARRAY OF CHAR; VAR pos: LONGINT);
    VAR text: ARRAY FormattedText.maxText OF CHAR; e: LONGINT;
  BEGIN
    FormattedText.Card(SYSTEM.VAL(HUGEINT, x), text);
    e := EndFrom(s, pos); PutField(text, n, s, e); pos := e
  END CardAt;

  PROCEDURE Card*(x: SYSTEM.CARD64; n: HUGEINT; VAR s: ARRAY OF CHAR);
    VAR e: LONGINT;
  BEGIN
    e := End(s); CardAt(x, n, s, e)
  END Card;

  (* x, of any CARD type, as hexadecimal digits, upper case, at least n of
     them (n is taken to be within 1..16), and as many as x needs if that
     is more *)
  PROCEDURE CardHexAt*(x: SYSTEM.CARD64; n: HUGEINT; VAR s: ARRAY OF CHAR; VAR pos: LONGINT);
    VAR text: ARRAY FormattedText.maxText OF CHAR; e: LONGINT;
  BEGIN
    FormattedText.CardHex(SYSTEM.VAL(HUGEINT, x), n, text);
    e := EndFrom(s, pos); Put(text, s, e); pos := e
  END CardHexAt;

  PROCEDURE CardHex*(x: SYSTEM.CARD64; n: HUGEINT; VAR s: ARRAY OF CHAR);
    VAR e: LONGINT;
  BEGIN
    e := End(s); CardHexAt(x, n, s, e)
  END CardHex;

  (* x in exponential form (d.dddE+dd), right-aligned in a field of n
     characters: as many digits as fit, from 2 to 9, at least 6 generated
     to drop trailing zeros from. A plus sign of the mantissa is not
     written. *)
  PROCEDURE RealAt*(x: REAL; n: INTEGER; VAR s: ARRAY OF CHAR; VAR pos: LONGINT);
    VAR text: ARRAY FormattedText.maxText OF CHAR; e: LONGINT;
  BEGIN
    FormattedText.Real(x, n, text);
    e := EndFrom(s, pos); PutField(text, n, s, e); pos := e
  END RealAt;

  PROCEDURE Real*(x: REAL; n: INTEGER; VAR s: ARRAY OF CHAR);
    VAR e: LONGINT;
  BEGIN
    e := End(s); RealAt(x, n, s, e)
  END Real;

  (* The same for a LONGREAL, with D and a three-digit exponent, and up to
     17 digits. *)
  PROCEDURE LongRealAt*(x: LONGREAL; n: INTEGER; VAR s: ARRAY OF CHAR; VAR pos: LONGINT);
    VAR text: ARRAY FormattedText.maxText OF CHAR; e: LONGINT;
  BEGIN
    FormattedText.LongReal(x, n, text);
    e := EndFrom(s, pos); PutField(text, n, s, e); pos := e
  END LongRealAt;

  PROCEDURE LongReal*(x: LONGREAL; n: INTEGER; VAR s: ARRAY OF CHAR);
    VAR e: LONGINT;
  BEGIN
    e := End(s); LongRealAt(x, n, s, e)
  END LongReal;

END OutStr.
