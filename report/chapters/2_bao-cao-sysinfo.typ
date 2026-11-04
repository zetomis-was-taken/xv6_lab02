= Sysinfo

== Mô tả bài toán

=== Yêu cầu

Bổ sung system call `sysinfo` nhận con trỏ đến `struct sysinfo`, cung cấp số byte bộ nhớ trống (`freemem`) và số tiến trình có trạng thái khác `UNUSED` (`nproc`).

=== Input
- Con trỏ đến biến `struct sysinfo` chứa địa chỉ bộ nhớ ảo trong không gian địa chỉ của tiến trình user.
- Gọi system call `sysinfotest()` để kiểm tra kết quả:

  ```bash
  sysinfotest
  ```

=== Output
- Trả về `0` nếu thành công
- Trả về `-1` nếu có lỗi xảy ra (ví dụ: người dùng truyền vào một con trỏ không hợp lệ, con trỏ NULL, hoặc địa chỉ nằm ngoài phạm vi bộ nhớ được cấp phát khiến hàm copyout thất bại).
Cuối cùng, thông báo `sysinfotest: OK` được in ra nếu tất cả các kiểm thử đều thành công.

== Thiết kế giải pháp

=== Kết nối system call từ user đến kernel

Chương trình user chuẩn bị một biến `struct sysinfo` và truyền địa chỉ của biến đó cho `sysinfo()`. Cấu trúc được định nghĩa trong `kernel/sysinfo.h`, gồm hai trường kiểu `uint64`, giúp phía user và kernel có chung cách bố trí dữ liệu. Trong `user/user.h`, khai báo trước tên cấu trúc và nguyên mẫu hàm để chương trình user có thể gọi syscall.

- *Khó khăn* : Nếu có mã stub ở user nhưng quên ánh xạ SYS_sysinfo vào mảng syscalls[] trong kernel/syscall.c: Khi chương trình chạy và gọi sysinfo(), lệnh ecall vẫn nhảy vào hàm syscall() của kernel, nhưng kernel tra bảng thấy con trỏ hàm tại vị trí SYS_sysinfo bị NULL. Khi đó, kernel sẽ in thông báo lỗi unknown sys call và gán giá trị trả về là -1 vào thanh ghi a0.

- *Giải pháp* : Bổ sung mục `sysinfo` trong `user/usys.pl` để sinh đoạn mã chuyển lời gọi vào kernel bằng lệnh `ecall`. Ở phía kernel, gán số hiệu `SYS_sysinfo` trong `kernel/syscall.h` và ánh xạ số hiệu này tới hàm `sys_sysinfo()` trong bảng syscall của `kernel/syscall.c`. Nhờ đó, kernel xác định đúng hàm xử lý khi chương trình user gọi `sysinfo()`.

=== Thống kê bộ nhớ trống

Trong `kernel/kalloc.c`, bộ cấp phát quản lý các trang vật lý còn trống bằng danh sách liên kết `kmem.freelist`. Mỗi phần tử tương ứng với một trang có kích thước `PGSIZE`. Hàm `freemem_size()` duyệt từ đầu đến hết danh sách, đếm số phần tử rồi nhân với `PGSIZE` để nhận số byte bộ nhớ trống.

- *Khó khăn* :Trong xv6, cấu trúc struct run (chứa con trỏ next) không nằm ở vùng nhớ riêng mà được lưu trực tiếp ngay đầu trang vật lý đang trống đó. Khi hệ thống chạy trên nhiều nhân CPU : một CPU đang duyệt danh sách kmem.freelist để đếm, trong khi một CPU khác gọi kalloc() hoặc kfree() và thay đổi cấu trúc danh sách cùng lúc. Con trỏ lúc này mang một địa chỉ bất kỳ không hợp lệ , dẫn đến lỗi truy cập bộ nhớ (Page Fault / Load access fault) ở vòng lặp kế tiếp và làm sập kernel.

- *Giải pháp* Thêm Hàm giữ khóa `kmem.lock` trong toàn bộ thời gian duyệt. Khóa ngăn thao tác cấp phát hoặc trả trang làm thay đổi danh sách khi đang đếm, tránh đọc danh sách không nhất quán. Sau khi đếm xong, hàm nhả khóa và trả kết quả.

=== Thống kê số tiến trình

Trong `kernel/proc.c`, hàm `nproc_count()` duyệt toàn bộ `NPROC` mục của bảng tiến trình. Với mỗi mục, hàm lấy khóa `p->lock`, kiểm tra trạng thái và tăng bộ đếm nếu trạng thái khác `UNUSED`, sau đó nhả khóa trước khi chuyển sang mục tiếp theo. Khóa bảo vệ việc đọc trạng thái trước các thay đổi đồng thời của kernel.

Điều kiện này tính cả tiến trình RUNNABLE, RUNNING, SLEEPING và ZOMBIE. Vì vậy, số tiến trình chỉ trở về mức ban đầu sau khi tiến trình cha thực hiện `wait()` và mục của tiến trình con được chuyển về `UNUSED`.

=== Trả kết quả về user space

Hàm `sys_sysinfo()` dùng `argaddr()` lấy địa chỉ ảo được truyền qua đối số đầu tiên, rồi gọi hai hàm thống kê để điền vào một biến `struct sysinfo` cục bộ trong kernel. Việc lấy địa chỉ đối số chưa có nghĩa địa chỉ đó hợp lệ để ghi dữ liệu.


