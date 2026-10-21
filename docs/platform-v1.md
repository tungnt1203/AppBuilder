# Platform v1: một nơi quản lý, nhiều storefront

Bản thiết kế để duyệt trước khi làm. Trạng thái: **đề xuất** (2026-10-15).

## 1. Mục tiêu

- **Platform**: builder, admin và toàn bộ phần lõi bán hàng ở **một app, một database**. Chủ shop
  quản lý mọi shop ở một nơi, cấu hình Stripe/Printify/pixel một lần.
- **Storefront**: mỗi shop là một app giao diện riêng, publish trên ONCE ở subdomain riêng. Agent
  chỉ sửa giao diện, và chỉ dùng dữ liệu Platform cung cấp qua Storefront API.
- Muốn có trường hay tính năng dữ liệu mới thì **Platform làm trước**; agent không tự tạo dữ liệu.

## 2. Quyết định đã chốt

| Chủ đề | Quyết định |
|---|---|
| Kiến trúc | Headless: Platform (Rails) + Storefront API + storefront riêng từng shop |
| Agent | Chỉ sửa giao diện của storefront; dùng đúng các trường API có; không tạo bảng, không giả lập tính năng |
| Điểm mở rộng v1 | Theme settings, trường tuỳ biến sản phẩm, thông tin khách nhập khi mua, trang nội dung/FAQ, form + hộp thư, collection/menu/chính sách |
| Theme settings | Theme khai báo (file schema trong storefront), Platform lưu giá trị, admin tự sinh form |
| Yêu cầu ngoài khả năng | Agent ghi "yêu cầu cho Platform", báo chủ shop; đội lõi ưu tiên theo số lần lặp |
| Dữ liệu cho preview | Catalog thật của shop (chỉ đọc) + catalog demo khi shop chưa có hàng; checkout trong preview luôn ở chế độ test |
| Booking | Bỏ khỏi sản phẩm |
| Hạ tầng | Platform chạy trên server riêng, tách khỏi máy chạy các storefront |
| Dữ liệu cũ | Không chuyển dữ liệu: các app thử (kể cả project 34) đã xoá, Platform bắt đầu từ đầu |
| Tài khoản khách | Riêng từng shop (khách của shop A không đăng nhập được ở shop B). Khách luôn mua được mà không cần tài khoản; tài khoản chỉ là tuỳ chọn để xem lại đơn |

## 3. Kiến trúc

```
┌──────────────────────── Platform (Rails 8.1 + PostgreSQL) ────────────────────────┐
│ Builder: agent, sandbox, preview, publish ONCE, eval                               │
│ Admin: mọi shop của chủ (đơn, sản phẩm, Printify, cài đặt, nội dung, hộp thư)       │
│ Lõi: catalog, giỏ, checkout, đơn, khuyến mãi, review, Printify, Stripe, Meta CAPI  │
│ Storefront API /v1 (key theo shop) · Webhook Stripe/Printify (một endpoint)        │
│ Ảnh: Active Storage trên S3/R2 + CDN · Job/cache: Solid Queue/Cache trên Postgres   │
└───────────────────────────────────▲───────────────────────────────────────────────┘
                                    │ HTTPS + key của shop
          ┌──────────────┬──────────┴───┬──────────────┐
   cats.<domain>   dogs.<domain>   nurse.<domain>   …   (ONCE, mỗi shop một container)
   Rails + Hotwire + Tailwind, không có database dữ liệu, chỉ cache cục bộ
```

Vì sao storefront là app riêng chứ không render trong Platform: code agent viết chạy trong
container riêng, chỉ cầm key của đúng shop đó, nên không thể đọc dữ liệu shop khác. Nếu theme
chạy trong Platform, một dòng Ruby sai có thể lộ dữ liệu mọi shop.

## 4. Công nghệ

