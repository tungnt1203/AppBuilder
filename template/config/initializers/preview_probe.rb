# Development only, for the builder's preview: tells the builder (the page around
# the preview) about JavaScript errors and error pages while someone tries the app,
# so it can offer to fix them. Never runs in production. Don't change or remove it.
if Rails.env.development?
  class PreviewProbe
    PATH = "/_preview/probe.js"
    REPORTED_STATUSES = [ 404, *500..599 ]

    SCRIPT = <<~JS
      (() => {
        if (window.parent === window) return
        const script = document.currentScript
        const page = () => location.pathname + location.search
        const send = (error) => window.parent.postMessage({ type: "preview:error", page: page(), ...error }, "*")
        const text = (selector) => document.querySelector(selector)?.textContent.replace(/\\s+/g, " ").trim()

        if (!window.__previewProbe) {
          window.__previewProbe = true
          window.addEventListener("error", (event) => {
            if (!event.message) return // a resource that failed to load, not a script error
            send({ kind: "javascript", message: event.message, source: event.filename && `${event.filename.replace(location.origin, "")}:${event.lineno}:${event.colno}`, stack: event.error?.stack })
          })
          window.addEventListener("unhandledrejection", (event) => {
            const reason = event.reason
            send({ kind: "javascript", message: `Unhandled promise rejection: ${reason?.message || reason}`, stack: reason?.stack })
          })
        }

        // Rails' error page in development: heading, where it happened, and the message.
        const status = Number(script?.dataset.status)
        if (status) {
          const report = () => {
            const where = [ ...document.querySelectorAll("p") ].map((node) => node.textContent.trim()).find((line) => line.startsWith("Showing"))
            const message = [ text("header h1"), where, text(".exception-message .message") || text("h2") ].filter(Boolean).join("\\n")
            send({ kind: "page", status, message: message || `The page answered ${status}.` })
          }
          document.readyState === "loading" ? document.addEventListener("DOMContentLoaded", report, { once: true }) : report()
        }
      })()
    JS

    def initialize(app)
      @app = app
    end

    def call(env)
      return [ 200, { "content-type" => "text/javascript", "cache-control" => "no-store" }, [ SCRIPT ] ] if env["PATH_INFO"] == PATH

      status, headers, body = @app.call(env)
      return [ status, headers, body ] unless headers["content-type"].to_s.start_with?("text/html")

      html = +""
      body.each { |part| html << part }
      body.close if body.respond_to?(:close)
      tag = %(<script src="#{PATH}"#{%( data-status="#{status}") if REPORTED_STATUSES.include?(status.to_i)}></script>)
      html.sub!(%r{</head>}i) { "#{tag}</head>" } || html.sub!(%r{</body>}i) { "#{tag}</body>" }
      headers.delete("content-length")
      [ status, headers, [ html ] ]
    end
  end

  Rails.application.config.middleware.insert_before 0, PreviewProbe
end
