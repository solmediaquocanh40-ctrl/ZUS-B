# ZUS — Ý tưởng tính năng chờ anh chọn

Ghi lại 2026-11-27 22:28 theo yêu cầu của anh (danh sách em gợi ý sau khi vụ "Đã nhận" khép lại ở 1.4.4). Chưa ý nào được xây — anh chấm ý nào thì đào sâu ý đó trước (dò log/thiết kế).

## Nhóm mở rộng từ nền sẵn có — làm được ngay

1. **Chặn cuộc gọi Zalo từ người lạ** — nâng tính năng chặn cuộc gọi theo từng người thành luật "không có trong danh bạ thì chặn luôn". Nền móc cuộc gọi đã có sẵn.
2. **Thống kê đoạn chat** — trong một đoạn chat: tổng số tin, tỉ lệ anh/họ nhắn, giờ hay nhắn nhất, tin dài nhất... Đọc dữ liệu cục bộ, không đụng máy chủ.
3. **Xuất đoạn chat ra file** — nối tiếp sao lưu tin nhắn: xuất riêng một đoạn chat thành file text/PDF đọc đẹp để lưu trữ/in.
4. **Nhắc trả lời theo đoạn chat** — nút "Nhắc tôi sau 1 giờ / tối nay" trong bảng ZUS của đoạn chat; hạ tầng theo-từng-đoạn-chat đã có.

## Nhóm cần một vòng dò đường mới — giá trị cao

5. **Tự động trả lời tin nhắn** — bật khi bận/ngoài giờ: tự đáp một câu mẫu, mỗi đoạn chat chỉ đáp 1 lần trong 30 phút. Cần dò đường GỬI tin (trước giờ toàn dò đường chặn).
6. **Lên lịch gửi tin** — soạn trước, hẹn giờ gửi. Dùng chung nền đường gửi với ý 5.
7. **Xem Khoảnh khắc (story) không để lại tên** — chặn báo cáo xem story, đúng họ hàng với "đọc không seen". Cần dò cửa báo cáo của story.
8. **Gửi ảnh/video giữ nguyên chất lượng gốc** — Zalo nén ảnh khi gửi; ép gửi nguyên bản. Cần dò đường gửi ảnh.
