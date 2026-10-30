# Someone who bought from the shop, by the email on their orders (buyers check out without an
# account): their name from the latest order (customer_name, as Order#name is the order's number),
# how many orders, what they spent (paid orders less refunds, as ShopReport counts sales) and when
# they first and last ordered. Tests and card checkouts left unpaid aren't orders yet. A buyer is
# reached by one of their orders' tokens, so no email goes in an address.
class Buyer
  SPENT = "COALESCE(SUM(orders.total_cents - orders.refunded_cents) FILTER (WHERE orders.status IN ('paid', 'in_production', 'shipped', 'delivered')), 0)"
  SORTS = {
    "recent" => "MAX(orders.created_at) DESC",
    "spent" => "#{SPENT} DESC, MAX(orders.created_at) DESC",
    "orders" => "COUNT(*) DESC, MAX(orders.created_at) DESC"
  }.freeze

  def self.orders = Order.real.where.not(id: Order.unpaid_card)

  def self.all(query: nil, sort: "recent")
    orders.search(query).group(:email)
      .select(:email, "(ARRAY_AGG(orders.shipping_name ORDER BY orders.created_at DESC))[1] AS customer_name",
        "(ARRAY_AGG(orders.token ORDER BY orders.created_at DESC))[1] AS latest_token",
        "COUNT(*) AS orders_count", "#{SPENT} AS spent_cents",
        "MIN(orders.created_at) AS first_order_at", "MAX(orders.created_at) AS last_order_at")
      .order(Arel.sql(SORTS.fetch(sort.to_s, SORTS["recent"])))
  end

  # The buyer with an order of this token.
  def self.find(token) = all.where(email: orders.find_by!(token:).email).take!
end
