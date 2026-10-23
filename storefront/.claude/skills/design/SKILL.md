---
name: design
description: How this storefront should look. Picking its theme (bin/theme, DESIGN.md), making the theme the shop's own (colors, fonts, photos, words), the signs that make a shop look AI-made, copying a site the owner shows, and checking the result. Use before the first screen of a new storefront, whenever you build or restyle a page visitors see, and when the owner asks about the look.
---

# Design

Buyers arrive from an ad and decide in seconds whether this is a real shop. A shop that looks
generated (a pill label over a big headline, tilted stickers, a pun headline, polka dots, cards
with hard shadows, a gradient blob in a corner) loses them, however well it works. The shops that
sell look like the best Shopify themes: made by a designer, plain, led by photos and products,
with almost no decoration.

So you don't design storefronts from scratch. Each one starts from a **theme**: a close copy of a
Shopify theme that sells well, already built here (header, footer, home page, product cards, and
the colors, fonts and corners every other page follows). You pick the theme that fits the shop,
then make it the shop's with its colors, a font, its photos and its words. That is most of the
work, and restraint is the skill: what you leave out matters more than what you add.

## What decides the look

What the owner asked for comes first (SPEC.md, "Asked"), then DESIGN.md, then the theme. A detailed
request leaves little to choose; a one-line one leaves the choice of theme, colors, photos and
words to you. When the owner shows a site (a link or a screenshot), that site is the look
("Copying a site the owner shows", below).

## 1. Pick the theme

| Theme | After | For shops selling |
|---|---|---|
| **clean** | Dawn: white, one plain font, square corners, a full-width photo, a dense square grid | almost anything; funny and graphic tees, fandom, pets, everyday gifts; the default |
| **bold** | Ride: near-black, huge condensed uppercase headings, one loud color | streetwear, gym and sport, gaming, music, attitude |
| **editorial** | Craft: warm gray, a light serif, centered logo, hairline cards | art prints, posters, home goods, mugs, candles, jewelry, considered gifts |
| **soft** | Sense: cream, one rounded sans, rounded lifted cards, a pale gradient card | gifts for moms, babies, families and pet lovers, self-care, cozy, keepsakes |

`bin/theme` lists them and which is in place (a new storefront starts with **clean**). Read
`themes/<name>/README.md` (what it is, what to change, what to keep), look at its reference store
with `bin/look <url>`, then put it in place with `bin/theme <name>` and `bin/rails tailwindcss:build`.
Pick by who buys and what they buy, not by the shop's jokes or name: a cat-pun tee shop is a
clean or soft shop with cat photos, not a comic book.

Write DESIGN.md before building anything else, in place of "Not decided yet":

```markdown
# Design

**For:** who opens this shop, on what device, in what moment (e.g. "dog owners tapping an Instagram ad on their phone in the evening").
**Theme:** clean (Dawn), and why it fits.
**Changed from it:** the colors (brand, and canvas if changed), the font if changed, and why.
**Photos:** what the hero and story photos show, and the light and mood they share.
**Words:** the voice in a few words, and the home page's headline.
```

