---
name: design
description: How this app should look. Choosing its visual direction (DESIGN.md), turning it into the theme, fonts and icons, designing customer-facing pages, and checking the result. Use before the first screen of a new app, whenever you build or restyle a page visitors see, and when the owner asks about the look.
---

# Design

Owners compare their app with the best apps on their phone. Each app should look made for its
owner, their business and their customers, not like the same template in another color. A gray
dashboard with an indigo button and everything centered in pale boxes is a failure, even when every
feature works.

The template's neutral theme and the UI kit are the floor, not the look.

## What decides the look

What the owner asked for comes first (SPEC.md, "Asked"), then DESIGN.md, then what you choose with
this skill, then the page blocks. Everything below is how to choose well where the owner said
nothing; it never overrides what they said. A detailed request leaves little to choose; a one-line
one leaves most of it.

## 1. Choose a direction (DESIGN.md)

When DESIGN.md says "Not decided yet", decide before writing views, from what the owner said
about their business and their customers; everything they asked for about the look goes in as
they said it. Replace DESIGN.md with:

```markdown
# Design

**For:** who opens this app, on what device, in what moment (e.g. "buyers tapping an ad on their phone between errands").
**Style:** which shop style below it starts from, and what makes it this shop's own.
**Feel:** three words (e.g. "warm, unhurried, pretty").
**Color:** light or dark; canvas, ink, brand and accent and why they fit.
**Type:** display font + text font from the list below.
**Shape:** corner radius, borders or shadows or solid color blocks, how images are framed.
**Signature:** the one thing visitors will remember (a huge serif product name, a ticket-stub order card, a marquee of the shop's jokes).
**Layout:** the home page's sections, and how the product page and cart look.
```

Be specific and committed. "Clean and modern" is not a direction. Find what is particular to this
owner: their name, place, products, prices, story, the moment their customers use the app. Design
around the most concrete of these rather than around the category the business belongs to.

When you plan instead of build, put a short **Look and feel** section in the plan with the same
choices so the owner can react before anything is built.

On later turns, read DESIGN.md first and stay inside it. When the owner asks for a different look,
update DESIGN.md and the theme together.

### Shop styles

