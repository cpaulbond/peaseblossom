MODULE peek;
  (* PLAN.md "Ongoing library enhancements", item 8: In.Peek gives the next
     character without consuming it, so the next Peek, Char or Line starts
     with it; Done is TRUE for a 0X byte read and FALSE only at the end. *)
  IMPORT In, Out;
  VAR ch: CHAR; line: ARRAY 32 OF CHAR; n: INTEGER;

  PROCEDURE ShowDone;
  BEGIN
    IF In.Done THEN Out.String(" done") ELSE Out.String(" not done") END;
    Out.Ln
  END ShowDone;

  PROCEDURE Show(what: ARRAY OF CHAR; ch: CHAR);
  BEGIN
    Out.String(what); Out.Char(" "); Out.Int(ORD(ch), 0); ShowDone
  END Show;

  PROCEDURE ShowLine(line: ARRAY OF CHAR);
  BEGIN
    Out.String("Line ["); Out.String(line); Out.Char("]"); ShowDone
  END ShowLine;

BEGIN
  In.Open;
  In.Peek(ch); Show("Peek", ch);
  In.Peek(ch); Show("Peek again", ch);
  In.Char(ch); Show("Char", ch);
  In.Peek(ch); Show("Peek", ch);
  In.Char(ch); Show("Char", ch);
  In.Peek(ch); Show("Peek at the line end", ch);
  In.Char(ch); Show("Char", ch);
  In.Peek(ch); Show("Peek before Line", ch);
  In.Line(line); ShowLine(line);
  In.Peek(ch); Show("Peek", ch);
  In.Char(ch); Show("Char", ch);
  In.Peek(ch); Show("Peek", ch);
  In.Line(line); ShowLine(line);
  In.Peek(ch); Show("Peek before Int", ch);
  In.Int(n); Out.String("Int "); Out.Int(n, 0); ShowDone;
  In.Line(line); ShowLine(line);
  In.Line(line); ShowLine(line);
  In.Peek(ch); Show("Peek at the end", ch);
  In.Peek(ch); Show("Peek again", ch);
  In.Char(ch); Show("Char", ch)
END peek.