| Phần | Chọn | Lý do |
|---|---|---|
| Platform | Rails 8.1, một app | Tận dụng code hiện có; đội nhỏ không nên chia microservice |
| Database | PostgreSQL | Nhiều shop cùng ghi; JSONB cho trường tuỳ biến/theme settings; Row-Level Security sau này; `pg_search` |
| Chia dữ liệu | `shop_id` mọi bảng + `acts_as_tenant`; RLS ở giai đoạn sau | Không bao giờ đọc nhầm shop |
| Storefront | Rails 8 tối giản + Hotwire + Tailwind + importmap, gem `storefront_kit` | Nhanh trên điện thoại rẻ (HTML render sẵn), agent đã quen; không React/Hydrogen |
| API | REST JSON, có phiên bản `/v1`, ETag | Đơn giản, cache được, agent dễ dùng |
| Cache storefront | HTTP ETag + Solid Cache (SQLite cục bộ), stale-while-revalidate | Trang nhanh, vẫn xem được khi Platform chập chờn |
| Thanh toán | Stripe Payment Element (PaymentIntent tạo ở Platform) | Checkout ngay trong shop, Apple/Google Pay; webhook về một chỗ |
| Ảnh | Active Storage + S3/Cloudflare R2 + CDN, libvips | Một kho ảnh, storefront chỉ nhận URL |
| Triển khai | Platform: server riêng (Kamal) + Postgres có backup ngoài máy; storefront: ONCE theo subdomain | Tách phần sống còn khỏi máy chạy shop |
| Giám sát | Rails error reporter + dịch vụ báo lỗi + kiểm tra uptime | Biết lỗi trước khách |

## 5. Mô hình dữ liệu (Platform)

Mọi bảng dữ liệu của shop có `shop_id` (not null, có index), mọi index unique đều kèm `shop_id`.

**Tài khoản và shop**
- `users` (chủ shop, nhân viên, quản trị viên builder), `shop_memberships` (user × shop × vai trò).
- `shops`: tên, subdomain, tiền tệ, múi giờ, `uid`, trạng thái (nháp, đang bán).
- `shop_api_keys`: key công khai cho storefront (chỉ đọc catalog + giỏ/checkout), có thể thu hồi.
- `business_settings` (theo chủ): Stripe, Printify (+ shop Printify), pixel; shop có thể ghi đè.
- `projects` (builder): một storefront ↔ một `shop`; git repo, preview, deployments như hiện nay.

**Catalog** (chuyển từ block `shop`, thêm `shop_id`)
- `products`, `variants`, `collections`, `collection_products`, `promotions`, `discounts`, `product_reviews`.
- `products.custom_fields` (JSONB) theo `custom_field_definitions` (shop × key × kiểu × nhãn).
- `products.buyer_inputs` (JSONB): định nghĩa ô khách nhập (vd. "Tên in lên áo", tối đa 20 ký tự).
  Printify không nhận text cho sản phẩm có sẵn qua API, nên đơn có text khách nhập không tự gửi:
  admin tự làm đơn trên Printify rồi dán mã đơn vào admin (hoặc gửi luôn không kèm text, vd. lời
  nhắn quà tặng). Sau đó tracking, trạng thái, chi phí về như đơn thường. Tự động hoá (tự vẽ file
  in có text rồi gửi Printify) để sau, cần thử với tài khoản Printify thật.

**Bán hàng**
- `carts`, `cart_items` (+ `properties` JSONB cho thông tin khách nhập), `orders`, `line_items`
  (+ `properties`), `order_events`; logic giữ nguyên (Checkout, Order, Printify::Fulfillment…).
- `customers` theo shop (unique theo `shop_id` + email), tuỳ chọn; checkout không bao giờ đòi đăng nhập.

**Nội dung**
- `pages` (slug, tiêu đề, các khối nội dung), `faqs` (hoặc khối FAQ trong page), `menus`, chính sách.
- `forms` (key, các trường do theme khai báo), `form_submissions` (+ báo email chủ shop).
- `theme_settings`: `shop_id`, `values` (JSONB), `schema_version`.

