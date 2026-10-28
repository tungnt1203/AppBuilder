# 11 — POD Provider Adapter Contract

Ngày: 2026-10-22. Hợp đồng cho mã sau này. Chưa có class này trong repo. Printify là adapter duy nhất sẽ được bọc, và chỉ khi có quyết định sửa mã.

Mục tiêu: `Order` và `Checkout` không đọc JSON Printify. Chúng nói với một kết quả đã chuẩn hóa hoặc một lỗi có loại.

---

## 1. Kết nối

Một shop có nhiều kết nối sau này. Hôm nay mỗi shop một kết nối, các cột Printify trên `stores`.

Hợp đồng không bắt adapter lưu token. `Store` giữ token đã mã hóa và đưa vào adapter lúc gọi. Adapter không ghi token ra log.

```text
Connection
  provider          "printify" hôm nay
  account_label     printify_shop_title
  external_shop_id  printify_shop_id
  capabilities      tập ở mục 4
```

`connect(token)` trả danh sách shop của tài khoản hoặc lỗi xác thực. `disconnect` gỡ webhook do platform đã đăng ký, rồi xóa secret. `Store#disconnect_printify!` đã làm việc này cho Printify.

---

## 2. Việc adapter phải trả lời

Mỗi method trả kết quả chuẩn hoặc raise lỗi thuộc loại ở mục 6. Method nào capability không có thì không được gọi. Gọi nhầm là lỗi lập trình, không phải lỗi nhà in.

| Method | Việc | Printify hôm nay |
|---|---|---|
| `list_shops` | Shop trong tài khoản | `PrintifyGateway#shops` |
| `list_products(page)` | Sản phẩm đã có bên nhà in | `Printify::Import#list` |
| `fetch_product(id)` | Chi tiết để nhập | `PrintifyGateway#product` |
| `quote_shipping(lines, address, method)` | Tiền ship tính cho shop, đơn vị cent | `shipping_costs` |
| `submit_order(order)` | Tạo đơn nhà in, trả id | `create_order` rồi có thể `send_to_production` |
| `find_submitted(external_id)` | Tìm đơn đã tạo khi mạng đứt sau lúc nhà in nhận | `find_existing_order`, đang giới hạn 3 trang |
| `fetch_order(id)` | Trạng thái, kiện, chi phí | `PrintifyGateway#order` |
| `cancel_order(id)` | Hủy nếu nhà in còn cho phép | `cancel_order` |
| `verify_webhook(body, headers)` | Đúng chữ ký hay không | `valid_signature?` |
| `register_webhooks(url)` | Đăng ký và trả secret đã lưu | `Store#register_printify_webhooks!` |

Không có trong hợp đồng bắt buộc: `upload_artwork`, `create_blank_product`, `generate_mockup`. Printify adapter khai báo là không hỗ trợ. Catalog áo trắng và file in là việc của một provider có capability đó, không phải của `Order`.

---

## 3. Dữ liệu đi qua biên

### Hàng nhập về catalog

Adapter trả cấu trúc trung gian. `Printify::Import` là chỗ duy nhất được hiểu `options`, `is_enabled`, `images`. Catalog nhận:

```text
ImportedProduct
  external_id
  title
  description_plain
  options[]          tên, giá trị, mã màu nếu có
  variants[]         external_variant_id, option values, price_cents, cost_cents, offered
  images[]           url, option value nó minh họa
```

Giá và cost là cent của shop. Import Printify đang coi `price` và `cost` trong JSON là cent. **VERIFIED** vì cột local là `price_cents` và `cost_cents`, gán thẳng từ JSON.

Lần cập nhật giữ title, mô tả và giá bán chủ đã sửa. Adapter không quyết định điều đó. `Import` quyết định.

### Báo giá ship

Vào: các dòng `{ external_product_id, external_variant_id, quantity }`, địa chỉ đã chuẩn hóa vùng, mã phương thức shop đã chọn.

Ra: một số cent, hoặc “không báo được”. Không báo được không phải số 0. Checkout hôm nay đang đổi “không báo được” thành giá flat. Hợp đồng cấm adapter trả 0 trong ca đó.

### Gửi đơn

Vào:

```text
SubmitRequest
  external_id          uid shop + số đơn, unique trong shop nhà in
  lines[]              external ids và quantity
  ship_to              tên, email, phone, địa chỉ
  shipping_method      mã đã lưu trên kết nối
  send_to_production   cờ của shop
```

Ra: `provider_order_id`.

`properties` chữ khách gõ không nằm trong request này. Commerce phải tách đơn “cần người” trước khi gọi `submit_order`. Hành vi đó ở `Fulfillment#needs_personalizing?`, giữ nguyên.

### Trạng thái kéo về

