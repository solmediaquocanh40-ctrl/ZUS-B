# ZUS 1.3.3 (gói com.anhdang.zalounseen)

Tweak chích vào Zalo trên máy đã jailbreak: đọc tin nhắn mà bên kia không thấy
"đã xem" — đoạn chat vẫn giữ chữ đậm như chưa đọc — kèm tắt "đang nhập...",
chặn "đã nhận", chống thu hồi, ẩn đã xem Story và bộ công cụ danh bạ riêng.

## Tính năng

- **Chặn "đã xem"**: đọc tin thoải mái, đoạn chat vẫn in đậm, bên kia không
  thấy "đã xem". Trả lời lại thì seen bình thường. Áp dụng mọi người + nhóm.
- **Chặn "đã nhận"** (công tắc riêng, mặc định bật như 1.0.6): bên kia chỉ
  thấy "đã gửi". Lần gọi nào mang cờ đã-xem vẫn bị chặn theo nhóm đã-xem.
- **Tắt "đang nhập..."** khi gõ trong đoạn chat.
- **Chống thu hồi**: tin bị thu hồi vẫn hiện nguyên nội dung trên máy này
  (cả xoá-cho-mọi-người vì cùng đường "undo").
- **Ẩn "đã xem" Story** theo nhóm đã-xem.
- **Tải Story về máy** (mặc định tắt): Zalo tự hiện nút lưu Story của chính nó.
- **Giữ màn hình sáng** khi dùng Zalo (mặc định tắt).
- **Màn chắn riêng tư** (mặc định tắt): phủ mờ Zalo khi thoát ra đa nhiệm,
  ảnh chụp màn hình đa nhiệm không lộ nội dung.
- **Backup danh bạ Zalo**: xuất ZUS-Contacts.json / .csv / .vcf vào thư mục
  Documents của Zalo (tên, mã Zalo, số điện thoại khi Zalo có, avatar).
- **Restore danh bạ**: đối chiếu bản sao lưu với danh bạ hiện tại, liệt kê
  người đã mất, chạm để mở trang Zalo của họ (có số) hoặc chép mã Zalo.
- **Hồ sơ ZUS**: xuất/nhập toàn bộ công tắc ra file ZUS-Profile.json.
- **Cảnh báo khi Zalo đổi phiên bản**: ghi log để đối chiếu lại cửa móc.

## Cài đặt — hai nơi, một kho

- Trong Zalo: **ấn giữ thanh tab dưới đáy** (bất kỳ tab nào, ~0,5 giây) mở
  bảng công tắc + mục Danh bạ & hồ sơ + xem trạng thái dò; nút tròn **ZUS**
  ở màn hình chat vẫn còn làm lối vào dự phòng. (1.1.1)
- **1.3.2 — sửa đường mở bảng + chặn cuộc gọi đúng selector (theo
  ZUS.log 1.3.1)**: (1) log 1.3.1 cho thấy ấn-giữ đã gắn thành công mà
  bảng không hiện, trong khi handler cũ không ghi log khi chạy nên
  không khoanh được bước tịt — bản này gom cả hai đường mở bảng (ấn-giữ
  tab + nút trong chat) về một hàm trình bày chung: ghi log từng bước
  (đã nhận ấn giữ → VC tìm được → đã gọi hiện bảng → bảng xác nhận đã
  nạp giao diện), VC theo responder không dùng được thì dự phòng hiện
  từ VC trên cùng của cửa sổ chính; (2) chặn cuộc gọi móc đúng
  executeActionWithItem:context: — hàm duy nhất của
  RMIncomingAlertAction theo dump của 1.3.1 (selector dài của log ứng
  viên 1.0.3 là của lớp khác) — kèm dump cấu trúc item/context 3 lần
  đầu để trích mã đoạn chat, chặn theo từng người bằng từ điển
  callBlock như thiết kế cũ. 45 cửa chặn cốt lõi giữ nguyên từng dòng.
