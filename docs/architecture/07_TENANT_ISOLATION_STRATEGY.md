# 07 — Tenant Isolation Strategy

Ngày: 2026-10-22. Cách cô lập đang chạy, chỗ còn hở, và quy tắc cho mã mới. Không sửa ứng dụng trong phase này.

Tenant là shop. Chi tiết cây sở hữu nằm ở `06`.

---

## 1. Lớp đang chặn

`ActsAsTenant` bật `require_tenant`. Model có `acts_as_tenant :shop` mà query khi không có current shop thì lỗi, thay vì trả mọi shop.

Đã có test đi theo hướng này: trong tenant shop cats, tìm id key của shop dogs thì `RecordNotFound` (`builder/test/models/shop_test.rb`). Đó là bằng chứng ý định, không phải bằng chứng đã rà hết query.

Foreign key `shop_id` có trên các bảng commerce đã liệt kê trong `04`. Unique của slug, mã giảm giá, email khách, số đơn đều kèm `shop_id`. Xóa shop có đơn bị `purge!` chặn trước khi đụng hàng.

---

## 2. Ba cửa và điều không được tin

| Nguồn | Được dùng để | Không được dùng để |
|---|---|---|
| Cookie session | Biết user nào | Chọn shop nếu user không có membership |
| Subdomain trên URL admin | Tìm membership của chính user đó | Đọc shop khi không có membership |
| Bearer shop key | Chọn shop của key chưa revoke | Nhận `shop_id` trong body |
| `cart_token`, `order` token | Tìm giỏ hoặc đơn **trong tenant đã chọn** | Nhảy shop. Token unique toàn cục nhưng query nằm sau khi đã set tenant |
| `shops.uid` trên webhook | Chọn shop | Bỏ qua chữ ký |
| `shop_id` trong job | Bọc `with_tenant` | Do client gửi |

`POST /v1/checkouts` tìm giỏ bằng `Cart.find_by!(token:)` sau khi key đã chọn shop. Token của shop khác không thấy trong tenant này. **VERIFIED** (`checkouts_controller.rb`, default scope tenant).

Webhook Stripe tìm đơn theo PaymentIntent trong tenant, hoặc theo id đơn chỉ khi metadata `shop` bằng `store.uid`. Id đơn lặp giữa các shop nên không đủ để chọn. **VERIFIED** (`Webhooks::StripeController#order_for`).

Order lookup giải token rồi so `shop_id` với tenant hiện tại. Token của shop khác trả nil. **VERIFIED** (`OrderLookup.from_token`).

---

## 3. Job

`ApplicationJob#serialize` ghi `shop_id` từ tenant lúc enqueue. `perform_now` tải shop bằng `without_tenant` rồi chạy `super` trong `with_tenant`. Job deserialize `Order` bên trong tenant đó, nên không đọc đơn shop khác.

Job không có `shop_id` phải tự lặp `Shop.each_in_turn`. `Cart::CleanupJob`, `Order::TrackShipmentsJob`, `Promotion::SyncJob` làm vậy. Xóa giỏ và key idempotency nằm trong vòng đó, nên `delete_all` chịu default scope của shop đang chạy.

`update_all` trên `Variant` và `Discount` lọc theo `id` của bản ghi đã load trong tenant. `update_all` không bỏ default scope của `acts_as_tenant` khi gọi từ relation `where(id:)`. Bản ghi đó đã thuộc shop hiện tại.

Quy tắc cho job mới: hoặc enqueue khi đang có tenant, hoặc gọi `each_in_turn` ở dòng đầu của `perform`. Không query model tenant ở ngoài cả hai.

---

## 4. Cache

Cache Platform là Solid Cache, namespace theo `Rails.env`, không theo shop (`config/cache.yml`).

Quote ship Printify dùng key gồm `printify_shop_id`, phương thức ship, line item và địa chỉ (`Printify::ShippingQuote`). Không có `shops.id`. Hai shop platform chung một shop Printify sẽ dùng chung một dòng cache. Cùng hàng và cùng địa chỉ thì cùng giá Printify, nên không lộ đơn. Không được nhét tên khách, email hay token vào cache key kiểu này.

Rate limit API lấy theo `api_key.id`. Id key unique toàn platform, nên hai shop không dùng chung ô đếm.

