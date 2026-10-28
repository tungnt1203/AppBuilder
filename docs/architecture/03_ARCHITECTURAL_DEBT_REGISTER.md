# 03 — Architectural Debt Register

Ngày: 2026-10-22. Mỗi dòng có bằng chứng trong mã. Không sửa ứng dụng.

Mức:

| Mức | Nghĩa ở đây |
|---|---|
| P0 | Lỗ bảo mật, tiền hoặc toàn vẹn dữ liệu đã thấy đường khai thác |
| P1 | Chặn vận hành thật hoặc làm sai tiền / đơn khi dùng nhiều shop |
| P2 | Lỗ kiến trúc lớn, luồng chính vẫn chạy |
| P3 | Khó bảo trì hoặc khó scale |
| P4 | Để sau |

Chưa gắn P0. Các đường tenant đã đọc không cho thấy đọc đơn shop khác. Số thẻ không vào app. Đơn Printify lỗi vẫn còn hàng trong `orders`.

| ID | Mức | Hiện trạng | Vấn đề | Bằng chứng | Hệ quả | Hướng xử lý khi được duyệt |
|---|---|---|---|---|---|---|
| D-01 | P1 | VERIFIED | Hoàn Stripe xảy ra trước transaction hủy/refund. Hủy Printify xảy ra sau, và lỗi chỉ được ghi nhận | `Order#cancel!`, `Order#refund!`; `Printify::Fulfillment#cancel!` | Stripe đã hoàn mà DB rollback thì tiền và đơn lệch. Đơn local đã refund mà Printify không hủy thì vẫn có thể bị in | Saga: ghi ý định refund, gọi ngoài, rồi trạng thái. Thất bại Printify phải thành hàng cần người xử lý có trạng thái riêng, không chỉ một cột text |
| D-02 | P1 | VERIFIED | Lưu settings chủ đẩy Stripe, Printify và pixel lên mọi shop user là owner hoặc admin | `Admin::SettingsController#update`, `BusinessSync#apply!` | Cấu hình riêng của một shop bị bộ của chủ ghi đè. Nhiều tài khoản Printify/Stripe theo shop không giữ được | Chọn một nguồn sự thật. Nếu đích là một chủ nhiều tài khoản theo shop, sync chỉ chạy lúc tạo shop |
| D-03 | P1 | VERIFIED | Phí ship Printify không báo được thì checkout lấy giá flat và vẫn tạo đơn | `Checkout#shipping_cents` | Shop có thể thu ship thấp hơn Printify tính | Khi đã có hàng Printify và quote lỗi, từ chối đặt hoặc đánh dấu đơn cần báo giá lại trước khi thu tiền |
| D-04 | P1 | VERIFIED | Thuế không có trong tổng checkout. Thuế cộng lúc tạo PaymentIntent và sửa `total_cents` | `Checkout#total_cents`, `Order#card_payment!` | Khách thấy một tổng, Stripe tính một tổng khác khi shop bật Stripe Tax. Đơn manual không có thuế | Quote phải gồm thuế trước khi khách xác nhận, hoặc tắt hiển thị tổng cuối cho đến khi có tax calculation |
| D-05 | P1 | VERIFIED | Sửa địa chỉ đơn không cập nhật đơn Printify đã gửi | `ShopAdmin::OrdersController#update` | In và giao theo địa chỉ cũ | Khóa địa chỉ sau khi có `printify_order_id`, hoặc gửi cập nhật và ghi kết quả |
| D-06 | P1 | PARTIAL | Production chưa có backup Postgres, SMTP, hay object storage trong repo | `production.rb` mailer host `example.com`, SMTP comment; `active_storage.service = :local`; không có `deploy.yml` | Bật máy thật theo mặc định này: mail sai host, ảnh nằm disk app, mất máy là mất đơn | Việc của phase vận hành. Không đổi kiến trúc ứng dụng trước |
| D-07 | P2 | VERIFIED | `Order` gọi thẳng Printify, Stripe và Meta | `Order#fulfill_later`, `refund_in_stripe`, `report_purchase_later` | Nhà in thứ hai phải sửa model đơn | PORO fulfillment theo cổng. `Order` giữ trạng thái. Làm khi có nhà in thứ hai, không làm trước |
| D-08 | P2 | VERIFIED | Job gửi Printify nuốt lỗi. Không có job quét đơn `paid` mà chưa có `printify_order_id` | `Printify::Fulfillment#submit!`, `Order::FulfillJob`, `Order::TrackShipmentsJob` | Hàng đợi màu xanh trong khi đơn kẹt. Chỉ người mở admin mới thấy `fulfillment_error` | Job thất bại để retry có hạn, rồi để trạng thái kẹt cho người. Track job không thay được submit |
| D-09 | P2 | VERIFIED | Key idempotency chưa có response thì lần gọi lại trong vòng một ngày nhận 409. `Cart::CleanupJob` chỉ xóa key cũ hơn một ngày | `StorefrontApi::Idempotent`, `ApiIdempotencyKey::KEEP_FOR`, `Cart::CleanupJob` | Khách bấm lại trong ngày không đặt được nếu request đầu chết sau khi tạo key | Key chưa có response hết hạn ngắn hơn một ngày, rồi cho chạy lại |
| D-10 | P2 | VERIFIED | Hai cửa tạo shop: admin tạo shop không có storefront; project tự `ensure_shop!` | `Admin::ShopsController#create`, `Project#ensure_shop!` | Shop bán được trong admin nhưng chưa có site, hoặc ngược lại tùy đường người dùng đi | Một luồng: tạo shop kèm project, hoặc tạo project là cách duy nhất mở shop |
| D-11 | P2 | VERIFIED | Hai hệ role: `users.role` (member/admin/owner của builder) và `shop_memberships.role` (owner/admin/staff) | `User`, `ShopMembership` | Admin builder thấy mọi project (`accessible_projects`). Dễ cấp quyền studio rộng hơn quyền shop | Giữ hai hệ vì việc khác nhau, nhưng tài liệu vận hành phải nói rõ. Hạn chế builder admin nếu có nhiều chủ trong tương lai |
| D-12 | P2 | VERIFIED | `find_existing_order` chỉ lật 3 trang khi Printify báo đơn đã tồn tại | `Printify::Fulfillment#find_existing_order` | Đơn cũ hơn 3 trang làm submit lỗi dù Printify đã có đơn. Có thể tạo thêm nếu thông báo lỗi không khớp chữ `already exists` | Tìm theo `external_id` nếu API cho phép. Hết trang thì dừng và báo người, không tạo mù |
| D-13 | P2 | VERIFIED | Đơn Printify hủy bên nhà in không thành `cancelled` và không refund | `Printify::Fulfillment#cancelled_by_printify!` | Shop vẫn coi đơn đang làm. Khách không được hoàn cho đến khi người thấy `fulfillment_error` | Trạng thái vận hành `needs_decision`, hiện trong hàng đợi admin |
| D-14 | P3 | VERIFIED | `Product#sync_variants` trong `after_save` xóa variant không còn trong tổ hợp option | `product.rb` `sync_variants` | Đổi option trên sản phẩm đã có đơn làm `line_items.variant_id` null (`on_delete: :nullify`) | Không xóa variant đã có line item. Đánh dấu không bán |
| D-15 | P3 | VERIFIED | Tìm kiếm `ILIKE` title. Không có `pg_search` như thiết kế | `Product.search` | Đủ cho catalog nhỏ. Chậm và yếu khi catalog lớn | Giữ `ILIKE` đến khi đo được độ chậm |
| D-16 | P3 | VERIFIED | Session cookie permanent, không thấy hạn tuổi session | `Authentication#start_new_session_for` | Máy mất cookie còn đăng nhập | Hạn session và xoay cookie khi vào trang nhạy cảm. Phase bảo mật |
| D-17 | P3 | VERIFIED | CSP đang comment | `content_security_policy.rb` | Studio và admin dễ XSS hơn mức Rails mặc định siết | Bật CSP theo những script đang dùng, sau khi có môi trường thử |
| D-18 | P3 | VERIFIED | Khóa mã hóa cột suy ra từ `secret_key_base` | `active_record_encryption.rb` | Đổi secret làm mù Stripe/Printify token đã lưu | Quy trình xoay khóa ghi trong runbook trước khi production. Không đổi thuật toán lúc này |
| D-19 | P3 | VERIFIED | Blob Active Storage không có `shop_id` | `active_storage_blobs`, `Product` `has_many_attached :images` | Xóa shop phải đi vòng qua attachment (`Shop#purge!`). Cô lập file phụ thuộc chữ ký URL của Rails | Giữ Active Storage. Khi chuyển R2, prefix theo `shop.uid` |
| D-20 | P3 | VERIFIED | Nhiều kiện Printify thành một chuỗi tracking. Phần hàng shop tự gửi không có shipment riêng | `Printify::Fulfillment#ship`, cột trên `orders` | Khách thấy một mã. Theo dõi từng kiện thì thiếu | Bảng shipment khi có nhà in thứ hai hoặc khi đơn hỗn hợp trở thành việc hàng ngày |
| D-21 | P4 | VERIFIED | Bảng `customers` và `password_digest` not null không có luồng đăng ký | `Customer`, `Checkout` không gán customer | Schema hứa tài khoản khách. Sản phẩm dùng order lookup | Để bảng. Không xây login khách cho đến khi có yêu cầu |
| D-22 | P4 | VERIFIED | `retry_on Deadlocked` bị comment | `ApplicationJob` | Deadlock hiếm sẽ fail job thay vì thử lại | Bật lại khi có deadlock thật trong log |
| D-23 | P4 | MISSING | Printful, Gelato, domain riêng, subscription commerce, RLS, Redis | Inventory mục 7 | Không phải nợ của luồng Printify hiện tại | Không xây cho đến khi một shop thật cần |

## Không tính là nợ

- Storefront không database, gọi `/v1`. Đây là ranh giới đúng.
- `acts_as_tenant` với `require_tenant`. Các `without_tenant` production đã đọc đều để phân giải shop.
- Đơn có chữ khách gõ không tự gửi Printify (`needs_personalizing?`). Hành vi đã chọn trong `docs/platform-v1.md`. Nợ chỉ xuất hiện nếu muốn tự vẽ file in.
- Một database shared schema cho một chủ nhiều shop.
- Solid Queue trên Postgres thay Redis.

## Thứ tự nên xử lý

1. D-06 trước khi có khách trả tiền trên máy thật.
2. D-01, D-03, D-04, D-05 trước khi nhiều đơn Printify chạy không có người canh.
3. D-02 trước khi hai shop của cùng chủ dùng hai tài khoản Stripe hoặc Printify.
4. D-07 và D-20 khi có nhà cung cấp thứ hai. Làm sớm hơn sẽ tách lớp chưa có người dùng.
