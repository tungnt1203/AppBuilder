require "application_system_test_case"

class TrackingSystemTest < ApplicationSystemTestCase
  test "events reach the ad tags in the browser, once each" do
    stores(:main).update!(google_tag_id: "G-ABC1234")

    visit product_path(products(:tee))
    assert_google_events %w[ page_view view_item ]

    click_on "Add to cart"
    assert_text "added to your cart"
    assert_google_events %w[ page_view view_item page_view add_to_cart ]

    # Going back and forward again never sends the add to cart twice.
    go_back
    assert_selector "h1", text: "Cat Mom Tee"
    go_forward
    assert_text "Your cart"
    sleep 0.5
    assert_equal 1, google_events.count("add_to_cart")
  end

  private
    def google_events
      evaluate_script("(window.dataLayer || []).filter((entry) => entry[0] === 'event').map((entry) => entry[1])")
    end

    # Turbo keeps the page (and dataLayer) between visits, and fires its events just after it renders.
    def assert_google_events(expected)
      events = nil
      Timeout.timeout(Capybara.default_max_wait_time) do
        sleep 0.1 until (events = google_events) == expected
      end
    rescue Timeout::Error
      assert_equal expected, events
    end
end
