# The shop's numbers over a period, for the dashboard: sales by day, the totals against the period
# before, what's left after Printify's costs, the products that sold most and where the buyers
# came from. Sales are paid orders that aren't tests (Order.counted_in_sales), less refunds.
class ShopReport
  PERIODS = { "7" => 7, "30" => 30, "90" => 90 }.freeze
  DEFAULT_PERIOD = "30"

  # What's left is Order#margin_cents over the period: sales less tax and Printify's bills (those
  # in so far), payment fees aside.
  Totals = Data.define(:sales_cents, :orders, :tax_cents, :printing_cents) do
    def average_cents = orders.zero? ? 0 : sales_cents / orders
    def left_cents = sales_cents - tax_cents - printing_cents
  end
  Day = Data.define(:date, :sales_cents, :orders)
  Line = Data.define(:title, :quantity, :sales_cents)

  attr_reader :period, :days

  # Days are the shop's (Shop#time_zone).
  def initialize(period: DEFAULT_PERIOD, time_zone: "UTC", now: Time.current)
    @period = PERIODS.key?(period.to_s) ? period.to_s : DEFAULT_PERIOD
    @days = PERIODS.fetch(@period)
    @zone = ActiveSupport::TimeZone[time_zone.to_s] || ActiveSupport::TimeZone["UTC"]
    now = now.in_time_zone(@zone)
    @to = now.end_of_day
    @from = (now - (@days - 1).days).beginning_of_day
  end

  def totals = @totals ||= totals_for(@from..@to)
  def previous = @previous ||= totals_for((@from - @days.days)..(@from - 1.second))

  # Change against the period before, as a fraction (0.25 is 25% up); nil when there was nothing.
  def change(measure)
    before = previous.public_send(measure)
    (totals.public_send(measure) - before).fdiv(before) unless before.zero?
  end

  def by_day
    @by_day ||= begin
      day = Arel.sql("DATE(orders.created_at AT TIME ZONE 'UTC' AT TIME ZONE #{Order.connection.quote(@zone.tzinfo.identifier)})")
      rows = orders.group(day).pluck(day, Arel.sql(SALES), Arel.sql("COUNT(*)"))
        .to_h { |date, sales, count| [ date, [ sales.to_i, count ] ] }
      (@from.to_date..@to.to_date).map { |date| Day.new(date, *rows.fetch(date, [ 0, 0 ])) }
    end
  end

  def top_products(limit: 5)
    LineItem.joins(:order).merge(orders).group(:product_title)
      .order(Arel.sql("SUM(line_items.unit_price_cents * line_items.quantity) DESC"))
      .limit(limit).pluck(:product_title, Arel.sql("SUM(line_items.quantity)"), Arel.sql("SUM(line_items.unit_price_cents * line_items.quantity)"))
      .map { |title, quantity, sales| Line.new(title, quantity.to_i, sales.to_i) }
  end

  # Sales by where the buyer came from (Order#source), most first.
  def sources
    orders.select(:id, :attribution, :total_cents, :refunded_cents).group_by(&:source)
      .map { |source, placed| [ source, placed.sum { |order| order.total_cents - order.refunded_cents }, placed.size ] }
      .sort_by { |_, sales, _| -sales }
  end

  private
    SALES = "SUM(orders.total_cents - orders.refunded_cents)"

    def orders = Order.counted_in_sales.where(created_at: @from..@to)

    def totals_for(range)
      sums = Order.counted_in_sales.where(created_at: range)
        .pick(Arel.sql("COALESCE(#{SALES}, 0)"), Arel.sql("COUNT(*)"), Arel.sql("COALESCE(SUM(orders.tax_cents), 0)"), Arel.sql("COALESCE(SUM(orders.fulfillment_cost_cents), 0)"))
      Totals.new(*sums.map(&:to_i))
    end
end
