# Development only, for the builder's preview: tells the builder (the page around
# the preview) about JavaScript errors and error pages while someone tries the app,
# so it can offer to fix them, and lets the owner point at a part of a page to talk
# about it. Never runs in production. Don't change or remove it.
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

          // Pointing: the builder turns it on, the element under the mouse is outlined,
          // and a click sends where it is instead of doing what it would do.
          let picking = false, box = null, hovered = null
          const cssName = (name) => window.CSS?.escape ? CSS.escape(name) : name
          const plainClass = (name) => ![ ":", "/", "[", "]", "!" ].some((character) => name.includes(character))
          const selectorOf = (element) => {
            const path = []
            for (let node = element; node && node.nodeType === 1 && path.length < 5; node = node.parentElement) {
              if (node.id) { path.unshift("#" + cssName(node.id)); break }
              let part = node.localName + [ ...node.classList ].filter(plainClass).slice(0, 2).map((name) => "." + cssName(name)).join("")
              const siblings = node.parentElement ? [ ...node.parentElement.children ].filter((child) => child.localName === node.localName) : []
              if (siblings.length > 1) part += ":nth-of-type(" + (siblings.indexOf(node) + 1) + ")"
              path.unshift(part)
              if (node === document.body) break
            }
            return path.join(" > ")
          }
          const outline = () => {
            if (!box || !hovered) return
            const rect = hovered.getBoundingClientRect()
            Object.assign(box.style, { top: rect.top + "px", left: rect.left + "px", width: rect.width + "px", height: rect.height + "px", display: "block" })
          }
          const setPicking = (on) => {
            picking = on
            if (on && !box) {
              box = document.createElement("div")
              Object.assign(box.style, { position: "fixed", zIndex: 2147483647, pointerEvents: "none", display: "none", borderRadius: "6px",
                outline: "2px solid #2f8f83", outlineOffset: "1px", background: "rgb(47 143 131 / 0.12)", transition: "all 60ms ease-out" })
              document.documentElement.append(box)
            }
            if (box && !on) box.style.display = "none"
            document.documentElement.style.cursor = on ? "crosshair" : ""
            if (!on) hovered = null
          }
          const stop = (event) => { if (picking) { event.preventDefault(); event.stopPropagation(); event.stopImmediatePropagation() } }

          window.addEventListener("message", (event) => {
            if (event.source === window.parent && event.data?.type === "preview:pick") setPicking(Boolean(event.data.on))
          })
          document.addEventListener("mousemove", (event) => {
            if (!picking || event.target === hovered) return
            hovered = event.target
            outline()
          }, true)
          window.addEventListener("scroll", outline, true)
          for (const type of [ "mousedown", "mouseup", "pointerdown", "pointerup", "submit" ]) document.addEventListener(type, stop, true)
          document.addEventListener("click", (event) => {
            if (!picking) return
            stop(event)
            const element = event.target
            const text = (element.innerText || element.value || element.getAttribute("alt") || element.getAttribute("aria-label") || element.getAttribute("placeholder") || "")
            window.parent.postMessage({ type: "preview:picked", page: page(), selector: selectorOf(element), tag: element.localName,
              text: text.replace(/\\s+/g, " ").trim().slice(0, 200), html: element.outerHTML.slice(0, 800) }, "*")
            setPicking(false)
          }, true)
          document.addEventListener("keydown", (event) => {
            if (!picking || event.key !== "Escape") return
            setPicking(false)
            window.parent.postMessage({ type: "preview:pick-ended" }, "*")
          }, true)
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
