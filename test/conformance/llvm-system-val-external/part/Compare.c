/* Compare.Mod's part in C: a comparison for qsort */
#include <stdint.h>

/* A name as the linker sees it: Mach-O (macOS) puts "_" before every C
   name (__USER_LABEL_PREFIX__), which the Oberon side's references get
   too; ELF puts nothing. As rtl/llvm/Platform.c's. */
#define LABEL_PREFIX_TEXT(p) #p
#define LABEL_PREFIX(p) LABEL_PREFIX_TEXT(p)
#define LABEL(n) LABEL_PREFIX(__USER_LABEL_PREFIX__) n

int CompareIntegers(const void *a, const void *b) __asm__(LABEL("Compare.-integers"));
int CompareIntegers(const void *a, const void *b)
{
  int32_t x = *(const int32_t *) a, y = *(const int32_t *) b;
  return x < y ? -1 : x > y;
}
