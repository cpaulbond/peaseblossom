/* ChildProcesses.c - ChildProcesses.Mod's part in C: child processes for
   llvm-tasks-events, and pipes. The names contain "-", as Platform.c's
   do. */
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define NAME(n) __asm__("ChildProcesses.-" n)

static void pause_us(long us)
{
  struct timespec ts;
  ts.tv_sec = us / 1000000; ts.tv_nsec = (us % 1000000) * 1000;
  while (nanosleep(&ts, &ts) != 0 && errno == EINTR) {}
}

static void nonblocking(int fd)
{
  fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
}

int32_t ChildWriter(int32_t lines, int32_t interval) NAME("writer");
int32_t ChildWriter(int32_t lines, int32_t interval)
{
  int p[2], i;
  if (pipe(p) != 0) return -1;
  if (fork() == 0) {
    close(p[0]);
    for (i = 0; i < lines; i++) {
      pause_us((long)interval * 1000);
      if (write(p[1], "line\n", 5) != 5) _exit(1);
    }
    _exit(0);
  }
  close(p[1]);
  nonblocking(p[0]);
  return p[0];
}

int32_t ChildSignaller(int32_t count, int32_t maxPause) NAME("signaller");
int32_t ChildSignaller(int32_t count, int32_t maxPause)
{
  int p[2], i;
  pid_t parent = getpid();
  char c;
  uint32_t seed;
  if (pipe(p) != 0) return -1;
  if (fork() == 0) {
    close(p[1]);
    /* a pseudo-random pause of our own: OpenBSD's linker warns of rand() */
    seed = (uint32_t)getpid();
    for (i = 0; i < count; i++) {
      seed = seed * 1103515245u + 12345u;
      pause_us((int)((seed >> 16) % (uint32_t)(maxPause + 1)));
      kill(parent, SIGINT);
      if (read(p[0], &c, 1) != 1) _exit(1);
    }
    _exit(0);
  }
  close(p[0]);
  return p[1];
}

void ChildAck(int32_t fd) NAME("ack");
void ChildAck(int32_t fd)
{
  char c = 0;
  ssize_t written = write(fd, &c, 1);
  (void)written;
}

int32_t ChildDrain(int32_t fd) NAME("drain");
int32_t ChildDrain(int32_t fd)
{
  char buffer[4096];
  ssize_t n = read(fd, buffer, sizeof buffer);
  return n < 0 ? -1 : (int32_t)n;
}

int32_t ChildFullPipe(void) NAME("full-pipe");
int32_t ChildFullPipe(void)
{
  int p[2];
  if (pipe(p) != 0) return -1;
  if (write(p[1], "x", 1) != 1) return -1;
  nonblocking(p[0]);
  return p[0];
}

int32_t ChildPipe(int32_t *w) NAME("pipe");
int32_t ChildPipe(int32_t *w)
{
  int p[2];
  if (pipe(p) != 0) return -1;
  nonblocking(p[0]);
  *w = p[1];
  return p[0];
}

void ChildClose(int32_t fd) NAME("close");
void ChildClose(int32_t fd) { close(fd); }

void ChildReap(void) NAME("reap");
void ChildReap(void)
{
  while (wait(0) > 0 || errno == EINTR) {}
}
