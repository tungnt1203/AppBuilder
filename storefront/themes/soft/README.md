# soft

Gentle and warm, after Shopify's Sense: a cream canvas, one rounded sans, rounded cards lifted by a soft shadow, a pale gradient behind the first card. For gifts for moms, babies and families, pets, self-care, cozy and wellness, personalized keepsakes.

Reference: https://theme-sense-demo.myshopify.com (look at it with `bin/look <url>` before changing anything).

## What it is

- Cream canvas (#f6f4ee), dark plum-gray text (#2e2a39), Nunito at medium weight for headings
  and regular for text. Rounded corners (14px cards, 11px buttons). Cards on a soft shadow.
- One pale two-color gradient (lime #e2f89c into blush #fbe3e1) behind the first screen's card,
  the announcement bar and the story band, nowhere else. A deep plum (#9b046f) for badges and
  links; the hero's button is dark with the gradient's color in its text, as on Sense.
- Header: search on the left, the name or logo centered, the cart on the right, the collections in
  a centered row underneath.
- Home: a big rounded photo with the gradient card over its edge, the promises, the newest
  products as lifted cards, "Make it yours", the story on the gradient beside a photo, the
  collections.
- Product cards: a rounded lifted card, square photo, title and price centered under it.

## Make it the shop's

- **Gradient**: `--color-accent` (first color) and `--soft-to` (second) in theme.css: keep both
  pale (peach #ffe1c7 into lilac #e9ddff, mint #d7f5e3 into butter #fff4c2, sky #d9ecff into
  blush #fde2e4).
- **Deep color**: `--color-brand-600` and its scale for links and badges (plum, deep teal #0f5e5a,
  cocoa #6b3f2a). The owner's `brand_color` setting replaces it.
- **Font**: Nunito, or one rounded sans in its place (Quicksand, Plus Jakarta Sans). Not Poppins: it reads as a template default.
- **Photos**: `hero_image` (close and warm: hands, faces, pets, the product in use, soft light)
  and `story_image`, as theme-setting defaults from `bin/images`.
- **Words**: `hero_title` is short and warm ("Made with their name on it"); `hero_text` says what
  the shop makes in one sentence.

## Keep

The cream, the rounded cards on a soft shadow, the single gradient, one font. Don't add borders
with hard offset shadows, tilted stickers, extra gradients or glows, emoji, decorative patterns
or more than one bright color.
