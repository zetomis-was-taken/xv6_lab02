

= System call Trace
<system-call-trace>
==  Mô tả bài toán
<mô-tả-bài-toán>
===  Yêu cầu
<yêu-cầu>
System call là giao diện giao tiếp chuẩn giữa user space và kernel. Nhằm hỗ trợ debug và kiểm thử hoạt động của hệ điều hành, bài toán yêu cầu xây dựng tính năng theo dõi system call linh hoạt:

- #strong[Xây dựng system call `trace`];: Tiếp nhận một số nguyên `mask`. Mỗi bit thứ $i$ trong `mask` khi được bật \(giá trị 1) biểu thị việc theo dõi syscall có số hiệu $i$ tương ứng \(theo định nghĩa mã `SYS_*` trong `kernel/syscall.h`).

- #strong[Ghi log trong kernel];: Khi một tiến trình thực thi một syscall nằm trong `mask`, kernel sẽ in ra một dòng log chuẩn định dạng:

  ```text
  <pid>: syscall <tên_syscall> -> <giá_trị_trả_về>
  ```

  Trong đó:

  - `<pid>`: ID của tiến trình đang thực thi.
  - `<tên_syscall>`: Tên định danh của syscall.
  - `<giá_trị_trả_về>`: Giá trị trả về sau khi syscall hoàn tất \(lấy từ register `a0`).

- #strong[Kế thừa và cô lập tiến trình];:

  - `trace_mask` phải được tự động sao chép sang các tiến trình con được tạo thông qua `fork()`.
  - Tiến trình được theo dõi hoàn toàn cô lập, không làm ảnh hưởng đến hành vi hay đầu ra của các tiến trình khác trong hệ thống.

- #strong[Chương trình user `trace`];: Cung cấp tiện ích dòng lệnh `trace <mask> <command> [args...]` cho phép người dùng khởi chạy bất kỳ chương trình nào kèm theo chế độ theo dõi mong muốn.

===  Input
<input>
- #strong[Cú pháp dòng lệnh];:

  ```bash
  $ trace <mask> <command> [args...]
  ```

  - `mask`: Số nguyên biểu diễn bitmask \(hệ thập phân). Ví dụ: `32` ứng với $1 lt.double 5$ \(`SYS_read`), `2147483647` ứng với việc bật toàn bộ 31 bit thấp để theo dõi tất cả syscall.
  - `<command>`: Tên chương trình mục tiêu cần chạy và các đối số đi kèm.

- #strong[Prototype API trong user space];:

  ```c
  int trace(int mask);
  ```

=== Output
<output>
- Thông tin log được kernel xuất trực tiếp ra console ngay khi syscall hoàn tất.
- Không in log đối với các syscall không được bật trong `mask`, hoặc khi chạy các chương trình thông thường không gọi `trace`.

==  Thuật toán và Thiết kế giải pháp
<thuật-toán-và-thiết-kế-giải-pháp>
=== Ý tưởng cốt lõi và Cơ sở thiết kế
<ý-tưởng-cốt-lõi-và-cơ-sở-thiết-kế>
+ #strong[Quản lý trạng thái theo dõi trong `struct proc`];: Mỗi tiến trình trong xv6 được kernel quản lý độc lập qua `struct proc` \(lưu PID, trạng thái, bộ nhớ, `trapframe`…). Trạng thái theo dõi không thể dùng biến toàn cục vì sẽ gây xung đột \(race condition) và mất tính cô lập \(isolation) giữa các tiến trình. Do đó, việc bổ sung trường `int trace_mask` vào `struct proc` giúp mỗi tiến trình ghi nhớ danh sách syscall cần theo dõi một cách độc lập.

+ #strong[Kế thừa qua `fork()` và bảo toàn qua `exec()`];:

  - #strong[`fork()`];: Nhân bản tiến trình cha sang tiến trình con \(sao chép toàn bộ vùng nhớ, thanh ghi và ngữ cảnh). Kernel sao chép trực tiếp giá trị `trace_mask` từ cha sang con để toàn bộ cây tiến trình con cháu đều duy trì trạng thái theo dõi.
  - #strong[`exec()`];: Thay thế không gian nhớ của tiến trình bằng chương trình thực thi mới nhưng giữ nguyên `struct proc` trong kernel. Do đó, khi tiện ích `trace` gọi `trace(mask)` rồi gọi `exec()`, chương trình mục tiêu tự động kế thừa `trace_mask` đã kích hoạt mà không cần cơ chế truyền tin phức tạp.