- **1.3.1 — sửa theo ZUS.log của 1.3.0 (chỉ sửa đúng lỗi log ghi
  nhận)**: sao lưu tin nhắn đọc thẳng bảng ChatContent trong
  chat_dbs/*.db (1.3.0 chọn nhầm bảng chỉ mục tìm kiếm FTS); sao lưu
  cuộc gọi rà tên bảng trên toàn bộ container thay vì 6 file lớn nhất;
  chặn cuộc gọi liệt kê mọi lớp trùng tên RMIncomingAlertAction + dump
  danh sách hàm thật (bản Zalo này lớp đó không có executeAction như
  log ứng viên 1.0.3); xác nhận gọi + dò ảnh gốc + emoji chỉ xét lớp
  thuộc image Zalo (1.3.0 bị lớp hệ thống Apple ngập) và nhận thêm
  dạng móc 4 tham số của makeCall; chặn quảng cáo đi từ cửa sổ chính,
  nhận cả UICollectionView + móc kích thước ô; cảnh báo link tìm lớp
  theo tên cuối (lớp Swift có tiền tố module) + census lớp *Link*;
  kho thu hồi dùng khoá chống trùng đã bỏ phần query ký tên của URL;
  thêm vòng dò đường lật trạng thái thu hồi (census hàm undo/recall +
  thử ép getter undo) — vì log cả ngày cho thấy 4/7 cửa thu hồi chặn
  thật mà bong bóng vẫn lật, 3 cửa còn lại không bao giờ cháy. 45 cửa
  chặn cốt lõi giữ nguyên từng dòng như 1.2.2.
- **1.3.0 — vòng tính năng lớn (15 món anh chốt)**: bảng ZUS giao diện
  mới (thẻ bo góc InsetGrouped, icon cho 4 tab, mục Tổng quan ở đầu tab
  Chặn); lọc nhiễu kho thu hồi (chỉ cất từ ô tin + chống cất trùng —
  bản 1.1.7 từng cất 1.255 mục rác); theo dõi thay đổi bạn bè qua mỗi
  lần sao lưu danh bạ; sao lưu tin nhắn + lịch sử cuộc gọi (đọc kho dữ
  liệu của Zalo ở chế độ chỉ-đọc trên bản sao) và nút Backup toàn bộ
  dữ liệu; ẩn tab Khám phá / Nhật ký dạng công tắc riêng (mặc định
  KHÔNG ẩn); xác nhận trước khi gọi; lưu ảnh đại diện / ảnh bìa của
  đoạn chat; chặn quảng cáo vòng 2 (móc delegate/dataSource thật của
  danh sách chat, thu chiều cao ô quảng cáo về 0); chặn cuộc gọi theo
  từng người — 3 trạng thái Tắt / Im lặng (bên kia vẫn nghe đổ chuông,
  máy mình không hiện) / Máy bận; ấn-giữ tải media ở màn hình Nhật ký;
  gửi ảnh chất lượng gốc, thêm emoji react và cảnh báo link ở mức
  dò + thử (mọi điểm dò đều ghi ZUS.log chi tiết để chốt tiếp theo log
  máy thật). 45 cửa chặn cốt lõi giữ nguyên từng dòng như 1.2.2.
- **1.2.2 — sửa lỗi key hợp lệ bị báo "chưa đúng"**: hàm kiểm tra
  của iOS (SecKeyVerifySignature, thuật toán X962) đòi chữ ký ở dạng
  DER/X9.62 trong khi key lưu dạng raw r||s — 1.2.0–1.2.1 đưa thẳng
  raw vào nên key thật cũng bị từ chối. Nay tweak tự chuyển raw→DER
  trước khi kiểm (đã kiểm chứng với key thật + 50 key ngẫu nhiên);
  toàn bộ key đã phát hành giữ nguyên giá trị, không phải sinh lại.
  Kèm sửa popup kích hoạt bị bàn phím che nửa dưới: bàn phím hiện
  lên thì thẻ popup tự nâng lên đủ tầm nhìn để dán key, hạ xuống
  thì về giữa (anh chụp phát hiện ở 1.2.1).
- **1.2.1 — chuyển sang BẢN DÙNG THẬT (anh chốt)**: bỏ hẳn dùng
  thử 3 ngày của 1.2.0. Chưa nhập key hợp lệ thì KHÔNG chức năng nào
  hoạt động; trang ZUS trong Cài đặt iOS cũng khoá theo (hiện trang
  RootLocked "Chưa kích hoạt" — tweak ghi đệm trạng thái vào file
  chung cho trang Cài đặt đọc). Popup kích hoạt CHỈ hiện
  khi mở bảng ZUS (vào Zalo hoàn toàn bình thường, không popup).
- **1.2.0 — hệ thống bản quyền**: dùng thử 3 ngày từ lần chạy đầu
  (mốc lưu 3 nơi gồm Keychain, chống vặn ngược đồng hồ, gỡ/cài lại
  không reset được). Hết hạn: popup kích hoạt hiện 1 lần mỗi lần mở
  Zalo (nút OK/Huỷ, tự đóng sau 30 giây, tạm dừng đếm khi đang nhập),
  bảng ZUS bị phủ mờ — chỉ các chức năng ZUS tự tắt, Zalo dùng bình
  thường. Key kích hoạt có chữ ký số ECDSA P-256 (key chủ vĩnh viễn,
  key phụ 3 ngày từ lúc kích hoạt, key theo mã máy), xem trạng thái và
  mã máy ở tab Thông tin → Bản quyền.
- **1.1.9 — đổi mô tả gói**: mô tả trong Sileo viết lại đầy đủ, dễ
  hiểu, ghi rõ "Phát triển bởi Anh Đặng" (kèm đổi Author/Maintainer).
  Không đổi tính năng so với 1.1.8.
- **1.1.8 — sửa nút phân đoạn**: nút Chung/Bật/Tắt ở mục cài riêng
  theo đoạn chat bị trắng hoá, không phân biệt được đang chọn nút nào.
  Nay nút đang chọn nhuộm xanh đặc chữ trắng, nút chưa chọn xám nhạt
  chữ đậm màu chữ. Chỉ sửa hiển thị này.
- **1.1.7 — sửa giao diện + tính năng mới**: theme viết lại kiểu
  ZaloZen (xanh chỉ là điểm nhấn, tách màu ô khỏi màu thanh, nhuộm cả
  chữ header/footer); icon Cài đặt thành huy hiệu tròn nhỏ; nút trong
  Zalo hiện đúng logo con mắt (ép nguyên bản, hết bị nhuộm thành chấm
  xanh). Mới: kho tin đã thu hồi; ấn giữ tin trong chat để tải video
  (chọn chất lượng theo link trích được), tải ảnh gốc, dịch tin nhắn;
  dò quảng cáo trong danh sách chat (mức dò — chỉ mặt qua log, chưa
  giấu). Ấn-giữ/dò quảng cáo đều là vòng dò: log ghi bản đồ lớp ô và
  model để hiệu chỉnh vòng sau.
- **1.1.6 — sửa khung bảng ZUS**: thanh tab của bảng bị chui dưới tai
  thỏ/thanh trạng thái trên máy 12 Pro (ghim khung từ y=0). Neo lại theo
  vùng an toàn + tắt tiêu đề lớn của thanh điều hướng. Chỉ sửa khung,
  không đổi tính năng.
- **1.1.5 — bản gộp theo ý anh**: icon Cài đặt thu lại bằng icon khác;
  nút trong chat đổi chữ ZUS thành icon con mắt; sao lưu danh bạ mang
  ngày-giờ, hiện đường dẫn + nút Chia sẻ, khôi phục có danh sách chọn bản;
  bảng ZUS chia 4 tab (Chặn / Dữ liệu / Giao diện / Thông tin) và nhuộm
  màu được (3 bộ sẵn + tự chọn từng phần); chặn theo giờ (mặc định TẮT,
  anh chủ động đặt mới chạy); cài riêng theo đoạn chat (Chung/Bật/Tắt),
  khoá đoạn chat tại chỗ bằng Face ID, nhật ký chặn theo đoạn chat;
  cảnh báo link đáng ngờ (mức dò). Ba món theo đoạn chat dùng chung chìa
  khoá trích mã đoạn chat từ màn hình chat — log sẽ cho biết trúng chưa.
- **1.1.4 — chữa trích xuất danh bạ**: log 1.1.3 cho thấy bắt thực thể +
  cloneFriendList đã chạy (266 bạn, lớp BuddyEntity) nhưng tên trường của
  BuddyEntity là chữ thường (displayname, zaloid, userid, avatarurl,
  contactname, mobile) trong khi danh sách khoá cũ dùng camelCase nên
  trích ra toàn rỗng và sao lưu ghi 0 bạn. Đổi danh sách khoá theo đúng
  dump. Bump version lần này rà đủ cả prefs/Resources/Info.plist và
  workflow trong cây (hai chỗ từng sót ở 1.1.3).
- **1.1.3 — hợp nhất kho cài đặt qua container + danh bạ vòng 3**: trang Cài
  đặt tự tìm file domain trong container của Zalo và đọc/ghi thẳng vào đó
  (hai điểm ghi đè chuẩn của PSListController), soi gương sang kho toàn cục
  và bắn thông báo để tweak nạp lại ngay; phía tweak cũng ưu tiên đọc/ghi
  file ngay trong container của mình (đường /var/mobile bị sandbox chặn —
  log 1.1.2 đã chứng minh). Danh bạ: móc các hàm init của FriendFlowManager
  và MSDataCoordinator để bắt thực thể ngay khi Zalo tạo ra, dump thuộc
  tính của coordinator, thêm các selector trả danh sách mà bản đồ đã lộ
  (copySortedFriendsArray, copyNonBlockedFriendsDictionary...). Bổ sung
  cùng bản: móc riêng đúng kiểu cho cửa seenTime của InboxDataManager —
  cửa duy nhất bị cổng an toàn từ chối ở mọi bản trước vì tham số double,
  nghi phạm của lỗi "đang mở chat, tin mới tới thì bị seen"; chặn khi nhóm
  đã-xem bật và lần gọi mang seenTime > 0, 10 lần gọi đầu ghi lại giá trị
  để đối chiếu.
- **1.1.2 — chữa lỗi hai kho cài đặt**: tweak đọc/ghi thẳng file prefs chung
  `/var/mobile/Library/Preferences/com.anhdang.zalounseen.plist` (đọc file
  trước, ghi cả hai kho) nên gạt trong Zalo và trong Cài đặt của máy từ nay
  là MỘT. Nút ZUS + ấn giữ thanh tab luôn hiện kể cả khi công tắc tổng tắt
  (chúng là lối vào cài đặt) — lỡ tắt ở đâu cũng mở lại ngay tại đó.
- Sao lưu danh bạ vòng 2 (1.1.1): bám thẳng `FriendFlowManager.cloneFriendList`
  — nguồn log 1.1.0 đã chỉ — qua `ChatDataManager.friendFlowManager`.
- Trong Cài đặt của máy: mục **ZUS** (có icon) với cùng các công tắc.
Hai nơi ghi cùng một kho cài đặt, gạt ở đâu là ăn ngay ở đó. Tweak còn nạp
lại cài đặt mỗi khi mở đoạn chat và ghi log mỗi lần cài đặt thay đổi.

## Log

File `ZUS.log` trong Documents của Zalo (Filza → Apps → Zalo → Documents).
Mọi lần chặn, lần đổi cài đặt, mốc nạp và kết quả dò danh bạ đều ghi vào đó.

## Cấu trúc gói

- `tweak/` — dylib ZUS chích vào Zalo (filter vn.com.vng.zingalo), danh sách
  trắng 45 cửa móc cố định (không quét theo mẫu), cổng kiểm tra kiểu dữ liệu
  cho từng cửa, hàm thay thế không giữ tham số (bài học văng 1.0.4).
- `prefs/` — gói Cài đặt ZUSPrefs (chỉ link UIKit + dynamic_lookup).
- `layout/` — mục PreferenceLoader (isController = true, icon ZUSIcon.png).

## Chưa làm (để vòng riêng, theo quy tắc "chưa chắc thì khỏi")

Chỉnh riêng từng hội thoại; khoá đoạn chat bằng Face ID; ẩn trạng thái đang
hoạt động (chưa có cửa); gửi ảnh gốc; tải media hàng loạt; gán nhãn bạn bè;
ẩn avatar/tên/tin cuối và ẩn tab (nhóm giao diện); chặn quảng cáo; chạm 2 lần
sao chép; kho lưu tin nhắn; dịch trong chat; cảnh báo link lạ; lên lịch gửi
tin; ghi âm cuộc gọi; phát nền khi tắt màn hình.
