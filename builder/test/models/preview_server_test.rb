require "test_helper"

class PreviewServerTest < ActiveSupport::TestCase
  test "reads the error out of Rails' development error page" do
    html = <<~HTML
      <header role="banner"><h1>ActionView::Template::Error</h1></header>
      <p><code>Rails.root: /apps/clinic</code></p>
      <div id="container">
        <p>Showing <i>app/views/shops/show.html.erb</i> where line <b>#3</b> raised:</p>
        <div class="exception-message"><div class="message">undefined local variable or method 'shop'</div></div>
      </div>
    HTML

    assert_equal "ActionView::Template::Error\nShowing app/views/shops/show.html.erb where line #3 raised:\nundefined local variable or method 'shop'",
      PreviewServer.error_from(html)
  end

  test "nothing to read from other pages" do
    assert_nil PreviewServer.error_from("<html><body>Internal Server Error</body></html>")
  end
end
