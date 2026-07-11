require "prawn"
require "prawn/table"
require "stringio"

# Base class for the company's commercial PDFs (invoice/quotation and the
# accounts-receivable report). Holds the shared branded header, the bank-account
# footer and a brand-styled table helper, so both documents stay visually
# consistent. Pure Ruby (Prawn, built-in AFM Helvetica) — runs in CI without Chrome.
#
# Palette mirrors the app design system (app/assets/stylesheets/app.css):
# indigo brand, ink/muted text and the neutral line/surface tints.
class BrandedPdf < Prawn::Document
  BRAND = "3838EC".freeze        # --brand
  BRAND_WEAK = "E7E7FC".freeze   # --brand-weak
  INK = "1B1B2B".freeze          # --ink
  INK_SOFT = "2C3140".freeze     # --ink-soft
  MUTED = "8A8FA0".freeze        # --muted
  LINE = "EDEEF2".freeze         # --line
  LINE_STRONG = "E4E6EC".freeze  # --line-strong
  SURFACE = "F7F8FA".freeze      # --surface (zebra)
  WARNING_WEAK = "F9EFD9".freeze # --warning-weak (total highlight)
  ON_BRAND = "FFFFFF".freeze

  def initialize(**opts)
    super({ page_size: "A4", margin: 40 }.merge(opts))
  end

  private

  # Left-aligned company identity: logo, razon social, optional subtitulo, and
  # the RUC/address/phone detail lines, closed by a brand rule.
  def build_branded_header(company)
    embed_logo(company)

    fill_color INK
    text company.razon_social.to_s, size: 19, style: :bold

    if company.subtitulo.present?
      fill_color INK_SOFT
      text company.subtitulo, size: 11, style: :italic
    end

    fill_color MUTED
    move_down 2
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
        text label, size: 14, style: :bold, align: :right
        fill_color MUTED
        text "N° #{reference}", size: 10, align: :right if reference.present?
        text "Fecha: #{date}", size: 10, align: :right
        fill_color INK
      end
    end
  end

  # Bank-account footer: cards laid out two-per-row (side by side) and anchored to
  # the bottom of the page. Each card is a brand title bar (bank + currency) over
  # the account/interbank lines.
  def build_bank_footer(company)
    accounts = company.bank_accounts.to_a
    return if accounts.empty?

    gutter = 16
    col_w = (bounds.width - gutter) / 2.0
    pairs = accounts.each_slice(2).to_a

    # Push the footer to the bottom of the page when there is room for it above
    # the current cursor (short documents); otherwise it just flows after content.
    needed = 14 + (pairs.size * 52) + ((pairs.size - 1) * 10)
    move_cursor_to(needed) if cursor > needed

    stroke_color LINE_STRONG
    stroke_horizontal_rule
    stroke_color "000000"
    move_down 10

    pairs.each_with_index do |(left, right), index|
      row = [ bank_card_cell(left, col_w), "", right ? bank_card_cell(right, col_w) : "" ]
      table([ row ], width: bounds.width, column_widths: [ col_w, gutter, col_w ]) do |t|
        t.cells.borders = []
        t.cells.padding = 0
        t.cells.valign = :top
      end
      move_down 10 unless index == pairs.size - 1
    end
  end

  # A single bank card as a standalone table (used as a cell in the 2-column row).
  def bank_card_cell(account, width)
    heading = [ account.bank, account.currency_label.presence ].compact.join(" ").upcase
    lines = []
    lines << "CTA. CTE.:  #{account.account_number}" if account.account_number.present?
    lines << "CTA. INTERBANCARIA:  #{account.interbank_number}" if account.interbank_number.present?

    make_table([
      [ { content: heading, background_color: BRAND, text_color: ON_BRAND,
          font_style: :bold, size: 8.5, padding: [ 5, 9 ], borders: [] } ],
      [ { content: lines.join("\n"), text_color: INK_SOFT, size: 8, leading: 2,
          padding: [ 6, 9 ], borders: [ :left, :right, :bottom ],
          border_color: LINE, border_width: 1 } ]
    ], width: width)
  end

  # A table with the brand-colored header row and subtle zebra striping.
  def branded_table(rows, column_widths: nil, &block)
    options = { header: true, width: bounds.width }
    options[:column_widths] = column_widths if column_widths
    table(rows, options) do |t|
      t.cells.padding = [ 5, 6 ]
      t.cells.border_color = LINE
      t.cells.size = 8
      (1...rows.length).each { |i| t.row(i).background_color = SURFACE if i.even? }
      t.row(0).background_color = BRAND
      t.row(0).text_color = ON_BRAND
      t.row(0).font_style = :bold
      t.row(0).size = 7.5
      block&.call(t)
    end
  end

  def brand_rule
    stroke_color BRAND
    self.line_width = 1.5
    stroke_horizontal_rule
    self.line_width = 1
    stroke_color "000000"
  end

  def fmt(value)
    ActiveSupport::NumberHelper.number_to_currency(value, unit: "USD ")
  end

  # Number-only currency format (no unit) — used where the "USD" prefix is
  # rendered separately (smaller) so the amount stands out.
  def fmt_amount(value)
    ActiveSupport::NumberHelper.number_to_currency(value, unit: "", format: "%n")
  end
end