+ #strong[Chặn bắt tại trap dispatcher \(`syscall()`)];: Khi tiến trình thực thi lệnh `ecall`, CPU trap vào kernel và chuyển điều khiển đến hàm điều phối `syscall()`. Tại đây, kernel gọi handler tương ứng và lưu kết quả trả về vào register `a0`. Bằng cách đặt điểm kiểm tra bitmask `(trace_mask & (1 << num))` ngay sau khi handler hoàn tất, kernel có thể tra cứu tên từ lookup table và in log ra console theo đúng định dạng.
 
=== Tiến trình xây dựng và thực thi giải pháp
<tiến-trình-xây-dựng-và-thực-thi-giải-pháp>
- #strong[Thiết lập giao diện và cầu nối User - Kernel];: Định nghĩa mã `SYS_trace` trong `kernel/syscall.h`, khai báo prototype `int trace(int)` trong `user/user.h`, và thêm entry vào `user/usys.pl` để sinh mã stub tự động \(`ecall`). Đồng thời, thêm chương trình vào danh sách `UPROGS` trong `Makefile` để hệ thống build biên dịch và đóng gói file thực thi `_trace` vào `fs.img` của xv6.

- #strong[Quản lý vòng đời `trace_mask` trong Kernel \(`kernel/proc.c`)];: Bảng tiến trình xv6 \(`NPROC = 64`) liên tục tái chế các slot `struct proc`. Vì vậy, cần khởi tạo `trace_mask = 0` trong `allocproc()` để tránh nhận giá trị rác từ tiến trình cũ; sao chép `np->trace_mask = p->trace_mask` trong `fork()` để tiến trình con kế thừa cấu hình theo dõi; và xóa sạch `trace_mask = 0` trong `freeproc()` khi giải phóng tiến trình.

- #strong[Cài đặt System Call Handler \(`kernel/sysproc.c`)];: Hiện thực hàm `sys_trace()` để đọc đối số `mask` từ register `a0` thông qua hàm trợ thủ `argint()`, sau đó lưu vào trường `trace_mask` của tiến trình hiện hành \(`myproc()`) và trả về `0`.

- #strong[Điều phối, kiểm tra mask và xuất log \(`kernel/syscall.c`)];: Đăng ký hàm `sys_trace` vào bảng vector `syscalls` và xây dựng lookup table `syscall_names` để ánh xạ số hiệu syscall sang chuỗi tên. Tại điểm trả về của hàm `syscall()`, kiểm tra điều kiện bit `(p->trace_mask & (1 << num)) != 0` để in log định dạng `<pid>: syscall <name> -> <return_value>`.

- #strong[Hiện thực tiện ích dòng lệnh `user/trace.c`];: Chương trình đọc và chuyển đổi `argv[1]` thành số nguyên `mask` bằng `atoi()`, gọi syscall `trace(mask)` để thiết lập trạng thái cho tiến trình hiện hành, sau đó gọi `exec()` nạp chương trình mục tiêu cùng các đối số còn lại.


=== Lưu đồ hoạt động
<lưu-đồ-hoạt-động>
==== Lưu đồ 1: Luồng thực thi chương trình user `trace`
<lưu-đồ-1-luồng-thực-thi-chương-trình-user-trace>
#figure([#image("luu_do_1.svg");],
  caption: [
    Lưu đồ 1
  ]
)


==== Lưu đồ 2: Cơ chế điều phối và ghi log trong kernel \(`syscall()`)
<lưu-đồ-2-cơ-chế-điều-phối-và-ghi-log-trong-kernel-syscall>
#figure([#image("luu_do_2.svg");],
  caption: [
    Lưu đồ 2
  ]
)


