# Hallmark in this storefront

Every look in this storefront is a Hallmark build: the Floor, the gates, the themes, the voice, the
sweep. This file says how each step of SKILL.md lands in a Rails shop that sells through the
Platform. Where the two differ, this file wins on what is fixed here (the stack, the shop's
structure, the data rules, how the builder works); SKILL.md wins on everything about the look.

## What is fixed, and what Hallmark decides

No two shops should look built from the same page. Hallmark decides the look **and** the home
page's composition; the storefront fixes only what makes a shop sell and work.

- **Fixed, every shop (the shop contract):**
  - The shared pages keep their parts: product page (photos, price, options, the buyer's
    personalization, add to cart, delivery and returns, reviews, related), collection, cart,
    checkout, order, policies, contact, 404 (CLAUDE.md, "What's built in"). Restyle them, don't
    remove a part.
  - On a phone, the first screen of the home page says what the shop sells and to whom, with one
    obvious action; real products with their prices are within the first two screens.
  - The home page shows the shop's own products from the API (never invented ones), what buyers
    can personalize (the products from `blocks/_personalized`'s query) when the shop has any, a
    way into the collections, and the promises a buyer checks (shipping, returns, secure
    checkout) as facts. These are **content to place**, not sections to keep: the layout's
    benefits strip, "New arrivals" grid, "Make it yours" block and collection tiles are its
    starting markup, and the draw decides what each becomes (a bento cell, a pinned run, a poster
    line, a ruled list) and where it goes. A home page that still reads hero, strip, grid, "Make
    it yours", tiles, story in that order hasn't been composed.
  - The header: logo or name, the collections, search (`layouts/site/_search`) and the cart, the
    menu button on phones; checkout keeps its focused header. The footer: the policies, contact,
    "Find my order", the social links.
  - Everything the owner can change stays a theme setting (words, photos, button, brand color).
- **The material** is a Hallmark theme, dealt and put in place with `bin/theme material <slug>`:
  paper, ink, faces, corners, depth, controls, motion, voice, photo treatment. Every page follows
  it (they read the same tokens).
- **The composition is the draw's:** the home page's shape and sections, the hero's posture, the
  nav and the footer come from `theme.mjs draw` (step 2), built in the shop's views. A **layout**
  (`bin/theme <layout>`: clean, bold, editorial, soft, after Shopify themes that sell) is only the
  starting files: pick the one nearest the draw, then rebuild its home page, header and footer
  to the draw.

  | Layout | Its starting files | Nearest to draws with |
  |---|---|---|
  | **clean** | full-width photo, dense square grid, collections, story | a full-bleed or product-led hero, a grid |
  | **bold** | split first screen with a huge line, wide grid | a poster or type-led hero, condensed heads |
  | **editorial** | centered line, wide photo, hairline cards | a statement, a long read, a gallery |
  | **soft** | photo with a card over its edge, lifted cards | a stage, cards, a bento |

- **The signature** is owed on every shop (SKILL.md, Signature): the one thing a buyer remembers,
  made from this shop's real material and built **once**, where it does the most work. It is a
  thing, not a style: a treatment applied to every card (borders, shadows, a texture, rounded
  corners, die-cut edges) is the material, never the signature. Shapes it can take: the
  personalization shown working in the hero (a product photo with a sample name or pet already
  on it, through `personalization/_layer`); the price set huge as the offer; the promise made
  concrete (the days from order to door drawn as a strip from the shop's delivery estimate); the
  catalogue as an index the buyer scans (sizes, colors, materials from the API); one product
  staged large with its options laid out around it. Name it in the stamp and DESIGN.md.

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

**2. Shape: the draw.** After the material is in place (step 3), draw the composition:
`node .claude/skills/hallmark/scripts/theme.mjs draw --material product --job buy --theme <slug>
--log .hallmark/log.json` (`--material photo` when the owner gave lifestyle photos). It deals the
shape, the hero's posture, the nav, the footer, the first section after the hero, where the action
sits, what to leave out, and the sections to build. Take it, read the shape's file in
`references/macrostructures/` and the postures in `references/layout.md`, and build the home page
(`app/views/home/show.html.erb`), the header and the footer (`app/views/layouts/site/`) to it,
inside the shop contract above, starting from the layout's markup and changing what the draw
changes (not only the hero): a section the draw asks for is made from the shop's real
material (its products, collections, promises, the owner's words), never invented; the draw's
"leave out" is honored. When the draw refuses the shop (a shape for words with a shop of
pictures), redraw once (`--reroll 1`) and say why in the Picks. The blocks in
`app/views/blocks/` (seen at `/_blocks`) are starting markup for common sections. Mirror test
(SKILL.md): if a neighbouring shop would get this exact home page, change one decision.

**Sections to compose with.** The shop's own content comes in sections a page renders, each in
several variants that follow the material (all of them at `/_blocks?only=sections`):

| Section | Variants | Render |
|---|---|---|
| products | `grid`, `feature` (one staged large beside rows), `rail` (a row to swipe), `index` (a ruled catalogue) | `render "sections/products", variant: :feature, products: @new_arrivals, title: "New arrivals"` |
| personalized | `split`, `steps` (how it works, with the products' photos), `band` (on the brand color) | `render "sections/personalized", variant: :steps, products: @personalized` |
| collections | `tiles`, `index` (names set large in a ruled list), `bento`, `row` (round photos to swipe) | `render "sections/collections", variant: :index, collections: @collections, title: "Shop by collection"` |

The header and footer the draw names come the same way: make `layouts/site/_header.html.erb` or
`_footer.html.erb` render one of these (they keep the logo, the collections, search, the cart, the
phone menu, checkout's focused header; the policies, contact, Find my order, the social pages),
or keep the layout's own when it is the draw's:

| Chrome | Variants | Render |
|---|---|---|
| header | `centered` (logo over its links), `search` (a search field across the middle), `pill` (a floating rounded bar) | `<%= render "headers/pill" %>` |
| footer | `mast` (the shop's name set as wide as the page), `colophon` (one ruled block, set small) | `<%= render "footers/mast" %>` |

Pick each variant from the draw (a catalogue shape takes `index`, a stage takes `feature`, a
bento shape takes `bento`), never the same three as the layout's home page, and build the draw's
other sections (how it's made, the signature, the promise made concrete) in the page itself.
`test/controllers/composition_test.rb` checks it once DESIGN.md is written: all three sections
rendered, at most one in its first variant (`grid`, `split`, `tiles`), unless DESIGN.md says
`Kept as asked: <section>` because the owner asked for it.

**3. Direction.** Deal: `node .claude/skills/hallmark/scripts/theme.mjs deal --genre <genre>
--prompt "<the owner's request, in English>" --log .hallmark/log.json`. Read the three pictures
(`references/themes/<slug>.jpg`), pick the material that can carry this shop, say which and why.
A look the owner picked in the studio ("Use the Sticker look (Hallmark's sticker material)") is a
theme they named: skip the deal and put that material in place (stamp `theme: Sticker (by request)`).
A look the owner named ("dark and techy", "like a gallery") routes the deal through its keywords;
a site the owner showed is the brand (SKILL.md § 0, `references/brand-truth.md`), built on the
nearest material. Then:

```sh
bin/theme <layout>               # only when the layout changes; it resets the material
bin/theme material <slug>        # theme.css and layouts/_fonts from the theme's file
bin/rails tailwindcss:build
```

Where the deal says `theme.mjs scaffold`, run `bin/theme material` instead, and put its seed in
the stamp (`theme: Squeeze (deal 1/3, seed …)`). Then draw (step 2) and stamp `draw: <seed>`,
the shape, hero, nav, footer and signature you built; never `n/a`.

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
- **Display sizes** fit the longest word: a wide face in capitals (Bowlby, Anton, Ultra) at the
  layout's size can break a word across lines in a narrow column ("QUESTIONA / BLE"). Look at the
  hero and section heads at 390 and 1280 with the real words, and set the head smaller in that
  view (or the line shorter) until every word stays whole.
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
