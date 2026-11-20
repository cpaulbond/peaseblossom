MODULE Directories;

  (* PLAN.md Phase 16 step 4: voc's version of rtl/llvm/Directories.Mod,
     with the same interface, over voc's Platform module, which has no such
     procedures. Stage 0 (tools/bootstrap/stage0) compiles it with poc's own
     source, as it does FileDescriptorOutput. IsDirectory changes to the
     directory and back, and MakeDirectory runs mkdir -p, as poc's source
     did before it had this module. *)

  IMPORT Platform;

  CONST
    (* what separates the directories of a list of them *)
    pathSeparator* = ":";

  TYPE
    (* a search for the files a pattern names (StartSearch, NextFile) *)
    Search* = RECORD
      context: INTEGER
    END;

  (* The file name in the directory dir in path, cut short if path is too
     small: dir and name with "/" between them, unless dir is "" or
     already ends in "/". *)
  PROCEDURE MakePath*(dir, name: ARRAY OF CHAR; VAR path: ARRAY OF CHAR);
    VAR i, j: LONGINT;
  BEGIN
    i := 0;
    WHILE (i < LEN(dir)) & (dir[i] # 0X) & (i < LEN(path) - 1) DO path[i] := dir[i]; INC(i) END;
    IF (i > 0) & (path[i - 1] # "/") & (i < LEN(path) - 1) THEN path[i] := "/"; INC(i) END;
    j := 0;
    WHILE (j < LEN(name)) & (name[j] # 0X) & (i < LEN(path) - 1) DO path[i] := name[j]; INC(i); INC(j) END;
    IF LEN(path) > 0 THEN path[i] := 0X END
  END MakePath;

  (* The subdirectory name of the directory dir in path, cut short if path
     is too small: on Unix, as MakePath joins them. *)
  PROCEDURE MakeSubdirectory*(dir, name: ARRAY OF CHAR; VAR path: ARRAY OF CHAR);
  BEGIN
    MakePath(dir, name, path)
  END MakeSubdirectory;

  (* Where the file's own name starts in path: after its last "/", or 0. *)
  PROCEDURE NameStart*(path: ARRAY OF CHAR): INTEGER;
    VAR i, start: INTEGER;
  BEGIN
    i := 0; start := 0;
    WHILE (i < LEN(path)) & (path[i] # 0X) DO
      IF path[i] = "/" THEN start := i + 1 END;
      INC(i)
    END;
    RETURN start
  END NameStart;

  (* A search for the files a pattern names, through NextFile *)
  PROCEDURE StartSearch*(VAR search: Search);
  BEGIN
    search.context := 0
  END StartSearch;

  (* The next file the pattern names, in name: FALSE, the search ended,
     when there is no other. On Unix, where the shell expands a pattern,
     the pattern itself, once. *)
  PROCEDURE NextFile*(VAR search: Search; pattern: ARRAY OF CHAR; VAR name: ARRAY OF CHAR): BOOLEAN;
  BEGIN
    IF search.context # 0 THEN search.context := 0; RETURN FALSE END;
    COPY(pattern, name); search.context := 1;
    RETURN TRUE
  END NextFile;

  (* Whether dir names a directory that exists: whether the process can
     change to it, which it then changes back from. *)
  PROCEDURE IsDirectory*(dir: ARRAY OF CHAR): BOOLEAN;
    VAR saved: ARRAY 256 OF CHAR; ok: BOOLEAN; e: Platform.ErrorCode;
  BEGIN
    COPY(Platform.CWD, saved);
    ok := Platform.Chdir(dir) = 0;
    IF ok THEN e := Platform.Chdir(saved) END;
    RETURN ok
  END IsDirectory;

  (* Makes the directory dir and those it is in that are missing, by mkdir
     -p, given dir in single quotes; whether dir is a directory
     afterwards. mkdir's own message is discarded: the caller words its
     own, as each system words mkdir's differently. *)
  PROCEDURE MakeDirectory*(dir: ARRAY OF CHAR): BOOLEAN;
    VAR command: ARRAY 1100 OF CHAR; suffix: ARRAY 14 OF CHAR; i, k: LONGINT; status: INTEGER;
  BEGIN
    command := "mkdir -p '"; k := 10; i := 0;
    WHILE (i < LEN(dir)) & (dir[i] # 0X) & (k < LEN(command) - 18) DO
      IF dir[i] = "'" THEN (* ' ends the quotes, \' is one, ' starts them again *)
        command[k] := "'"; command[k + 1] := "\"; command[k + 2] := "'"; command[k + 3] := "'"; INC(k, 4)
      ELSE command[k] := dir[i]; INC(k)
      END;
      INC(i)
    END;
    suffix := "' 2>/dev/null"; i := 0;
    WHILE suffix[i] # 0X DO command[k] := suffix[i]; INC(k); INC(i) END;
    command[k] := 0X;
    status := Platform.System(command);
    RETURN IsDirectory(dir)
  END MakeDirectory;

  (* text[from..to - 1] onto command at k, in single quotes, as
     MakeDirectory quotes dir; FALSE when command is too small *)
  PROCEDURE AppendQuoted(VAR command: ARRAY OF CHAR; VAR k: LONGINT; text: ARRAY OF CHAR; from, to: LONGINT): BOOLEAN;
  BEGIN
    IF k >= LEN(command) - 2 THEN RETURN FALSE END;
    command[k] := "'"; INC(k);
    WHILE (from < to) & (k < LEN(command) - 6) DO
      IF text[from] = "'" THEN
        command[k] := "'"; command[k + 1] := "\"; command[k + 2] := "'"; command[k + 3] := "'"; INC(k, 4)
      ELSE command[k] := text[from]; INC(k)
      END;
      INC(from)
    END;
    command[k] := "'"; INC(k); command[k] := 0X;
    RETURN from = to
  END AppendQuoted;

  (* Whether the directory of the file path names lists it spelled exactly
     as in path, as rtl/llvm's: by ls -a in that directory, and grep -F -x
     for the name. *)
  PROCEDURE SpelledAsGiven*(path: ARRAY OF CHAR): BOOLEAN;
    VAR command: ARRAY 2300 OF CHAR; middle: ARRAY 48 OF CHAR; i, k, slash, length: LONGINT;
  BEGIN
    length := 0; slash := -1;
    WHILE (length < LEN(path)) & (path[length] # 0X) DO
      IF path[length] = "/" THEN slash := length END;
      INC(length)
    END;
    command := "cd "; k := 3;
    IF slash < 0 THEN command[k] := "."; INC(k)
    ELSIF slash = 0 THEN command[k] := "/"; INC(k)
    ELSIF ~AppendQuoted(command, k, path, 0, slash) THEN RETURN FALSE
    END;
    middle := " 2>/dev/null && ls -a | grep -F -x -q -- "; i := 0;
    WHILE middle[i] # 0X DO command[k] := middle[i]; INC(k); INC(i) END;
    RETURN AppendQuoted(command, k, path, slash + 1, length) & (Platform.System(command) = 0)
  END SpelledAsGiven;

END Directories.
