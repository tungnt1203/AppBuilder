require "test_helper"

class Admin::StaffMembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    enable_booking
    sign_in_as users(:staff)
  end

  test "adds a staff member with their hours and services" do
    get new_admin_staff_member_path
    assert_response :success

    post admin_staff_members_path, params: { staff_member: { name: "Hoa", active: "1", service_ids: [ "", services(:haircut).id ],
      working_hours_attributes: { "0" => { weekday: 1, opens_at_text: "9:00", closes_at_text: "18:00" }, "1" => { weekday: 2, opens_at_text: "", closes_at_text: "" } } } }

    hoa = StaffMember.find_by!(name: "Hoa")
    assert_redirected_to edit_admin_staff_member_path(hoa)
    assert_equal [ [ 540, 1080 ] ], hoa.hours_on(1)
    assert_not hoa.works_on?(2)
    assert_equal [ services(:haircut) ], hoa.services.to_a

    get edit_admin_staff_member_path(hoa)
    assert_select "input[value=?]", "18:00"
  end

  test "deleting keeps their appointments" do
    delete admin_staff_member_path(staff_members(:mai))
    assert_nil appointments(:upcoming).reload.staff_member
  end
end
