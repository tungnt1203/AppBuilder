# The extra fields on products (Settings → Fields): material, care, anything the catalog doesn't have.
class ShopAdmin::CustomFieldsController < ShopAdmin::BaseController
  before_action :require_administrator

  def edit
    @definitions = CustomFieldDefinition.ordered
  end

  def update
    rows = field_rows
    if rows.map { |row| row[:key] }.uniq.size != rows.size
      @definitions = CustomFieldDefinition.ordered
      flash.now[:alert] = t(".duplicate")
      return render :edit, status: :unprocessable_entity
    end

    CustomFieldDefinition.transaction do
      kept = rows.each_with_index.map { |row, position| save_definition(row, position) }
      CustomFieldDefinition.where.not(id: kept.map(&:id)).destroy_all
    end
    redirect_to edit_shop_admin_custom_fields_path, notice: t(".notice")
  rescue ActiveRecord::RecordInvalid => error
    @definitions = CustomFieldDefinition.ordered
    flash.now[:alert] = error.record.errors.full_messages.to_sentence
    render :edit, status: :unprocessable_entity
  end

  private
    def field_rows
      Array(params.dig(:custom_fields, :definitions)).filter_map do |row|
        row = row.permit(:id, :key, :label, :field_type).to_h.symbolize_keys
        key = row[:key].to_s.parameterize(separator: "_").presence || row[:label].to_s.parameterize(separator: "_")
        next if row[:label].to_s.squish.blank? || key.blank?

        row.merge(key:)
      end
    end

    def save_definition(row, position)
      record = CustomFieldDefinition.find_by(id: row[:id]) || CustomFieldDefinition.new
      record.update!(key: row[:key], label: row[:label], field_type: row[:field_type].presence || "text", position:)
      record
    end
end
