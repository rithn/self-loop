# Create Deck Skill

> Type `/create-deck` to turn voice transcriptions or notes into a polished HTML presentation deck, built slide by slide with visual review at each step.

Linked to [[AI assisted work]].

---

## What it does

1. Asks for any existing context — notes, file path, or existing outline
2. Gathers a deck brief: title, audience, goal, slide count, style, and output mode
3. Drafts a slide-by-slide outline and waits for approval before building anything
4. Generates the deck **one slide at a time**, saving to a single self-contained HTML file
5. Uses Playwright to screenshot every slide and checks fill level, font hierarchy, and alignment
6. Fixes issues slide-by-slide, re-screenshots to verify, then hands off for feedback
7. Iterates — content, layout, images, structure — until the user is satisfied

---

## When to use it

- Turning rough notes or a voice transcript into a client-ready presentation
- Building a pitch deck, investor update, or internal briefing from scratch
- When you want a polished, printable deck without opening PowerPoint or Google Slides
- Refreshing or rebuilding an existing deck with new content

---

## Output

- A **single self-contained HTML file** with embedded CSS and JS
- Default: **PDF/print mode** — vertical scroll, one slide per page, prints cleanly via File → Print → Save as PDF
- Optional: **browser presentation mode** — click-through slides with keyboard arrow support
- Saved in the current working directory as `[deck-title-slug].html`

---

## Design decisions

- **Outline-first** — never builds the deck until the outline is explicitly approved; avoids wasted generation
- **One slide at a time** — each slide is built, saved, and screenshotted before moving to the next; catches issues early
- **Scoped CSS per slide** — every slide gets its own `<style>` block scoped to `#slide-N`; makes targeted edits safe and predictable
- **Font hierarchy enforced** — slide title > card headers > body > labels; never lets internal headers exceed the slide title
- **≥60% vertical fill target** — fills slides with expanded bullets or increased sizing before touching spacing
- **Real images only** — searches the web for relevant visuals and embeds via URL; never leaves placeholders
- **Visual review loop** — Playwright screenshots every slide post-generation; fixes are verified before moving on

---

## Files it reads

- Any file path the user provides as input context
- `Context System/projects.md` — if referenced for background

## Files it creates

- `[deck-title-slug].html` — in the current working directory

---

## Skill file location

`~/.claude/commands/create-deck.md`

---

*Created: 13 March 2026*
