# Hallmark in this storefront

Every look in this storefront is a Hallmark build: the Floor, the gates, the themes, the voice, the
sweep. This file says how each step of SKILL.md lands in a Rails shop that sells through the
Platform. Where the two differ, this file wins on what is fixed here (the stack, the shop's
structure, the data rules, how the builder works); SKILL.md wins on everything about the look.

## What is fixed, and what Hallmark decides

- **The layout** is one of four shop structures, each after a Shopify theme that sells, put in
  place with `bin/theme <layout>`: the header, the footer, the home page's sections, the product
  card. The shared pages (product page, collection, cart, checkout, order, policies, contact, 404)
  keep their structure in every layout. A layout is the shop's anatomy, the "buy" job already read
  (`references/anatomy.md`): don't replace it with a macrostructure.

  | Layout | Structure | Suits |
  |---|---|---|
  | **clean** | full-width photo (or the newest products' photos), a dense square grid, collections, story | almost anything; the default |
  | **bold** | split first screen with a huge line, wide-spaced grid, story, collections | loud, sport, streetwear, gaming, attitude |
  | **editorial** | centered line, wide photo, hairline collection cards, story statement | art, home goods, considered gifts |
  | **soft** | photo with a card over its edge, lifted cards, story band | gifts, family, pets, cozy, keepsakes |

- **The material** is a Hallmark theme, dealt and put in place with `bin/theme material <slug>`:
  paper, ink, faces, corners, depth, controls, motion, voice, photo treatment. It goes over the
  layout and every shared page follows it (they read the same tokens).
- **Everything about the look** inside that: type, color, surfaces, the hero's posture, the
  sections' composition on the home page, words, pictures, states. That is Hallmark, in full.

## The flow, step by step

**0. Pre-flight.** Read SPEC.md (what the owner asked, in their words), then DESIGN.md: when it is
decided, it is the locked system (SKILL.md § 0) and later turns stay inside it. Read
`app/assets/tailwind/theme.css` (its first line is the stamp of the last build). The products,
collections, prices, shipping and policies come from the Platform (`bin/look`, the API), and they
are the page's real material.

**1. Ask once: don't.** The builder builds first and the owner reacts to the preview: infer
material, audience, use and tone from the request, state the inferences in one line of your reply
and in DESIGN.md, and build. The use is always **buy**. Facts are never inferred (SKILL.md § 1):
no invented reviews, counts, quotes, logos or founders.

**2. Shape.** Pick the layout by the shop's structure (table above). Within it, design the home
page as SKILL.md § 2 says: the material inventory, the anatomy of a shop that sells from ads
(the product and its price within the first screens, the promises a buyer checks, the
collections), each section's composition from `references/layout.md`, the hero's posture, the
signature. Add, drop or reorder home page sections in the layout's views; keep the shared
pages' parts (CLAUDE.md, "What's built in").

**3. Direction.** Deal: `node .claude/skills/hallmark/scripts/theme.mjs deal --genre <genre>
--prompt "<the owner's request, in English>" --log .hallmark/log.json`. Read the three pictures
(`references/themes/<slug>.jpg`), pick the material that can carry this shop, say which and why.
A look the owner named ("dark and techy", "like a gallery") routes the deal through its keywords;
a site the owner showed is the brand (SKILL.md § 0, `references/brand-truth.md`), built on the
nearest material. Then:

```sh
bin/theme <layout>               # only when the layout changes; it resets the material
bin/theme material <slug>        # theme.css and layouts/_fonts from the theme's file
bin/rails tailwindcss:build
```

Where the deal says `theme.mjs scaffold`, run `bin/theme material` instead, and put its seed in
the stamp (`theme: Squeeze (deal 1/3, seed …)`). Run `theme.mjs draw` as SKILL.md says for the hero posture, nav and footer within the layout.

**4. Load** what SKILL.md § 4 lists: layout, anatomy (buy), imagery, craft, the genre, the
theme's file, `gates.md` § 1 to § 4.

**5. Picks** go into DESIGN.md, written to `references/design-md.md`, and in one short paragraph
of your reply for the owner.

**6. Build**, in the storefront's own system:

- **No tokens.css or base.css.** `bin/theme material` already wrote the theme's tokens into
  `app/assets/tailwind/theme.css`: the names every page reads in `@theme` (canvas, surface,
  surface-muted, ink, muted, line, accent, on-accent, brand-50…950 with on-brand, radius-lg,
  radius-xl, font-display, font-sans) as hex, so the studio's Design tab can change them; the
  theme's other tokens and Hallmark's shared scale in `:root`; its build hint in
  `@layer components`. Views use Tailwind classes on those names (`bg-canvas`, `text-ink`,
  `rounded-xl`, `bg-brand-600 text-on-brand`); the material's own tokens through arbitrary
  values (`shadow-(--cast-stock)`, `bg-(--color-cotton)`). Never a literal color in a view.
- **The stamp** is line 1 of theme.css: fill every `<…>` field, then the critique line and any
  waivers, all within its first 40 lines.
- **Controls**: every button is `button_classes` (`.btn`); the theme's control pair is styled on
  `.btn` and its variants in theme.css's `@layer components`, from the theme's Controls section.
- **Fonts** load from Google Fonts or Fontshare in `app/views/layouts/_fonts.html.erb` (written by
  `bin/theme material`); a different face means changing that link and `--font-*` together.
- **Pictures** (`references/imagery.md`): the products' own photos are the shop's real pictures
  and lead wherever they can (the first screen without a hero photo already shows them). A
  lifestyle photo (the hero, the story) is a theme setting of type `image` whose default comes
  from `bin/images "<what it shows>"` (Unsplash, credited in `stock/CREDITS.md`), read with
  `theme_setting(:key)` and given the class `photo` (the theme's photo treatment). Never a stock
  photo as a product, never a product drawn or invented, never Hallmark's stand-in slots in a
  shop.
- **Words** are theme settings (`hero_title`, `hero_text`, `story_title`, `story_text`,
  `hero_button`) in the theme's voice: what the shop sells and to whom, plainly, in English.
- **Motion** only within the theme's Motion section, with its reduced-motion fallback.
- **Log** the build: `node .claude/skills/hallmark/scripts/theme.mjs log --entry '<json>'
  --log .hallmark/log.json`.

**7. Sweep.** `bin/look` the pages you changed at both widths and Read every screenshot, then
`bin/sloplint` (the home page, all products, a product, the cart; or the paths you give): fix
every FAIL, fix or waive every REFLEX in the stamp, then the judged gates and the finish review
(`gates.md`, `references/review-hero.md`, `references/review-finish.md`). Three rounds at most;
say in your reply what still isn't right.

## Later turns

A change to an existing look is not a new Hallmark run (SKILL.md, Verbs): do it in the shop's
system (DESIGN.md, the material, the stamp), and sweep what you changed. A new look the owner asks
for ("make it darker", "more playful") is a new deal: re-run step 3, keep the layout unless its
structure is what they want changed, update DESIGN.md and the stamp.
