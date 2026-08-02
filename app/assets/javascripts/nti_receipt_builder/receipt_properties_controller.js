import { Controller } from "@hotwired/stimulus"

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (char) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;"
  }[char]))
}

const FONT_SIZE_MIN = 6
const FONT_SIZE_MAX = 72
const LINE_HEIGHT_MIN = 0.8
const LINE_HEIGHT_MAX = 3.0
const ROW_SPACING_MIN = 0
const ROW_SPACING_MAX = 10
const Z_INDEX_MIN = 0
const Z_INDEX_MAX = 1000
const MIN_ELEMENT_DIMENSION_MM = 1.0
const TEXT_MAX_LENGTH = 500
const FALLBACK_MAX_LENGTH = 200
const PREFIX_MAX_LENGTH = 50
const SUFFIX_MAX_LENGTH = 50

// Connects to data-controller="nrb-properties"
export default class extends Controller {
  static targets = ["content"]
  static values = { scalarVariables: Object }

  connect() {
    this.boundKeydown = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  render(element) {
    this.currentElement = element

    if (!element) {
      this.contentTarget.innerHTML =
        '<p class="text-secondary nrb-receipt-hint">Select an element on the canvas to edit its properties.</p>'
      return
    }

    this.contentTarget.innerHTML = this.templateFor(element)
  }

  fieldChanged(event) {
    if (!this.currentElement) return

    const field = event.params.field
    const valueType = event.params.valueType || "string"
    const value = this.readFieldValue(event.target, valueType)
    const patch = this.buildPatch(field, value)

    this.dispatch("changed", {
      prefix: "receipt-properties",
      bubbles: true,
      detail: { id: this.currentElement.id, patch }
    })
  }

  deleteElement() {
    if (!this.currentElement) return

    this.dispatch("delete-requested", {
      prefix: "receipt-properties",
      bubbles: true,
      detail: { id: this.currentElement.id }
    })
  }

  handleKeydown(event) {
    if (event.key !== "Delete" && event.key !== "Backspace") return
    if (!this.currentElement) return

    const active = document.activeElement
    const isTextEntry = active && (active.tagName === "INPUT" || active.tagName === "TEXTAREA" || active.isContentEditable)
    if (isTextEntry) return

    event.preventDefault()
    this.deleteElement()
  }

  readFieldValue(target, valueType) {
    if (valueType === "boolean") return target.checked

    if (valueType === "integer") {
      const num = parseInt(target.value, 10)
      return Number.isNaN(num) ? 0 : num
    }

    if (valueType === "number") {
      const num = parseFloat(target.value)
      return Number.isNaN(num) ? 0 : num
    }

    return target.value
  }

  buildPatch(field, value) {
    const path = field.split(".")
    if (path.length === 1) return { [path[0]]: value }

    const [group, key] = path
    return { [group]: { [key]: value } }
  }

  // Template building

  templateFor(element) {
    return [this.commonFieldsTemplate(element), this.typeFieldsTemplate(element), this.deleteButtonTemplate()].join("")
  }

  commonFieldsTemplate(element) {
    return `
      <div class="row g-2">
        <div class="col-6">${this.numberField("X (mm)", "x_mm", element.x_mm, { min: 0, step: 0.1 })}</div>
        <div class="col-6">${this.numberField("Y (mm)", "y_mm", element.y_mm, { min: 0, step: 0.1 })}</div>
      </div>
      <div class="row g-2">
        <div class="col-6">${this.numberField("Width (mm)", "width_mm", element.width_mm, { min: MIN_ELEMENT_DIMENSION_MM, step: 0.1 })}</div>
        <div class="col-6">${this.numberField("Height (mm)", "height_mm", element.height_mm, { min: MIN_ELEMENT_DIMENSION_MM, step: 0.1 })}</div>
      </div>
      <div class="row g-2">
        <div class="col-6">${this.numberField("Layer (z-index)", "z_index", element.z_index || 0, { min: Z_INDEX_MIN, max: Z_INDEX_MAX, step: 1, valueType: "integer" })}</div>
        <div class="col-6 d-flex align-items-end">${this.checkboxField("Visible", "visible", element.visible !== false)}</div>
      </div>
    `
  }

  typeFieldsTemplate(element) {
    if (element.type === "variable") return this.variableFieldsTemplate(element)
    if (element.type === "text") return this.textFieldsTemplate(element)
    return this.orderLinesFieldsTemplate(element)
  }

  variableFieldsTemplate(element) {
    return `
      <hr class="my-3">
      ${this.selectField("Variable", "variable_key", element.variable_key, this.scalarVariableOptions())}
      ${this.textField("Prefix", "prefix", element.prefix, { maxlength: PREFIX_MAX_LENGTH })}
      ${this.textField("Suffix", "suffix", element.suffix, { maxlength: SUFFIX_MAX_LENGTH })}
      ${this.textField("Fallback (if empty)", "fallback", element.fallback, { maxlength: FALLBACK_MAX_LENGTH })}
      <hr class="my-3">
      ${this.styleFieldsTemplate(element.styles || {})}
    `
  }

  textFieldsTemplate(element) {
    return `
      <hr class="my-3">
      ${this.textareaField("Text", "text", element.text, { maxlength: TEXT_MAX_LENGTH })}
      <hr class="my-3">
      ${this.styleFieldsTemplate(element.styles || {})}
    `
  }

  styleFieldsTemplate(styles) {
    return `
      <div class="row g-2">
        <div class="col-6">${this.numberField("Font Size (pt)", "styles.font_size_pt", styles.font_size_pt || 10, { min: FONT_SIZE_MIN, max: FONT_SIZE_MAX, step: 1 })}</div>
        <div class="col-6">${this.selectField("Weight", "styles.font_weight", styles.font_weight || "normal", [["Normal", "normal"], ["Bold", "bold"]])}</div>
      </div>
      <div class="row g-2">
        <div class="col-6">${this.selectField("Align", "styles.text_align", styles.text_align || "left", [["Left", "left"], ["Center", "center"], ["Right", "right"]])}</div>
        <div class="col-6">${this.numberField("Line Height", "styles.line_height", styles.line_height || 1.2, { min: LINE_HEIGHT_MIN, max: LINE_HEIGHT_MAX, step: 0.1 })}</div>
      </div>
    `
  }

  orderLinesFieldsTemplate(element) {
    const config = element.config || {}
    const columns = config.columns || []

    const columnRows = columns
      .map(
        (column) => `
      <tr>
        <td>${escapeHtml(column.label)}</td>
        <td>${escapeHtml(column.key)}</td>
        <td>${escapeHtml(String(column.width_mm))}mm</td>
        <td>${escapeHtml(column.align)}</td>
      </tr>
    `
      )
      .join("")

    return `
      <hr class="my-3">
      <div class="row g-2">
        <div class="col-6 d-flex align-items-end">${this.checkboxField("Show header row", "config.show_header", config.show_header !== false)}</div>
        <div class="col-6">${this.numberField("Font Size (pt)", "config.font_size_pt", config.font_size_pt || 8, { min: FONT_SIZE_MIN, max: FONT_SIZE_MAX, step: 1 })}</div>
      </div>
      ${this.numberField("Row Spacing (mm)", "config.row_spacing_mm", config.row_spacing_mm != null ? config.row_spacing_mm : 1.0, { min: ROW_SPACING_MIN, max: ROW_SPACING_MAX, step: 0.1 })}
      <label class="form-label mt-2">Columns</label>
      <table class="table table-sm nrb-receipt-columns-table">
        <thead><tr><th>Label</th><th>Key</th><th>Width</th><th>Align</th></tr></thead>
        <tbody>${columnRows}</tbody>
      </table>
      <p class="text-secondary nrb-receipt-hint">Column layout isn&rsquo;t editable yet &mdash; shown for reference.</p>
    `
  }

  deleteButtonTemplate() {
    return `
      <hr class="my-3">
      <button type="button" class="btn btn-outline-danger w-100" data-action="click->nrb-properties#deleteElement">
        <span class="material-symbols-outlined pe-1">delete</span>Delete Element
      </button>
    `
  }

  // Field builders

  numberField(label, field, value, { min, max, step, valueType = "number" } = {}) {
    const minAttr = min != null ? `min="${min}"` : ""
    const maxAttr = max != null ? `max="${max}"` : ""
    const stepAttr = step != null ? `step="${step}"` : ""

    return `
      <div class="form-group mb-3">
        <label class="form-label">${escapeHtml(label)}</label>
        <input type="number" class="form-control" value="${escapeHtml(value)}" ${minAttr} ${maxAttr} ${stepAttr}
            data-nrb-properties-field-param="${field}"
            data-nrb-properties-value-type-param="${valueType}"
            data-action="input->nrb-properties#fieldChanged">
      </div>
    `
  }

  textField(label, field, value, { maxlength } = {}) {
    return `
      <div class="form-group mb-3">
        <label class="form-label">${escapeHtml(label)}</label>
        <input type="text" class="form-control" value="${escapeHtml(value)}" maxlength="${maxlength}"
            data-nrb-properties-field-param="${field}"
            data-nrb-properties-value-type-param="string"
            data-action="input->nrb-properties#fieldChanged">
      </div>
    `
  }

  textareaField(label, field, value, { maxlength } = {}) {
    return `
      <div class="form-group mb-3">
        <label class="form-label">${escapeHtml(label)}</label>
        <textarea class="form-control" rows="3" maxlength="${maxlength}"
            data-nrb-properties-field-param="${field}"
            data-nrb-properties-value-type-param="string"
            data-action="input->nrb-properties#fieldChanged">${escapeHtml(value)}</textarea>
      </div>
    `
  }

  checkboxField(label, field, checked) {
    return `
      <div class="form-check form-switch mb-3">
        <input type="checkbox" class="form-check-input" ${checked ? "checked" : ""}
            data-nrb-properties-field-param="${field}"
            data-nrb-properties-value-type-param="boolean"
            data-action="change->nrb-properties#fieldChanged">
        <label class="form-check-label">${escapeHtml(label)}</label>
      </div>
    `
  }

  selectField(label, field, selected, options) {
    const optionTags = options
      .map(
        ([optLabel, optValue]) =>
          `<option value="${escapeHtml(optValue)}" ${optValue === selected ? "selected" : ""}>${escapeHtml(optLabel)}</option>`
      )
      .join("")

    return `
      <div class="form-group mb-3">
        <label class="form-label">${escapeHtml(label)}</label>
        <select class="form-select"
            data-nrb-properties-field-param="${field}"
            data-nrb-properties-value-type-param="string"
            data-action="change->nrb-properties#fieldChanged">
          ${optionTags}
        </select>
      </div>
    `
  }

  scalarVariableOptions() {
    return Object.entries(this.scalarVariablesValue).map(([key, label]) => [label, key])
  }
}
