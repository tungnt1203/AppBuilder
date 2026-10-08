require "test_helper"

class Admin::ServicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    enable_booking
    sign_in_as users(:staff)
  end

  test "lists, adds with who does it, changes and deletes services" do
    get admin_services_path
    assert_select "a[href=?]", edit_admin_service_path(services(:haircut))

    post admin_services_path, params: { service: { name: "Beard trim", duration_minutes: 20, price: "15", status: "active", staff_member_ids: [ "", staff_members(:linh).id ] } }
    service = Service.find_by!(name: "Beard trim")
    assert_equal [ staff_members(:linh) ], service.staff_members.to_a
    assert_equal 1500, service.price_cents

    patch admin_service_path(service), params: { service: { status: "hidden" } }
    assert service.reload.hidden?

    delete admin_service_path(services(:haircut))
    assert_nil appointments(:upcoming).reload.service
    assert_equal "Haircut", appointments(:upcoming).service_name
  end
end
