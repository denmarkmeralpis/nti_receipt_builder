# NtiReceiptBuilder

A drag-and-drop receipt template designer and millimetre-accurate renderer, packaged as a
Rails engine.

The gem ships the whole vertical — model, layout validation, renderer, print views, and a
Stimulus builder UI — but carries **no domain vocabulary of its own**. Your application
declares a `Variables` subclass mapping receipt placeholders to methods on whatever object it
prints receipts for, and the gem drives the designer, the validator and the renderer from it.

## Installation

```ruby
# Gemfile
gem 'nti_receipt_builder'
```

```bash
bundle install
bin/rails generate nti_receipt_builder:install
bin/rails db:migrate
```

The generator creates:

- `config/initializers/nti_receipt_builder.rb`
- a migration creating `nti_receipt_templates`
- `config/initializers/turbo_stream_tags.rb` — **skipped** if your app already defines
  `open_modal` on `Turbo::Streams::TagBuilder`

## Declaring your variables

`MAPPINGS` supplies the placeholder keys and the method that produces each value. Everything
else is derived, and overridden per key with `variable` only where the derived default is
wrong.

```ruby
class OrderReceiptVariables < NtiReceiptBuilder::Variables
  MAPPINGS = {
    'CUSTOMER_NAME'   => 'customer_name',
    'ORDER_REFERENCE' => 'order_reference',
    'ORDER_SUBTOTAL'  => 'order_subtotal',
    'ORDER_DATETIME'  => 'order_datetime',
    'ORDER_LINES'     => 'order_lines'
  }.freeze

  variable 'CUSTOMER_NAME',  sample: 'Juan Dela Cruz'
  variable 'ORDER_SUBTOTAL', sample: BigDecimal('275.00')
  variable 'ORDER_DATETIME', label: 'Order Date/Time',
                             sample: -> { Time.zone.local(2026, 7, 31, 14, 32) }
  variable 'ORDER_LINES', columns: {
    'description' => { label: 'Description', width_mm: 24 },
    'quantity'    => { label: 'Qty',         width_mm: 8,  align: 'center' },
    'unit_price'  => { label: 'Unit Price',  width_mm: 12, align: 'right' },
    'line_total'  => { label: 'Total',       width_mm: 12, align: 'right' }
  }

  def customer_name   = receipt_object.customer.name
  def order_reference = receipt_object.reference
  def order_subtotal  = receipt_object.subtotal
  def order_datetime  = receipt_object.created_at

  def order_lines
    receipt_object.order_lines.order(:order_line_number).map do |line|
      { 'description' => line.product_name, 'quantity'   => line.quantity,
        'unit_price'  => line.retail_price,  'line_total' => line.subtotal }
    end
  end
end
```

`receipt_object` is whatever you pass to the renderer — an order, an invoice, a booking.

### What is derived, and what you can override

| Aspect | Derived default | Override |
|---|---|---|
| Label | `key.titleize` — `'STORE_NAME'` → `'Store Name'` | `label:` |
| Formatting type | the value's class at render time: `BigDecimal` → currency, responds to `strftime` → datetime, `Array` → collection, other `Numeric` → plain, else string | `type:` |
| Preview sample | the label as a string; a collection gets three filler rows | `sample:` — a value or a lambda |
| Collection | the one key declaring `columns:` **is** the collection | — |

Type is decided at format time, not declaration time, so real data and preview samples travel
the same path. `type:` exists for the cases inference cannot get right — a pre-formatted
`String` that should be currency, say.

Column options are `label:`, `type:`, `width_mm:` and `align:`, all optional. They whitelist
the column keys a saved layout may use, seed the builder when a designer drops a fresh table,
and decide cell formatting.

A malformed class fails when its schema is first read — missing `MAPPINGS`, a mapped method
that does not exist, a `variable` call for a key absent from `MAPPINGS`, or two keys declaring
`columns:` all raise `NtiReceiptBuilder::InvalidVariablesError`. Typos surface in development
rather than at print time.

An error raised inside a mapping method propagates. That is deliberate: a receipt printing
silently without its total is worse than a visible failure.

## Configuration

```ruby
NtiReceiptBuilder.configure do |config|
  config.variables_class = 'OrderReceiptVariables'   # required
  config.template_class  = 'ReceiptTemplate'         # default 'NtiReceiptBuilder::Template'
  config.currency_unit   = '₱'
  config.datetime_format = '%m/%d/%Y %I:%M %p'
  config.print_stylesheet = 'nti_receipt_builder'    # nil to load none
end
```

Class references may be given as a `Class` or a `String`; either way the gem retains only the
**name** and resolves it per access. Holding a reloadable application class in configuration
would pin that class and its constant tree past every development reload, and would serve a
stale class after your code reloads.

## Wiring a controller

The gem ships its actions as a concern. Your controller keeps routing, authorization and
tenant scoping.

