MODULE TableOut;
  (* prints what ConstTables' procedures give, on both backends, and
     indexes its constants from here, another module, with a variable *)
  IMPORT Out, C := ConstTables;
  VAR i, j: INTEGER; p: C.Point; n: LONGINT;

  PROCEDURE Show(x: LONGINT);
  BEGIN Out.Int(x, 0); Out.Char(" ")
  END Show;

BEGIN
  Show(C.SumSquares()); Out.Ln;
  FOR i := 0 TO 2 DO
    FOR j := 0 TO 3 DO Show(C.GridAt(i, j)) END;
    Show(C.RowSum(i)); Out.Ln
  END;
  FOR i := 0 TO 2 DO
    C.PointAt(i, p); Show(C.PointX(i)); Show(p.x); Show(p.y); Show(C.points[i].y)
  END;
  Out.Ln;
  FOR i := 0 TO 3 DO Show(C.NamedValue(i)); Show(C.named.values[3 - i]) END;
  Out.Ln;
  n := 0;
  FOR i := 0 TO 5 DO n := n + C.squares[i] END;
  Show(n); Show(C.SumOpen(C.grid[2])); Out.Ln;
  FOR i := 15 TO 0 BY -1 DO Out.Char(C.Digit(i)); Out.Char(C.digits[i]) END;
  Out.Ln
END TableOut.
