# shop

The shop core every app made with AppBuilder starts with: catalog (products, variants,
collections), cart, guest checkout, orders and their timeline, card payments on Stripe Checkout,
the store's settings and the order emails.

It runs inside an app made from `template/` (it uses the app's `ApplicationRecord`,
`ApplicationMailer`, `ApplicationJob`, `User` and `Customer`). Each app gets a copy in
`vendor/blocks/shop`, which it doesn't change: an update of the core replaces that folder.

An app builds its own screens on the core and adds to its models in
`app/models/<model>/extension.rb` (see `Shop.extend_model`). Its views, mailer templates and
translations override the engine's ones with the same name.