```ruby
class Partner::ReceiptTemplatesController < PartnerController
  include NtiReceiptBuilder::TemplatesController

  def index
    # yours — datatable, decorators, whatever you already use
  end

  private

  def receipt_owner = current_account
end
```

```ruby
# config/routes.rb
resources :receipt_templates do
  member do
    get   :preview
    post  :render_preview
    get   :print
    patch :set_default
  end
end
```

`receipt_owner` is mandatory: every query the concern makes is scoped through it, so the
tenant boundary stays visible in your code rather than in a configured lambda. A controller
that omits it raises `NotImplementedError` instead of running an unscoped query.

The concern provides `new`, `create`, `edit`, `update`, `destroy`, `preview`,
`render_preview`, `print` and `set_default`. Define any of them in your controller to take
over — a method on the including class wins. Rails app overrides `destroy`, for instance, to
archive rather than delete. The navigation hooks `after_create_path`, `after_destroy_path` and
`after_set_default_path` are overridable too, and worth overriding if you have named routes.

### Subclassing the model

Point `template_class` at a subclass to attach your own concerns while sharing the table:

```ruby
class ReceiptTemplate < NtiReceiptBuilder::Template
  # See the note below — these two lines go together.
  def self.base_class = self
  self.table_name = 'nti_receipt_templates'

  include Auditable
  has_assignable_status

  validates :is_default, uniqueness: { scope: %i[owner_type owner_id],
                                       conditions: -> { where(is_default: true) } }
end
```

The parent sets `inheritance_column = nil`, so the subclass shares `nti_receipt_templates`
with no STI type condition and no `type` column to maintain. Host-specific columns go in your
own migration against the same table.

**If you subclass, override `base_class` and re-declare the table.** Rails resolves
`base_class` up the superclass chain, so without the override it returns
`NtiReceiptBuilder::Template`. Anything that records a class name from `base_class` —
PaperTrail's `item_type`, polymorphic `*_type` columns — would then store the gem's class name
rather than yours, and your own queries would not find those rows. Returning `self` is safe
precisely because there is no STI to disturb.

The two lines are a pair: once the subclass is its own `base_class`, Rails derives the table
name from *it*, which would give `receipt_templates`. Naming the engine's table explicitly
keeps them on the same rows.

### Overriding a view

Host view prefixes are searched before the gem's, so dropping
`app/views/partner/receipt_templates/edit.html.erb` into your app shadows the gem's copy with
no configuration. The same trick works for `_print_assets.html.erb` if you want exact control
over what the standalone print document loads.

## Rendering a receipt

```ruby
@render_result = NtiReceiptBuilder::Renderer.new(
  template: template, receipt_object: order
).call

render template: 'nti_receipt_builder/templates/print', layout: false
```

Omit `receipt_object:` and the renderer uses your declared samples without calling a single
mapping method — that is what the designer's preview does.

`RenderResult` exposes `elements` (presenters in paint order), `overflow?` and
`content_height_mm`. Preload whatever associations your scalar mappings traverse; the gem
cannot know them.

## JavaScript and CSS

```js
// app/javascript/controllers/index.js
import { registerNtiReceiptBuilder } from 'nti_receipt_builder'

registerNtiReceiptBuilder(application)
```

```css
/* app/assets/stylesheets/application.css */
@import 'nti_receipt_builder';
```

Identifiers are `nrb-builder`, `nrb-canvas`, `nrb-draggable`, `nrb-print` and `nrb-properties`.
Set `--nrb-accent` and `--nrb-accent-rgb` to tint the builder's selection and palette
affordances; both fall back to Tabler's primary.

## Host requirements

1. **Tabler 1.x with Bootstrap JS** in the layout — the builder chrome uses Tabler's card,
   button and form classes, and the preview modal uses Bootstrap's dismiss behaviour.
2. **`Turbo::Streams::TagBuilder` responding to** `open_modal(size:, &block)`, `close_modal`,
   `toast(message, type:)` and `reload_datatable(id)`, with matching `turbo_stream` action
   handlers in your JavaScript. The install generator supplies these if you lack them.
3. **`receipt_owner`** on the controller including the concern.
4. Optional: a global `window.Toast` with `.warning(message)` for the element-limit notice.
   The builder degrades silently without it.
5. Optional: the `material-symbols-outlined` icon font, used for palette and toolbar icons.

## Limits

Enforced by `LayoutValidator` before anything persists, which is what bounds the memory a
single template can consume:

| Limit | Value |
|---|---|
| Elements per template | 60 |
| Minimum element dimension | 1.0mm |
| Text length | 500 |
| Fallback / prefix / suffix | 200 / 50 / 50 |
| Order-line columns | 1–6 |
| Font size | 6–72pt |
| `z-index` | 0–1000 |

## Development

```bash
bin/setup
createdb nti_receipt_builder_test    # specs need PostgreSQL — layout is jsonb
bundle exec rspec
bundle exec rubocop
```

Specs run against a minimal dummy Rails app in `spec/dummy`.

## License

MIT.
