#ifndef _PTREE_H_
#define _PTREE_H_

// Cấu trúc thông tin tiến trình phục vụ system call ptree
struct ptreeinfo {
  int pid;          // Mã định danh tiến trình (Process ID)
  int ppid;         // Mã định danh tiến trình cha (Parent Process ID)
  int state;        // Trạng thái tiến trình (enum procstate: 1..5)
  uint64 memsize;   // Kích thước bộ nhớ người dùng tính theo bytes (p->sz)
  char name[16];    // Tên tiến trình (tối đa 16 ký tự)
};

#endif
