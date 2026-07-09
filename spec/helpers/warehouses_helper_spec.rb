require "rails_helper"

# Helper spec for the shared submission-aware preselection helper (RF-DW-3, RF-DW-4).
# Contract (design #300, WARNING 3):
#   1. record.warehouse_id if present            -> edit / convert / submitted-with-value
#   2. elsif params[record's param key] present   -> honor the user's own submission
#      (a cleared/blank submit stays blank, NOT re-forced to the default)
#   3. else CompanySettings.instance.default_warehouse_id if record.new_record?
RSpec.describe WarehousesHelper, type: :helper do
  describe "#preselected_warehouse_id" do
    context "fresh new record, no submission, a default is configured (rule 3)" do
      it "returns the configured default warehouse id" do
        warehouse = create(:warehouse)
        create(:company_settings, default_warehouse: warehouse)
        sale = build(:sale, warehouse: nil, warehouse_id: nil)

        expect(helper.preselected_warehouse_id(sale)).to eq(warehouse.id)
      end
    end

    context "fresh new record, no submission, no default configured (rule 3, blank)" do
      it "returns nil" do
        sale = build(:sale, warehouse: nil, warehouse_id: nil)

        expect(helper.preselected_warehouse_id(sale)).to be_nil
      end
    end

    context "record already carries its own warehouse_id (rule 1 — edit/convert/product create failure)" do
      it "returns the record's own warehouse_id, ignoring a configured default" do
        own_warehouse = create(:warehouse, name: "Almacén Norte")
        default_warehouse = create(:warehouse, name: "Almacén Central")
        create(:company_settings, default_warehouse: default_warehouse)
        product = build(:product, warehouse: own_warehouse)

        expect(helper.preselected_warehouse_id(product)).to eq(own_warehouse.id)
      end
    end

    context "no record warehouse_id, but the form's own params key is present (rule 2 — failed sales submit)" do
      it "honors the user's submitted warehouse_id, ignoring a configured default" do
        default_warehouse = create(:warehouse, name: "Almacén Central")
        submitted_warehouse = create(:warehouse, name: "Almacén Norte")
        create(:company_settings, default_warehouse: default_warehouse)
        sale = build(:sale, warehouse: nil, warehouse_id: nil)
        params[:sale] = { warehouse_id: submitted_warehouse.id.to_s }

        expect(helper.preselected_warehouse_id(sale)).to eq(submitted_warehouse.id.to_s)
      end

      it "stays blank when the user submitted a cleared (blank) warehouse_id — does NOT re-force the default" do
        default_warehouse = create(:warehouse, name: "Almacén Central")
        create(:company_settings, default_warehouse: default_warehouse)
        sale = build(:sale, warehouse: nil, warehouse_id: nil)
        params[:sale] = { warehouse_id: "" }

        expect(helper.preselected_warehouse_id(sale)).to be_nil
      end
    end
  end
end
