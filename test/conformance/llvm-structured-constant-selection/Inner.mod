MODULE Inner;
(* PLAN.md, "Ongoing bug fixing", 32: exported structured constants for
   main.mod to select from, directly and through Relay *)
TYPE
  Point* = RECORD x*, y*: INTEGER END;
  Matrix* = ARRAY 2, 2 OF INTEGER;
CONST
  origin* = Point{x := -1, y := -2};
  identity* = Matrix{{1, 0}, {0, 1}};
END Inner.