```text
ProviderOrder
  id
  phase                held, printing, shipped, delivered, cancelled, needs_attention
  shipments[]          carrier, number, url, delivered_at
  cost_cents           nil nếu nhà in chưa có số
  attention_reason     có khi phase là needs_attention hoặc cancelled
```

Map từ Printify, làm trong adapter Printify chứ không trong `Order`:

| JSON Printify | phase |
|---|---|
| on-hold, trước send_to_production | `held` |
| sending-to-production, in-production, partially-fulfilled | `printing` |
| fulfilled và đã có shipment | `shipped` |
| mọi shipment có delivered_at | `delivered` |
| canceled | `cancelled` |
| has-issues, unfulfillable, payment-not-received | `needs_attention` |

Commerce áp phase lên `Order` theo bảng trong `10` mục 5. Đơn có cả hàng tự gửi không nhảy `shipped` chỉ vì phase là `shipped`. Đó là luật commerce, không phải luật adapter.

---

## 4. Capability

| Capability | Printify trong mã | Nếu không có |
|---|---|---|
| `connect` | Có | Không nối được |
| `import_existing_product` | Có | Không có màn nhập |
| `upload_artwork` | Không | Ẩn nút upload |
| `create_product` | Không | Chủ tạo hàng bên nhà in |
| `quote_shipping` | Có | Checkout không được bịa giá ship của nhà in |
| `submit_order` | Có | |
| `send_to_production` | Có, cờ trên store | Đơn ở `held` đến khi nhà in hoặc người đẩy |
| `cancel_order` | Có, nhà in từ chối khi đã in | Commerce ghi needs_attention, không giả định đã hủy |
| `fetch_order` | Có | |
| `webhooks` | Có, ba topic | Job giờ vẫn chạy như `TrackShipmentsJob` |
| `buyer_text` | Không | Đơn có chữ không gọi `submit_order` |

Provider mới thêm một hàng vào bảng này trước khi có nút trên admin. Thiếu capability thì ẩn việc, không trả lỗi lúc khách đã trả tiền.

---

## 5. Idempotency và thử lại

`external_id` là khóa idempotency với nhà in. Gửi lại cùng id phải trả đơn đã có, không tạo đơn thứ hai.

Adapter Printify hôm nay dựa vào thông báo lỗi khớp `/already exists/i` rồi tìm ba trang. Hợp đồng yêu cầu: nếu nhà in không có API tìm theo `external_id`, adapter nói rõ là tìm không hết, và không tạo đơn mới khi chưa chắc.

Lỗi mạng và HTTP 429 thuộc loại `temporary`. Job được phép thử lại có trần. Lỗi 401 thuộc loại `authentication` và không thử lại. Lỗi validation địa chỉ thuộc loại `rejected` và để người sửa.

`Order::FulfillJob` hiện không thấy lỗi vì `submit!` nuốt exception. Khi bọc adapter, lỗi `temporary` phải làm job thất bại để Solid Queue thử lại. Lỗi `rejected` ghi `fulfillment_error` và kết thúc job. Trùng với nợ D-08.

Webhook trùng đã được `WebhookEvent` chặn theo `(shop, provider, event_id)`. Adapter chỉ kiểm chữ ký. Không xử lý đơn trong adapter.

---

## 6. Loại lỗi

| Loại | Ví dụ Printify | Commerce làm gì |
|---|---|---|
| `authentication` | 401, 403 | Ngừng gửi của shop, báo admin nối lại |
| `temporary` | timeout, 429, 5xx | Thử lại có trần, đơn vẫn paid |
| `rejected` | địa chỉ, variant không bán | `fulfillment_error`, không thử lại đến khi người gửi |
| `not_cancellable` | đã in | Giữ đơn commerce như đã quyết định, ghi cần xử lý bên nhà in |
| `unknown` | body không parse được | Như `temporary` một lần, rồi `rejected` nếu vẫn vậy |

Không có loại nào được xóa đơn hay hoàn tiền. Hoàn tiền là việc của commerce sau quyết định của người, trừ khi luật hủy hiện có đã gọi Stripe trước. Luật đó là nợ D-01, không giao cho adapter.

---

## 7. Việc cấm

- `Checkout` gọi URL Printify.
- `Order` đọc `status` JSON của nhà in.
- Adapter sửa `price_cents` chủ đã chỉnh khi import lại.
- Adapter gửi `buyer_inputs` như ghi chú rồi coi là đã in chữ.
- Thêm `if provider == "printful"` trong `Order`.
- Tạo class Printful hoặc Gelato trước khi có tài khoản thử và một đơn thật cần đi đường đó.

Lần triển khai đầu, nếu được duyệt, chỉ chuyển thân `PrintifyGateway`, `Import`, `ShippingQuote` và `Fulfillment` ra sau các method trên. Hành vi đơn, webhook và import giữ nguyên. Test hiện có của Printify là tiêu chí không đổi hành vi.
