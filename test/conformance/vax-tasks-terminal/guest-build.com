$ ! vax-tasks-terminal (doc/developer/tasks.md, Phase 11): poc's runtime
$ ! and Coroutines' switch are assembled, and TASKTERM.COM, which poc
$ ! -build wrote, assembles TaskTerm's modules and links TASKTERM.EXE,
$ ! which terminal.exp then runs at the terminal and deletes, with every
$ ! other file made here
$ SET NOON
$ MACRO/OBJECT POCRTL.MAR
$ S = $STATUS
$ IF S THEN MACRO/OBJECT COROUTINESWITCH.MAR
$ IF S THEN S = $STATUS
$ IF S THEN @TASKTERM
$ IF S THEN S = $STATUS
$ EXIT S .OR. %X10000000