Shops that sell well online look like the best Shopify themes: a big photo of people using the
thing, a few strong sections, the products large. Start every storefront from the one of these
styles that fits what the shop sells and who buys it (or the one the owner's words point to), then
make it this shop's: its own colors, its name and products in the words, the photos for its
buyers. Two shops in the same style should still not look alike. Before building, look at the
style's reference store (`bin/look <url> --desktop --screens 3`) and take its layout ideas: the
header, the order of sections, how photos and type are framed. Never its words, logo or photos.

| Style | For shops selling | Reference |
|---|---|---|
| **Quiet luxury**: warm off-white, near-black ink, one deep color (espresso, olive, ink blue) and brass; a big serif (Cormorant Garamond, Playfair Display) with Manrope; square corners, hairlines, no shadows; a centered logo over a centered nav; huge serif statements with room around them | jewelry, art prints, candles, home goods, anything at a higher price | https://theme-craft-demo.myshopify.com, https://theme-studio-demo.myshopify.com, https://theme-origin-demo.myshopify.com |
| **Bold street**: a dark canvas, white type and one loud accent (lime, safety orange, electric blue); Montserrat or Space Grotesk in heavy uppercase; square corners and solid blocks; a split hero with the photo bleeding off the edge; a marquee in the accent color | streetwear, gym and sport, gaming, music and fandom tees | https://theme-ride-demo.myshopify.com |
| **Playful pop**: bright flat colors on cream or white, 2px ink borders with a hard offset shadow (`shadow-[4px_4px_0_var(--color-ink)]`), pills and stickers set at an angle; Baloo 2 or Bricolage Grotesque with Nunito; a photo hero with a bordered text card | funny tees, pets, kids, snacks, gifts | https://theme-colorblock-demo.myshopify.com, https://theme-crave-demo.myshopify.com |
| **Soft natural**: pale tinted canvas, pastel gradient cards, very round corners (`rounded-3xl`); Plus Jakarta Sans or Quicksand; close-up photos in soft light with a floating text card over them | skincare, self-care, baby, wellness, tea | https://theme-sense-demo.myshopify.com, https://theme-refresh-demo.myshopify.com |
| **Warm handmade**: cream canvas, terracotta, sage or mustard, a soft serif (Fraunces, Lora) with Nunito; gentle corners, a paper grain on bands of color; the maker's story beside a photo of hands at work | mugs, coffee, crafts, local makers, slow fashion | https://theme-craft-demo.myshopify.com |

Say in DESIGN.md which style you started from and what you changed. When the owner shows another
site or names a feel, that wins over the table.

## 2. Make it the theme

Set the direction in `app/assets/tailwind/application.css` (`@theme`). Every kit block, the owner's
screens and sign in follow. Tint the neutrals toward the brand hue rather than leaving them blue-gray.
Use OKLCH, and a full brand scale 50–950 (buttons use 600 with white text: keep that readable).

Choose the colors from the direction: light or dark, quiet or loud, warm or cool. Give brand and
accent enough contrast with the canvas to read, and keep body text near black on light themes and
near white on dark ones.

A dark app sets dark `canvas`/`surface`/`line`, light `ink`/`muted`, and flips `brand-50…200`
(used for quiet backgrounds) to dark tints and `brand-700…950` to light ones, so kit badges and
alerts stay readable. Check the cart, checkout and order pages after changing the theme.

Custom pieces of the design (a hero with a grain overlay, a ticket-stub card, keyframes) go at the
end of application.css as named classes. Don't scatter one-off hex values in views.

## 3. Fonts

Self-hosted in `app/assets/fonts`, declared in `app/assets/tailwind/fonts.css`.
Set `--font-display` (headings, h1–h3 use it) and `--font-sans` (text). One or two families.

| Family | Character |
|---|---|
| Fraunces | soft, old-style serif, italic |
| Playfair Display | high-contrast fashion serif, italic |
| Cormorant Garamond | delicate classic serif, italic (use large) |
| Lora | calm book serif, italic |
| Roboto Slab | sturdy slab |
| Bricolage Grotesque | quirky editorial grotesque |
| Space Grotesk | technical, geometric |
| Montserrat | wide geometric |
| Lexend | very legible, open |
| Baloo 2 | round, playful display |
| Quicksand | light, rounded |
| Nunito | rounded, friendly text |
| Plus Jakarta Sans | crisp modern text |
| Manrope | neutral modern text |
| Inter | neutral UI text, italic |
| Be Vietnam Pro | neutral, slightly geometric |
| JetBrains Mono | monospace |

Keep body `leading-relaxed` (1.6+), headings at least `leading-tight`, and give uppercase labels
some tracking. Avoid weights below 300 for text.

## 4. Icons

`icon "calendar-check", size: 18, class: "text-brand-600"` draws any Lucide icon inline.
Find names with `bin/icons cake` or `bin/icons "hair dryer"`. Use icons to make lists, features and
buttons scannable; don't use emoji as icons.

## 5. Customer-facing pages

The storefront is designed, not assembled from admin blocks.

The shop's pages are already there, working, in a plain starting look: home (`home/show`), all
products (`products/index`), a product (`products/show`, with its photo gallery and option
picker), a collection, the cart, checkout and the buyer's order page. (The order emails are the
Platform's, not the storefront's.) Restyle them for the brand and rearrange them freely; keep their forms' fields,
the Stimulus targets (`variant-picker`, `gallery`) and the links between them working.

