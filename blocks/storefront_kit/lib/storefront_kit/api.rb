module StorefrontKit
  # The Storefront API's endpoints as methods that answer records (docs/storefront-api.md).
  # Catalog reads may come from the cache for fresh_for seconds; carts, checkouts and orders are
  # always asked for.
  class Api
    attr_reader :client

    def initialize(client, fresh_for: 30)
      @client, @fresh_for = client, fresh_for
    end

    # The shop
    def shop = Shop.new(read("shop")["shop"])
    def policy(id) = Policy.new(read("policies/#{escape(id)}")["policy"])
    def page(slug) = Page.new(read("pages/#{escape(slug)}")["page"])
    def menu(key) = Menu.new(read("menus/#{escape(key)}")["menu"])

    # The catalog
    def products(q: nil, collection: nil, sort: nil, page: nil, per_page: nil)
      body = read("products", q:, collection:, sort:, page:, per_page:)
      ListPage.new(Product.wrap(body["products"]), page: body["page"], per_page: body["per_page"], total: body["total"], pages: body["pages"])
    end

    def product(slug) = Product.new(read("products/#{escape(slug)}")["product"])

    def reviews(slug, page: nil)
      body = read("products/#{escape(slug)}/reviews", page:)
      ListPage.new(Review.wrap(body["reviews"]), page: body["page"], per_page: body["per_page"], total: body["total"])
    end

    def collections = Collection.wrap(read("collections")["collections"])
    def collection(slug) = Collection.new(read("collections/#{escape(slug)}")["collection"])

    # A US ZIP code's city and region ({ "zip", "country", "region", "city" }), nil when unknown.
    def zip_code(zip)
      Record.new(read("zip_codes/#{escape(zip)}")["zip_code"])
    rescue NotFound
      nil
    end

    # The cart
    def create_cart = cart_from(client.post("carts"))
    def cart(token) = cart_from(client.get("carts/#{escape(token)}"))

    # A buyer's photo for a personalized product (an uploaded file): { "token", "width", "height",
    # "thumb", "large" }. Send the token as the photo field's property when adding the line.
    def upload(file) = Record.new(client.post_file("uploads", photo: file)["upload"])

    def add_to_cart(token, variant_id:, quantity: 1, properties: {})
      cart_from(client.post("carts/#{escape(token)}/items", { variant_id:, quantity:, properties: }))
    end

    def update_cart_item(token, id, quantity:) = cart_from(client.patch("carts/#{escape(token)}/items/#{escape(id)}", { quantity: }))
    def remove_cart_item(token, id) = cart_from(client.delete("carts/#{escape(token)}/items/#{escape(id)}"))
    def apply_discount(token, code) = cart_from(client.post("carts/#{escape(token)}/discount", { code: }))
    def remove_discount(token) = cart_from(client.delete("carts/#{escape(token)}/discount"))

    # Checkout: what the cart comes to for the address so far, then the order.
    def quote(cart_token, **fields)
      body = client.post("checkouts/quote", fields.merge(cart_token:))
      Checkout.new(body["checkout"], problems: body["problems"])
    end

    # Placing the same order again with the same idempotency_key gives the first order back.
    def place_order(cart_token, idempotency_key:, **fields)
      Order.new(client.post("checkouts", fields.merge(cart_token:), idempotency_key:)["order"])
    end

    def order(token) = Order.new(client.get("orders/#{escape(token)}")["order"])

    # The card payment for Stripe's Payment Element: client_secret, publishable_key, amount_cents…
    def payment(order_token, idempotency_key: "payment-#{order_token}")
      Payment.new(client.post("orders/#{escape(order_token)}/payment", {}, idempotency_key:)["payment"])
    end

    # Asks the shop to email the buyer a link to their orders (/orders/find/<token>). Answers the
    # same whether or not the email has orders; raises Invalid for an email that isn't one.
    def request_order_lookup(email)
      client.post("order_lookups", { email: })
      nil
    end

    # The buyer's orders by the emailed link's token; NotFound once it's expired.
    def order_lookup(token) = OrderLookup.new(client.get("order_lookups/#{escape(token)}")["order_lookup"])

    # reviews: [{ product_slug:, rating:, body: }]
    def review_order(order_token, reviews:, author_name: nil)
      Review.wrap(client.post("orders/#{escape(order_token)}/reviews", { reviews:, author_name: }.compact)["reviews"])
    end

    def submit_form(key, answers, idempotency_key: SecureRandom.uuid)
      Record.new(client.post("forms/#{escape(key)}/submissions", { answers: }, idempotency_key:)["submission"])
    end

    private
      def read(path, params = {}) = client.get(path, params, fresh_for: @fresh_for)
      def cart_from(body) = Cart.new(body["cart"])
      def escape(value) = URI.encode_uri_component(value.to_s)
  end
end
