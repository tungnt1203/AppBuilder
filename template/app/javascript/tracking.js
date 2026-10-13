// Sends page views and the page's events (see app/controllers/concerns/tracking.rb) to the ad
// accounts the owner connected: Meta Pixel, TikTok Pixel, Google tag. Each event goes once, even
// when Turbo shows a page again from its cache (going back).
const NAMES = {
  view_content: { meta: "ViewContent", tiktok: "ViewContent", google: "view_item" },
  add_to_cart: { meta: "AddToCart", tiktok: "AddToCart", google: "add_to_cart" },
  initiate_checkout: { meta: "InitiateCheckout", tiktok: "InitiateCheckout", google: "begin_checkout" },
  purchase: { meta: "Purchase", tiktok: "CompletePayment", google: "purchase" }
}

function accounts() {
  const tag = document.querySelector("meta[name=tracking]")
  return tag ? JSON.parse(tag.content) : null
}

function alreadySent(id) {
  try {
    const sent = JSON.parse(sessionStorage.getItem("tracking-sent") || "[]")
    if (sent.includes(id)) return true
    sessionStorage.setItem("tracking-sent", JSON.stringify(sent.concat(id).slice(-50)))
  } catch {}
  return false
}

function send(to, event) {
  const names = NAMES[event.name]
  if (!names) return
  const ids = event.items.map((item) => item.id)

  if (to.meta && window.fbq) {
    fbq("track", names.meta, { content_ids: ids, content_type: "product", value: event.value, currency: event.currency,
      contents: event.items.map((item) => ({ id: item.id, quantity: item.quantity, item_price: item.price })),
      num_items: event.items.reduce((sum, item) => sum + item.quantity, 0) }, { eventID: event.id })
  }
  if (to.tiktok && window.ttq) {
    ttq.track(names.tiktok, { value: event.value, currency: event.currency,
      contents: event.items.map((item) => ({ content_id: item.id, content_name: item.name, content_type: "product", quantity: item.quantity, price: item.price })) },
      { event_id: event.id })
  }
  if (to.google && window.gtag) {
    gtag("event", names.google, { currency: event.currency, value: event.value, transaction_id: event.order ? String(event.order) : undefined,
      items: event.items.map((item) => ({ item_id: item.id, item_name: item.name, price: item.price, quantity: item.quantity })) })
  }
}

document.addEventListener("turbo:load", () => {
  const to = accounts()
  if (!to) return

  if (to.meta && window.fbq) fbq("track", "PageView")
  if (to.tiktok && window.ttq) ttq.page()
  if (to.google && window.gtag) gtag("event", "page_view", { page_location: location.href, page_title: document.title })

  const data = document.getElementById("tracking-events")
  const events = data ? JSON.parse(data.textContent) : []
  events.forEach((event) => { if (!alreadySent(event.id)) send(to, event) })
})