- *Khó khăn* : Nếu kernel dùng con trỏ trực tiếp đến biến cục bộ trong hàm `sys_sysinfo()` để trả kết quả, chương trình user sẽ nhận được dữ liệu không hợp lệ. Khi tiến trình user gọi `sysinfo()`, kernel chuyển sang chế độ supervisor và dùng bảng trang của tiến trình đó. Nếu kernel ghi dữ liệu vào địa chỉ cục bộ trong kernel space, địa chỉ đó không nằm trong không gian địa chỉ của tiến trình user, dẫn đến lỗi truy cập bộ nhớ (Page Fault / Store access fault) khi tiến trình user đọc kết quả.

- *Giải pháp* : Kernel tạo một biến cục bộ trong hàm `sys_sysinfo()` để lưu kết quả, sau đó dùng `copyout()` để chép dữ liệu đến địa chỉ user space được truyền vào. Nếu `copyout()` thất bại, syscall trả về `-1`; nếu sao chép thành công, syscall trả về `0` và chương trình user đọc kết quả từ biến đã truyền vào.

=== Xây dựng chương trình kiểm thử sysinfotest

Mục tiêu  của sysinfotest là kiểm tra xem kernel có thu thập chính xác dung lượng bộ nhớ vật lý trống và số lượng tiến trình đang hoạt động hay không, đồng thời đánh giá tính an toàn khi sao chép dữ liệu từ kernel space sang user space.
Thông qua ba giai đoạn kiểm thử: 

+ Kiểm tra xử lý đối số con trỏ không hợp lệ:
  - *Quy trình* : Chương trình cố tình truyền một địa chỉ bộ nhớ ảo không hợp lệ (địa chỉ lớn nhất có thể biểu diễn của kiểu số nguyên 64-bit không dấu) vào system call `sysinfo`
  - *Ý nghĩa*: Đảm bảo hàm sao chép dữ liệu từ kernel sang user trong `sys_sysinfo` để kiểm tra chặt chẽ quyền truy cập bộ nhớ và xử lý ngoại lệ an toàn.

+ Kiểm tra bộ nhớ khi cấp phát:
  - *Quy trình* : Sử dụng sbrk để cấp phát thêm một trang bộ nhớ (4096 byte), sau đó kiểm tra freemem có giảm đúng 4096 byte hay không.
  - *Ý nghĩa* : Kiểm thử xác minh rằng system call `sysinfo` phản ánh chính xác sự thay đổi dung lượng bộ nhớ vật lý khi tiến trình yêu cầu cấp phát thêm bộ nhớ.

+ Kiểm tra bộ nhớ khi giải phóng
  - *Quy trình* : Sử dụng sbrk để giải phóng một trang bộ nhớ, kiểm tra freemem có trở về giá trị trước khi cấp phát hay không.
  - *Ý nghĩa* : Kiểm thử xác minh rằng bộ nhớ vật lý được thu hồi sau khi thu nhỏ heap và thông tin do sysinfo cung cấp phản ánh chính xác quá trình giải phóng bộ nhớ.

+  Kiểm tra số lượng tiến trình khi sử dụng fork
  - *Quy trình* : Sử dụng fork để tạo tiến trình con, đồng bộ bằng pipe và kiểm tra nproc có tăng thêm 1 hay không.
    
  - *Ý nghĩa* : Kiểm thử xác minh rằng system call sysinfo có thể ghi nhận chính xác sự gia tăng số lượng tiến trình sau khi hệ thống tạo một tiến trình mới.

+  Kiểm tra số lượng tiến trình sau khi kết thúc
  - *Quy trình* : Cho tiến trình con kết thúc và sử dụng wait để thu hồi, kiểm tra nproc có trở về giá trị ban đầu hay không.
  - *Ý nghĩa* : Kiểm thử xác minh rằng system call sysinfo phản ánh đúng trạng thái bảng tiến trình sau khi tiến trình con được thu hồi, không tiếp tục tính tiến trình đã được giải phóng.

+  Kiểm tra thu hồi bộ nhớ sau khi tiến trình con kết thúc
  - *Quy trình* : Sau khi tiến trình con được thu hồi, kiểm tra freemem có trở về giá trị trước khi thực hiện fork hay không.
  - *Ý nghĩa* : Kiểm thử xác minh rằng các trang bộ nhớ vật lý được cấp phát phục vụ tiến trình con được thu hồi sau khi tiến trình kết thúc, đồng thời system call sysinfo phản ánh chính xác trạng thái bộ nhớ sau quá trình thu hồi.


== Kiểm thử và kết quả

Chạy `sysinfotest` bằng `make qemu`. Chương trình kiểm tra:

- Trả về lỗi khi nhận con trỏ không hợp lệ.
- Bộ nhớ trống giảm một trang khi cấp phát và được khôi phục khi giải phóng.
- Số tiến trình tăng sau `fork()` và trở về ban đầu sau `wait()`.
- Bộ nhớ của tiến trình con được thu hồi sau khi kết thúc và được chờ.

Kết quả: *`sysinfotest: OK`*.

#figure(
  image("../images/result.png", width: 80%),
  caption: [Output của chương trình sysinfotest],
  placement: none,
  kind: image,
) <fig-example>

== Kết luận
Bài thực hành đã hoàn thành việc thiết kế và cài đặt tính năng Sysinfo trên hệ điều hành xv6-riscv. System call `sysinfo` cung cấp thông tin về bộ nhớ trống và số lượng tiến trình đang hoạt động, đồng thời đảm bảo an toàn khi sao chép dữ liệu từ kernel space sang user space. Chương trình kiểm thử `sysinfotest` đã xác minh tính chính xác và độ tin cậy của hệ thống, bao gồm xử lý đối số không hợp lệ, quản lý bộ nhớ khi cấp phát và giải phóng, cũng như theo dõi số lượng tiến trình qua các thao tác `fork()` và `wait()`. Kết quả kiểm thử thành công chứng minh rằng hệ thống hoạt động đúng như mong đợi.
