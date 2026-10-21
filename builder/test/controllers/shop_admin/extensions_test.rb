require "test_helper"

class ShopAdmin::ExtensionsTest < ActionDispatch::IntegrationTest
  setup { in_shop_admin }
  setup { sign_in_as users(:cats_admin) }

  test "staff can't edit pages" do
    sign_in_as users(:cats_staff)
    get shop_admin_pages_path
    assert_redirected_to shop_admin_root_path
  end

  test "an admin writes a page, a menu and a form, and reads a message" do
    get new_shop_admin_page_path
    assert_response :success
    post shop_admin_pages_path, params: { page: { title: "About", body: "We print tees.", published: "1", faqs: [ { question: "How long?", answer: "A week." }, { question: "", answer: "" } ] } }
    assert_redirected_to shop_admin_pages_path
    follow_redirect!
    assert_select "a", text: /About/

    post shop_admin_menus_path, params: { menu: { title: "Header", key: "header", items: [ { label: "About", url: "/pages/about" } ] } }
    assert_redirected_to shop_admin_menus_path

    post shop_admin_forms_path, params: { form: { title: "Contact", key: "contact", fields: [ { label: "Email", key: "email", type: "email", required: "1" } ] } }
    assert_redirected_to edit_shop_admin_form_path("contact")

    submission = ActsAsTenant.with_tenant(shops(:cats)) do
      form = Form.find_by!(key: "contact")
      message = form.submissions.build
      assert message.submit("email" => "a@b.co")
      message
    end
    get shop_admin_form_submission_path("contact", submission)
    assert_response :success
    assert_match "a@b.co", response.body
  end

  test "theme settings and custom fields" do
    get edit_shop_admin_theme_setting_path
    assert_select "h2", text: "No theme settings yet"

    ActsAsTenant.with_tenant(shops(:cats)) do
      ThemeSetting.apply_schema!([ { "key" => "hero_title", "type" => "text", "label" => "Hero", "default" => "Hello" },
        { "key" => "hero_image", "type" => "image", "label" => "Photo", "default" => "https://images.unsplash.com/photo-1" } ])
    end
    get edit_shop_admin_theme_setting_path
    assert_select "img[src=?]", "https://images.unsplash.com/photo-1"
    patch shop_admin_theme_setting_path, params: { theme_setting: { values: { hero_title: "Cats" } } }
    assert_redirected_to edit_shop_admin_theme_setting_path
    assert_equal "Cats", ActsAsTenant.with_tenant(shops(:cats)) { ThemeSetting.current.values["hero_title"] }

    patch shop_admin_custom_fields_path, params: { custom_fields: { definitions: [ { label: "Material", key: "material", field_type: "text" }, { label: "", key: "" } ] } }
    assert_equal [ "material" ], ActsAsTenant.with_tenant(shops(:cats)) { CustomFieldDefinition.pluck(:key) }

    patch shop_admin_product_path(products(:tee)), params: { product: { custom_fields: { material: "Cotton" }, buyer_inputs: [ { label: "Name on the shirt", key: "print_name", max_length: "20", required: "1" } ] } }
    product = ActsAsTenant.with_tenant(shops(:cats)) { products(:tee).reload }
    assert_equal "Cotton", product.custom_fields["material"]
    assert_equal "print_name", product.buyer_inputs.sole["key"]
  end

  test "custom fields can take a removed field's key, or swap keys, in one save" do
    material, care = ActsAsTenant.with_tenant(shops(:cats)) do
      definitions = [ CustomFieldDefinition.create!(key: "material", label: "Material"), CustomFieldDefinition.create!(key: "care", label: "Care") ]
      products(:tee).update!(custom_fields: { "material" => "Cotton", "care" => "Cold wash" })
      definitions
    end

    patch shop_admin_custom_fields_path, params: { custom_fields: { definitions: [
      { id: material.id, label: "Care", key: "care" }, { id: care.id, label: "Material", key: "material" } ] } }
    assert_redirected_to edit_shop_admin_custom_fields_path
    assert_equal({ "material" => "Cold wash", "care" => "Cotton" }, ActsAsTenant.with_tenant(shops(:cats)) { products(:tee).reload.custom_fields })

    patch shop_admin_custom_fields_path, params: { custom_fields: { definitions: [ { id: material.id, label: "Material", key: "material" } ] } }
    assert_redirected_to edit_shop_admin_custom_fields_path
    ActsAsTenant.with_tenant(shops(:cats)) do
      assert_equal [ [ material.id, "material" ] ], CustomFieldDefinition.pluck(:id, :key)
      assert_equal({ "material" => "Cotton" }, products(:tee).reload.custom_fields)
    end
  end
end
