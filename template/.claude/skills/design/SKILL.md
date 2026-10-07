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

**For:** who opens this app, on what device, in what moment (e.g. "regulars booking from their phone between errands").
**Feel:** three words (e.g. "warm, unhurried, pretty").
**Color:** light or dark; canvas, ink, brand and accent and why they fit.
**Type:** display font + text font from the list below.
**Shape:** corner radius, borders or shadows or solid color blocks, how images are framed.
**Signature:** the one thing visitors will remember (a big serif price list, a ticket-stub booking card, a marquee of class times).
**Layout:** which screens are on the customers' site and which are in /admin (CLAUDE.md, "Two halves").
```

Be specific and committed. "Clean and modern" is not a direction. Find what is particular to this
owner: their name, place, products, prices, story, the moment their customers use the app. Design
around the most concrete of these rather than around the category the business belongs to.

When you plan instead of build, put a short **Look and feel** section in the plan with the same
choices so the owner can react before anything is built.

On later turns, read DESIGN.md first and stay inside it. When the owner asks for a different look,
update DESIGN.md and the theme together.

## 2. Make it the theme

Set the direction in `app/assets/tailwind/application.css` (`@theme`). Every kit block, the owner's
screens and sign in follow. Tint the neutrals toward the brand hue rather than leaving them blue-gray.
Use OKLCH, and a full brand scale 50–950 (buttons use 600 with white text: keep that readable).

Choose the colors from the direction: light or dark, quiet or loud, warm or cool. Give brand and
accent enough contrast with the canvas to read, and keep body text near black on light themes and
near white on dark ones.

A dark app sets dark `canvas`/`surface`/`line`, light `ink`/`muted`, and flips `brand-50…200`
(used for quiet backgrounds) to dark tints and `brand-700…950` to light ones, so kit badges and
alerts stay readable. Check sign in and `/admin/users` after changing the theme.

Custom pieces of the design (a hero with a grain overlay, a ticket-stub card, keyframes) go at the
end of application.css as named classes. Don't scatter one-off hex values in views.

## 3. Fonts

Self-hosted in `app/assets/fonts`, declared in `app/assets/tailwind/fonts.css`, all with Vietnamese.
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
| Be Vietnam Pro | made for Vietnamese, neutral |
| JetBrains Mono | monospace |

Vietnamese diacritics stack above and below letters: keep body `leading-relaxed` (1.6+), headings at
least `leading-tight`, and give uppercase labels some tracking. Avoid weights below 300 for text.

## 4. Icons

`icon "calendar-check", size: 18, class: "text-brand-600"` draws any Lucide icon inline.
Find names with `bin/icons cake` or `bin/icons "hair dryer"`. Use icons to make lists, features and
buttons scannable; don't use emoji as icons.

## 5. Customer-facing pages

The customers' site (everything outside /admin) is designed, not assembled from admin blocks.

The shop's pages are already there, working, in a plain starting look: home (`home/show`), all
products (`products/index`), a product (`products/show`, with its photo gallery and option
picker), a collection, the cart, checkout and the buyer's order page, plus the order emails
(`order_mailer/`). Restyle them for the brand and rearrange them freely; keep their forms' fields,
the Stimulus targets (`variant-picker`, `gallery`) and the links between them working.

**Start from the page blocks** in `app/views/blocks/`: hero (split, full-bleed photo), features,
price list or menu, gallery, timetable, testimonials, stats, FAQ, find-us (address, hours, call,
Zalo, map), closing call to action, and a bottom action bar for phones. They use only the theme's
names, so they wear the app's look, and they already work at 390px. See them all in this app's theme
at `/_blocks` on the preview (development only; `?only=price_list` for one). To use one, **copy its
markup into the page's own view and make it this app's**: real content and records instead of the
samples, the app's wording, its photos, and changes to layout and detail that the owner and the direction ask for
(a serif price list, a ticket-stub card, square corners). Don't `render "blocks/…"` from pages, and
don't edit the blocks themselves: they are the starting point for every page. Pick the few blocks
this business needs, in the order a visitor wants them; a page with every block is a template, not a
design.


- **Header and footer** (`app/views/layouts/site/_header.html.erb`, `_account.html.erb`, `_footer.html.erb`):
  redesign them for the app; with customer accounts on, also the sign-in link and the customers'
  sign in, sign up and account pages (`app/views/sessions/`, `registrations/`, `accounts/`). The footer carries what visitors look for: address, hours, phone, Zalo, map link.
- **First screen**: say what this is and what to do, with real content from the owner's description
  (what they offer, prices, what's on today), not a generic welcome. Avoid the centered title +
  subtitle + button in a pale rounded box.
- **Composition**: vary the sections: split layouts, full-bleed bands of brand color, a big number,
  an asymmetric grid, a horizontal scroller of cards. Generous space (`py-16 md:py-24` between
  sections), one clear max width, text `text-base`/`text-lg`.
- **Images**: use what the owner gives first (Active Storage uploads, attach in seeds when they
  provide files). When a page needs photos they haven't given (a hero, the services, the classes),
  get free stock photos with `bin/images`:
  - Unsplash photos you know fit (`images.unsplash.com/photo-…`): check them first with
    `bin/images --check <links>`; it drops links that don't exist and Unsplash+ photos, which
    aren't free.
  - Otherwise search: `bin/images "<what the photo should show>"` (English words; `--count 5`,
    `--orientation portrait|square`).

  Unsplash photos (`LINK`) are used by their URL exactly as printed, with a small copy in
  `tmp/images/` to look at; the others are saved to `app/assets/images/stock/` for
  `image_tag "stock/<file>"` or attaching in seeds. All are listed in `stock/CREDITS.md`. Look at
  each one (Read the file) and use only those that show what you meant and fit the app's direction;
  delete the rest and their lines in CREDITS.md. Photos found by search on Unsplash or under CC BY
  need their credit on the page as listed, with its links (a small caption, or a "Photos" line in
  the footer). Never put a photo URL on a page that `bin/images` hasn't printed: unchecked links
  break or show something else, and other sites' photos aren't the owner's. Without fitting
  photos, design with type, color, gradients, shapes and icons, or inline SVG.
- **Detail**: hover and focus states on everything clickable, `transition` on color and transform,
  one tasteful entrance or hover motion. Prices with `number_to_currency`, big and clear.
- **Phones first**: most visitors are on a phone. Design at 390px wide, then widen. Put the main
  action within thumb reach (a sticky bottom bar on booking or ordering pages works well).
- Forms on these pages still use `form_with` and `form.field`; style the surroundings, and adjust
  the field look through the theme if needed.

The owner's screens in /admin (managing orders, products, settings) stay on the `admin` layout with the
UI kit (`ui-kit` skill). They follow the theme, so they still feel like the same product. An app that
is only a tool for the owner keeps its site to a simple home page; give its theme the same care.

## 6. Look before you finish

After building or restyling a page, run `bin/rails tailwindcss:build`, then look at it in the
running app: `bin/look / /menu` (`--as customer` for a customer's pages, `--as owner` for /admin). It saves the first three
screens of each page; add `--screens N` when what you changed is further down. Read every screenshot it saves,
phone first, and judge it as a visitor would:

- Does the first screen say what this is, with one obvious next step, without scrolling on a phone?
- Does anything look like a default: gray boxes, an indigo button, everything centered, stock words?
- Is the text readable on its background, and the spacing even? Do photos show what they should?
- Does it look the way the owner asked (SPEC.md), made for them rather than for any business like it?
- Would the owner show it to a customer with pride?

Fix the problems `bin/look` reports and what fails these questions, then look again, only at the
pages you changed. Stop when it passes, and after three rounds at most: say in your summary what
still isn't right instead of looking again.
