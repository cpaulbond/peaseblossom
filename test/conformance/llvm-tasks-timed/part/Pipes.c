/* Pipes.c - Pipes.Mod's part in C: non-blocking pipes for
   llvm-tasks-timed. The names contain "-", as Platform.c's do. */
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <unistd.h>

/* A name as the linker sees it: Mach-O (macOS) puts "_" before every C
   name (__USER_LABEL_PREFIX__), which the Oberon side's references get
   too; ELF puts nothing. As rtl/llvm/Platform.c's. */
#define LABEL_PREFIX_TEXT(p) #p
#define LABEL_PREFIX(p) LABEL_PREFIX_TEXT(p)
#define LABEL(n) LABEL_PREFIX(__USER_LABEL_PREFIX__) n
#define NAME(n) __asm__(LABEL("Pipes.-" n))

static void nonblocking(int fd)
{
  fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
}

int32_t PipesMake(int32_t *w) NAME("make");
int32_t PipesMake(int32_t *w)
{
  int p[2];
  if (pipe(p) != 0) return -1;
  nonblocking(p[0]); nonblocking(p[1]);
  *w = p[1];
  return p[0];
}

void PipesPut(int32_t fd) NAME("put");
void PipesPut(int32_t fd)
{
  while (write(fd, "x", 1) < 0 && errno == EINTR) {}
}

int32_t PipesFill(int32_t fd) NAME("fill");
int32_t PipesFill(int32_t fd)
{
  char buffer[4096] = {0};
  ssize_t n;
  int32_t total = 0;
  for (;;) {
    n = write(fd, buffer, sizeof buffer);
    if (n > 0) total += (int32_t)n;
    else if (n < 0 && errno == EINTR) continue;
    else return total;
  }
}

int32_t PipesDrain(int32_t fd) NAME("drain");
int32_t PipesDrain(int32_t fd)
{
  char buffer[4096];
  ssize_t n;
  int32_t total = 0;
  for (;;) {
    n = read(fd, buffer, sizeof buffer);
    if (n > 0) total += (int32_t)n;
    else if (n < 0 && errno == EINTR) continue;
    else return total;
  }
}

void PipesClose(int32_t fd) NAME("close");
void PipesClose(int32_t fd)
{
  close(fd);
}
