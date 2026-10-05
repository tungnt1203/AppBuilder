# Default form builder (see config/application.rb): every form_with gets styled
# fields, so views only add classes for layout, never for looks.
class UiFormBuilder < ActionView::Helpers::FormBuilder
  INPUT_CLASSES = "block w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900 shadow-xs placeholder:text-gray-400 focus:border-brand-500 focus:outline-2 focus:outline-brand-500/20"
  INVALID_CLASSES = "border-red-400 focus:border-red-500 focus:outline-red-500/20"

  %i[ text_field email_field password_field number_field telephone_field url_field search_field
      date_field datetime_local_field time_field text_area file_field ].each do |input|
    define_method(input) do |method, options = {}|
      super(method, with_classes(options, input_classes(method)))
    end
  end

  def select(method, choices = nil, options = {}, html_options = {}, &block)
    super(method, choices, options, with_classes(html_options, input_classes(method)), &block)
  end

  def collection_select(method, collection, value_method, text_method, options = {}, html_options = {})
    super(method, collection, value_method, text_method, options, with_classes(html_options, input_classes(method)))
  end

  def check_box(method, options = {}, checked_value = "1", unchecked_value = "0")
    super(method, with_classes(options, "size-4 rounded border-gray-300 accent-brand-600"), checked_value, unchecked_value)
  end

  def label(method, text = nil, options = {}, &block)
    super(method, text, with_classes(options, "block text-sm font-medium text-gray-700"), &block)
  end

  def submit(value = nil, options = {})
    super(value, with_classes(options, @template.button_classes(:primary)))
  end

  # Label, input, hint and error message in one call:
  #   form.field :email_address, :email_field, hint: "We never share it", required: true
  def field(method, type = :text_field, label: nil, hint: nil, **options)
    @template.tag.div(class: "space-y-1.5") do
      @template.safe_join([
        label(method, label),
        public_send(type, method, options),
        (@template.tag.p(hint, class: "text-xs text-gray-500") if hint),
        error_message(method)
      ].compact)
    end
  end

  # Summary of all errors, for the top of a form.
  def errors
    @template.render("ui/form_errors", model: object) if object&.errors&.any?
  end

  private
    def input_classes(method)
      [ INPUT_CLASSES, (INVALID_CLASSES if error?(method)) ].compact.join(" ")
    end

    def error_message(method)
      @template.tag.p(object.errors.full_messages_for(method).first, class: "text-xs text-red-600") if error?(method)
    end

    def error?(method)
      object.respond_to?(:errors) && object.errors.include?(method)
    end

    def with_classes(options, classes)
      options.merge(class: [ classes, options[:class] ].compact.join(" "))
    end
end
