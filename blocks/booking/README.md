# booking

Appointments for apps made with AppBuilder, for businesses people book a time with: salons,
clinics, spas, tutors. Services (length, price), staff members and their weekly hours, time off
and closures, the free times of a day (`Availability`), booking them (`Booking`, which checks the
time again as it books), the customer's appointment page by token, cancellations, and the
emails: confirmation, a reminder the day before, cancellation.

It runs inside an app made from `template/`, next to the `shop` block (it uses the shop's money
helpers and `Store` for the currency, contact email and address). Apps turn it on with
`config.x.booking`; the screens are the app's, like the shop's. Each app gets a copy in
`vendor/blocks/booking`, which it doesn't change, and adds to the models in
`app/models/<model>/extension.rb` (see `Bookings.extend_model`).
