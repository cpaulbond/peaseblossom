/* Twice.Mod's part in C */
#include <stdint.h>

/* A name as the linker sees it: Mach-O (macOS) puts "_" before every C
   name (__USER_LABEL_PREFIX__), which the Oberon side's references get
   too; ELF puts nothing. As rtl/llvm/Platform.c's. */
#define LABEL_PREFIX_TEXT(p) #p
#define LABEL_PREFIX(p) LABEL_PREFIX_TEXT(p)
#define LABEL(n) LABEL_PREFIX(__USER_LABEL_PREFIX__) n

int32_t TwiceDouble(int32_t x) __asm__(LABEL("Twice.-double"));
int32_t TwiceDouble(int32_t x) { return 2 * x; }