**Vận hành**
- `platform_requests`: yêu cầu agent gửi khi không làm được (shop, nội dung, số lần lặp, trạng thái).
- `webhook_events`: log webhook Stripe/Printify nhận về (để dò lỗi, chống xử lý trùng), mỗi shop
  một dòng cho mỗi event. Địa chỉ `/webhooks/stripe/:uid`, `/webhooks/printify/:uid`: uid chọn secret
  của shop để kiểm chữ ký; shop chỉ đổi đơn của chính nó, nên shop khác dùng chung tài khoản
  Stripe/Printify nhận cùng event thì bỏ qua (`ignored`).

## 6. Storefront API v1

Chi tiết từng endpoint: [storefront-api.md](storefront-api.md). Header `Authorization: Bearer <shop key>`. JSON; tiền là `cents` + `currency`; lỗi dạng
`{ "error": { "code", "message", "fields" } }`; có ETag; POST quan trọng nhận `Idempotency-Key`.

| Nhóm | Endpoint |
|---|---|
| Shop | `GET /v1/shop`: tên, tiền tệ, thông báo, free ship, ngày giao, pixel id, chính sách, **theme settings** |
| Catalog | `GET /v1/products` (collection, tìm kiếm, sắp xếp, phân trang) · `GET /v1/products/:slug` (biến thể, ảnh theo màu, bảng size, trường tuỳ biến, ô khách nhập, rating) · `GET /v1/collections` · `GET /v1/collections/:slug` |
| Nội dung | `GET /v1/pages/:slug` · `GET /v1/menus/:key` · `GET /v1/policies/:id` |
| Review | `GET /v1/products/:slug/reviews` · `POST /v1/orders/:token/reviews` |
| Giỏ | `POST /v1/carts` · `GET /v1/carts/:token` · `POST/PATCH/DELETE /v1/carts/:token/items` · `POST/DELETE /v1/carts/:token/discount` |
| Checkout | `POST /v1/checkouts/quote` (địa chỉ, email) → tổng tiền gồm phí ship Printify thật · `POST /v1/checkouts` → đặt đơn · `POST /v1/orders/:token/payment` → thuế (Stripe Tax) và `client_secret` cho Payment Element |
| Đơn | `GET /v1/orders/:token` (trạng thái, tracking) |
| Form | `POST /v1/forms/:key/submissions` |
| Tiện ích | `GET /v1/zip_codes/:zip` |

Preview dùng key preview của shop: đọc catalog thật (hoặc demo khi trống), checkout luôn tạo
PaymentIntent ở Stripe test mode và không bao giờ gửi đơn sang Printify.

## 7. Theme settings

Storefront khai báo `config/theme_settings.yml`:

```yaml
- key: hero_title
  type: text            # text | richtext | image | color | url | boolean | select
  label: Hero title
  default: "Tees for people who love a chubby cat"
- key: accent_color
  type: color
  default: "#e8743b"
```

Khi publish, Platform đọc schema của phiên bản đó, giữ giá trị cũ còn hợp lệ, sinh form trong
admin. API trả về giá trị đã gộp với mặc định. Agent dùng `theme_setting(:hero_title)` trong view.

Form của storefront khai báo trong `config/forms.yml`:

```yaml
- key: contact
  title: Contact us
  fields:               # type: text | email | textarea | boolean
    - { key: email, label: Email, type: email, required: true }
    - { key: message, label: Message, type: textarea }
```

Khi publish (bản đã live), Platform tạo hoặc cập nhật từng form theo `key`. Form không còn trong file
thì vẫn giữ, cùng các tin đã nhận. File lỗi thì bỏ qua cả file, ghi vào log deploy, dữ liệu của shop
giữ nguyên; app vẫn live. Chủ shop cũng có thể tạo hoặc sửa form trong admin, nhưng lần publish sau
sẽ ghi đè form có trong file.

## 8. Storefront (template mới)

- Không có model dữ liệu; gem `storefront_kit`: client API, cache, helper (`products`, `cart`,
  `checkout`, `theme_setting`, `money`…), đối tượng trả về có kiểu (`Product`, `Variant`…).
