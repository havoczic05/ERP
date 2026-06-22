require "rails_helper"

RSpec.describe DateRange do
  describe ".for" do
    it "maps today to the current day range" do
      travel_to Time.zone.local(2026, 6, 22, 14, 0) do
        expect(DateRange.for("today")).to eq(Date.new(2026, 6, 22).all_day)
      end
    end

    it "maps week and month to the current week/month ranges" do
      travel_to Time.zone.local(2026, 6, 22, 14, 0) do
        expect(DateRange.for("week")).to eq(Date.new(2026, 6, 22).all_week)
        expect(DateRange.for("month")).to eq(Date.new(2026, 6, 22).all_month)
      end
    end

    it "returns nil for blank/unknown presets" do
      expect(DateRange.for("")).to be_nil
      expect(DateRange.for(nil)).to be_nil
      expect(DateRange.for("bogus")).to be_nil
    end
  end

  describe ".for_day" do
    it "returns the all-day range for a valid ISO date" do
      expect(DateRange.for_day("2026-06-17")).to eq(Date.new(2026, 6, 17).all_day)
    end

    it "returns nil for blank or invalid input" do
      expect(DateRange.for_day("")).to be_nil
      expect(DateRange.for_day("not-a-date")).to be_nil
    end
  end
end
