# Development data for the preview. There are no sample products: the shop shows that its
# products are coming (products/_coming_soon) until the owner imports theirs from Printify, or
# describes them in the chat and they're seeded here, idempotently, with the owner's photos.
# Seed the store's settings (announcement, free shipping, delivery days) only as the owner says.

# Sample services and staff for the preview, when the app takes bookings (config.x.booking).
# Replace them with the owner's real services, team and hours when they give them.
if Rails.env.development? && Rails.configuration.x.booking && Service.none?
  services = [
    [ "Signature cut", "A consultation, wash, cut and style.", 60, 45 ],
    [ "Express trim", "A quick tidy-up between cuts.", 30, 25 ],
    [ "Color & gloss", "All-over color with a glossing treatment.", 120, 110 ]
  ].each_with_index.map do |(name, description, duration_minutes, price), position|
    Service.create!(name:, description:, duration_minutes:, price:, position:)
  end

  [ [ "Alex", [ 2, 3, 4, 5, 6 ] ], [ "Sam", [ 1, 2, 3, 4, 5 ] ] ].each_with_index do |(name, weekdays), position|
    StaffMember.create!(name:, position:, services:,
      working_hours_attributes: weekdays.map { |weekday| { weekday:, opens_at_text: "9:00", closes_at_text: "18:00" } })
  end
end
