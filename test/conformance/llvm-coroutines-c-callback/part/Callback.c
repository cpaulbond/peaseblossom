/* Callback.Mod's part in C. */
#include <fenv.h>
#include <stdint.h>

/* A name as the linker sees it: Mach-O (macOS) puts "_" before every C
   name (__USER_LABEL_PREFIX__), which the Oberon side's references get
   too; ELF puts nothing. As rtl/llvm/Platform.c's. */
#define LABEL_PREFIX_TEXT(p) #p
#define LABEL_PREFIX(p) LABEL_PREFIX_TEXT(p)
#define LABEL(n) LABEL_PREFIX(__USER_LABEL_PREFIX__) n
#define NAME(n) __asm__(LABEL("Callback.-" n))

void CallbackHold(uintptr_t (*make)(void), void (*pause)(void), void (*check)(uintptr_t)) NAME("hold");
void CallbackHold(uintptr_t (*make)(void), void (*pause)(void), void (*check)(uintptr_t))
{
  /* volatile: in this frame's memory, not in a register the switch saves */
  volatile uintptr_t held = make();
  pause();
  check(held);
}

void CallbackRoundUp(void) NAME("round-up");
void CallbackRoundUp(void) { fesetround(FE_UPWARD); }

int32_t CallbackRoundingUp(void) NAME("rounding-up");
int32_t CallbackRoundingUp(void) { return fegetround() == FE_UPWARD; }
