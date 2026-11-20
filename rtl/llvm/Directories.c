/* Directories.c - the part of Directories.Mod written in C (PLAN.md
   Phase 16 step 4), compiled by clang for the target from the system's
   own headers, as Platform.c is: S_ISDIR is a macro of them, and mkdir's
   mode_t is 16 bits on FreeBSD, 32 elsewhere. The names contain "-", as
   Platform.c's do. */

#include <dirent.h>
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

/* A name as the linker sees it: Mach-O (macOS) puts "_" before every C
   name (__USER_LABEL_PREFIX__), which the Oberon side's references get
   too; ELF puts nothing. */
#define LABEL_PREFIX_TEXT(p) #p
#define LABEL_PREFIX(p) LABEL_PREFIX_TEXT(p)
#define LABEL(n) LABEL_PREFIX(__USER_LABEL_PREFIX__) n
#define NAME(n) __asm__(LABEL("Directories.-" n))

/* Whether name is a directory. */
int32_t DirectoriesIsDirectory(const char *name) NAME("is-directory");
int32_t DirectoriesIsDirectory(const char *name)
{
  struct stat s;
  return stat(name, &s) == 0 && S_ISDIR(s.st_mode);
}

/* Makes the directory name, readable, writable and searchable by all but
   what the umask takes away: 0 or the errno value. */
int32_t DirectoriesMake(const char *name) NAME("make");
int32_t DirectoriesMake(const char *name)
{
  return mkdir(name, 0777) < 0 ? errno : 0;
}

/* Whether the directory of the file path names has an entry spelled
   exactly as path's last component: 1 or 0, 0 too when the directory
   cannot be read. */
int32_t DirectoriesSpelledAsGiven(const char *path) NAME("spelled-as-given");
int32_t DirectoriesSpelledAsGiven(const char *path)
{
  const char *slash = strrchr(path, '/');
  const char *name = slash != NULL ? slash + 1 : path;
  struct dirent *entry;
  int32_t found = 0;
  DIR *dir;

  if (slash == NULL) dir = opendir(".");
  else if (slash == path) dir = opendir("/");
  else {
    size_t length = (size_t)(slash - path);
    char *dirName = malloc(length + 1);
    if (dirName == NULL) return 0;
    memcpy(dirName, path, length);
    dirName[length] = '\0';
    dir = opendir(dirName);
    free(dirName);
  }
  if (dir == NULL) return 0;
  while (!found && (entry = readdir(dir)) != NULL) found = strcmp(entry->d_name, name) == 0;
  closedir(dir);
  return found;
}
