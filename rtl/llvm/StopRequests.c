/* StopRequests.c - the part of StopRequests.Mod written in C (PLAN.md,
   "Ongoing library enhancements", 7), compiled by clang for the target
   from the system's own headers, as Platform.c is: Platform's handlers
   are installed without SA_RESETHAND, which a request caught once needs.
   The names contain "-", as Platform.c's do. */

#include <signal.h>
#include <stdint.h>
#include <string.h>

#define NAME(n) __asm__("StopRequests.-" n)

/* Platform.c's count of the signal handlers running, which Coroutines
   reads to refuse a Transfer in one; the notifier runs inside a handler,
   so it is counted too. */
extern volatile int32_t PlatformHandlersRunning __asm__("Platform.-handlers-running");

/* What StopRequests.Mod's none, interrupt and terminate are. */
enum { none = 0, interrupt = 1, terminate = 2 };

static volatile sig_atomic_t latest = none;
static void (*volatile notifier)(void) = 0;

static void caught(int number)
{
  void (*notify)(void) = notifier;
  latest = number == SIGTERM ? terminate : interrupt;
  PlatformHandlersRunning++;
  if (notify != 0) notify();
  PlatformHandlersRunning--;
}

static void catch_one(int number)
{
  struct sigaction action;
  memset(&action, 0, sizeof action);
  action.sa_handler = caught;
  sigemptyset(&action.sa_mask);
  /* each is blocked while either is caught, so that latest is the kind
     of the last; SA_RESETHAND makes the next of the same kind end the
     program, as uncaught */
  sigaddset(&action.sa_mask, SIGINT);
  sigaddset(&action.sa_mask, SIGTERM);
  action.sa_flags = SA_RESTART | SA_RESETHAND;
  sigaction(number, &action, 0);
}

void StopRequestsCatch(void) NAME("catch");
void StopRequestsCatch(void)
{
  catch_one(SIGINT);
  catch_one(SIGTERM);
}

int32_t StopRequestsLatest(void) NAME("latest");
int32_t StopRequestsLatest(void)
{
  return latest;
}

void StopRequestsSetNotifier(void (*notify)(void)) NAME("set-notifier");
void StopRequestsSetNotifier(void (*notify)(void))
{
  notifier = notify;
}
