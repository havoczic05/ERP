require "prawn"
require "prawn/table"
require "stringio"

# Base class for the company's commercial PDFs (invoice/quotation and the
# accounts-receivable report). Holds the shared branded header, the bank-account
# footer and a brand-styled table helper, so both documents stay visually
# consistent. Pure Ruby (Prawn, built-in AFM fonts) — runs in CI without Chrome.
class BrandedPdf < Prawn::Document
  # Botanical-green brand, approximated to sRGB hex from the app's
  # oklch(0.46 0.11 160) design token (app/assets/stylesheets/app.css).
  BRAND = "2E7D5B".freeze
  BRAND_WEAK = "EAF4EF".freeze
  INK = "2B2B2B".freeze
  MUTED = "6B6B6B".freeze
  LINE = "DDDDDD".freeze

  def initialize(**opts)
    super({ page_size: "A4", margin: 40 }.merge(opts))
  end

  private

  # Left-aligned company identity: logo, razon social, optional subtitulo, and
  # the RUC/address/phone detail lines, closed by a brand rule.
  def build_branded_header(company)
    embed_logo(company)

    fill_color INK
    text company.razon_social.to_s, size: 18, style: :bold

    if company.subtitulo.present?
      fill_color BRAND
      text company.subtitulo, size: 10, style: :bold
    end

    fill_color MUTED
    text "RUC: #{company.ruc}", size: 9 if company.ruc.present?
    text company.direccion, size: 9 if company.direccion.present?
    text "Tel: #{company.telefono}", size: 9 if company.telefono.present?

    fill_color INK
    move_down 6
    brand_rule
    move_down 12
  end

  def embed_logo(company)
    return unless company.logo.attached?

    image StringIO.new(company.logo.download), width: 90, position: :left
    move_down 6
  rescue Prawn::Errors::UnsupportedImageType
    # Unsupported image format — render the document without the logo rather than failing.
  end

  # Floating top-right meta block (document label + reference + date). `float`
  # saves/restores the cursor, so the header below still starts at the top-left.
  def build_doc_meta(label:, date:, reference: nil)
    box_width = 190
    float do
      bounding_box([ bounds.width - box_width, bounds.top ], width: box_width) do
        fill_color BRAND
        text label, size: 15, style: :bold, align: :right
        fill_color MUTED
        text "N° #{reference}", size: 10, align: :right if reference.present?
        text "Fecha: #{date}", size: 10, align: :right
        fill_color INK
      end
    end
  end

  # Bank-account footer (BCP, etc.), flowed at the end of the document.
  def build_bank_footer(company)
    accounts = company.bank_accounts.to_a
    return if accounts.empty?

    move_down 16
    brand_rule
    move_down 6

    fill_color BRAND
    text "Cuentas bancarias", size: 9, style: :bold
    fill_color INK

    accounts.each do |account|
      heading = [ account.bank, account.currency_label.presence ].compact.join(" — ")
      details = []
      details << "CTA. CTE.: #{account.account_number}" if account.account_number.present?
      details << "CTA. INTERBANCARIO: #{account.interbank_number}" if account.interbank_number.present?
      line = [ heading, details.join("   ") ].reject(&:blank?).join("   ")
      text line, size: 8
    end
  end

  # A table with the brand-colored header row.
  def branded_table(rows, column_widths: nil, &block)
    options = { header: true, width: bounds.width }
    options[:column_widths] = column_widths if column_widths
    table(rows, options) do |t|
      t.row(0).background_color = BRAND
      t.row(0).text_color = "FFFFFF"
      t.row(0).font_style = :bold
      t.cells.padding = [ 4, 6 ]
      t.cells.border_color = LINE
      t.cells.size = 9
      block&.call(t)
    end
  end

  def brand_rule
    stroke_color BRAND
    stroke_horizontal_rule
    stroke_color "000000"
  end

  def fmt(value)
    ActiveSupport::NumberHelper.number_to_currency(value, unit: "USD ")
  end
end
