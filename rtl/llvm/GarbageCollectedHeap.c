/* GarbageCollectedHeap's part in C: the stack scan's words, as memcheck
   should see them (doc/developer/collector-under-valgrind.md).

   The collector scans a stack conservatively: every word between the
   stack pointer and the stack's base that holds a heap block's address
   keeps that block. memcheck takes a word of a frame for undefined until
   the program writes it, and LLVM reserves slots that a function writes
   only on some paths, so such a slot can still hold a pointer an earlier
   call left there. When that pointer names a live block, the collector's
   tests of the word, and the marking of the block it reaches, use an
   undefined value, and memcheck reports each use, thousands of times in a
   long run, though the scan is right: a stale word keeps at most a block
   no longer needed, as with any conservative collector.

   So under valgrind the scan reads each word through DefinedWord, which
   copies the word and tells memcheck that the copy, not the stack, is
   defined. What memcheck knows of the stack is unchanged, so a real use
   of an undefined value anywhere else is still reported. Run natively,
   the collector asks UnderValgrind once and reads the words itself; on
   OpenBSD and NetBSD, where valgrind does not run, valgrind.h makes
   RUNNING_ON_VALGRIND 0 alone. */
#include <stdint.h>
#include "valgrind.h"
#include "memcheck.h"

#define NAME(n) __asm__("GarbageCollectedHeap.-" n)

/* Whether the program runs under valgrind: 1 if so, else 0. */
int32_t GarbageCollectedHeapUnderValgrind(void) NAME("under-valgrind");
int32_t GarbageCollectedHeapUnderValgrind(void)
{
  return RUNNING_ON_VALGRIND != 0;
}

/* The word at address, as a value memcheck takes for defined. */
uintptr_t GarbageCollectedHeapDefinedWord(uintptr_t address) NAME("defined-word");
uintptr_t GarbageCollectedHeapDefinedWord(uintptr_t address)
{
  volatile uintptr_t word = *(volatile uintptr_t *)address;
  (void)VALGRIND_MAKE_MEM_DEFINED(&word, sizeof word);
  return word;
}