== Những khó khăn gặp phải và giải pháp
<những-khó-khăn-gặp-phải-và-giải-pháp>
+ #strong[Vấn đề self-tracing \(chính syscall `trace` bị bỏ lỡ)];:
  - #emph[Khó khăn];: Trong kịch bản theo dõi toàn bộ syscall \(`trace 2147483647 ...`), dòng log đầu tiên xuất hiện phải là `4: syscall trace -> 0`. Nếu việc kiểm tra `trace_mask` được đặt trước khi gọi handler `sys_trace()`, tại thời điểm đó `trace_mask` của tiến trình vẫn bằng 0 nên lời gọi `trace` sẽ bị bỏ qua và không bao giờ được ghi vết.
  - #emph[Giải pháp];: Đặt bước kiểm tra điều kiện `(p->trace_mask & (1 << num))` ngay #strong[sau] khi handler `syscalls[num]()` đã chạy xong. Lúc này `sys_trace()` đã cập nhật xong `mask` mới vào `struct proc`, giúp nhận diện và in chính xác log của chính syscall `trace`.
+ #strong[Cảnh báo format của trình biên dịch và hiển thị mã lỗi số âm];:
  - #emph[Khó khăn];: Trình biên dịch GCC trên RISC-V kích hoạt cờ kiểm tra nghiêm ngặt `-Werror=format=`, báo lỗi nếu dùng định dạng `%d` cho `p->trapframe->a0` \(do trường này có kiểu `uint64`). Tuy nhiên, nếu đổi sang `%lu`, các mã lỗi syscall trả về dạng số âm như `-1` sẽ bị in thành số nguyên không dấu 64-bit cực lớn \($18446744073709551615$), sai lệch định dạng yêu cầu.
  - #emph[Giải pháp];: Ép kiểu tường minh `(int)p->trapframe->a0` khi truyền vào hàm `printf`. Thao tác này vừa loại bỏ triệt để cảnh báo từ compiler, vừa đảm bảo hiển thị đúng số nguyên có dấu của mã lỗi \(ví dụ `-> -1`).
+ #strong[Bảo toàn và cô lập `trace_mask` qua các thế hệ tiến trình];:
  - #emph[Khó khăn];: Khi tiến trình gọi `exec()`, image bộ nhớ bị thay thế nhưng `struct proc` trong kernel vẫn giữ nguyên nên `trace_mask` được duy trì. Tuy nhiên, khi gọi `fork()`, một `struct proc` mới được cấp phát cho tiến trình con. Nếu không sao chép cẩn thận, toàn bộ cây tiến trình con cháu \(ví dụ trong các bài test fork nhiều tầng) sẽ mất tính năng theo dõi. Đồng thời, nếu không dọn dẹp khi tiến trình kết thúc, tiến trình mới tái sử dụng lại slot `struct proc` cũ có thể bị ảnh hưởng bởi dữ liệu rác.
  - #emph[Giải pháp];: Sao chép trực tiếp `np->trace_mask = p->trace_mask` trong hàm `fork()`, đồng thời chủ động gán `p->trace_mask = 0` trong cả `allocproc()` và `freeproc()`, đảm bảo tính toàn vẹn và cô lập giữa các tiến trình độc lập.


== Kiểm thử 
<kiểm-thử-testing>
Nhóm tiến hành thực nghiệm trên bộ công cụ kiểm thử tự động `grade-lab-syscall` cùng các kịch bản kiểm tra thủ công.

=== Kịch bản 1: Theo dõi một syscall cụ thể \(`trace 32 grep hello README`)
<kịch-bản-1-theo-dõi-một-syscall-cụ-thể-trace-32-grep-hello-readme>
- #strong[Mục đích];: Kiểm tra khả năng lọc chính xác syscall được chỉ định \(`32 = 1 << 5` tức `SYS_read`). Các syscall khác như `exec`, `open`, `close` không được phép xuất hiện.

- #strong[Kết quả thực tế];:

  ```text
  $ trace 32 grep hello README
  3: syscall read -> 1023
  3: syscall read -> 966
  3: syscall read -> 70
  3: syscall read -> 0
  ```

- #strong[Nhận xét];: Chỉ có syscall `read` được in ra cùng số byte đọc được; khi kết thúc file đọc trả về 0. Đạt yêu cầu.

