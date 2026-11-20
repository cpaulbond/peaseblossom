$ ! PLAN.md "Ongoing library enhancements", item 8: PEEK.COM (llvm-in-peek's
$ ! peek.mod), which poc -build wrote, run after poc's runtime is
$ ! assembled; then the image, with SYS$INPUT its input file. Everything
$ ! made is deleted
$ SET NOON
$ MACRO/OBJECT POCRTL.MAR
$ S = $STATUS
$ IF S THEN @PEEK
$ IF S THEN S = $STATUS
$ WRITE SYS$OUTPUT "build status: ", S
$ IF .NOT. S THEN GOTO CLEAN
$ DEFINE/USER SYS$INPUT INPUT.TXT
$ RUN PEEK.EXE
$ WRITE SYS$OUTPUT "run status: ", $STATUS
$ CLEAN:
$ DELETE/NOLOG POCRTL.OBJ;*,LINEOUTPUT.OBJ;*,FORMATTEDOUTPUT.OBJ;*,FORMATTEDTEXT.OBJ;*,REALDIGITS.OBJ;*,OUT.OBJ;*
$ DELETE/NOLOG IN.OBJ;*,FORMATTEDINPUT.OBJ;*,DECIMALTOREAL.OBJ;*,PLATFORM.OBJ;*
$ DELETE/NOLOG PEEK.OBJ;*,PEEK.OPT;*,PEEK.EXE;*,INPUT.TXT;*
$ EXIT 1
