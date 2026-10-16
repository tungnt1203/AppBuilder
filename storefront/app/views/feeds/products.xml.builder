xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.rss version: "2.0", "xmlns:g" => "http://base.google.com/ns/1.0" do
  xml.channel do
    xml.title current_shop.name
    xml.link root_url
    xml.description t(".description", app: current_shop.name)

    @products.each do |product|
      names = product.options.map(&:name)
      color_name = product.options.find(&:color?)&.name
      size_name = product.size_option
      description = strip_tags(product.description.to_s).squish.presence || product.title

      product.variants.each do |variant|
        values = names.zip(variant.options).to_h
        image = product.image_for(variant)
        xml.item do
          xml.tag! "g:id", variant.catalog_id
          xml.tag! "g:item_group_id", "product-#{product.slug}" if names.any?
          xml.tag! "g:title", [ product.title, variant.title ].compact.join(" – ").truncate(150)
          xml.tag! "g:description", description.truncate(5000)
          xml.tag! "g:link", product_url(product, options: variant.options.presence)
          xml.tag! "g:image_link", image.url(:large) if image
          (product.images - [ image ]).first(10).each { |photo| xml.tag! "g:additional_image_link", photo.url(:large) }
          xml.tag! "g:availability", variant.available? ? "in_stock" : "out_of_stock"
          xml.tag! "g:condition", "new"
          xml.tag! "g:brand", current_shop.name
          if variant.on_sale?
            xml.tag! "g:price", StorefrontKit::Money.feed(variant.compare_at_price_cents, current_shop.currency)
            xml.tag! "g:sale_price", StorefrontKit::Money.feed(variant.price_cents, current_shop.currency)
          else
            xml.tag! "g:price", StorefrontKit::Money.feed(variant.price_cents, current_shop.currency)
          end
          xml.tag! "g:color", values[color_name] if color_name
          xml.tag! "g:size", values[size_name] if size_name
          xml.tag! "g:identifier_exists", "no"
        end
      end
    end
  end
end
