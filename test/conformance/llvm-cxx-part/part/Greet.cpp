// Greet.Mod's part in C++: it needs the C++ runtime (operator new, the
// exception personality routine) and libnative.a's native_triple.
#include <stdint.h>
#include <string>
#include <vector>

extern "C" int native_triple(int x);

/* A name as the linker sees it: Mach-O (macOS) puts "_" before every C
   name (__USER_LABEL_PREFIX__), which the Oberon side's references get
   too; ELF puts nothing. As rtl/llvm/Platform.c's. */
#define LABEL_PREFIX_TEXT(p) #p
#define LABEL_PREFIX(p) LABEL_PREFIX_TEXT(p)
#define LABEL(n) LABEL_PREFIX(__USER_LABEL_PREFIX__) n

int32_t GreetCount(int32_t n) __asm__(LABEL("Greet.-count"));
int32_t GreetCount(int32_t n) {
  try {
    if (n < 0) throw n;
    std::vector<std::string> words(n, std::string("hello"));
    return native_triple(static_cast<int32_t>(words.size() * words[0].size()));
  } catch (int) {
    return -1;
  }
}