- Biến môi trường: `PLATFORM_URL`, `SHOP_KEY`, `STOREFRONT_MODE` (`preview`/`live`).
- Giữ các phần đang bán tốt: trang sản phẩm (ảnh theo màu, bảng size, thanh mua dính, zoom),
  giỏ, checkout (ZIP tự điền, phí ship thật), pixel, review, trang trống "sắp có hàng".
- CLAUDE.md cho agent: tài liệu dữ liệu tự sinh từ API; quy tắc "chỉ giao diện"; luồng yêu cầu.
- Code: app ở `storefront/` (template cũ `template/` đã gỡ ở #19), gem ở `blocks/storefront_kit/`
  (link vào `storefront/vendor/blocks/`, như các block khác). Thẻ trả tiền bằng Stripe Payment Element
  ở `/orders/:token/payment`. Test chạy với Platform giả trong bộ nhớ (`StorefrontKit::Testing::FakeApi`).
- Chưa có: tài khoản khách hàng (checkout luôn là khách vãng lai), CLAUDE.md/skill cho agent (#15).

## 9. Tận dụng code hiện có

| Hiện có | Đi đâu |
|---|---|
| `blocks/shop` (models, Printify, Stripe, Meta, ZipCode, Region, DemoCatalog) | Platform, thêm `shop_id` |
| `/agent/v1` storefront API | Nền cho Storefront API v1 |
| `/admin` của shop + UI kit | Admin của Platform, thêm chọn shop |
| Builder (agent, sandbox, preview, publish, eval, `/admin` Orders/Products/Settings) | Giữ; đọc DB trực tiếp |
| View của template (products, cart, checkout, home, blocks) | Storefront template, đổi sang `storefront_kit` |
| `AppTask`, lệnh `shop:*` | Đã bỏ (#10/#19) |
| `BusinessSync`, `OrdersSummary`, `Store#uid` | Giữ: đã chuyển sang đọc DB của Platform |
| `blocks/shop`, `blocks/booking`, `template/`, `integrations/commerce-agents` | Đã gỡ ở #19 (còn trong git history) |

## 10. Giai đoạn và tiêu chí xong

1. **Platform nền tảng**: Postgres, `shops`, membership, tenancy, chuyển block `shop` vào với
   `shop_id`; toàn bộ test lõi chạy theo shop. Xong khi: 2 shop cùng DB không thấy dữ liệu nhau.
2. **Admin trung tâm**: chọn shop, sản phẩm, đơn, cài đặt, Printify, nội dung, hộp thư.
3. **Storefront API v1** đủ bảng mục 6, có test hợp đồng, rate limit, idempotency.
4. **Điểm mở rộng**: theme settings, trường tuỳ biến, ô khách nhập (đơn có text chờ admin làm trên Printify), pages/FAQ, forms.
5. **Storefront template + `storefront_kit`**: chuyển giao diện hiện tại; checkout Payment Element.
6. **Builder**: preview gọi API (key preview, demo catalog), publish ONCE với `PLATFORM_URL`/`SHOP_KEY`,
   agent rules mới, luồng `platform_requests`.
7. **Webhook tập trung** (Stripe, Printify) + `webhook_events`.
8. **Triển khai**: Platform trên server riêng, Postgres backup, R2/CDN, giám sát.
9. **Eval POD trên kiến trúc mới** (p061–p068): không chuyển dữ liệu cũ, shop mới tạo từ đầu.
10. **Gỡ bỏ** database riêng từng shop, `AppTask`/`shop:*`, block booking, `blocks/shop`, `template/`, commerce-agents (xong ở #19).

## 11. Rủi ro

- Platform là điểm sống còn của mọi shop: cache catalog ở storefront, giám sát, backup, diễn tập khôi phục.
- Đợt viết lại lớn: làm theo giai đoạn, shop cũ chạy song song tới khi chuyển xong.
- Agent bị giới hạn bởi API: bộ điểm mở rộng v1 phải đủ rộng; theo dõi `platform_requests`.
- Bảo mật: key storefront chỉ có quyền tối thiểu; secrets tích trữ ở Platform cần xoay vòng khoá.
