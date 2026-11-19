# Hứng quà 10 năm · Lotus Hospitality

Minigame hứng logo kỷ niệm 10 năm Lotus Hospitality. Mở đầu bằng lời chúc mừng sinh nhật của Ban Giải pháp Công nghệ Tập đoàn.

- Logo thương hiệu (Tiktak, Kite, Flexi, Diamond Time, Sứ Retreat, Sứ Memoir) +10, logo Lotus 10 năm +30.
- Bánh kem sinh nhật: x2 điểm trong 8 giây.
- Mây giông −20 và mất x2, đồng hồ +5 giây.

Chơi: https://vngroup23.github.io/lotus-hung-qua-10-nam/

`Lotus-Hung-qua-10-nam-demo.html` là bản 1 file đã nhúng sẵn ảnh, mở trực tiếp không cần mạng nội bộ.

## Xếp hạng và giải thưởng

Giống game Kahoot: mỗi người tính lượt có điểm cao nhất (3 lượt mỗi số điện thoại), Top 5 nhận quà. Bảng xếp hạng hiện toàn bộ người chơi và làm nổi bật Top 5.

Điểm lưu trên Supabase (cùng dự án với game Kahoot). Schema ở `supabase/schema.sql`, áp bằng
`node ../../../Game/scripts/db.mjs apply supabase/schema.sql`. Nếu chạy lại schema của game Kahoot thì phải áp lại file này.

- BTC: `#admin`, đăng nhập bằng mã quản trị của game Kahoot. Có danh sách đầy đủ kèm SĐT, nút đóng/mở game, xoá người gian lận và tải CSV.
- Chạy thử không cần máy chủ: thêm `?mock=1` vào link (mã BTC giả lập: `test`).
