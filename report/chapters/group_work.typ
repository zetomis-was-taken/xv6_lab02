#import "../theme.typ": *
= Phân công công việc và đánh giá <hidden>
#figure(
  kind: table,
  table(
    columns: (auto, auto, 1.5fr, 3fr, auto),
    fill: (col, row) => if row == 0 { title_color } else if calc.odd(row) { rgb("#F4F7FB") } else { none },
    align: (col, row) => if row == 0 { center + horizon } else {
      (center, center, left, left, center).at(col) + horizon
    },
    stroke: 0.6pt + title_color,
    inset: (x: 7pt, y: 10pt),

    table.header(
      [*#text(white)[STT]*],
      [*#text(white)[MSSV]*],
      [*#text(white)[Họ và tên]*],
      [*#text(white)[Nhiệm vụ]*],
      [*#text(white)[Đánh giá]*],
    ),

    [1], [24120135], [Nguyễn Đức Duy Tân], [thực hiện CHỦ ĐỀ 1 — Trace], [100%],
    [2], [24120123], [Võ Hoàng Phúc], [thực hiện CHỦ ĐỀ 2 — Sysinfo], [100%],
    [3], [24120177], [Cáp Hửu Duy], [thực hiện CHỦ ĐỀ 3 — Process Tree], [100%],
  ),
  caption: [Phân công công việc và đánh giá mức độ đóng góp của các thành viên]
) 