=== Kịch bản 2: Theo dõi toàn bộ syscall \(`trace 2147483647 grep hello README`)
<kịch-bản-2-theo-dõi-toàn-bộ-syscall-trace-2147483647-grep-hello-readme>
- #strong[Mục đích];: Kiểm tra khả năng theo dõi đồng thời tất cả các syscall khi toàn bộ 31 bit thấp được bật.

- #strong[Kết quả thực tế];:

  ```text
  $ trace 2147483647 grep hello README
  4: syscall trace -> 0
  4: syscall exec -> 3
  4: syscall open -> 3
  4: syscall read -> 1023
  4: syscall read -> 966
  4: syscall read -> 70
  4: syscall read -> 0
  4: syscall close -> 0
  ```

- #strong[Nhận xét];: Log ghi nhận đầy đủ chu trình từ khởi tạo `trace`, nạp chương trình qua `exec`, mở file `open`, đọc dữ liệu `read` đến khi kết thúc bằng `close`.

=== Kịch bản 3: Không kích hoạt theo dõi \(`grep hello README`)
<kịch-bản-3-không-kích-hoạt-theo-dõi-grep-hello-readme>
- #strong[Mục đích];: Đảm bảo hệ thống không in log khi chạy các lệnh thông thường không thông qua `trace`.

- #strong[Kết quả thực tế];:

  ```text
  $ grep hello README
  $
  ```

- #strong[Nhận xét];: Không có bất kỳ dòng log nào xuất hiện, chứng minh tính cô lập hoàn toàn giữa các tiến trình.

=== Kịch bản 4: Kế thừa theo dõi qua các thế hệ tiến trình con \(`trace 2 usertests forkforkfork`)
<kịch-bản-4-kế-thừa-theo-dõi-qua-các-thế-hệ-tiến-trình-con-trace-2-usertests-forkforkfork>
- #strong[Mục đích];: Kiểm tra việc kế thừa qua nhiều cấp `fork()` \(`2 = 1 << 1` tức `SYS_fork`).

- #strong[Kết quả thực tế];:

  ```text
  $ trace 2 usertests forkforkfork
  usertests starting
  test forkforkfork: 407: syscall fork -> 408
  408: syscall fork -> 409
  409: syscall fork -> 410
  410: syscall fork -> 411
  ...
  411: syscall fork -> -1
  OK
  ```

- #strong[Nhận xét];: Tất cả tiến trình con cháu sinh ra đều tự động kế thừa `trace_mask` và in log khi gọi `fork()`. Khi bảng tiến trình đạt giới hạn cực đại, giá trị `-1` được hiển thị chính xác.

=== Kết quả chấm điểm tự động \(`grade-lab-syscall`)
<kết-quả-chấm-điểm-tự-động-grade-lab-syscall>
Toàn bộ testcase trong bộ chấm điểm đều vượt qua:

```text
== Test trace 32 grep == trace 32 grep: OK (1.1s) 
== Test trace close grep == trace close grep: OK (0.6s) 
== Test trace exec + open grep == trace exec + open grep: OK (1.0s) 
== Test trace all grep == trace all grep: OK (1.1s) 
== Test trace nothing == trace nothing: OK (0.8s) 
== Test trace children == trace children: OK (23.0s) 
```



== Kết luận
<kết-luận>
- Nhóm đã hoàn thành việc triển khai system call `trace` trên hệ điều hành xv6-riscv, đáp ứng đầy đủ các tiêu chí kỹ thuật và vượt qua 100% các bài kiểm thử.
- #strong[Kiến thức đúc kết];:
  - Nắm vững chu trình kích hoạt và điều phối của system call từ user space qua lệnh `ecall` vào kernel trap handler.
  - Hiểu rõ cơ chế quản lý dữ liệu tiến trình thông qua `struct proc`, cách kernel duy trì trạng thái khi gọi `exec()` và kế thừa ngữ cảnh khi gọi `fork()`.
  - Thành thạo việc xử lý giá trị trả về, kiểm soát kiểu dữ liệu và định dạng đầu ra an toàn trong môi trường kernel.
