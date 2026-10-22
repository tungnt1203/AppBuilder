require "storefront_kit"

module StorefrontKit
  # A Platform in memory for a storefront's tests: StorefrontKit.api = StorefrontKit::Testing::FakeApi.new.
  # It answers like the Storefront API (the same records) with a small shop: a tee in Black and
  # White, S and M (White M isn't made), and a mug; carts, quotes, orders and card payments work,
  # the code SAVE10 takes 10% off. Change its data (fake.shop_data, fake.products_data) to set a
  # test up, and read what the storefront sent in fake.requests.
  module Testing
    class FakeApi
      attr_accessor :shop_data, :products_data, :collections_data, :pages_data, :menus_data, :policies_data, :reviews_data, :zip_codes
      attr_reader :carts, :orders, :requests, :form_submissions, :order_lookups

      def initialize
        @shop_data = default_shop
        @uploads = {}
        @products_data = default_products
        @collections_data = [ { "slug" => "cats", "title" => "Cats", "description" => "For cat people.", "product_count" => 1,
          "image" => { "id" => 1, "alt" => "Cats", "thumb" => "https://cdn.example/cat-thumb.webp", "card" => "https://cdn.example/cat-card.webp", "large" => "https://cdn.example/cat-large.webp" } },
          { "slug" => "new", "title" => "New", "product_count" => 0 } ] # no description: the API leaves empty ones out
        @pages_data = { "about" => { "slug" => "about", "title" => "About us", "blocks" => [ { "type" => "text", "body" => "We print tees." },
          { "type" => "faq", "items" => [ { "question" => "How long?", "answer" => "About a week." } ] } ] } }
        @menus_data = { "header" => { "key" => "header", "title" => "Header", "items" => [ { "label" => "About", "url" => "/pages/about" } ] } }
        @policies_data = { "refund" => { "id" => "refund", "title" => "Refund policy", "body" => "Returns within 30 days." } }
        @reviews_data = { "cat-tee" => [ { "rating" => 5, "body" => "Soft and cute.", "author_name" => "Robin B.", "created_at" => "2026-10-01T10:00:00Z" } ] }
        @zip_codes = { "78701" => { "zip" => "78701", "country" => "US", "region" => "TX", "city" => "Austin" } }
        @carts, @orders, @requests, @form_submissions, @placed, @order_lookups = {}, {}, [], [], {}, {}
      end

      def shop = Shop.new(record(:shop, @shop_data))
      def policy(id) = Policy.new(record(:policy, @policies_data.fetch(id.to_s) { not_found("policy") }))
      def page(slug) = Page.new(record(:page, @pages_data.fetch(slug.to_s) { not_found("page") }))
      def menu(key) = Menu.new(record(:menu, @menus_data.fetch(key.to_s) { not_found("menu") }))

      def products(q: nil, collection: nil, sort: nil, page: nil, per_page: nil)
        record(:products, { q:, collection:, sort:, page: })
        list = @products_data.select { |product| q.blank? || product["title"].downcase.include?(q.to_s.downcase) }
        list = list.select { |product| Array(product["collections"]).any? { |c| c["slug"] == collection } } if collection.present?
        list = list.sort_by { |product| product["title"] } if sort == "title"
        per = (per_page || 24).to_i
        number = [ page.to_i, 1 ].max
        ListPage.new(list.drop((number - 1) * per).first(per).map { |product| Product.new(summary(product)) }, page: number, per_page: per, total: list.size)
      end

      def product(slug) = Product.new(record(:product, @products_data.find { |product| product["slug"] == slug.to_s } || not_found("product")))

      def reviews(slug, page: nil)
        list = @reviews_data.fetch(slug.to_s, [])
        ListPage.new(Review.wrap(list), page: 1, per_page: 10, total: list.size)
      end

      def collections = Collection.wrap(@collections_data)
      def collection(slug) = Collection.new(@collections_data.find { |collection| collection["slug"] == slug.to_s } || not_found("collection"))
      def zip_code(zip) = (Record.new(@zip_codes[zip.to_s]) if @zip_codes[zip.to_s])

      def create_cart
        token = SecureRandom.hex(8)
        @carts[token] = { "token" => token, "lines" => [], "discount_code" => nil }
        cart(token)
      end

      def cart(token) = Cart.new(cart_json(find_cart(token)))

      def upload(file)
        record(:upload, { filename: file.respond_to?(:original_filename) ? file.original_filename : nil })
        raise Invalid.new("Some details need fixing", status: 422, code: "invalid", fields: { "photo" => "must be a JPEG, PNG or WebP photo" }) unless file.respond_to?(:content_type) && file.content_type.to_s.start_with?("image/")

        token = "upl_test#{@uploads.size + 1}"
        @uploads[token] = { "token" => token, "width" => 1200, "height" => 1200, "thumb" => "https://platform.test/uploads/#{token}/thumb.webp", "large" => "https://platform.test/uploads/#{token}/large.webp" }
        Record.new(@uploads[token])
      end

      def add_to_cart(token, variant_id:, quantity: 1, properties: {})
        record(:add_to_cart, { token:, variant_id:, quantity:, properties: })
        data = find_cart(token)
        product, variant = find_variant(variant_id)
        raise Unavailable.new("#{product["title"]} can't be bought right now", status: 409, code: "unavailable") unless variant["available"]

        missing = product["buyer_inputs"].to_a.select { |input| input["required"] && properties.to_h.stringify_keys[input["key"]].blank? }
        raise Invalid.new("Some details need fixing", status: 422, code: "invalid", fields: missing.to_h { |input| [ input["key"], "can't be blank" ] }) if missing.any?

        properties = properties.to_h.stringify_keys.compact_blank
        line = data["lines"].find { |candidate| candidate["variant_id"] == variant["id"] && candidate["properties"] == properties }
        line ||= (data["lines"] << { "id" => data["lines"].size + 1, "variant_id" => variant["id"], "quantity" => 0, "properties" => properties }).last
        line["quantity"] = (line["quantity"] + quantity.to_i).clamp(1, 99)
        cart(token)
      end

      def update_cart_item(token, id, quantity:)
        data = find_cart(token)
        line = data["lines"].find { |candidate| candidate["id"] == id.to_i } || not_found("cart item")
        quantity.to_i.positive? ? line["quantity"] = quantity.to_i.clamp(1, 99) : data["lines"].delete(line)
        cart(token)
      end

      def remove_cart_item(token, id)
        find_cart(token)["lines"].reject! { |line| line["id"] == id.to_i }
        cart(token)
      end

      def apply_discount(token, code)
        raise Invalid.new("That code doesn't exist", status: 422, code: "unknown", fields: { "code" => "That code doesn't exist" }) unless code.to_s.upcase == "SAVE10"

        find_cart(token)["discount_code"] = "SAVE10"
        cart(token)
      end

      def remove_discount(token)
        find_cart(token)["discount_code"] = nil
        cart(token)
      end

      def quote(cart_token, **fields)
        record(:quote, fields.merge(cart_token:))
        Checkout.new(checkout_json(find_cart(cart_token), fields), problems: problems(fields.stringify_keys, final: false))
      end

      def place_order(cart_token, idempotency_key:, **fields)
        record(:place_order, fields.merge(cart_token:, idempotency_key:))
        return @placed[idempotency_key] if @placed[idempotency_key]

        fields = fields.stringify_keys
        data = find_cart(cart_token)
        raise Invalid.new("Your cart is empty", status: 422, code: "invalid") if data["lines"].empty?
        if (found = problems(fields, final: true)).any?
          raise Invalid.new("Some details need fixing", status: 422, code: "invalid", fields: found)
        end

        checkout = checkout_json(data, fields)
        token = SecureRandom.hex(8)
        card = fields["payment_method"] == "stripe"
        @orders[token] = {
          "token" => token, "number" => 1000 + @orders.size + 1, "name" => "##{1000 + @orders.size + 1}", "status" => "pending",
          "test" => @shop_data["preview"], "placed_at" => Time.now.utc.iso8601, "paid_at" => nil, "shipped_at" => nil, "delivered_at" => nil,
          "cancelled_at" => nil, "refunded_at" => nil, "email" => fields["email"], "currency" => @shop_data["currency"],
          "items" => checkout["items"].map { |item|
            { "title" => item["product"]["title"], "variant_title" => item["variant"]["title"], "quantity" => item["quantity"],
              "unit_price_cents" => item["variant"]["price_cents"], "line_total_cents" => item["line_total_cents"],
              "product_slug" => item["product"]["slug"], "image" => item["product"]["image"], "properties" => item["properties"] }.compact
          },
          "subtotal_cents" => checkout["subtotal_cents"], "discount_cents" => checkout["discount_cents"], "discount_code" => checkout["discount_code"],
          "shipping_cents" => checkout["shipping_cents"], "tax_cents" => 0, "total_cents" => checkout["total_cents"], "refunded_cents" => 0,
          "shipping_address" => { "name" => fields["shipping_name"], "address1" => fields["shipping_address1"], "address2" => fields["shipping_address2"],
            "city" => fields["shipping_city"], "region" => fields["shipping_region"], "postal_code" => fields["shipping_postal_code"], "country" => fields["shipping_country"] },
          "payment" => { "method" => fields["payment_method"], "required" => card, "instructions" => (card ? nil : @shop_data["payment_instructions"]) },
          "tracking" => nil, "reviewable_products" => []
        }
        data["lines"].clear
        data["discount_code"] = nil
        @placed[idempotency_key] = order(token)
      end

      def order(token) = Order.new(record(:order, @orders.fetch(token.to_s) { not_found("order") }))

      # A card order's payment, as Stripe's Payment Element needs it.
      def payment(order_token, idempotency_key: nil)
        order = @orders.fetch(order_token.to_s) { not_found("order") }
        raise Invalid.new("#{order["name"]} doesn't wait for a card payment", status: 422, code: "payment_not_needed") unless order.dig("payment", "required")

        Payment.new("provider" => "stripe", "client_secret" => "pi_fake_secret_#{order_token}", "publishable_key" => "pk_test_fake",
          "amount_cents" => order["total_cents"], "tax_cents" => 0, "currency" => order["currency"], "test_mode" => true)
      end

      # What Stripe does once the buyer paid: the order is paid.
      def pay!(order_token)
        order = @orders.fetch(order_token.to_s)
        order.merge!("status" => "paid", "paid_at" => Time.now.utc.iso8601)
        order["payment"] = order["payment"].merge("required" => false)
      end

      def ship!(order_token, tracking: { "carrier" => "USPS", "number" => "9400 1", "url" => "https://tools.usps.com/go/TrackConfirmAction?tLabels=94001" })
        order = @orders.fetch(order_token.to_s)
        order.merge!("status" => "shipped", "shipped_at" => Time.now.utc.iso8601, "tracking" => tracking,
          "reviewable_products" => order["items"].map { |item| { "slug" => item["product_slug"], "title" => item["title"] } }.uniq)
      end

      def review_order(order_token, reviews:, author_name: nil)
        order = @orders.fetch(order_token.to_s) { not_found("order") }
        picked = reviews.map(&:stringify_keys).select { |review| review["rating"].present? }
        raise Invalid.new("Nothing here to review", status: 422, code: "nothing_to_review") if picked.empty?

        order["reviewable_products"].reject! { |product| picked.any? { |review| review["product_slug"] == product["slug"] } }
        picked.map { |review| Review.new(review.merge("author_name" => author_name, "created_at" => Time.now.utc.iso8601)) }
      end

      # The links the shop emailed, { token => email }: only for an email with orders.
      def request_order_lookup(email)
        record(:request_order_lookup, email:)
        email = email.to_s.strip.downcase
        raise Invalid.new("Enter a valid email", status: 422, code: "invalid", fields: { "email" => "isn't a valid email" }) unless email.match?(/\A[^@\s]+@[^@\s]+\.[a-z]{2,}\z/i)

        @order_lookups["lookup-#{SecureRandom.hex(4)}"] = email if @orders.values.any? { |order| order["email"].to_s.downcase == email }
        nil
      end

      def order_lookup(token)
        email = @order_lookups.fetch(token.to_s) { not_found("order lookup") }
        found = @orders.values.select { |order| order["email"].to_s.downcase == email }.reverse
        OrderLookup.new(record(:order_lookup, "email" => email, "orders" => found))
      end

      def submit_form(key, answers, idempotency_key: nil)
        @form_submissions << { key: key.to_s, answers: answers.to_h.stringify_keys }
        Record.new("id" => @form_submissions.size)
      end

      def variant(id) = Variant.new(find_variant(id).last)

      private
        def record(name, value)
          @requests << [ name, value ] unless value.is_a?(Hash) && name == :shop
          value
        end

        def not_found(what) = raise(NotFound.new("No #{what} here", status: 404, code: "not_found"))
        def find_cart(token) = @carts.fetch(token.to_s) { not_found("cart") }

        def find_variant(id)
          @products_data.each do |product|
            variant = product["variants"].find { |candidate| candidate["id"] == id.to_i }
            return [ product, variant ] if variant
          end
          not_found("variant")
        end

        def summary(product) = product.slice("slug", "title", "available", "price", "image", "rating")

        def cart_json(data)
          items = data["lines"].map { |line| line_json(line) }
          subtotal = items.sum { |item| item["line_total_cents"] }
          discount = ({ "code" => "SAVE10", "kind" => "percentage", "amount_cents" => subtotal / 10 } if data["discount_code"])
          threshold = @shop_data.dig("shipping", "free_over_cents")
          { "token" => data["token"], "currency" => @shop_data["currency"], "items" => items, "item_count" => items.sum { |item| item["quantity"] },
            "subtotal_cents" => subtotal, "discount" => discount,
            "free_shipping_remaining_cents" => (threshold - subtotal if threshold && items.any? && subtotal < threshold) }
        end

        def line_json(line)
          product, variant = find_variant(line["variant_id"])
          image = product["images"].find { |photo| photo["id"] == variant["image_id"] } || product["image"]
          labels = product["buyer_inputs"].to_a.to_h { |input| [ input["key"], input["label"] ] }
          { "id" => line["id"], "quantity" => line["quantity"], "line_total_cents" => variant["price_cents"] * line["quantity"],
            "product" => { "slug" => product["slug"], "title" => product["title"], "image" => image }, "variant" => variant,
            "properties" => (line["properties"].filter_map { |key, value|
              next if key.end_with?("_crop")

              upload = @uploads[value]
              option = product["buyer_inputs"].to_a.find { |input| input["key"] == key }.to_h["options"].to_a.find { |candidate| candidate["id"].to_s == value.to_s }
              { "key" => key, "label" => labels[key] || key, "value" => (upload ? "Added" : option ? option["label"] : value) }.merge((upload || option || {}).slice("thumb", "large"))
            } if line["properties"].any?),
            "preview" => preview_layers(product, line["properties"], image).presence }.compact
        end

        # What the buyer added on the line's photo, as the Platform places it (BuyerInputs.layers).
        def preview_layers(product, properties, image)
          properties = properties.to_h.stringify_keys
          product["buyer_inputs"].to_a.filter_map do |input|
            preview, value = input["preview"], properties[input["key"]]
            next unless preview && value.present? && image && (preview["images"].to_a.empty? || preview["images"].include?(image["id"]))

            box = preview.slice("x", "y", "w", "h")
            case input["kind"]
            when "photo"
              upload = @uploads[value] or next
              zoom, x, y = properties["#{input["key"]}_crop"].to_s.split(",").map(&:to_f)
              filter = properties["#{input["key"]}_filter"].then { |pick| pick if preview["filters"].to_a.include?(pick) } || "original"
              box.merge("kind" => "photo", "crop" => [ zoom || 1.0, x || 0.5, y || 0.5 ], "filter" => filter, "photo" => upload["large"])
            when "choice"
              option = input["options"].to_a.find { |candidate| candidate["id"].to_s == value.to_s } or next
              box.merge("kind" => "choice", "picture" => option["large"])
            when "color"
              box.merge("kind" => "color", "color" => value)
            else
              picked = ->(kind, all) { properties["#{input["key"]}_#{kind}"].then { |pick| pick if all.to_a.include?(pick) } }
              box.merge(preview.slice("align", "uppercase", "curve", "style")).merge("kind" => "text", "text" => value,
                "font" => picked.("font", preview["fonts"]) || preview["font"], "color" => picked.("color", preview["colors"]) || preview["color"])
            end
          end
        end

        def checkout_json(data, fields)
          cart = cart_json(data)
          fields = fields.to_h.stringify_keys
          known = fields["shipping_country"].present? && fields["shipping_postal_code"].present?
          shipping = cart["free_shipping_remaining_cents"].nil? && @shop_data.dig("shipping", "free_over_cents") ? 0 : (known ? 475 : @shop_data.dig("shipping", "first_item_cents"))
          discount = cart.dig("discount", "amount_cents").to_i
          { "currency" => cart["currency"], "items" => cart["items"], "subtotal_cents" => cart["subtotal_cents"], "discount_cents" => discount,
            "discount_code" => cart.dig("discount", "code"), "shipping_cents" => shipping, "shipping_known" => known,
            "total_cents" => cart["subtotal_cents"] - discount + shipping, "payment_methods" => @shop_data["payment_methods"], "phone_required" => false }
        end

        def problems(fields, final:)
          required = %w[ email shipping_name shipping_address1 shipping_city shipping_country ]
          found = required.select { |field| fields[field].blank? }.to_h { |field| [ field, "can't be blank" ] }
          found["email"] = "is invalid" if fields["email"].present? && !fields["email"].to_s.include?("@")
          final ? found : found.slice(*fields.keys)
        end

        def image(id, color)
          { "id" => id, "alt" => "Cat Tee", "thumb" => "https://cdn.example/#{color}-thumb.webp", "card" => "https://cdn.example/#{color}-card.webp",
            "large" => "https://cdn.example/#{color}-large.webp" }
        end

        def default_shop
          {
            "name" => "Chubby Cat Tees", "currency" => "USD", "preview" => false, "announcement" => "Free shipping over $50",
            "shipping" => { "first_item_cents" => 500, "additional_item_cents" => 200, "free_over_cents" => 5000, "ships_to" => %w[ US CA ],
              "delivery_days" => { "min" => 5, "max" => 8 }, "delivery_dates" => { "first" => (Date.today + 7).iso8601, "last" => (Date.today + 10).iso8601 },
              "countries" => [ { "code" => "CA", "name" => "Canada", "regions" => { "ON" => "Ontario", "QC" => "Quebec" } },
                { "code" => "US", "name" => "United States", "regions" => { "CA" => "California", "NY" => "New York", "TX" => "Texas" } } ] },
            "payment_methods" => %w[ stripe manual ], "payment_instructions" => "Pay by bank transfer to 123-456.", "tax_at_payment" => false,
            "pixels" => { "meta" => nil, "tiktok" => nil, "google" => nil },
            "policies" => [ { "id" => "refund", "title" => "Refund policy" } ],
            "contact" => { "email" => "hello@chubbycat.example", "phone" => nil, "address" => nil },
            "theme_settings" => { "hero_title" => "Tees for people who love a chubby cat" }
          }
        end

        def default_products
          black, white = image(1, "black"), image(2, "white")
          tee_variants = [
            [ 101, %w[ Black S ], 2400, nil, true, 1 ], [ 102, %w[ Black M ], 2400, 3000, true, 1 ],
            [ 103, %w[ White S ], 2600, nil, true, 2 ], [ 104, %w[ White M ], 2600, nil, false, 2 ]
          ].map do |id, options, price, compare, available, image_id|
            { "id" => id, "title" => options.join(" / "), "options" => options, "sku" => "TEE-#{id}", "catalog_id" => "TEE-#{id}", "price_cents" => price,
              "compare_at_price_cents" => compare, "available" => available, "stock" => nil, "image_id" => image_id }
          end
          [
            { "slug" => "cat-tee", "title" => "Cat Tee", "available" => true, "description" => "Soft cotton.\n\nPrinted to order.",
              "price" => { "min_cents" => 2400, "max_cents" => 2600, "currency" => "USD", "compare_at_cents" => 3000 },
              "image" => black, "images" => [ black.merge("option_value" => "Black"), white.merge("option_value" => "White") ],
              "rating" => { "average" => 5.0, "count" => 1 }, "size_guide" => "Size | Chest\nS | 34\nM | 38", "size_option" => "Size", "made_to_order" => true,
              "options" => [ { "name" => "Color", "values" => %w[ Black White ], "colors" => { "Black" => "#000000", "White" => "#ffffff" } }, { "name" => "Size", "values" => %w[ S M ] } ],
              "variants" => tee_variants, "collections" => [ { "slug" => "cats", "title" => "Cats" } ], "custom_fields" => [], "buyer_inputs" => [] },
            { "slug" => "morning-mug", "title" => "Morning Mug", "available" => true, "description" => nil,
              "price" => { "min_cents" => 1500, "max_cents" => 1500, "currency" => "USD", "compare_at_cents" => nil },
              "image" => nil, "images" => [], "rating" => nil, "size_guide" => nil, "size_option" => nil, "made_to_order" => false,
              "options" => [], "variants" => [ { "id" => 201, "title" => nil, "options" => [], "sku" => nil, "catalog_id" => "variant-201", "price_cents" => 1500,
                "compare_at_price_cents" => nil, "available" => true, "stock" => nil, "image_id" => nil } ],
              "collections" => [], "custom_fields" => [], "buyer_inputs" => [] }
          ]
        end
    end
  end
end
