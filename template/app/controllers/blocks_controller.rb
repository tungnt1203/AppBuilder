# Development only: every block in app/views/blocks on one page, in this app's theme, to look at
# (bin/rails tailwindcss:build first) and pick from. See the design skill.
class BlocksController < ApplicationController
  # In the order they'd usually appear on a page; any other block comes after.
  ORDER = %w[ hero_split hero_photo features price_list gallery schedule testimonials stats faq visit cta_band action_bar ]

  allow_unauthenticated_access
  layout "public"

  def index
    @blocks = Rails.root.glob("app/views/blocks/_*.html.erb").map { |file| file.basename.to_s.delete_prefix("_").delete_suffix(".html.erb") }
      .sort_by { |block| [ ORDER.index(block) || ORDER.size, block ] }
    @blocks &= [ params[:only] ] if params[:only]
  end
end
