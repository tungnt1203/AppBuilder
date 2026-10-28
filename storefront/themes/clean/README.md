# clean

White, plain and product-first, after Shopify's Dawn: one full-width photo, then the products in a dense square grid. Fits almost any shop, and any shop whose buyers just want to see the designs (funny tees, fandom, pets, everyday gifts).

Reference: https://theme-dawn-demo.myshopify.com (look at it with `bin/look <url>` before changing anything).

## What it is

- White canvas, near-black text (#121212), one font (Assistant) at its regular weight, headings
  never bold. Square corners everywhere. Thin gray lines, no shadows, no gradients.
- Header: logo or name on the left, the collections beside it, search and cart on the right.
- Home: a full-width photo with a centered line and an outlined button (until there's a
  `hero_image`, the line beside the newest products' own photos: `home/_product_collage`), the shop's promises, the
  newest products in 4 columns (2 on phones) with an 8px gap, "Make it yours", the collections
  with "Title →" under each photo, the shop's story beside a photo.
- Product cards: square photo on #f3f3f3, small pill badges at its bottom left, the title small,
  the price under it.

## Make it the shop's

- **Brand color**: Dawn's buttons are near-black. Keep them so for most shops; give a shop with a
  strong color of its own that color as `--color-brand-600` (and its scale) in theme.css. The
  owner's `brand_color` setting replaces it.
- **Font**: Assistant, or one plain sans in its place when the shop needs a slightly different
  voice (Figtree, Manrope, Be Vietnam Pro). Still one family, regular weight for headings.
- **Photos**: `hero_image` (people wearing or using what the shop sells, or what its designs are
  about) and `story_image` as theme-setting defaults from `bin/images`. The hero carries the page:
  pick a calm, well-lit photo with room for the line in the middle.
- **Words**: `hero_title` says what the shop sells and to whom, in a few plain words; `story_title`
  and `story_text` say who makes it and why.

## Keep

The white, the square corners, the single regular-weight font, the dense grid, the quiet header.
Don't add colored bands, badges on headings, tilted or bordered stickers, shadows, emoji, extra
sections or a second accent color: Dawn's whole point is that it gets out of the products' way.
