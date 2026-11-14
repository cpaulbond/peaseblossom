$ ! vax-tasks-events: TASKEVENTS's subprocess, which writes 50 lines to
$ ! the mailbox TASKEVENTS_MBX, 50 ms apart, then END
$ OPEN/WRITE MB TASKEVENTS_MBX
$ N = 0
$LOOP:
$ N = N + 1
$ WRITE MB "line ", N
$ WAIT 00:00:00.05
$ IF N .LT. 50 THEN GOTO LOOP
$ WRITE MB "END"
$ CLOSE MB
$ EXIT 1
