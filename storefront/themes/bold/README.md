# bold

Dark and loud, after Shopify's Ride: huge condensed uppercase headings on near-black, one electric color on the buttons. For streetwear, gym and sport, gaming, music and fandom tees, anything sold with attitude to a young crowd.

Reference: https://theme-ride-demo.myshopify.com (look at it with `bin/look <url>` before changing anything).

## What it is

- Near-black canvas (#1f1f21), white text, Oswald (uppercase, medium weight) for headings and
  Figtree for text. Square corners. No shadows, no gradients, no borders around cards.
- One loud color (lime #e3fc02 by default) on the buttons, the announcement bar, the cart count
  and the "Personalize" badge, and nowhere else. Its text is dark (`on-brand`).
- Header: the name or logo big on the left, the collections in small uppercase beside it.
- Home: a split first screen (the line in huge type, a few words and the button beside a tall
  photo), the promises, the newest products in 4 wide-spaced columns, "Make it yours", the story
  beside a photo, the collections.
- Product cards: tall 4:5 photo, the title in the headings' uppercase, the price under it.

## Make it the shop's

- **Loud color**: lime, or the shop's own (safety orange #ff5a1f, electric blue #2f6bff, hot pink
  #ff2e88): set `--color-brand-600` and its scale (50–200 dark tints, 700–950 light ones) in
  theme.css; `--color-on-brand` is the text on it (dark on light colors, white on dark ones). The
  owner's `brand_color` setting replaces it.
- **Font**: Oswald, or Bebas Neue / Montserrat (heavy) for the headings; Figtree stays.
- **Photos**: `hero_image` (people in motion wearing what the shop sells, shot hard and bright)
  and `story_image`, as theme-setting defaults from `bin/images`.
- **Words**: `hero_title` is short and punchy (two to five words in uppercase: "BUILT FOR LEG
  DAY"), plain words, not a pun formula; `hero_text` says what the shop sells in one sentence.

## Keep

The dark canvas, one loud color used sparingly, the uppercase headings, the square corners, the
wide spacing between products. Don't add a second accent, outlined or tilted stickers, offset
shadows, marquees of jokes, emoji, neon glows or fake terminal and comic effects.
