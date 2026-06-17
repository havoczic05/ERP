# SaleAnnulmentService — annuls a confirmed Sale atomically.
#
# Admin-only enforcement is done at the POLICY layer (SalePolicy#annul?).
# This service is role-agnostic — it does not check user roles.
#
# Transaction steps:
#   1. Idempotency guard: reject if already anulada (no side effects).
#   2. Set sale status='anulada' and discarded_at=Time.current.
#   3. Restore product stock for each sale_item (venta only).
#   4. Void all installments (status='anulada', amount_usd=0, balance_usd=0).
#   5. Create a CreditNote atomically.
#   6. Commit → Result.success(sale).
#
# Returns a Result PORO.
class SaleAnnulmentService
  def self.call(sale, user)
    new(sale, user).call
  end

  def initialize(sale, user)
    @sale = sale
    @user = user
  end

  def call
    # Step 1: idempotency guard (outside transaction — no side effects needed)
    if @sale.anulada?
      return Result.failure(@sale, [ "This sale has already been annulled" ])
    end

    ActiveRecord::Base.transaction do
      # Step 2: set status and soft-delete timestamp
      @sale.update!(status: "anulada", discarded_at: Time.current)

      # Step 3: restore product stock (venta only)
      # Lock product rows individually in id-ascending order (deadlock-free)
      product_ids = @sale.sale_items.pluck(:product_id).sort

      product_ids.each do |pid|
        product = Product.find(pid)
        product.with_lock do
          qty = @sale.sale_items.where(product_id: pid).sum(:quantity)
          product.update_column(:stock, product.stock + qty)
        end
      end

      # Step 4: void installments (bypass model validations via update_columns — zeroing amounts
      # on an anulada installment is intentional and valid at the business level).
      @sale.installments.each do |installment|
        installment.update_columns(status: "anulada", amount_usd: 0.00, balance_usd: 0.00)
      end

      # Step 5: create CreditNote (sale_id unique index prevents double-notes)
      CreditNote.create!(
        sale:      @sale,
        total_usd: @sale.total_usd,
        issued_at: Time.current
      )

      Result.success(@sale)
    end
  rescue ActiveRecord::RecordInvalid => e
    Result.failure(@sale, [ e.message ])
  rescue ActiveRecord::StatementInvalid => e
    Result.failure(@sale, [ e.message ])
  end
end
