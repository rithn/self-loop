# UI Design Principles

## 1. Signal over decoration
Every element should tell the user something useful. A placeholder, icon, or state that communicates nothing — or worse, communicates the wrong thing — should be fixed before adding anything new.

## 2. Completion should be visible
When a user finishes an action or step, the UI must confirm it unambiguously. Numbers in a stepper don't communicate "done" — a checkmark does. Critical in multi-step flows where users need to track their progress without re-reading every field.

## 3. Hierarchy through contrast
Subordinate controls (navigation, actions) should be visually separated from content, not floating ambiguously within it. The modal footer separator creates a clear boundary between "form" and "what to do next".

## 4. Interactive affordance = feedback loop
If something is clickable, it needs a selected/active state so the user knows their action registered. Without it, users click again, wonder if it worked, or lose trust in the interface.

## 5. Polish is subtractive, not additive
The trap when making something look more production-grade is adding more visual complexity. All four quick wins above were clarifying or subtractive changes — not decorative ones. That's what separates a production UI from an over-designed MVP.

## 6. Every view should add information the user doesn't already have
If a section echoes the user's own input without transforming it, or duplicates what another panel already shows, it is occupying space without earning it. Apply this to placement decisions: if removing a panel would cost the user nothing, it shouldn't be there — or should be demoted to a compact acknowledgement.

## 7. Explore all states before evaluating
Evaluate the UI at every depth — expand every collapsible section, open every modal step, scroll to the bottom of every scrollable area — before forming suggestions. A before screenshot of the collapsed state is not a before screenshot of the screen. Issues hidden behind interactions (buried submit buttons, raw data dumps inside expanded cards, redundant decision echoes) are invisible to surface-level evaluation and will be missed entirely.
