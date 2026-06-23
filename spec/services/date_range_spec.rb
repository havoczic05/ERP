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

  describe ".upcoming" do
    it "returns a range from today through N days ahead" do
      travel_to Time.zone.local(2026, 6, 22, 14, 0) do
        expect(DateRange.upcoming("3")).to eq(Date.new(2026, 6, 22)..Date.new(2026, 6, 25))
        expect(DateRange.upcoming(5)).to eq(Date.new(2026, 6, 22)..Date.new(2026, 6, 27))
      end
    end

    it "returns nil for blank, zero, or non-positive input" do
      expect(DateRange.upcoming("")).to be_nil
      expect(DateRange.upcoming(nil)).to be_nil
      expect(DateRange.upcoming("0")).to be_nil
      expect(DateRange.upcoming("-2")).to be_nil
    end
  end
end