Cache storefront là file trên đĩa của container đó (`storefront` production: `file_store` tại `storage/cache`). Key HTTP là `storefront_kit/` + path, không có shop id (`StorefrontKit::Client#get`). An toàn vì một process storefront một `SHOP_KEY`. Không được trỏ hai shop vào cùng thư mục cache đó.

---

## 5. File

Ảnh product và theme là Active Storage. Bảng blob không có `shop_id`. File production đang cấu hình disk local (`production.rb`).

Cô lập hiện tại là cô lập qua record cha: đọc ảnh của product trong tenant thì chỉ thấy product của shop. `Shop#purge!` xóa attachment của product và theme setting theo `shop_id` trước khi xóa hàng.

URL blob ký bởi Rails không kiểm tra membership lần nữa. Ai có URL thì lấy file. URL không đoán được nếu chữ ký còn nguyên. Đây chưa phải lỗ đã chứng minh. Khi chuyển R2, prefix đường dẫn theo `shop.uid` để xóa và backup theo shop.

Không có bucket riêng mỗi shop. Chưa cần.

---

## 6. Tìm kiếm

`Product.search` và `Order.search` là `ILIKE` trên relation đã có default scope tenant. Admin và API đều set tenant trước khi search. Không có engine tìm kiếm dùng index chung.

Đừng thêm search engine với document không có `shop_id`.

---

## 7. Webhook và thư

Webhook một URL mỗi shop, secret trên `Store` của shop đó. Sai chữ ký thì 400 hoặc 401, không đổi đơn. Event lạ ghi `ignored` trong shop nhận webhook, không sang shop khác.

Mail đơn dùng địa chỉ storefront của `order.shop` (`Order#storefront_url`). Không có hàng đợi mail riêng theo shop. Mailer production chưa cấu hình SMTP (nợ D-06), không phải lỗ chéo tenant.

---

## 8. Admin và người vận hành

| Vai | Thấy dữ liệu shop |
|---|---|
| Staff, admin, owner của shop | Đúng các shop có membership |
| User không có membership | 404 ở admin shop |
| Builder admin | Mọi project studio. Đơn chỉ khi họ cũng có membership, trừ khi một màn studio đọc đơn mà phase này chưa thấy |
| Dashboard `/admin` | Chỉ shop của `Current.user`, từng tenant một |

`OrdersSummary` map đơn ra hash có token đơn và tên người nhận, trong tenant. Không gộp query `Order` không tenant.

---

## 9. Chỗ chưa cô lập bằng database

RLS **MISSING**. Mọi chặn đều ở Rails. `without_tenant` là cửa thoát. Các chỗ production đã đọc dùng nó để tìm shop hoặc xóa đúng một `shop_id`, rồi vào lại tenant. Một chỗ mới bọc `without_tenant` quanh `Order.all` sẽ đọc mọi shop và không có policy Postgres nào cản.

`BusinessSync` ghi secret của chủ lên `Store` của mọi shop user đó admin. Không đọc shop của người khác. Nó phá cấu hình riêng trong các shop của cùng một người. Nợ D-02.

Blob không mang `shop_id`. Cô lập file yếu hơn cô lập hàng.

---

## 10. Quy tắc cho mã mới

1. Model có dữ liệu của một shop thì `acts_as_tenant :shop`, `shop_id` not null, foreign key tới `shops`.
2. Unique của dữ liệu shop phải kèm `shop_id`, trừ token bí mật cố ý unique toàn cục (`orders.token`, `carts.token`, digest API key, `stripe_payment_intent_id`).
3. Controller không gọi `set_current_tenant` từ param `shop_id` số. Admin dùng membership. API dùng key. Webhook dùng `uid` và chữ ký.
4. Job đụng model tenant thì mang `shop_id` hoặc `each_in_turn`.
5. Cache dùng chung trên Platform thì key có `shop.id` hoặc một id đã unique toàn cục. Không cache body đơn bằng key chỉ là số đơn.
6. Storefront giữ cache trong container của nó.
7. `without_tenant` chỉ để phân giải shop, kiểm tra trùng subdomain, hoặc xóa theo `shop_id` trong `purge!`. Không trả collection commerce ra khỏi block đó.
8. RLS để sau, khi role database của app không bypass policy và bộ test hai shop đã phủ các cửa trên.

Chưa cần schema riêng, database riêng, hay Redis để cô lập.