On later turns, read DESIGN.md first and stay inside it. When the owner asks for a different look,
pick the theme that fits it (`bin/theme <name>`; it refuses to overwrite files changed for this
shop until you've carried over what they need, then `--force`), and update DESIGN.md.

## 2. Make it the shop's

Change these, and little else:

- **Colors**, in `app/assets/tailwind/theme.css`: the brand scale 50–950 (600 is the button color,
  `--color-on-brand` the text on it: white on deep colors, dark on light ones like lime or butter
  yellow), and the canvas and ink only within what the theme's README allows. Use colors from the
  shop's world (a logo the owner gave, the colors of their designs), not from the category
  ("pets = orange"). The owner can set `brand_color` in the admin; it replaces the brand scale
  (`layouts/_theme_colors`), and the text on it turns dark by itself when it's light.
- **Font**: the theme's, or one of the alternatives its README names. Families are self-hosted in
  `app/assets/fonts` and declared in `app/assets/tailwind/fonts.css`; set `--font-display` and
  `--font-sans` in theme.css. One family, two at most.

  | Family | Character |
  |---|---|
  | Assistant | plain humanist sans (Dawn) |
  | Figtree | sturdy geometric sans (Ride's text) |
  | Oswald | tall condensed display, uppercase (Ride's headings) |
  | Trirong | light, calm serif (Craft's headings) |
  | Quattrocento Sans | quiet humanist sans (Craft's text) |
  | Poppins | rounded geometric sans (Sense) |
  | Manrope, Be Vietnam Pro, Plus Jakarta Sans | neutral modern sans |
  | Quicksand, Nunito | soft, rounded |
  | Montserrat, Bebas Neue | heavy display |
  | Lora, Cormorant Garamond, Playfair Display, Fraunces | serifs |

- **Photos**: the home page's `hero_image` and `story_image` theme settings. They carry the page,
  so choose them carefully (section 5).
- **Words**: `hero_title`, `hero_text`, `story_title`, `story_text`, `hero_button` (section 4), as
  theme-setting defaults in `config/theme_settings.yml`, so the owner can change them.

Leave the theme's layout, spacing, type sizes, corners, borders and the shared pages (product page,
cart, checkout, order) as they are unless the owner asks for a change. They already follow the
theme's colors, fonts and corners.

## 3. What makes a shop look AI-made: never do these

- A small pill or uppercase label above a headline ("NEW DROP", "MADE WITH LOVE"), or over a section.
- Tilted stickers, speech bubbles, "POW" bursts, stamps, starbursts, hand-drawn arrows.
- 2px ink borders with hard offset shadows; pill buttons with shadows; every corner very round.
- Polka dots, grain, halftone, grids of dots, glows, gradient blobs, more than one gradient.
- A marquee of jokes or puns; a fake terminal, comic, ECG line, ticket stub or other gimmick that
  acts out the shop's theme.
- Emoji as icons; an icon in a tinted circle beside every line; an arrow in every button.
- A split hero with a pale tinted box on one side and a floating, rotated photo on the other.
- A headline built as a pun formula ("Big cat energy, soft cotton."), "Elevate your…", "Crafted
  with love", "Not just a tee, a statement", exclamation marks.
- Many sections with little in them: lots of empty space and only three products in view.
- Several bright colors, or the brand color on big bands, headings and backgrounds at once.

If you're adding something to make the shop "memorable", stop: real shops are remembered for their
products and photos. Themes have none of these; keep it that way.

## 4. Words

Write like the owner of a real shop, not like an ad. Plain, specific, short.

- `hero_title`: what the shop sells and who it's for, in a few words: "Tees for nurses who've
  seen it all", "Your dog's face on a hoodie", "Prints for quiet walls". The design or the buyer,
  not the brand's feelings. No puns unless the owner wrote one.
- `hero_text`: one sentence with a concrete fact: what it is, how it's made, how fast it ships.
- Section headings are plain names: "New arrivals", "Shop by collection", "Make it yours",
  "Our story". Buttons say where they go: "Shop all", "Shop hoodies".
- `story_title` / `story_text`: who makes it and why, in the owner's facts (their words, their
  city, their dog). Never invent a founder, a history or numbers.
- Real reviews only, from the shop. No invented quotes, counts or urgency.

## 5. Photos

Products imported from Printify come with their mockups, and the owner adds photos in the admin;
a collection's photo is its first product's (`collection_image`). Don't invent products to fill a
grid: a shop without products shows `products/_coming_soon`.

The home page's lifestyle photos are theme settings of type `image` with the `bin/images` link as
their `default` (`hero_image`, `story_image`; add one for any other photo the owner should be able
to swap), read with `theme_setting(:key)`:

- What the shop's buyers and designs are about, and people wearing or using what it sells, in the
  theme's light and mood: search for that ("woman laughing in oversized tee golden hour", "dog
  owner hugging golden retriever park"), not for "t-shirt". Stock photos are never product photos:
  never show one as if it were the shop's product.
- `bin/images "<what the photo should show>"` searches (English words; `--count 5`,
  `--orientation portrait|square|landscape`); `bin/images --check <links>` checks Unsplash links you
  know. Use Unsplash links exactly as printed; others are saved to `app/assets/images/stock/` for
  `image_tag "stock/<file>"`. All are listed in `stock/CREDITS.md`.
- Read each one (its copy in `tmp/images/`) and keep only those that show what you meant and fit
  together; delete the rest and their CREDITS lines. Credit photos as listed (a "Photos" line in
  the footer). Never put a photo URL on a page that `bin/images` hasn't printed.
- Photos the owner attaches come first: copy them into `app/assets/images/`, or set them as a
  theme setting's default.

## 6. Icons

`icon "truck", size: 20, stroke: 1.5` draws any Lucide icon inline, in the text's color. Find names
with `bin/icons truck`. Use them sparingly and plainly (thin strokes, no tinted circles), as the
themes do.

## 7. When the owner asks for changes

**Rearranging is moving markup.** "Put the reviews above the description", "a bigger photo", "menu
in the middle": change the view's structure (order, grid columns, widths), not only classes, in
the theme's own style. When the owner pointed at an element in the preview, that element is the
one they mean. If their layout would break the shop (the add-to-cart form below the fold on
phones, prices hidden), build it as close as works and say why.

**A new section** (an FAQ, a gallery, a newsletter sign-up): the page blocks in
`app/views/blocks/` (seen at `/_blocks` on the preview, `?only=faq` for one) are starting points.
Copy one's markup into the page and make it the theme's: its spacing, type and corners, the
shop's words and records. Don't `render "blocks/…"` from pages (except `blocks/_personalized`,
which the themes share) and don't edit the blocks themselves. Add only what the owner asked for.

**A look is the whole site.** After changing colors, fonts or the theme, check every page a buyer
passes through: home, all products, a product, a collection, the cart, checkout, the order page,
policies and contact, header and footer.

**Header and footer**: on a phone the header holds only the menu button, the logo or name, search
and the cart; a long name wraps onto two lines rather than being cut off. Keep the footer's links
to the policies and the contact page, and "Find my order".

## 8. Copying a site the owner shows

"Make it like this" means a buyer who knows that site would recognize it. Start from the theme
closest to it (white and plain: clean; dark: bold; serif and calm: editorial; rounded and soft:
soft), then:

- Go through all of it: `bin/look <url>` (the whole home page, at phone and desktop) and the
  product page it suggests. Besides screenshots (Read every one), it prints what it measured:
  fonts with their sizes and weights, colors, buttons, the header, the sections in order (height,
  background, heading, grids with columns, gaps and image ratios) and, on a product page, where
  the photos sit and what the buy box holds. A screenshot the owner sends counts the same,
  without the numbers. Read all of what it prints (or its `tmp/look/*-measured.txt` files).
- Build to those numbers at both widths: the site's own font when Google Fonts has it, else the
  nearest one in fonts.css, at the same sizes and weights; the same section order and heights,
  columns, gaps, image ratios, corners and button shapes; its header, its product cards (photo
  ratio, the background behind photos, badges, where the price sits) and its product page. Rebuild
  those in the views; don't only change theme.css.
- Add nothing of your own. The owner's colors take the place of the site's but keep their roles: a
  mostly white site with one button color stays mostly white, with their color on buttons, links
  and small accents.
- Never its words, logo or photos. DESIGN.md names the site and what differs from it.

## 9. Look before you finish

Run `bin/rails tailwindcss:build`, then look at what you changed in the running app:
`bin/look / /products /products/<a slug> /collections/<a slug> /cart /contact` after a change of
look (add `--screens N` for what's further down). Read every screenshot, phone first, and the
theme's reference store beside them:

- Side by side with the reference, would a buyer believe both were made by the same designer? Is
  anything there the reference doesn't have?
- Is any sign from section 3 on the page? Remove it.
- Does the first screen say what the shop sells and to whom, with one obvious next step, without
  scrolling on a phone?
- Do the photos show people and the products' world, sharing one light and mood?
- Does it look the way the owner asked (SPEC.md)? Would they show it to a customer with pride?

Fix the problems `bin/look` reports and what fails these questions, then look again, only at the
pages you changed. Stop after three rounds at most and say in your summary what still isn't right.
