/* TaskWaiting.c - the part of TaskWaiting.Mod written in C
   (doc/developer/tasks.md, decisions 1 and 9): the monotonic clock, the
   self-pipe, poll, and the messages of traps 19 and 20.

   The names contain "-", as Platform.c's do. */

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define NAME(n) __asm__("TaskWaiting.-" n)

/* TaskWaiting.Mod's PollEntry and its events are struct pollfd's */
_Static_assert(sizeof(struct pollfd) == 8, "struct pollfd is not 8 bytes");
_Static_assert(offsetof(struct pollfd, fd) == 0, "pollfd.fd");
_Static_assert(offsetof(struct pollfd, events) == 4, "pollfd.events");
_Static_assert(offsetof(struct pollfd, revents) == 6, "pollfd.revents");
_Static_assert(POLLIN == 1 && POLLOUT == 4, "POLLIN or POLLOUT");

static void trap(const char *message, int status)
{
  write(2, message, strlen(message));
  exit(status);
}

/* Trap 19: no task is ready and nothing can make one ready. */
void TaskWaitingDeadlock(void) NAME("deadlock");
void TaskWaitingDeadlock(void) { trap("all tasks are blocked\n", 19); }

/* Trap 20, misuse: which is TaskWaiting.Mod's number of the case. */
void TaskWaitingMisuse(int32_t which) NAME("misuse");
void TaskWaitingMisuse(int32_t which)
{
  static const char *const texts[] = {
    "Unlock of a mutex the running task does not hold\n",
    "Join of the running task\n",
    "Send on a closed channel\n",
    "Close of a channel already closed\n",
    "Start of a task already started\n",
    "NewChannel with a negative capacity\n",
    "AwaitReadable or AwaitWritable of a negative descriptor\n",
    "AwaitReadable or AwaitWritable on VAX/VMS\n",
  };
  if (which < 0 || which >= (int32_t)(sizeof texts / sizeof texts[0])) which = 0;
  trap(texts[which], 20);
}

/* The monotonic clock in microseconds. */
int64_t TaskWaitingNow(void) NAME("now");
int64_t TaskWaitingNow(void)
{
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (int64_t)ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
}

/* The self-pipe: both ends non-blocking and closed on exec. */
static int wake_write = -1;

/* Makes the self-pipe and returns its read end, or -1. */
int32_t TaskWaitingPipe(void) NAME("pipe");
int32_t TaskWaitingPipe(void)
{
  int ends[2], i;
  if (pipe(ends) != 0) return -1;
  for (i = 0; i < 2; i++) {
    fcntl(ends[i], F_SETFL, fcntl(ends[i], F_GETFL) | O_NONBLOCK);
    fcntl(ends[i], F_SETFD, FD_CLOEXEC);
  }
  wake_write = ends[1];
  return ends[0];
}

/* One byte to the self-pipe; async-signal-safe, errno kept. A full
   pipe already wakes, so a failed write is let go. */
void TaskWaitingWake(void) NAME("wake");
void TaskWaitingWake(void)
{
  int saved = errno;
  char c = 0;
  if (wake_write >= 0) {
    ssize_t written = write(wake_write, &c, 1);
    (void)written;
  }
  errno = saved;
}

/* poll on entries[0..count), entry 0 the self-pipe's read end, which it
   empties when readable. An interrupted or failed poll finds nothing. */
int32_t TaskWaitingPoll(struct pollfd *entries, int32_t count, int32_t timeout) NAME("poll");
int32_t TaskWaitingPoll(struct pollfd *entries, int32_t count, int32_t timeout)
{
  int result = poll(entries, (nfds_t)count, timeout), i;
  if (result <= 0) {
    for (i = 0; i < count; i++) entries[i].revents = 0;
    return 0;
  }
  if (entries[0].fd >= 0 && entries[0].revents != 0) {
    char buffer[64];
    while (read(entries[0].fd, buffer, sizeof buffer) > 0) {}
  }
  return result;
}
