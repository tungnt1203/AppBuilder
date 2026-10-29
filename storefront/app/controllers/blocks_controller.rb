# Development only: every block in app/views/blocks on one page, in this app's theme, to look at
# (bin/rails tailwindcss:build first) and pick from. See the design skill.
class BlocksController < ApplicationController
  # In the order they'd usually appear on a page; any other block comes after.
  ORDER = %w[ image_banner marquee benefits collection_tiles product_carousel collage image_with_text gallery faq newsletter cta_band ]

  def index
    @blocks = Rails.root.glob("app/views/blocks/_*.html.erb").map { |file| file.basename.to_s.delete_prefix("_").delete_suffix(".html.erb") }
      .sort_by { |block| [ ORDER.index(block) || ORDER.size, block ] }
    @blocks &= [ params[:only] ] if params[:only]
    @sections = SECTIONS.select { |name, _| params[:only].blank? || params[:only] == "sections" || params[:only] == name }
    @chrome = CHROME.select { |name, _| params[:only].blank? || params[:only] == "chrome" || params[:only] == name }
  end

  # The headers and footers a layout's header and footer can render instead (app/views/headers, footers).
  CHROME = { "headers" => %w[ centered search pill ], "footers" => %w[ mast colophon ] }.freeze

  # The sections a page renders, each in every variant (app/views/sections; STOREFRONT.md).
  SECTIONS = { "products" => %w[ grid feature rail index ], "personalized" => %w[ split steps band ], "collections" => %w[ tiles index bento row ] }.freeze
end
