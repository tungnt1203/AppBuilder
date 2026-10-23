# editorial

Calm and refined, after Shopify's Craft: a warm gray canvas, a light serif, the logo centered over a centered menu, products in cards drawn with a hairline. For art prints and posters, home goods, mugs, candles, jewelry, stationery, slow fashion, anything sold at a higher price or as a considered gift.

Reference: https://theme-craft-demo.myshopify.com (look at it with `bin/look <url>` before changing anything).

## What it is

- Warm light-gray canvas (#efecec), near-black text, Trirong (light weight) for headings and
  Quattrocento Sans for text. One deep color (forest #2c332f) on the buttons, the announcement
  bar and the footer. Cards and photos barely rounded (6px), drawn with a hairline, no shadows.
- Header: search on the left, the name or logo large and centered, the cart on the right, the
  collections in a centered row underneath.
- Home: a centered line in the serif, a wide photo, the collections as hairline cards three to a
  row, the newest products in 3 columns, "Make it yours", the story over a wide
  photo with a centered statement under it.
- Product cards: a hairline card, 4:5 photo, the title in the serif, the price under it.

## Make it the shop's

- **Deep color**: forest, or the shop's own deep tone (espresso #3b2a22, ink blue #1f2a44,
  aubergine #3a2433, olive #3d4127): set `--color-brand-600` and its scale in theme.css. The
  owner's `brand_color` setting replaces it. The canvas can warm (#f1ece4, paper) or cool
  (#eceeee) a touch; it stays light and quiet.
- **Font**: Trirong, or another light serif for the headings (Lora, Cormorant Garamond set large,
  Playfair Display at 400); the text font stays a calm sans.
- **Photos**: `hero_image` (the products in a real room or in hands, soft daylight) and
  `story_image` (the making, the materials), as theme-setting defaults from `bin/images`.
- **Words**: `hero_title` is one calm sentence about what the shop makes ("Prints for quiet
  walls"); `story_text` is the shop's belief in one or two sentences.

## Keep

The quiet canvas, the light serif, the hairlines, the centered header, the room around things.
Don't add bold headings, bright accents, gradients, tilted stickers, badges on headings, emoji or
decorative patterns.
