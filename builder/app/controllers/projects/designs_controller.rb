# The Design tab, in the chat's place: the storefront's theme, its colors, fonts, corners and
# width (tried on live in the preview, saved as a version without a turn of the agent), and its
# words and photos (the shop's theme settings, as in the admin).
class Projects::DesignsController < ApplicationController
  before_action :set_project

  def show
    load_panel
  end

  # Colors, fonts and shape (ProjectDesign).
  def update
    load_panel
    @design.assign_attributes(params.expect(design: %i[ brand background text accent heading_font text_font corners width ]))

    if !@project.accepts_messages?
      @design.errors.add(:base, "Wait until the current step finishes.")
      render :show, status: :unprocessable_entity
    elsif @design.save
      saved "Saved as a version. Undo it from History."
    else
      @design.errors.add(:base, "Nothing changed.") if @design.errors.empty?
      render :show, status: :unprocessable_entity
    end
  rescue ProjectShell::Error => error
    @design.errors.add(:base, "Saved as a version, but the preview's styles didn't rebuild: #{error.message.lines.first}")
    render :show, status: :unprocessable_entity
  end

  # Another theme (ProjectTheme); files changed for this shop are listed before they're replaced.
  def theme
    load_panel
    name = params.expect(:theme)
    changed = @themes.changed_files(name)

    if !@project.accepts_messages?
      @theme_error = "Wait until the current step finishes."
      render :show, status: :unprocessable_entity
    elsif changed.any? && params[:force] != "1"
      @theme_conflict = { name:, files: changed }
      render :show, status: :unprocessable_entity
    else
      @themes.switch(name)
      saved "Now on the #{name.capitalize} layout, as a version. Undo it from History.", section: :theme
    end
  rescue ProjectShell::Error => error
    @theme_error = "The theme didn't switch: #{error.message.lines.first}"
    render :show, status: :unprocessable_entity
  end

  # Words and photos (ProjectContent).
  def content
    load_panel
    texts = params.fetch(:content, {}).permit(texts: {})[:texts].to_h
    uploads = params.fetch(:content, {}).permit(photos: {})[:photos].to_h

    if @content.save(texts:, uploads:)
      saved "Saved. The shop shows them now, the live one too.", section: :content
    else
      render :show, status: :unprocessable_entity
    end
  end

  # Stock photos for an image field (StockPhotos), in that field's frame; More photos brings the
  # next page into the same grid.
  def photos
    @key = params.expect(:key)
    @query = params[:q].to_s.strip
    @page = params[:page].to_i.clamp(1, 20)
    @photos = begin
      StockPhotos.search(@query, page: @page)
    rescue StandardError => error
      Rails.logger.warn("Stock photo search failed: #{error.message}")
      @search_error = "The photo search didn't answer. Try again in a moment."
      []
    end
  end

  # One of them becomes the field's photo (ProjectContent#use_photo), as a version.
  def photo
    load_panel
    choice = JSON.parse(params.expect(:choice))
    @content.use_photo(choice["key"].to_s, url: choice["url"], credit: choice["credit"].to_s.squish, page: choice["page"].to_s)
    StockPhotos.used(choice["download"]) if choice["download"]
    saved "Photo changed, as a version. Undo it from History.", section: :content
  rescue JSON::ParserError, ArgumentError => error
    @content.errors << error.message
    render :show, status: :unprocessable_entity
  end

  private
    def set_project
      @project = find_project(params[:project_id])
    end

    def load_panel
      @design = ProjectDesign.for(@project)
      @themes = ProjectTheme.new(@project)
      @content = ProjectContent.new(@project)
    end

    # The studio's own refresh skips the window that saved, so the panel and History are brought
    # up to date here; the preview reloads (preview#designed).
    def saved(notice, section: :look)
      load_panel
      render turbo_stream: [
        turbo_stream.update("design", partial: "projects/designs/panel", locals: { notice:, section: }),
        turbo_stream.update("versions", partial: "projects/versions", locals: { project: @project })
      ]
    end
end
