xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.rss version: "2.0", "xmlns:g" => "http://base.google.com/ns/1.0" do
  xml.channel do
    xml.title Rails.configuration.x.app_name
    xml.link root_url
    xml.description t(".description", app: Rails.configuration.x.app_name)

    @products.each do |product|
      color_name = product.option_names.find { |name| color_option?(name) }
      size_name = product.size_option_name
      description = strip_tags(product.description.to_s).squish.presence || product.title
      photos = product.images.select(&:representable?)

      product.variants.each do |variant|
        values = product.option_names.zip(variant.option_values).to_h
        image = product.image_for(variant)
        xml.item do
          xml.tag! "g:id", variant.catalog_id
          xml.tag! "g:item_group_id", "product-#{product.id}" if product.has_options?
          xml.tag! "g:title", [ product.title, variant.title ].compact.join(" – ").truncate(150)
          xml.tag! "g:description", description.truncate(5000)
          xml.tag! "g:link", product_url(product, options: variant.option_values.presence)
          xml.tag! "g:image_link", url_for(image.variant(:large)) if image&.representable?
          (photos - [ image ]).first(10).each { |photo| xml.tag! "g:additional_image_link", url_for(photo.variant(:large)) }
          xml.tag! "g:availability", variant.buyable? ? "in_stock" : "out_of_stock"
          xml.tag! "g:condition", "new"
          xml.tag! "g:brand", Rails.configuration.x.app_name
          if variant.on_sale?
            xml.tag! "g:price", feed_price(variant.compare_at_price_cents, @store.currency)
            xml.tag! "g:sale_price", feed_price(variant.price_cents, @store.currency)
          else
            xml.tag! "g:price", feed_price(variant.price_cents, @store.currency)
          end
          xml.tag! "g:color", values[color_name] if color_name
          xml.tag! "g:size", values[size_name] if size_name
          xml.tag! "g:identifier_exists", "no"
        end
      end
    end
  end
end
