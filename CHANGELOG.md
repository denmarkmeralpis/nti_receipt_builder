# Changelog

## [0.1.0] - 2026-08-02

Initial release, extracted from SalesWiz's receipt builder.

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
