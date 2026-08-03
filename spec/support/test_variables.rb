# frozen_string_literal: true

# A stand-in for a host application's variables class, exercising every derivation path:
# derived labels, an overridden label, declared and omitted samples, and a collection.
class TestVariables < NtiReceiptBuilder::Variables
  MAPPINGS = {
    'CUSTOMER_NAME' => 'customer_name',
    'STORE_NAME' => 'store_name',
    'ORDER_SUBTOTAL' => 'order_subtotal',
    'ORDER_DATETIME' => 'order_datetime',
    'ORDER_LINES' => 'order_lines'
  }.freeze

  variable 'CUSTOMER_NAME', sample: 'Juan Dela Cruz'
  variable 'ORDER_SUBTOTAL', sample: BigDecimal('275.00')
  variable 'ORDER_DATETIME', label: 'Order Date/Time', sample: -> { Time.utc(2026, 7, 31, 14, 32) }
  variable 'ORDER_LINES',
           columns: {
             'description' => { label: 'Description' },
             'quantity' => { label: 'Qty' },
             'unit_price' => { label: 'Unit Price' },
             'line_total' => { label: 'Total' }
           },
           sample: [
             { 'description' => 'Bottled Water 500ml', 'quantity' => 2,
               'unit_price' => BigDecimal('25.00'), 'line_total' => BigDecimal('50.00') }
           ]

  def customer_name = receipt_object.customer_name
  def store_name = receipt_object.store_name
  def order_subtotal = receipt_object.subtotal
  def order_datetime = receipt_object.created_at
  def order_lines = receipt_object.lines
end

TestReceipt = Struct.new(:customer_name, :store_name, :subtotal, :created_at, :lines,
                         keyword_init: true)

# A host that declares a wider collection than the gem would ever guess at. Exists to hold the
# validator to the rule that the host's vocabulary — not a constant in the gem — is the ceiling
# on column count.
class WideVariables < NtiReceiptBuilder::Variables
  MAPPINGS = { 'ORDER_LINES' => 'order_lines' }.freeze

  variable 'ORDER_LINES',
           columns: {
             'no' => { label: '#' }, 'sku' => { label: 'SKU' },
             'product_name' => { label: 'Product' }, 'unit_name' => { label: 'Unit' },
             'category_names' => { label: 'Category' }, 'total_items' => { label: 'Items' },
             'retail_price' => { label: 'Retail Price' }, 'subtotal' => { label: 'Subtotal' }
           }

  def order_lines = receipt_object.lines
end
