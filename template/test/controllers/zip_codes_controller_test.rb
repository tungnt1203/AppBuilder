require "test_helper"

class ZipCodesControllerTest < ActionDispatch::IntegrationTest
  test "a US ZIP code gives its state and city" do
    get zip_code_path("78701")
    assert_response :success
    assert_equal({ "state" => "TX", "city" => "Austin" }, response.parsed_body)

    get zip_code_path("99999")
    assert_response :not_found
  end
end
