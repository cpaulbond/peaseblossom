MODULE MaxMinAddress;
  IMPORT SYSTEM, Out, AddressBounds;
  VAR a, doubled: SYSTEM.ADDRESS;

  PROCEDURE Report(what: ARRAY OF CHAR; ok: BOOLEAN);
  BEGIN
    Out.String(what); IF ok THEN Out.String(": yes") ELSE Out.String(": no") END; Out.Ln
  END Report;

BEGIN
  doubled := 1;
  WHILE doubled > 0 DO doubled := doubled * 2 END; (* the last wraps *)
  Report("MIN is the top bit alone", MIN(SYSTEM.ADDRESS) = doubled);
  Report("MAX is one below it", MAX(SYSTEM.ADDRESS) = doubled - 1);
  Report("imported MIN is the same", AddressBounds.min = MIN(SYSTEM.ADDRESS));
  Report("imported MAX is the same", AddressBounds.max = MAX(SYSTEM.ADDRESS));
  a := MAX(SYSTEM.ADDRESS); INC(a);
  Report("MAX + 1 wraps to MIN", a = MIN(SYSTEM.ADDRESS))
END MaxMinAddress.
