MODULE Tasks;
  (* Cooperative tasks, conditions, mutexes and channels over Coroutines
     (doc/developer/tasks.md; AGENTS.md, "Tasks"). The same source on both
     back ends; what differs is in TaskWaiting.

     A task is an extension of TaskDesc whose Run is its body. Start gives
     it a stack of its own and puts it at the end of the run queue; it runs
     when the running task blocks. Returning from Run ends the task, and its
     stack is given back. The main program is a task too.

         TYPE
           Worker = POINTER TO RECORD (Tasks.TaskDesc) n: LONGINT; out: Tasks.Channel END;
           Result = POINTER TO RECORD (Tasks.MessageDesc) value: LONGINT END;

         PROCEDURE (w: Worker) Run*;
           VAR r: Result;
         BEGIN
           NEW(r); r.value := w.n * w.n; Tasks.Send(w.out, r)
         END Run;

     An override of Run must be exported, as the base procedure is.

     SCHEDULING. Nothing preempts: a task runs until it makes a call that
     can block (Yield, Join, Wait, Lock, Send, Receive, Select, Sleep,
     Await, AwaitReadable, AwaitWritable, AwaitReadableFor,
     AwaitWritableFor), and only then may another run, so code between
     two such calls is atomic. A task that blocks switches straight to
     the first ready task, in the order they became ready; Yield puts the
     running task at the end. A blocking call, I/O included, of any other
     module stops every task.
     The program ends when the main module's body ends: tasks still
     running are abandoned (their Runs do not finish), so Join is how to
     wait for one.

     CONDITIONS AND MUTEXES. A zeroed Condition or Mutex is ready to use;
     pass them by VAR, never copy them. A condition is Mesa's: a woken task
     tests again, WHILE ~ok DO Tasks.Wait(c) END. Signal wakes the task
     that has waited longest. Code between switches is atomic already, so
     a Mutex is needed only around a region that blocks.

     CHANNELS. A message is an extension of MessageDesc, unpacked by a type
     guard, and NIL is a message too. A channel of capacity 0 hands each
     message from a sender to a receiver; one of capacity n holds up to n.
     After Close, Receive takes the messages still held, then returns
     FALSE.

     TIME. Sleep and After wait at least their time, and longer when the
     clock ticks coarsely (10 ms on OpenBSD, NetBSD and VAX/VMS) or other
     tasks keep running: while tasks are ready the clock is read only
     every 256 picks of a task to run. AwaitReadableFor and
     AwaitWritableFor wait until a descriptor is ready or their time has
     passed, and say which: a deadline on a socket's read or write.

     EVENTS. An Event is how a signal handler, an AST, or a replaced idle
     step's callback wakes a task: Post sets a flag, which the scheduler
     sees at its next pick, and wakes the idle wait. Make the Event a
     global variable or part of a heap record, so that it outlives the
     Await. Platform.SetInterruptHandler's handler or a $QIO's AST may
     Post; neither may call anything else of Tasks.

     WAITING. When no task is ready, Tasks waits: on POSIX in poll, for
     the descriptors tasks await and a pipe that Post writes to; on
     VAX/VMS in $HIBER, which Post's $WAKE ends. SetIdleStep replaces
     that wait, for a toolkit's event loop (doc/developer/tasks.md,
     decision 10). On POSIX, while tasks are ready and some task awaits
     a descriptor, descriptors are polled about every millisecond.

     TRAPS. When no task is ready and nothing can make one ready, the
     program traps (19), "all tasks are blocked": none is ready, sleeping,
     in Await, or awaiting a descriptor. Misuse traps (20): an Unlock of
     a mutex the running task does not hold, a Join of the running task,
     a Send on a closed channel (also one waiting when the channel is
     closed), a Close of a channel already closed, a Start of a task
     already started, NewChannel with a negative capacity, AwaitReadable,
     AwaitWritable or their For forms of a negative descriptor, or on
     VAX/VMS at all. A call that blocks traps (17) in a finalizer, as
     Transfer does there; on LLVM in a signal handler too. On VAX/VMS a call that blocks at AST
     level is undefined.

     RULES the program keeps, which nothing checks:
     - A program that imports Tasks may use Coroutines only inside one
       task, between coroutines Tasks does not own, and must be back on
       that task's own coroutine before it calls Tasks again.
     - A task blocked for good keeps its stack until the program ends: one
       waiting on a channel nothing else can reach is a leak. *)

  IMPORT SYSTEM, Coroutines, TaskWaiting;

  CONST
    DefaultStackSize* = Coroutines.DefaultStackSize;
    (* a task's states *)
    notStarted = 0; ready = 1; running = 2; blocked = 3; finished = 4;
    (* while tasks are ready and a timer is pending or a task waits for a
       descriptor, every pollEvery picks the clock is read: due timers
       expire, and when pollInterval microseconds have passed since the
       last poll, descriptors are polled without waiting (decision 9) *)
    pollEvery = 256; pollInterval = 1000;
    (* the longest timeout passed to the idle step, in ms *)
    longestTimeout = 7FFFFFFFH;

  TYPE
    Task* = POINTER TO TaskDesc;
    Message* = POINTER TO MessageDesc;
    MessageDesc* = RECORD END;
    Channel* = POINTER TO ChannelDesc;

    (* tasks in the order they joined, linked through next *)
    TaskQueue = RECORD first, last: Task END;

    (* a task waiting in a channel's queue: one for each channel of a
       Select, the task's own for a Send or Receive *)
    Waiter = POINTER TO WaiterDesc;
    WaiterDesc = RECORD
      task: Task;
      channel: Channel;
      message: Message;
      index: LONGINT;      (* in Select's array *)
      delivered: BOOLEAN;  (* FALSE: woken by Close *)
      queued: BOOLEAN;
      next, previous: Waiter;  (* in the channel's queue *)
      sibling: Waiter      (* the same Select's others, or the task's spares *)
    END;
    WaiterQueue = RECORD first, last: Waiter END;

    (* a Sleep's or a timed descriptor wait's (task) or an After's
       (channel), in the list of timers *)
    Timer = POINTER TO TimerDesc;
    TimerDesc = RECORD
      deadline: HUGEINT;   (* TaskWaiting.Now's microseconds *)
      task: Task;
      channel: Channel;
      next: Timer
    END;

    TaskDesc* = RECORD
      coroutine: Coroutines.Coroutine;
      state: INTEGER;
      next: Task;          (* in the run queue or a queue of waiting tasks *)
      joiners: TaskQueue;
      waiter: Waiter;      (* its own, for a Send or a Receive *)
      spares: Waiter;      (* for Select *)
      fired: Waiter;       (* the waiter that woke it; NIL while it waits *)
      timer: Timer;        (* its own, for Sleep and a timed descriptor wait *)
      event: SYSTEM.ADDRESS;  (* the flag of the Event it awaits *)
      descriptor: LONGINT; (* the one it awaits *)
      forWriting: BOOLEAN;
      (* in watching with its timer pending, in AwaitReadableFor or
         AwaitWritableFor; whether that wait's timer ended it *)
      timed, timedOut: BOOLEAN
    END;

    Condition* = RECORD waiting: TaskQueue END;
    Mutex* = RECORD holder: Task; waiting: TaskQueue END;

    (* set by Post, which a signal handler or an AST may call *)
    Event* = RECORD posted: BOOLEAN END;

    (* called instead of the idle wait (decision 10) with the longest time
       to wait in ms, -1 for no limit *)
    IdleStep* = PROCEDURE (timeout: LONGINT);

    Messages = POINTER TO ARRAY OF Message;
    ChannelDesc* = RECORD
      buffer: Messages;
      capacity, head, count: LONGINT;
      closed: BOOLEAN;
      receivers, senders: WaiterQueue
    END;

  VAR
    mainTask, current: Task;
    runQueue: TaskQueue;
    (* a task that has ended, whose stack the next task to run gives back:
       Coroutines.Free of the running coroutine traps *)
    endedTask: Task;
    timers: Timer;          (* the nearest deadline first *)
    awaiting: TaskQueue;    (* tasks in Await *)
    watching: TaskQueue;    (* tasks awaiting a descriptor, timed or not *)
    watchCount: LONGINT;
    picks: LONGINT;         (* since the clock was last read *)
    lastPoll: HUGEINT;
    idleStep: IdleStep;
    (* written by Post in a signal handler or an AST, so read and written
       only by SYSTEM.GET and SYSTEM.PUT, which the compiler does not keep
       in registers: whether an event was posted since the last harvest,
       and whether the idle wait is about to start or going on *)
    anyPosted, idle: BOOLEAN;

  (* The body: what the task does. Returning ends the task. *)
  PROCEDURE (t: Task) Run*;
  END Run;

  PROCEDURE Append(VAR q: TaskQueue; t: Task);
  BEGIN
    t.next := NIL;
    IF q.first = NIL THEN q.first := t ELSE q.last.next := t END;
    q.last := t
  END Append;

  PROCEDURE Remove(VAR q: TaskQueue): Task;
    VAR t: Task;
  BEGIN
    t := q.first;
    IF t # NIL THEN
      q.first := t.next;
      IF q.first = NIL THEN q.last := NIL END;
      t.next := NIL
    END;
    RETURN t
  END Remove;

  PROCEDURE MakeReady(t: Task);
  BEGIN
    t.state := ready;
    Append(runQueue, t)
  END MakeReady;

  (* The running task waits in a queue of its own *)
  PROCEDURE WaitIn(VAR q: TaskQueue);
  BEGIN
    current.state := blocked;
    Append(q, current)
  END WaitIn;

  (* Makes ready the tasks whose events were posted, in the order they
     began to await *)
  PROCEDURE Harvest;
    VAR t, previous, next: Task; posted: BOOLEAN;
  BEGIN
    SYSTEM.PUT(SYSTEM.ADR(anyPosted), FALSE);
    previous := NIL; t := awaiting.first;
    WHILE t # NIL DO
      next := t.next;
      SYSTEM.GET(t.event, posted);
      IF posted THEN
        SYSTEM.PUT(t.event, FALSE);
        IF previous = NIL THEN awaiting.first := next ELSE previous.next := next END;
        IF awaiting.last = t THEN awaiting.last := previous END;
        t.event := 0;
        MakeReady(t)
      ELSE previous := t
      END;
      t := next
    END
  END Harvest;

  PROCEDURE ^ Put(ch: Channel; m: Message): BOOLEAN;

  (* Takes t, which is there, out of watching *)
  PROCEDURE Unwatch(t: Task);
    VAR p: Task;
  BEGIN
    IF watching.first = t THEN watching.first := t.next; p := NIL
    ELSE
      p := watching.first;
      WHILE p.next # t DO p := p.next END;
      p.next := t.next
    END;
    IF watching.last = t THEN watching.last := p END;
    t.next := NIL;
    DEC(watchCount)
  END Unwatch;

  (* Takes t, which is there, out of the list of timers *)
  PROCEDURE RemoveTimer(t: Timer);
    VAR p: Timer;
  BEGIN
    IF timers = t THEN timers := t.next
    ELSE
      p := timers;
      WHILE p.next # t DO p := p.next END;
      p.next := t.next
    END;
    t.next := NIL
  END RemoveTimer;

  (* Ends the timers whose deadlines are not after now: a timed
     descriptor wait's ends with the task timed out *)
  PROCEDURE ExpireTimers(now: HUGEINT);
    VAR t: Timer; sent: BOOLEAN;
  BEGIN
    WHILE (timers # NIL) & (timers.deadline <= now) DO
      t := timers; timers := t.next; t.next := NIL;
      IF t.task # NIL THEN
        IF t.task.timed THEN
          Unwatch(t.task); t.task.timed := FALSE; t.task.timedOut := TRUE
        END;
        MakeReady(t.task)
      ELSIF ~t.channel.closed THEN sent := Put(t.channel, NIL)
      END
    END
  END ExpireTimers;

  PROCEDURE AddTimer(t: Timer);
    VAR p: Timer;
  BEGIN
    IF (timers = NIL) OR (t.deadline < timers.deadline) THEN
      t.next := timers; timers := t
    ELSE
      p := timers;
      WHILE (p.next # NIL) & (p.next.deadline <= t.deadline) DO p := p.next END;
      t.next := p.next; p.next := t
    END
  END AddTimer;

  (* The idle step: waits for the nearest timer, a descriptor a task
     awaits, or a Post, or, unless wait, only looks *)
  PROCEDURE Idle(wait: BOOLEAN);
    VAR timeout: LONGINT; remaining: HUGEINT; t, previous, next: Task;
      i: LONGINT; posted: BOOLEAN;
  BEGIN
    IF ~wait THEN timeout := 0
    ELSIF timers = NIL THEN timeout := -1
    ELSE
      remaining := timers.deadline - TaskWaiting.Now();
      IF remaining <= 0 THEN timeout := 0
      ELSIF remaining >= longestTimeout * 1000 - 999 THEN timeout := longestTimeout
      ELSE timeout := SHORT((remaining + 999) DIV 1000)
      END
    END;
    TaskWaiting.Clear;
    t := watching.first;
    WHILE t # NIL DO TaskWaiting.Add(t.descriptor, t.forWriting); t := t.next END;
    (* a Post from here on wakes the wait *)
    SYSTEM.PUT(SYSTEM.ADR(idle), TRUE);
    SYSTEM.GET(SYSTEM.ADR(anyPosted), posted);
    IF posted THEN timeout := 0 END;
    IF (idleStep # NIL) & (timeout # 0) THEN
      (* it waits; a look without waiting then finds what is ready *)
      idleStep(timeout);
      timeout := 0
    END;
    TaskWaiting.Wait(timeout);
    SYSTEM.PUT(SYSTEM.ADR(idle), FALSE);
    lastPoll := TaskWaiting.Now();
    previous := NIL; t := watching.first; i := 0;
    WHILE t # NIL DO
      next := t.next;
      IF TaskWaiting.Ready(i) THEN
        IF previous = NIL THEN watching.first := next ELSE previous.next := next END;
        IF watching.last = t THEN watching.last := previous END;
        DEC(watchCount);
        IF t.timed THEN t.timed := FALSE; RemoveTimer(t.timer) END;
        MakeReady(t)
      ELSE previous := t
      END;
      t := next; INC(i)
    END
  END Idle;

  (* Reads the clock: due timers expire, and descriptors are looked at if
     a task waits for one and pollInterval has passed *)
  PROCEDURE Look;
    VAR now: HUGEINT;
  BEGIN
    now := TaskWaiting.Now();
    IF timers # NIL THEN ExpireTimers(now) END;
    IF (watchCount > 0) & (now - lastPoll >= pollInterval) THEN Idle(FALSE) END
  END Look;

  (* The next task to run, waiting in the idle step while none is ready *)
  PROCEDURE NextReady(): Task;
    VAR posted: BOOLEAN;
  BEGIN
    LOOP
      SYSTEM.GET(SYSTEM.ADR(anyPosted), posted);
      IF posted THEN Harvest END;
      IF runQueue.first # NIL THEN
        IF (timers # NIL) OR (watchCount > 0) THEN
          INC(picks);
          IF picks >= pollEvery THEN picks := 0; Look END
        END;
        RETURN Remove(runQueue)
      END;
      picks := 0;
      IF timers # NIL THEN ExpireTimers(TaskWaiting.Now()) END;
      IF runQueue.first = NIL THEN
        IF (timers = NIL) & (watchCount = 0) & (awaiting.first = NIL) THEN
          TaskWaiting.Deadlock
        END;
        Idle(TRUE);
        IF timers # NIL THEN ExpireTimers(TaskWaiting.Now()) END
      END
    END
  END NextReady;

  PROCEDURE FreeFinished;
  BEGIN
    IF endedTask # NIL THEN
      Coroutines.Free(endedTask.coroutine);
      endedTask := NIL
    END
  END FreeFinished;

  (* The running task has put itself where something will make it ready
     again, or in the run queue: runs the next ready task, if that is not
     the running one *)
  PROCEDURE Block;
    VAR old, next: Task;
  BEGIN
    old := current;
    next := NextReady();
    next.state := running;
    IF next # old THEN
      current := next;
      Coroutines.TransferForTasks(old.coroutine, next.coroutine);
      FreeFinished
    END
  END Block;

  (* Every task's coroutine body *)
  PROCEDURE Trampoline;
    VAR t, joiner, next: Task;
  BEGIN
    FreeFinished;
    t := current;
    t.Run;
    t.state := finished;
    joiner := Remove(t.joiners);
    WHILE joiner # NIL DO MakeReady(joiner); joiner := Remove(t.joiners) END;
    endedTask := t;
    next := NextReady();
    next.state := running;
    current := next;
    Coroutines.TransferForTasks(t.coroutine, next.coroutine)
    (* never resumed: its stack is freed *)
  END Trampoline;

  (* Starts t with a stack of stackSize bytes (Coroutines.Init's rules;
     DefaultStackSize is the recommendation): t runs when it reaches the
     front of the run queue. *)
  PROCEDURE Start*(t: Task; stackSize: LONGINT);
  BEGIN
    IF t.state # notStarted THEN TaskWaiting.Misuse(TaskWaiting.startOfStarted) END;
    Coroutines.Init(Trampoline, stackSize, t.coroutine);
    NEW(t.waiter); t.waiter.task := t;
    MakeReady(t)
  END Start;

  (* The running task; the main program's while it runs *)
  PROCEDURE Current*(): Task;
  BEGIN
    RETURN current
  END Current;

  (* Lets every other ready task run first *)
  PROCEDURE Yield*;
  BEGIN
    MakeReady(current);
    Block
  END Yield;

  (* Whether t's Run has returned *)
  PROCEDURE Done*(t: Task): BOOLEAN;
  BEGIN
    RETURN t.state = finished
  END Done;

  (* Waits until t's Run has returned; at once if it has *)
  PROCEDURE Join*(t: Task);
  BEGIN
    IF t = current THEN TaskWaiting.Misuse(TaskWaiting.joinOfRunning) END;
    IF t.state # finished THEN WaitIn(t.joiners); Block END
  END Join;

  (* Waits until c is signalled *)
  PROCEDURE Wait*(VAR c: Condition);
  BEGIN
    WaitIn(c.waiting);
    Block
  END Wait;

  (* Wakes the task that has waited on c longest, if any *)
  PROCEDURE Signal*(VAR c: Condition);
    VAR t: Task;
  BEGIN
    t := Remove(c.waiting);
    IF t # NIL THEN MakeReady(t) END
  END Signal;

  (* Wakes every task waiting on c *)
  PROCEDURE Broadcast*(VAR c: Condition);
    VAR t: Task;
  BEGIN
    t := Remove(c.waiting);
    WHILE t # NIL DO MakeReady(t); t := Remove(c.waiting) END
  END Broadcast;

  (* Takes m, waiting while another task holds it *)
  PROCEDURE Lock*(VAR m: Mutex);
  BEGIN
    IF m.holder = NIL THEN m.holder := current
    ELSE
      (* Unlock hands it over *)
      WaitIn(m.waiting);
      Block
    END
  END Lock;

  (* Gives m back, to the task that has waited longest, if any *)
  PROCEDURE Unlock*(VAR m: Mutex);
    VAR t: Task;
  BEGIN
    IF m.holder # current THEN TaskWaiting.Misuse(TaskWaiting.unlockNotHeld) END;
    t := Remove(m.waiting);
    m.holder := t;
    IF t # NIL THEN MakeReady(t) END
  END Unlock;

  (* Waits at least milliseconds; Yield when it is not positive *)
  (* Puts the running task's own timer in the list, due in milliseconds,
     which is positive *)
  PROCEDURE ArmTimer(milliseconds: LONGINT);
    VAR t: Timer; delay: HUGEINT;
  BEGIN
    IF current.timer = NIL THEN NEW(current.timer); current.timer.task := current END;
    t := current.timer;
    delay := milliseconds;
    t.deadline := TaskWaiting.Now() + delay * 1000;
    AddTimer(t)
  END ArmTimer;

  (* Waits at least milliseconds; Yield when it is not positive *)
  PROCEDURE Sleep*(milliseconds: LONGINT);
  BEGIN
    IF milliseconds <= 0 THEN Yield
    ELSE
      ArmTimer(milliseconds);
      current.state := blocked;
      Block
    END
  END Sleep;

  (* Events *)

  (* Waits until e is posted, at once if it has been since it was last
     awaited; then it is not posted. A Post wakes one task awaiting e,
     the one that has waited longest. *)
  PROCEDURE Await*(VAR e: Event);
    VAR posted: BOOLEAN;
  BEGIN
    SYSTEM.GET(SYSTEM.ADR(e.posted), posted);
    IF posted THEN SYSTEM.PUT(SYSTEM.ADR(e.posted), FALSE)
    ELSE
      current.event := SYSTEM.ADR(e.posted);
      WaitIn(awaiting);
      Block
    END
  END Await;

  (* Posts e: wakes a task awaiting it, or the next to await it. It only
     sets flags, so a signal handler or an AST may call it. Posts before
     e is awaited count as one. *)
  PROCEDURE Post*(VAR e: Event);
    VAR waiting: BOOLEAN;
  BEGIN
    SYSTEM.PUT(SYSTEM.ADR(e.posted), TRUE);
    SYSTEM.PUT(SYSTEM.ADR(anyPosted), TRUE);
    SYSTEM.GET(SYSTEM.ADR(idle), waiting);
    IF waiting THEN TaskWaiting.Wake END
  END Post;

  (* Makes Tasks call step instead of its own wait when no task is ready
     (decision 10), NIL its own again. step(timeout) waits at most timeout
     ms, -1 for no limit, and must return when WakeDescriptor() is
     readable and when a descriptor a task awaits is ready; it runs on
     the stack of the task that idles. *)
  PROCEDURE SetIdleStep*(step: IdleStep);
  BEGIN
    idleStep := step
  END SetIdleStep;

  (* Descriptors, POSIX only: a VAX/VMS program waits for a $QIO's AST
     that posts an event *)

  PROCEDURE AwaitDescriptor(fd: LONGINT; forWriting: BOOLEAN);
  BEGIN
    TaskWaiting.CheckDescriptor(fd);
    current.descriptor := fd; current.forWriting := forWriting;
    WaitIn(watching); INC(watchCount);
    Block
  END AwaitDescriptor;

  (* Waits until fd can be read without blocking (POSIX's poll), or is at
     its end or in error. A regular file always can. *)
  PROCEDURE AwaitReadable*(fd: LONGINT);
  BEGIN
    AwaitDescriptor(fd, FALSE)
  END AwaitReadable;

  (* Waits until fd can be written to without blocking, or is in error *)
  PROCEDURE AwaitWritable*(fd: LONGINT);
  BEGIN
    AwaitDescriptor(fd, TRUE)
  END AwaitWritable;

  (* AwaitDescriptor for at most milliseconds: whether fd became ready.
     The task waits for fd and for its own timer, and whichever comes
     first takes it out of the other's list. When the clock is read the
     timers expire before the descriptors are polled, so a wait whose
     time has passed times out even if fd is ready by then. *)
  PROCEDURE AwaitDescriptorFor(fd: LONGINT; forWriting: BOOLEAN;
    milliseconds: LONGINT): BOOLEAN;
    VAR ready: BOOLEAN;
  BEGIN
    TaskWaiting.CheckDescriptor(fd);
    IF milliseconds <= 0 THEN
      (* a look without waiting; Idle rebuilds the list it uses each time *)
      TaskWaiting.Clear;
      TaskWaiting.Add(fd, forWriting);
      TaskWaiting.Wait(0);
      ready := TaskWaiting.Ready(0);
      Yield
    ELSE
      current.descriptor := fd; current.forWriting := forWriting;
      current.timed := TRUE; current.timedOut := FALSE;
      ArmTimer(milliseconds);
      WaitIn(watching); INC(watchCount);
      Block;
      ready := ~current.timedOut
    END;
    RETURN ready
  END AwaitDescriptorFor;

  (* Waits until fd can be read without blocking, as AwaitReadable, or
     until milliseconds have passed, whichever is first: TRUE when fd is
     ready, FALSE when the time passed (at least milliseconds, then).
     When milliseconds is not positive it looks without waiting, then
     Yields. *)
  PROCEDURE AwaitReadableFor*(fd, milliseconds: LONGINT): BOOLEAN;
  BEGIN
    RETURN AwaitDescriptorFor(fd, FALSE, milliseconds)
  END AwaitReadableFor;

  (* AwaitWritable with a time limit, as AwaitReadableFor *)
  PROCEDURE AwaitWritableFor*(fd, milliseconds: LONGINT): BOOLEAN;
  BEGIN
    RETURN AwaitDescriptorFor(fd, TRUE, milliseconds)
  END AwaitWritableFor;

  (* The read end of the pipe that a Post during the idle step writes to,
     for a replaced step to watch; -1 on VAX/VMS, or if it could not be
     made *)
  PROCEDURE WakeDescriptor*(): LONGINT;
  BEGIN
    RETURN TaskWaiting.WakeDescriptor()
  END WakeDescriptor;

  (* Channels *)

  (* A channel that holds up to capacity messages; 0 makes each Send wait
     for a receiver *)
  PROCEDURE NewChannel*(capacity: LONGINT): Channel;
    VAR ch: Channel;
  BEGIN
    IF capacity < 0 THEN TaskWaiting.Misuse(TaskWaiting.negativeCapacity) END;
    NEW(ch);
    ch.capacity := capacity;
    IF capacity > 0 THEN NEW(ch.buffer, capacity) END;
    RETURN ch
  END NewChannel;

  PROCEDURE Enqueue(VAR q: WaiterQueue; w: Waiter);
  BEGIN
    w.next := NIL; w.previous := q.last; w.queued := TRUE;
    IF q.last = NIL THEN q.first := w ELSE q.last.next := w END;
    q.last := w
  END Enqueue;

  PROCEDURE Unlink(VAR q: WaiterQueue; w: Waiter);
  BEGIN
    IF w.previous = NIL THEN q.first := w.next ELSE w.previous.next := w.next END;
    IF w.next = NIL THEN q.last := w.previous ELSE w.next.previous := w.previous END;
    w.next := NIL; w.previous := NIL; w.queued := FALSE
  END Unlink;

  (* Takes the first waiter of q whose task is still waiting: a Select's
     other waiters stay queued until its task runs again *)
  PROCEDURE FirstWaiting(VAR q: WaiterQueue): Waiter;
    VAR w: Waiter;
  BEGIN
    w := q.first;
    WHILE (w # NIL) & (w.task.fired # NIL) DO Unlink(q, w); w := q.first END;
    IF w # NIL THEN Unlink(q, w) END;
    RETURN w
  END FirstWaiting;

  (* Wakes w's task, which then finds w in its fired *)
  PROCEDURE Fire(w: Waiter; delivered: BOOLEAN);
  BEGIN
    w.delivered := delivered;
    w.task.fired := w;
    MakeReady(w.task)
  END Fire;

  PROCEDURE Hold(ch: Channel; m: Message);
  BEGIN
    ch.buffer[(ch.head + ch.count) MOD ch.capacity] := m;
    INC(ch.count)
  END Hold;

  (* Hands m to a waiting receiver or holds it, if either can be done
     without waiting *)
  PROCEDURE Put(ch: Channel; m: Message): BOOLEAN;
    VAR w: Waiter;
  BEGIN
    w := FirstWaiting(ch.receivers);
    IF w # NIL THEN w.message := m; Fire(w, TRUE); RETURN TRUE
    ELSIF ch.count < ch.capacity THEN Hold(ch, m); RETURN TRUE
    ELSE RETURN FALSE
    END
  END Put;

  (* Takes a message held, or a waiting sender's, if there is one *)
  PROCEDURE Take(ch: Channel; VAR m: Message): BOOLEAN;
    VAR w: Waiter;
  BEGIN
    IF ch.count > 0 THEN
      m := ch.buffer[ch.head]; ch.buffer[ch.head] := NIL;
      ch.head := (ch.head + 1) MOD ch.capacity; DEC(ch.count);
      w := FirstWaiting(ch.senders);
      IF w # NIL THEN Hold(ch, w.message); w.message := NIL; Fire(w, TRUE) END;
      RETURN TRUE
    END;
    w := FirstWaiting(ch.senders);
    IF w # NIL THEN m := w.message; w.message := NIL; Fire(w, TRUE); RETURN TRUE END;
    RETURN FALSE
  END Take;

  (* Sends m on ch, if that can be done without waiting *)
  PROCEDURE TrySend*(ch: Channel; m: Message): BOOLEAN;
  BEGIN
    IF ch.closed THEN TaskWaiting.Misuse(TaskWaiting.sendOnClosed) END;
    RETURN Put(ch, m)
  END TrySend;

  (* Sends m on ch, waiting until a receiver takes it or ch has room *)
  PROCEDURE Send*(ch: Channel; m: Message);
    VAR w: Waiter;
  BEGIN
    IF ~TrySend(ch, m) THEN
      w := current.waiter;
      w.message := m; w.channel := ch;
      current.fired := NIL; current.state := blocked;
      Enqueue(ch.senders, w);
      Block;
      IF ~current.fired.delivered THEN
        w.message := NIL;
        TaskWaiting.Misuse(TaskWaiting.sendOnClosed)
      END
    END
  END Send;

  (* Receives a message from ch in m, if that can be done without
     waiting; m is NIL when it cannot *)
  PROCEDURE TryReceive*(ch: Channel; VAR m: Message): BOOLEAN;
  BEGIN
    m := NIL;
    RETURN Take(ch, m)
  END TryReceive;

  (* Receives a message from ch in m, waiting for one; FALSE, with m NIL,
     when ch is closed and holds no more *)
  PROCEDURE Receive*(ch: Channel; VAR m: Message): BOOLEAN;
    VAR w: Waiter;
  BEGIN
    IF Take(ch, m) THEN RETURN TRUE END;
    m := NIL;
    IF ch.closed THEN RETURN FALSE END;
    w := current.waiter;
    w.channel := ch; w.message := NIL;
    current.fired := NIL; current.state := blocked;
    Enqueue(ch.receivers, w);
    Block;
    m := w.message; w.message := NIL;
    RETURN w.delivered
  END Receive;

  (* Closes ch: no more can be sent. Its receivers waiting get FALSE, and
     its senders waiting trap (20). *)
  PROCEDURE Close*(ch: Channel);
    VAR w: Waiter;
  BEGIN
    IF ch.closed THEN TaskWaiting.Misuse(TaskWaiting.closeOfClosed) END;
    ch.closed := TRUE;
    w := FirstWaiting(ch.receivers);
    WHILE w # NIL DO w.message := NIL; Fire(w, FALSE); w := FirstWaiting(ch.receivers) END;
    w := FirstWaiting(ch.senders);
    WHILE w # NIL DO Fire(w, FALSE); w := FirstWaiting(ch.senders) END
  END Close;

  (* A channel of capacity 1 that gets one message, NIL, at least
     milliseconds from now: at once when that is not positive. A channel
     closed by then gets none. *)
  PROCEDURE After*(milliseconds: LONGINT): Channel;
    VAR ch: Channel; t: Timer; delay: HUGEINT;
  BEGIN
    ch := NewChannel(1);
    IF milliseconds <= 0 THEN Hold(ch, NIL)
    ELSE
      NEW(t); t.channel := ch;
      delay := milliseconds;
      t.deadline := TaskWaiting.Now() + delay * 1000;
      AddTimer(t)
    END;
    RETURN ch
  END After;

  PROCEDURE SpareWaiter(): Waiter;
    VAR w: Waiter;
  BEGIN
    w := current.spares;
    IF w = NIL THEN NEW(w); w.task := current ELSE current.spares := w.sibling END;
    RETURN w
  END SpareWaiter;

  (* Receives a message in m from whichever channel of from has one first,
     waiting for one, and returns its index; the first in from's order when
     several have one. A NIL entry, or a channel closed and holding no
     more, is passed over; -1, with m NIL, when every entry is. *)
  PROCEDURE Select*(VAR from: ARRAY OF Channel; VAR m: Message): LONGINT;
    VAR i, index: LONGINT; open: BOOLEAN; w, waiters, next: Waiter;
  BEGIN
    LOOP
      open := FALSE;
      i := 0;
      WHILE i < LEN(from) DO
        IF from[i] # NIL THEN
          IF Take(from[i], m) THEN RETURN i END;
          IF ~from[i].closed THEN open := TRUE END
        END;
        INC(i)
      END;
      m := NIL;
      IF ~open THEN RETURN -1 END;
      current.fired := NIL; current.state := blocked;
      waiters := NIL;
      i := 0;
      WHILE i < LEN(from) DO
        IF (from[i] # NIL) & ~from[i].closed THEN
          w := SpareWaiter();
          w.index := i; w.channel := from[i]; w.message := NIL;
          Enqueue(from[i].receivers, w);
          w.sibling := waiters; waiters := w
        END;
        INC(i)
      END;
      Block;
      w := current.fired;
      index := -1;
      IF w.delivered THEN m := w.message; index := w.index END;
      w := waiters;
      WHILE w # NIL DO
        next := w.sibling;
        IF w.queued THEN Unlink(w.channel.receivers, w) END;
        w.message := NIL; w.channel := NIL;
        w.sibling := current.spares; current.spares := w;
        w := next
      END;
      IF index >= 0 THEN RETURN index END
      (* woken by a Close: look again *)
    END
  END Select;

BEGIN
  NEW(mainTask);
  mainTask.state := running;
  NEW(mainTask.waiter); mainTask.waiter.task := mainTask;
  current := mainTask
END Tasks.
