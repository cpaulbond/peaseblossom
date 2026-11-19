MODULE ConstTables;
  (* bug 31 (PLAN.md): structured constants indexed with a
     variable, which the VAX backend refused ("this designator as a
     value"): an element, an element of a two-dimensional table both ways,
     a field of an element, an element of a field, a row passed to an open
     array, an element of a CHAR table, a record element copied *)
  TYPE
    Squares* = ARRAY 6 OF INTEGER;
    Grid* = ARRAY 3, 4 OF INTEGER;
    Point* = RECORD x*, y*: LONGINT END;
    Points* = ARRAY 3 OF Point;
    Named* = RECORD count*: INTEGER; values*: ARRAY 4 OF LONGINT END;
    Digits* = ARRAY 16 OF CHAR;

  CONST
    squares* = Squares{0, 1, 4, 9, 16, 25};
    grid* = Grid{{1, 2, 3, 4}, {10, 20, 30, 40}, {-1, -2, -3, -4}};
    points* = Points{{x := 1, y := -1}, {x := 100000, y := -100000}, {x := 7, y := 8}};
    named* = Named{count := 3, values := {5, 50, 500, 5000}};
    digits* = Digits{"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"};

  PROCEDURE SumSquares*(): LONGINT;
    VAR i: INTEGER; sum: LONGINT;
  BEGIN
    sum := 0;
    FOR i := 0 TO 5 DO sum := sum + squares[i] END;
    RETURN sum
  END SumSquares;

  PROCEDURE GridAt*(i, j: INTEGER): LONGINT;
  BEGIN
    RETURN grid[i, j] * 100 + grid[i][j]
  END GridAt;

  PROCEDURE SumOpen*(row: ARRAY OF INTEGER): LONGINT;
    VAR i: LONGINT; sum: LONGINT;
  BEGIN
    sum := 0;
    FOR i := 0 TO LEN(row) - 1 DO sum := sum + row[i] END;
    RETURN sum
  END SumOpen;

  PROCEDURE RowSum*(i: INTEGER): LONGINT;
  BEGIN
    RETURN SumOpen(grid[i])
  END RowSum;

  PROCEDURE PointX*(i: INTEGER): LONGINT;
  BEGIN
    RETURN points[i].x
  END PointX;

  PROCEDURE PointAt*(i: INTEGER; VAR p: Point);
  BEGIN
    p := points[i]
  END PointAt;

  PROCEDURE NamedValue*(i: INTEGER): LONGINT;
  BEGIN
    RETURN named.values[i]
  END NamedValue;

  PROCEDURE Digit*(i: INTEGER): CHAR;
  BEGIN
    RETURN digits[i]
  END Digit;

END ConstTables.
