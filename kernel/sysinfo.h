#ifndef XV6_SYSINFO_H
#define XV6_SYSINFO_H

struct sysinfo {
  uint64 freemem; // Number of bytes of free physical memory.
  uint64 nproc;   // Number of processes whose state is not UNUSED.
};

#endif
