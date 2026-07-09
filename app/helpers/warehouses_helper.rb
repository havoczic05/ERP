module WarehousesHelper
  # Submission-aware "which warehouse should be preselected" helper, shared by
  # the new-sale and new-product forms (RF-DW-3, RF-DW-4). Contract:
  #   1. record.warehouse_id if present          -> edit / convert / already-set
  #   2. elsif the record's own param key is present in params (a re-render of
  #      a submission) -> honor the user's submitted warehouse_id, even blank
  #      (a cleared submit stays blank, it is NOT re-forced back to the default)
  #   3. else CompanySettings.instance.default_warehouse_id, but ONLY for a
  #      fresh new_record? (never on a persisted record with no warehouse_id)
  #
  # Detecting a failed re-render via `params` presence (not `record.errors`) is
  # deliberate: SalesController#create's failure path re-renders `new` with
  # `@sale = result.sale || Sale.new`, and `result.sale` is nil on failure, so
  # both `record.warehouse_id` and `record.errors` can be blank/empty on that
  # sale — only `params[:sale]` reliably tells us "the user just submitted this
  # form." Products don't need this (ProductsController#create re-renders with
  # `Product.new(product_create_params)`, so rule 1 already covers it), but the
  # same helper stays correct there too.
  def preselected_warehouse_id(record)
    return record.warehouse_id if record.warehouse_id.present?

    param_key = record.model_name.param_key
    if params[param_key].present?
      return params.dig(param_key, :warehouse_id).presence
    end

    CompanySettings.instance.default_warehouse_id if record.new_record?
  end
end
