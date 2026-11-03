#include "kernel/types.h"
#include "kernel/riscv.h"
#include "kernel/sysinfo.h"
#include "user/user.h"

static void
check(int ok, char *message)
{
  if(!ok){
    printf("sysinfotest: %s\n", message);
    exit(1);
  }
}

static struct sysinfo
info(void)
{
  struct sysinfo s;
  check(sysinfo(&s) == 0, "sysinfo failed");
  return s;
}

int
main(void)
{
  int ready[2], done[2], status;
  char c;
  struct sysinfo before, after;

  check(sysinfo((struct sysinfo *)~0ULL) == -1,
        "invalid pointer was accepted");

  // A page added to an existing heap needs exactly one physical page.
  check(sbrk(PGSIZE) != (char *)-1, "sbrk failed");
  before = info();
  check(sbrk(PGSIZE) != (char *)-1, "sbrk failed");
  after = info();
  check(before.freemem == after.freemem + PGSIZE,
        "allocation did not reduce freemem by one page");
  check(sbrk(-PGSIZE) != (char *)-1, "sbrk shrink failed");
  after = info();
  check(before.freemem == after.freemem,
        "freeing a page did not restore freemem");

  check(pipe(ready) == 0 && pipe(done) == 0, "pipe failed");
  before = info();
  int pid = fork();
  check(pid >= 0, "fork failed");
  if(pid == 0){
    close(ready[0]);
    close(done[1]);
    check(write(ready[1], "x", 1) == 1, "child signal failed");
    check(read(done[0], &c, 1) == 1, "child wait failed");
    exit(0);
  }
  check(read(ready[0], &c, 1) == 1, "parent wait failed");
  after = info();
  check(after.nproc == before.nproc + 1, "fork did not increase nproc");
  check(write(done[1], "x", 1) == 1, "parent signal failed");
  check(wait(&status) == pid && status == 0, "child failed");
  after = info();
  check(after.nproc == before.nproc, "wait did not restore nproc");
  check(after.freemem == before.freemem, "child memory was not reclaimed");
  close(ready[0]);
  close(ready[1]);
  close(done[0]);
  close(done[1]);

  printf("sysinfotest: OK\n");
  exit(0);
}
