# Hứng quà 10 năm · Lotus Hospitality

Minigame hứng logo kỷ niệm 10 năm thành lập Lotus Hospitality. Mở đầu bằng lời chúc mừng sinh nhật của Ban Giải pháp Công nghệ Tập đoàn.

- Logo thương hiệu (Tiktak, Kite, Flexi, Diamond Time, Sứ Retreat, Sứ Memoir) +10, logo Lotus 10 năm +30.
- Bánh kem sinh nhật: x2 điểm trong 8 giây.
- Mây giông −20 và mất x2. Không có cộng giờ.

Chơi: https://vngroup23.github.io/lotus-hung-qua-10-nam/

`Lotus-Hung-qua-10-nam-demo.html` là bản 1 file đã nhúng sẵn ảnh, mở trực tiếp không cần mạng nội bộ.

## Xếp hạng và giải thưởng

Giống game Kahoot: người chơi đăng ký vào phòng chờ, BTC bấm "Bắt đầu" ở `#admin`, mọi điện thoại đếm ngược 10 giây rồi cả phòng chơi chung 45 giây theo giờ máy chủ và hết giờ cùng lúc. Mỗi số điện thoại 1 lượt. Hết giờ hiện bảng xếp hạng toàn bộ người chơi, Top 5 được làm nổi bật và nhận quà. Nút "Vòng mới" xoá điểm để chơi lại (dùng khi chơi thử).

Điểm lưu trên Supabase (cùng dự án với game Kahoot). Schema ở `supabase/schema.sql`, áp bằng
`node ../../../Game/scripts/db.mjs apply supabase/schema.sql`. Nếu chạy lại schema của game Kahoot thì phải áp lại file này.

- BTC: `#admin`, đăng nhập bằng mã quản trị của game Kahoot. Có nút Bắt đầu / Vòng mới, danh sách đầy đủ kèm SĐT, xoá người gian lận và tải CSV.
- Chạy thử không cần máy chủ: thêm `?mock=1` vào link (mã BTC giả lập: `test`).
