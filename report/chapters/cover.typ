#let info-title(body) = text(weight: "semibold", 12pt, body)

// Áp dụng viền từ ảnh border.png
#place(top + left, dx: -1.5cm, dy: -1.5cm)[
  #image("../images/border.png", width: 100% + 3cm, height: 100% + 3cm, fit: "stretch")
]

// first page
#align(center)[
  #v(0.5cm)
  #text(16pt, weight: "bold")[ĐẠI HỌC QUỐC GIA THÀNH PHỐ HỒ CHÍ MINH \
  TRƯỜNG ĐẠI HỌC KHOA HỌC TỰ NHIÊN]
  #v(0.3cm)
  #text(14pt, weight: "bold")[KHOA CÔNG NGHỆ THÔNG TIN]
  #v(1.0cm)
  #image("../images/logo.png", width: 32%)
  #v(30pt)
  #text(24pt, weight: "bold", fill: rgb("#1E3778"))[BÁO CÁO]
  #v(0.18cm)
  #text(18pt, weight: "bold")[LAB 2 - SYSTEM CALL] 
  \

  #v(0.4cm)
  #align(center)[
    #set text(13pt)
    #grid(
      columns: (auto, auto),
      column-gutter: 0.3cm,
      row-gutter: 0.2cm,
      align: (left, left),
      [*Học phần:*], [Hệ diều hành ],
      [*Lớp:*], [CQ2024/22],
    )
  ]
  #v(0.9cm)
]

#align(center)[
  #block(width: 86%)[
    #line(length: 100%, stroke: 0.6pt + luma(160))
    #v(0.5cm)

    #grid(
      columns: (1.25fr, 1fr),
      column-gutter: 1.2cm,

      [
        #align(left)[
          #info-title[Thành viên thực hiện]
          #v(0.15cm)
          #table(
            columns: (1fr, auto),
            stroke: (x, y) => if x == 1 { (left: 0.8pt + rgb("#1E3778")) } else { none },
            align: (left, right),
            inset: (col, row) => (
              left: if col == 0 { 0pt } else { 10pt },
              right: 8pt,
              y: 4.5pt,
            ),
            [Võ Hoàng Phúc], [24120123],
            [Nguyễn Đức Duy Tân], [24120135],
            [Cáp Hửu Duy], [24120177]
          )
        ]
      ],

      [
        #align(left)[
          #info-title[Giảng viên hướng dẫn]
          #v(0.15cm)
          #table(
            columns: (auto,),
            stroke: none,
            inset: (left: 0pt, right: 0pt, y: 4.5pt),
            [ThS. Lê Viết Long],
            [ThS. Phạm Tuấn Sơn],
          )
        ]
      ],
    )
  ]
]

#place(bottom + center)[
  #text(11pt)[Thành phố Hồ Chí Minh, ngày 5 tháng 11 năm 2026]
  #v(0.5cm)
]
