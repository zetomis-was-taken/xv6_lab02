#include "kernel/types.h"
#include "kernel/stat.h"
#include "kernel/ptree.h"
#include "user/user.h"

#define MAX_PROC 64

// In khoảng trắng để thụt lề
static void
print_indent(int depth)
{
  int i;
  for (i = 0; i < depth; i++) {
    printf("  ");
  }
}

// Duyệt và in cây tiến trình theo thứ tự ưu tiên chiều sâu (DFS)
static void
print_tree(int pid, int depth, struct ptreeinfo plist[], int total, int visited[])
{
  int idx = -1;
  int i, j;

  // Tìm vị trí tiến trình có PID tương ứng trong mảng
  for (i = 0; i < total; i++) {
    if (plist[i].pid == pid) {
      idx = i;
      break;
    }
  }

  if (idx < 0 || visited[idx])
    return;

  visited[idx] = 1;
  print_indent(depth);
  printf("%d %s state=%d mem=%ld\n",
         plist[idx].pid,
         plist[idx].name,
         plist[idx].state,
         plist[idx].memsize);

  // Duyệt đệ quy tất cả các tiến trình con (có ppid == pid hiện tại)
  for (j = 0; j < total; j++) {
    if (plist[j].ppid == pid && !visited[j]) {
      print_tree(plist[j].pid, depth + 1, plist, total, visited);
    }
  }
}

int
main(int argc, char *argv[])
{
  struct ptreeinfo plist[MAX_PROC];
  int visited[MAX_PROC];
  int n, i, j;

  // Gọi system call ptree để lấy danh sách tiến trình từ kernel
  n = ptree(plist, MAX_PROC);
  if (n < 0) {
    fprintf(2, "pstree: ptree failed\n");
    exit(1);
  }

  for (i = 0; i < n; i++) {
    visited[i] = 0;
  }

  // Sắp xếp danh sách theo PID tăng dần để hiển thị nhất quán
  for (i = 0; i < n - 1; i++) {
    for (j = i + 1; j < n; j++) {
      if (plist[i].pid > plist[j].pid) {
        struct ptreeinfo tmp = plist[i];
        plist[i] = plist[j];
        plist[j] = tmp;
      }
    }
  }

  // Bắt đầu in từ tiến trình gốc init (pid == 1)
  for (i = 0; i < n; i++) {
    if (plist[i].pid == 1) {
      print_tree(1, 0, plist, n, visited);
      break;
    }
  }

  // In các tiến trình gốc khác có ppid <= 0 nếu chưa được duyệt
  for (i = 0; i < n; i++) {
    if (!visited[i] && plist[i].ppid <= 0) {
      print_tree(plist[i].pid, 0, plist, n, visited);
    }
  }

  // In các tiến trình còn sót lại để không bỏ sót tiến trình nào
  for (i = 0; i < n; i++) {
    if (!visited[i]) {
      print_tree(plist[i].pid, 0, plist, n, visited);
    }
  }

  exit(0);
}