**A look is the whole site.** Choosing or changing the direction (a new app, "make it look like
this site", a screenshot, "more premium") isn't done until every page a buyer passes through wears
it: home, all products, a product, a collection, the cart, checkout, the order page, the policies
and contact pages, header and footer. A buyer who taps a product and lands on the starting look
sees a template. Check them all (section 6).

**A reference is a layout, not a palette.** When the owner shows a site or a screenshot, take what
makes it recognizable: the order of sections, the header (centered logo, mega menu, announcement
bar), how product cards look (photo ratio, hover image, badges, price position), the product page
(gallery beside or above, sticky buy box, accordions), the type scale and spacing, as well as the
colors. Rebuild those in the views; don't only change the theme.

**Rearranging is moving markup.** "Put the reviews above the description", "a bigger photo", "menu in
the middle": change the view's structure (order, grid columns, widths), not only classes. When the
owner pointed at an element in the preview, that element is the one they mean. If their layout
would break the shop (the add-to-cart form below the fold on phones, prices hidden), build it as
close as works and say why.

**Start from the page blocks** in `app/views/blocks/`, after the sections of Shopify's themes: an
image banner (the first screen), a marquee, benefits (free shipping, delivery dates, secure
checkout, from the shop's settings), collection tiles with photos, a product carousel, a collage
of two photo cards, image with text, a gallery, an FAQ, a newsletter sign-up and a closing call
to action. A shop's home page usually runs: image banner, benefits or marquee, collection tiles,
products (a carousel or the grid), image with text or a collage, newsletter. Buyers' words
come from the shop's real reviews, never a block of quotes. They use only the theme's
names, so they wear the app's look, and they already work at 390px. See them all in this app's theme
at `/_blocks` on the preview (development only; `?only=faq` for one). To use one, **copy its
markup into the page's own view and make it this app's**: real content and records instead of the
samples, the app's wording, its photos, and changes to layout and detail that the owner and the direction ask for
(a serif product grid, a ticket-stub card, square corners). Don't `render "blocks/…"` from pages, and
don't edit the blocks themselves: they are the starting point for every page. Pick the few blocks
this business needs, in the order a visitor wants them; a page with every block is a template, not a
design.


- **Header and footer** (`app/views/layouts/site/_header.html.erb`, `_account.html.erb`, `_footer.html.erb`):
  redesign them for the app; with customer accounts on, also the sign-in link and the customers'
  sign in, sign up and account pages (`app/views/sessions/`, `registrations/`, `accounts/`). The footer carries what visitors look for: the policies and contact links (keep them), social links, and for a local business its address and hours.
- **First screen**: say what this is and what to do, with real content from the owner's description
  (what they offer, prices, what's on today), not a generic welcome. Avoid the centered title +
  subtitle + button in a pale rounded box.
- **Composition**: vary the sections: split layouts, full-bleed bands of brand color, a big number,
  an asymmetric grid, a horizontal scroller of cards. Generous space (`py-16 md:py-24` between
  sections), one clear max width, text `text-base`/`text-lg`.
- **Product photos** come from the Platform: products imported from Printify come with their
  mockups, and the owner adds others in the shop's admin. A collection's photo is its first
  product's (`collection_image`). Don't invent products to fill the grid: a new shop shows its
  coming-soon state (`products/_coming_soon`) until the owner's products are in.
- **Lifestyle photos make a shop look alive.** Give the home page at least three: the first
  screen, and two more further down (a collage, image with text, a band). What the designs are
  about (the cats on a cat-tee shop, runners on a race shirt) and people wearing or using what
  the shop sells, in the style's light and colors (search for that: "woman laughing
  in oversized tee golden hour", not "t-shirt"). Make each one a theme setting of type `image`
  with the `bin/images` link as its `default` (`hero_image` is already there), and read it with
  `theme_setting(:key)`: the owner can swap it for their own photo in the admin, and the preview
  shows the default until the storefront is published. Stock photos are never product photos:
  don't show a stock photo as if it were one of the shop's products.
- **Images**: use what the owner gives first (a logo or photos they attach: copy them into
  `app/assets/images/`, or make them a theme setting of type `image` when they'll change them). When a page needs photos they haven't given (a banner, the shop's story, a collection's world),
  get free stock photos with `bin/images`:
  - Unsplash photos you know fit (`images.unsplash.com/photo-…`): check them first with
    `bin/images --check <links>`; it drops links that don't exist and Unsplash+ photos, which
    aren't free.
  - Otherwise search: `bin/images "<what the photo should show>"` (English words; `--count 5`,
    `--orientation portrait|square`).

  Unsplash photos (`LINK`) are used by their URL exactly as printed, with a small copy in
  `tmp/images/` to look at; the others are saved to `app/assets/images/stock/` for
  `image_tag "stock/<file>"`. All are listed in `stock/CREDITS.md`. Look at
  each one (Read the file) and use only those that show what you meant and fit the app's direction;
  delete the rest and their lines in CREDITS.md. Photos found by search on Unsplash or under CC BY
  need their credit on the page as listed, with its links (a small caption, or a "Photos" line in
  the footer). Never put a photo URL on a page that `bin/images` hasn't printed: unchecked links
  break or show something else, and other sites' photos aren't the owner's. Without fitting
  photos, design with type, color, gradients, shapes and icons, or inline SVG.
- **Detail**: hover and focus states on everything clickable, `transition` on color and transform,
  one tasteful entrance or hover motion. Prices with `number_to_currency`, big and clear.
- **Phones first**: most visitors are on a phone. Design at 390px wide, then widen. Put the main
  action within thumb reach (a sticky bottom bar on product pages works well).
- Forms on these pages still use `form_with` and `form.field`; style the surroundings, and adjust
  the field look through the theme if needed.


## 6. Look before you finish

After building or restyling a page, run `bin/rails tailwindcss:build`, then look at it in the
running app: `bin/look / /products`.
After a change of look, look at the whole buyer's path: `bin/look / /products /products/<a slug>
/collections/<a slug> /cart /contact` (the cart and checkout need items: check their views by
reading them too). It saves the first three
screens of each page; add `--screens N` when what you changed is further down. Read every screenshot it saves,
phone first, and judge it as a visitor would:

- Does the first screen say what this is, with one obvious next step, without scrolling on a phone?
- Does anything look like a default: gray boxes, an indigo button, everything centered, stock words?
- Put beside the style's reference store, would a buyer believe it's a shop of the same class?
  Are there photos of people and the products' world, or only boxes and text?
- Is the text readable on its background, and the spacing even? Do photos show what they should?
- Does it look the way the owner asked (SPEC.md), made for them rather than for any business like it?
- Would the owner show it to a customer with pride?

Fix the problems `bin/look` reports and what fails these questions, then look again, only at the
pages you changed. Stop when it passes, and after three rounds at most: say in your summary what
still isn't right instead of looking again.
