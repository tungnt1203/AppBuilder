# Plain page-by-page lists without a gem: @page = paginate(scope, per: 24), then
# @page.records in the view and render "ui/pagination", page: @page.
module Pagination
  Page = Struct.new(:records, :number, :per, :total, keyword_init: true) do
    def pages = [ (total.to_f / per).ceil, 1 ].max
    def previous = (number - 1 if number > 1)
    def next = (number + 1 if number < pages)
    def many? = pages > 1
  end

  private
    def paginate(scope, per: 24)
      total = scope.count
      total = total.size if total.is_a?(Hash) # grouped scopes count per group
      number = params[:page].to_i.clamp(1, [ (total.to_f / per).ceil, 1 ].max)
      Page.new(records: scope.limit(per).offset((number - 1) * per), number:, per:, total:)
    end
end
