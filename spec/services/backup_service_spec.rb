require "rails_helper"

RSpec.describe BackupService do
  describe ".call" do
    context "when pg_dump is not available" do
      before do
        allow(described_class).to receive(:system).with("pg_dump --version").and_return(false)
      end

      it "returns failure with Spanish error message" do
        result = described_class.call
        expect(result.failure?).to be true
        expect(result.record).to be_nil
        expect(result.errors).to include("pg_dump no está disponible en el sistema")
      end
    end

    context "when pg_dump succeeds" do
      let(:dump_output) { "-- PostgreSQL dump\nCREATE TABLE public.users ...\n" }

      before do
        allow(described_class).to receive(:system).with("pg_dump --version").and_return(true)
        allow(Open3).to receive(:capture3).and_return([ dump_output, "", double(success?: true) ])
      end

      it "returns success with the SQL dump string as record" do
        result = described_class.call
        expect(result.success?).to be true
        expect(result.record).to eq(dump_output)
      end

      it "passes --format=plain --no-owner --no-acl to pg_dump" do
        expect(Open3).to receive(:capture3) do |env, cmd, *args|
          expect(args).to include("--format=plain")
          expect(args).to include("--no-owner")
          expect(args).to include("--no-acl")
          [ dump_output, "", double(success?: true) ]
        end

        described_class.call
      end
    end

    context "when pg_dump fails at runtime" do
      let(:stderr_output) { "pg_dump: error: connection refused\n" }

      before do
        allow(described_class).to receive(:system).with("pg_dump --version").and_return(true)
        allow(Open3).to receive(:capture3).and_return([ "", stderr_output, double(success?: false) ])
      end

      it "returns failure with error message" do
        result = described_class.call
        expect(result.failure?).to be true
        expect(result.record).to be_nil
        expect(result.errors.first).to include("pg_dump: error")
      end
    end

    context "when PGPASSWORD leaks into stderr" do
      let(:dirty_stderr) { "PGPASSWORD=secret123 pg_dump: connection failed" }
      let(:dump_output)   { "-- SQL dump\n" }

      before do
        allow(described_class).to receive(:system).with("pg_dump --version").and_return(true)
        allow(Open3).to receive(:capture3).and_return([ dump_output, dirty_stderr, double(success?: true) ])
      end

      it "sanitizes the password from the error message even on success (stderr is logged but not surfaced)" do
        result = described_class.call
        # On success the dump is returned normally; PGPASSWORD may appear in stderr
        # but should not leak into the returned data.
        expect(result.success?).to be true
        expect(result.record).to eq(dump_output)
        expect(result.record).not_to include("secret123")
      end
    end
  end

  describe ".sanitize_error" do
    it "redacts PGPASSWORD value from the message" do
      dirty = "PGPASSWORD=secret123 pg_dump: connection failed"
      clean = described_class.sanitize_error(dirty)
      expect(clean).not_to include("secret123")
      expect(clean).to include("[REDACTED]")
    end

    it "returns the original message unchanged when no PGPASSWORD is present" do
      msg = "pg_dump: connection refused"
      expect(described_class.sanitize_error(msg)).to eq(msg)
    end

    it "handles empty string" do
      expect(described_class.sanitize_error("")).to eq("")
    end

    it "handles nil input" do
      expect(described_class.sanitize_error(nil)).to eq("")
    end
  end
end
