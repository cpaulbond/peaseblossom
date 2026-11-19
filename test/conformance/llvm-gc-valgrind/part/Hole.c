/* Hole.Mod's part in C: stack slots the collector scans that the program
   has not written since their frame was made. */
#include <stdint.h>

#define NAME(n) __asm__("Hole.-" n)
#define SLOTS 64

/* Fills a frame's slots with word, then returns: the next frame made at
   the same depth finds word in its unwritten slots, as an LLVM spill slot
   can find a pointer an earlier call left. */
void HoleSmear(uintptr_t word) NAME("smear");
void HoleSmear(uintptr_t word)
{
  volatile uintptr_t slots[SLOTS];
  int i;
  for (i = 0; i < SLOTS; i++) slots[i] = word;
}

/* Calls collect from a frame whose slots it never writes. */
void HoleCall(void (*collect)(void)) NAME("call");
void HoleCall(void (*collect)(void))
{
  volatile uintptr_t slots[SLOTS];
  collect();
  __asm__ volatile ("" : : "r" (slots) : "memory");
}
