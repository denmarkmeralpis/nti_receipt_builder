# Changelog

## [0.1.2] - 2026-08-13

- Paper geometry on the new-template page now reacts to the form. The page mounts `nrb-builder`
  and targets the paper size, dimension, orientation and height mode fields, so the width and
  height shown follow the selected preset instead of staying at whatever the model was
  initialized with. `edit` already had this wiring.
- Orientation now rewrites the dimensions rather than only the canvas: `settingsChanged` puts the
  larger value on width for `landscape` and on height for `portrait`, and writes both back to the
  inputs. Previously the pair was passed through untouched, so switching orientation left the
  numbers — and the saved record — describing the other orientation.
- Saved preview opens in a modal over the editor instead of a new tab.
  `templates/preview.html.erb` is replaced by `templates/preview.turbo_stream.erb`, and the
  preview link posts for a Turbo Stream. **Hosts overriding `templates/preview.html.erb` must
  move that override to the Turbo Stream view.**
- The Print button was the deleted preview page's only appearance, so nothing in the gem's views
  links to `print` now. The action, route and `templates/print.html.erb` are unchanged — hosts
  that need the button should add their own link to the `print` action.
- Renamed the two preview affordances to say which state they render: "Live Preview" is now
  "Draft Preview" (unsaved form state) and "Preview" is now "Saved Preview" (the persisted
  record).
- Canvas zoom in and out are real controls. Both glyphs were inert `<span>`s; they are now
  buttons wired to `zoomIn`/`zoomOut`, and all three entry points share `setZoom`, which clamps
  to 0.5–2.0 in 0.1 steps and syncs the range input back to the value.
- Removed the canvas viewport's `max-height: 70vh` and let the panels size to content, so a tall
  paper scrolls the page instead of being clipped inside the viewport.

## [0.1.1] - 2026-08-04

- Fixed layout edits being silently discarded on save. Serialization hung off
  `turbo:submit-start`, which Turbo dispatches *after* the `FormSubmission` constructor has
  snapshotted the request body, so the server re-saved the layout the page was rendered with.
  The hidden field is now written from `layoutValueChanged` — every add, patch, move, resize and
  delete reassigns `layoutValue`, so it can't go stale — with a `formdata` handler as a
  submit-time backstop for a layout mutated in place.
- Removed `Elements::MAX_ORDER_LINE_COLUMNS`. `LayoutValidator` now enforces only the lower
  bound, since every column key must already be one of the host's declared collection columns and
  duplicates are rejected — the host's own vocabulary is the ceiling. A host whose collection is
  wider than six columns is no longer rejected.
- Order line table cells wrap instead of truncating. `overflow-wrap: break-word` splits only a
  word too long for its column on its own, so ordinary text still breaks at spaces.
- Draft preview no longer trips a host's default-template uniqueness rule. The draft is built
  with `dup`, which copied `is_default`, so the unsaved copy collided with the record it came
  from and preview failed on exactly the templates most likely to be previewed. The flag is now
  cleared on the draft; nothing in the layout or geometry reads it, so the render is unaffected.
- Draft preview modal widened from `modal-lg` to `modal-xl`.

## [0.1.0] - 2026-08-02

- `NtiReceiptBuilder::Variables` — host-declared receipt vocabulary. `MAPPINGS` supplies keys
  and value methods; label, formatting type and preview sample are derived and overridable per
  key with `variable`. The key declaring `columns:` is the collection.
- `NtiReceiptBuilder::Template` — paper geometry, validations and jsonb layout, with
  `inheritance_column = nil` so hosts can subclass and share the table without STI.
- `NtiReceiptBuilder::LayoutValidator` — structural and whitelist validation driven by the
  host's declared variable and column keys.
- `NtiReceiptBuilder::Renderer` — one render path for both the designer preview and printed
  output; omit `receipt_object:` to render declared samples.
- `NtiReceiptBuilder::TemplatesController` — the builder's actions as a concern, scoped through
  an abstract `receipt_owner` the host must define.
- Builder UI: five Stimulus controllers, builder and print views, and a `nrb-receipt-*`
  stylesheet themable via `--nrb-accent`.
- `rails generate nti_receipt_builder:install` — initializer, migration, and Turbo Stream
  helpers for hosts that lack them.
