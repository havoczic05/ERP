# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_27_120100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "amortizations", force: :cascade do |t|
    t.decimal "amount_usd", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.bigint "installment_id", null: false
    t.datetime "paid_at", null: false
    t.datetime "updated_at", null: false
    t.index ["installment_id"], name: "index_amortizations_on_installment_id"
  end

  create_table "bank_accounts", force: :cascade do |t|
    t.string "account_number"
    t.string "bank", null: false
    t.bigint "company_settings_id", null: false
    t.datetime "created_at", null: false
    t.string "currency_label"
    t.string "interbank_number"
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["company_settings_id", "position"], name: "index_bank_accounts_on_company_settings_id_and_position"
    t.index ["company_settings_id"], name: "index_bank_accounts_on_company_settings_id"
  end

  create_table "clients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "departamento"
    t.string "direccion"
    t.datetime "discarded_at"
    t.string "distrito"
    t.string "document_number", null: false
    t.string "document_type", null: false
    t.string "full_name", null: false
    t.string "phone", null: false
    t.string "provincia"
    t.datetime "updated_at", null: false
    t.index ["document_number"], name: "index_clients_on_document_number", unique: true, where: "(discarded_at IS NULL)"
  end

  create_table "company_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "direccion"
    t.string "razon_social", null: false
    t.string "ruc", null: false
    t.string "subtitulo"
    t.string "telefono"
    t.datetime "updated_at", null: false
  end

  create_table "credit_notes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "issued_at", null: false
    t.text "notes"
    t.bigint "sale_id", null: false
    t.decimal "total_usd", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["sale_id"], name: "index_credit_notes_on_sale_id", unique: true
  end

  create_table "installments", force: :cascade do |t|
    t.decimal "amount_usd", precision: 10, scale: 2, null: false
    t.decimal "balance_usd", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.date "due_date", null: false
    t.integer "installment_number", null: false
    t.bigint "sale_id", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["sale_id", "installment_number"], name: "index_installments_on_sale_id_and_installment_number", unique: true
    t.index ["sale_id"], name: "index_installments_on_sale_id"
  end

  create_table "products", force: :cascade do |t|
    t.decimal "base_price_usd", precision: 10, scale: 2, null: false
    t.string "brand", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "name", null: false
    t.string "sku", null: false
    t.integer "stock", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "warehouse_id", null: false
    t.index ["sku"], name: "index_products_on_sku", unique: true, where: "(discarded_at IS NULL)"
    t.index ["warehouse_id"], name: "index_products_on_warehouse_id"
    t.check_constraint "stock >= 0", name: "check_stock_non_negative"
  end

  create_table "sale_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "line_total_usd", precision: 10, scale: 2, null: false
    t.bigint "product_id", null: false
    t.integer "quantity", null: false
    t.bigint "sale_id", null: false
    t.decimal "unit_price_usd", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_sale_items_on_product_id"
    t.index ["sale_id"], name: "index_sale_items_on_sale_id"
    t.check_constraint "quantity > 0", name: "check_quantity_positive"
  end

  create_table "sales", force: :cascade do |t|
    t.jsonb "billing_response_metadata", default: {}
    t.string "billing_status", default: "pending"
    t.bigint "client_id", null: false
    t.datetime "confirmed_at"
    t.string "correlative", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "document_type", null: false
    t.text "notes"
    t.bigint "source_cotizacion_id"
    t.string "status", null: false
    t.decimal "subtotal_usd", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "tax_usd", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "total_usd", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.bigint "warehouse_id", null: false
    t.index ["client_id"], name: "index_sales_on_client_id"
    t.index ["correlative"], name: "index_sales_on_correlative", unique: true
    t.index ["document_type"], name: "index_sales_on_document_type"
    t.index ["status"], name: "index_sales_on_status"
    t.index ["warehouse_id"], name: "index_sales_on_warehouse_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "password_digest"
    t.string "role"
    t.datetime "updated_at", null: false
  end

  create_table "warehouses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "location"
    t.string "name", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "amortizations", "installments"
  add_foreign_key "bank_accounts", "company_settings", column: "company_settings_id"
  add_foreign_key "credit_notes", "sales"
  add_foreign_key "installments", "sales"
  add_foreign_key "products", "warehouses"
  add_foreign_key "sale_items", "products"
  add_foreign_key "sale_items", "sales"
  add_foreign_key "sales", "clients"
  add_foreign_key "sales", "sales", column: "source_cotizacion_id"
  add_foreign_key "sales", "warehouses"
end
