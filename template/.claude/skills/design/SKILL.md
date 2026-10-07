---
name: design
description: How this app should look. Choosing its visual direction (DESIGN.md), turning it into the theme, fonts and icons, designing customer-facing pages, and checking the result. Use before the first screen of a new app, whenever you build or restyle a page visitors see, and when the owner asks about the look.
---

# Design

Owners compare their app with the best apps on their phone. Each app should look made for its
business: a nail salon, a film night, a gym and a bakery should not be told apart only by the color
of a button. A gray dashboard with an indigo button and everything centered in pale boxes is a
failure, even when every feature works.

The template's neutral theme and the UI kit are the floor, not the look.

## What decides the look

When sources disagree, the higher one wins:

1. **What the owner said**: colors, style, mood, sections, wording, content, prices, photos, apps
   they want it to look like. Their words beat any rule of thumb in this skill.
2. **DESIGN.md**: the direction already chosen for this app on earlier turns.
3. **This skill's suggestions** (feel, fonts, the hardest-to-fake detail of the business): only for
   what the owner didn't say.
4. **The page blocks**: layouts to start from, reshaped to fit everything above.

A detailed description leaves little to suggestions; a one-line one ("an app for my nail salon")
leaves most of it. Don't blend: when the owner wants a black, minimal nail salon, it is black and
minimal, with no pastel pink "because salons are pink". If what they ask for would hurt visitors
(text too pale to read, a page that breaks on phones), build it as close as works and say why in
your summary.

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
**Layout:** which screens are customer-facing (public layout) and which are the owner's (application layout).
```

Be specific and committed. "Clean and modern" is not a direction. Pick the hardest-to-fake detail
of the business and design around it: a salon is about hands and color swatches, a cinema about the
dark room and the poster, a gym about energy and the timetable.

When you plan instead of build, put a short **Look and feel** section in the plan with the same
choices so the owner can react before anything is built.

On later turns, read DESIGN.md first and stay inside it. When the owner asks for a different look,
update DESIGN.md and the theme together.

## 2. Make it the theme

Set the direction in `app/assets/tailwind/application.css` (`@theme`). Every kit block, the owner's
screens and sign in follow. Tint the neutrals toward the brand hue rather than leaving them blue-gray.
Use OKLCH, and a full brand scale 50–950 (buttons use 600 with white text: keep that readable).

Three directions, to show the range (don't copy them):

| | Salon, light and soft | Cinema, dark | Gym, loud |
|---|---|---|---|
| canvas | `oklch(97.5% 0.012 20)` blush paper | `oklch(16% 0.012 270)` | `oklch(98% 0.005 100)` |
| surface | `oklch(99.5% 0.004 20)` | `oklch(21% 0.016 270)` | `oklch(100% 0 0)` |
| ink | `oklch(27% 0.03 10)` | `oklch(95% 0.01 80)` | `oklch(18% 0.02 260)` |
| brand-600 | `oklch(56% 0.16 10)` rose | `oklch(72% 0.15 75)` amber | `oklch(64% 0.2 135)` volt |
| fonts | Fraunces + Be Vietnam Pro | Bricolage Grotesque + Inter | Space Grotesk + Manrope |
| shape | 24px corners, no borders, soft shadows | 6px corners, poster images, glow on hover | square, thick borders, color blocks |

A dark app sets dark `canvas`/`surface`/`line`, light `ink`/`muted`, and flips `brand-50…200`
(used for quiet backgrounds) to dark tints and `brand-700…950` to light ones, so kit badges and
alerts stay readable. Check sign in and `/admin/users` after changing the theme.

Custom pieces of the design (a hero with a grain overlay, a ticket-stub card, keyframes) go at the
end of application.css as named classes. Don't scatter one-off hex values in views.

## 3. Fonts

Self-hosted in `app/assets/fonts`, declared in `app/assets/tailwind/fonts.css`, all with Vietnamese.
Set `--font-display` (headings, h1–h3 use it) and `--font-sans` (text). One or two families.

| Family | Character | Good for |
|---|---|---|
| Fraunces | soft, old-style serif, italic | bakeries, florists, cafés, salons |
| Playfair Display | high-contrast fashion serif, italic | beauty, restaurants, events |
| Cormorant Garamond | delicate classic serif, italic (use large) | weddings, spa, luxury |
| Lora | calm book serif, italic | clinics, teachers, long text |
| Roboto Slab | sturdy slab | workshops, garages, logistics |
| Bricolage Grotesque | quirky editorial grotesque | creative studios, cinema, events |
| Space Grotesk | technical, geometric | gyms, tech, sports |
| Montserrat | wide geometric | fitness, real estate, bold headlines |
| Lexend | very legible, open | schools, kids, older users |
| Baloo 2 | round, playful display | kids, snacks, games |
| Quicksand | light, rounded | pets, baby, soft brands |
| Nunito | rounded, friendly text | community, education |
| Plus Jakarta Sans | crisp modern text | most products |
| Manrope | neutral modern text | dashboards, tools |
| Inter | neutral UI text, italic | dense tools |
| Be Vietnam Pro | made for Vietnamese, neutral | any Vietnamese text |
| JetBrains Mono | monospace | codes, receipts, numbers |

Vietnamese diacritics stack above and below letters: keep body `leading-relaxed` (1.6+), headings at
least `leading-tight`, and give uppercase labels some tracking. Avoid weights below 300 for text.

## 4. Icons

`icon "calendar-check", size: 18, class: "text-brand-600"` draws any Lucide icon inline.
Find names with `bin/icons cake` or `bin/icons "hair dryer"`. Use icons to make lists, features and
buttons scannable; don't use emoji as icons.

## 5. Customer-facing pages

Visitors' pages use `layout "public"` and are designed, not assembled from admin blocks.

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


- **Header and footer** (`app/views/layouts/public/_header.html.erb`, `_footer.html.erb`): redesign
  them for the app. The footer carries what visitors look for: address, hours, phone, Zalo, map link.
- **First screen**: say what this is and what to do, with real content from the owner's description
  (services and prices, today's classes, the films), not a generic welcome. Avoid the centered title +
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
  - Otherwise search: `bin/images "nail salon"` (English words; `--count 5`,
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

The owner's screens (managing bookings, members, settings) stay on the `application` layout with the
UI kit (`ui-kit` skill). They follow the theme, so they still feel like the same product. An app that
is only a tool for the owner has no public pages; give its theme the same care.

## 6. Look before you finish

After building or restyling a page, run `bin/rails tailwindcss:build`, then look at it in the
running app: `bin/look / /menu` (add `--as owner` for staff pages). It saves the first three
screens of each page; add `--screens N` when what you changed is further down. Read every screenshot it saves,
phone first, and judge it as a visitor would:

- Does the first screen say what this is, with one obvious next step, without scrolling on a phone?
- Does anything look like a default: gray boxes, an indigo button, everything centered, stock words?
- Is the text readable on its background, and the spacing even? Do photos show what they should?
- Does it look made for this business, and would the owner show it to a customer with pride?

Fix the problems `bin/look` reports and what fails these questions, then look again, only at the
pages you changed. Stop when it passes, and after three rounds at most: say in your summary what
still isn't right instead of looking again.
