MODULE StopVax;
  (* PLAN.md, "Ongoing library enhancements", 7: StopRequests on VAX/VMS,
     where the program runs over telnet, so Catch arms the CTRL/C AST on
     a terminal; nothing types CTRL/C, so Latest stays none, and the
     program ends normally with the AST armed, after Catch twice and a
     notifier set and taken away. *)
  IMPORT StopRequests, Out;

  PROCEDURE Notify;
  END Notify;

  PROCEDURE Report(what: ARRAY OF CHAR);
  BEGIN
    Out.String(what); Out.String(": latest "); Out.Int(StopRequests.Latest(), 0); Out.Ln
  END Report;

BEGIN
  Report("before Catch");
  StopRequests.SetNotifier(Notify);
  StopRequests.Catch;
  Report("after Catch");
  StopRequests.Catch;
  StopRequests.SetNotifier(NIL);
  Report("after Catch again");
  Out.String("done"); Out.Ln
END StopVax.
