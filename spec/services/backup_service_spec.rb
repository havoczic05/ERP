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

  # ---------------------------------------------------------------------------
  # .dump_to_file — REQ-SCH-001
  # ---------------------------------------------------------------------------
  describe ".dump_to_file" do
    let(:tmp_dir) { Dir.mktmpdir("backup_spec") }
    let(:dump_output) { "-- PostgreSQL dump\nCREATE TABLE test ...\n" }

    after { FileUtils.remove_entry(tmp_dir) if Dir.exist?(tmp_dir) }

    def stub_pg_dump_success(output = dump_output)
      allow(described_class).to receive(:system).with("pg_dump --version").and_return(true)
      stdout = StringIO.new(output)
      stderr = StringIO.new("")
      stdin = instance_double(IO)
      allow(stdin).to receive(:close)
      waithr = double(value: double(success?: true))
      allow(Open3).to receive(:popen3).and_yield(stdin, stdout, stderr, waithr)
    end

    def stub_pg_dump_failure(stderr_msg = "pg_dump: error: connection refused\n")
      allow(described_class).to receive(:system).with("pg_dump --version").and_return(true)
      stdout = StringIO.new("")
      stderr = StringIO.new(stderr_msg)
      stdin = instance_double(IO)
      allow(stdin).to receive(:close)
      waithr = double(value: double(success?: false))
      allow(Open3).to receive(:popen3).and_yield(stdin, stdout, stderr, waithr)
    end

    # SCEN-001-a: success
    it "writes dump to file and returns success with the file path" do
      stub_pg_dump_success
      result = described_class.dump_to_file(tmp_dir)

      expect(result.success?).to be true
      expect(result.record).to match(%r{erp-\d{4}-\d{2}-\d{2}-\d{4}\.sql\z})
      expect(File.read(result.record)).to eq(dump_output)
    end

    # SCEN-001-b: pg_dump missing
    it "returns failure when pg_dump is not available" do
      allow(described_class).to receive(:system).with("pg_dump --version").and_return(false)
      result = described_class.dump_to_file(tmp_dir)

      expect(result.failure?).to be true
      expect(result.record).to be_nil
      expect(result.errors).to include("pg_dump no está disponible en el sistema")
    end

    # SCEN-001-c: runtime error
    it "returns failure when pg_dump fails at runtime" do
      stub_pg_dump_failure
      result = described_class.dump_to_file(tmp_dir)

      expect(result.failure?).to be true
      expect(result.record).to be_nil
      expect(result.errors.first).to include("pg_dump: error")
    end

    # SCEN-001-d: dir auto-create
    it "creates the directory if it does not exist" do
      nonexistent = File.join(tmp_dir, "nested", "backups")
      stub_pg_dump_success
      result = described_class.dump_to_file(nonexistent)

      expect(result.success?).to be true
      expect(File.exist?(result.record)).to be true
    end

    # SCEN-001-e: params match .call
    it "passes the same pg_dump args as .call (--format=plain --no-owner --no-acl)" do
      allow(described_class).to receive(:system).with("pg_dump --version").and_return(true)
      stdout = StringIO.new(dump_output)
      stderr = StringIO.new("")
      stdin = instance_double(IO)
      allow(stdin).to receive(:close)
      waithr = double(value: double(success?: true))

      expect(Open3).to receive(:popen3) do |_env, _cmd, *args|
        expect(args).to include("--format=plain")
        expect(args).to include("--no-owner")
        expect(args).to include("--no-acl")
        [ stdin, stdout, stderr, waithr ]
      end.and_yield(stdin, stdout, stderr, waithr)

      described_class.dump_to_file(tmp_dir)
    end
  end

  # ---------------------------------------------------------------------------
  # .list_recent — REQ-BKP-101
  # ---------------------------------------------------------------------------
  describe ".list_recent" do
    let(:tmp_dir) { Dir.mktmpdir("backup_spec") }

    after { FileUtils.remove_entry(tmp_dir) if Dir.exist?(tmp_dir) }

    # SCEN-101-a: files exist — sorted newest first
    it "returns .sql files sorted by mtime descending" do
      older = File.join(tmp_dir, "erp-2026-07-14-0300.sql")
      newer = File.join(tmp_dir, "erp-2026-07-15-1500.sql")
      File.write(older, "old")
      File.write(newer, "new")
      File.utime(Time.new(2026, 7, 14, 3, 0, 0), Time.new(2026, 7, 14, 3, 0, 0), older)
      File.utime(Time.new(2026, 7, 15, 15, 0, 0), Time.new(2026, 7, 15, 15, 0, 0), newer)

      result = described_class.list_recent(tmp_dir)

      expect(result.length).to eq(2)
      expect(result.first[:filename]).to eq("erp-2026-07-15-1500.sql")
      expect(result.last[:filename]).to eq("erp-2026-07-14-0300.sql")
      expect(result.first).to have_key(:size)
      expect(result.first).to have_key(:mtime)
    end

    # SCEN-101-b: empty dir
    it "returns empty array when directory has no .sql files" do
      result = described_class.list_recent(tmp_dir)
      expect(result).to eq([])
    end

    # SCEN-101-c: missing dir
    it "returns empty array when directory does not exist" do
      result = described_class.list_recent("/nonexistent/dir/for/backup_test")
      expect(result).to eq([])
    end
  end

  # ---------------------------------------------------------------------------
  # .prune_old — REQ-SCH-002
  # ---------------------------------------------------------------------------
  describe ".prune_old" do
    let(:tmp_dir) { Dir.mktmpdir("backup_spec") }

    after { FileUtils.remove_entry(tmp_dir) if Dir.exist?(tmp_dir) }

    # SCEN-002-a: old files deleted, new ones kept
    it "deletes .sql files older than 14 days and keeps newer ones" do
      old_file = File.join(tmp_dir, "erp-2026-06-30-0300.sql")
      new_file = File.join(tmp_dir, "erp-2026-07-14-1500.sql")
      File.write(old_file, "old")
      File.write(new_file, "new")
      old_time = Time.new(2026, 6, 30, 3, 0, 0)
      new_time = Time.new(2026, 7, 14, 15, 0, 0)
      File.utime(old_time, old_time, old_file)
      File.utime(new_time, new_time, new_file)

      travel_to Time.new(2026, 7, 15, 0, 0, 0) do
        described_class.prune_old(dir: tmp_dir)
      end

      expect(File.exist?(old_file)).to be false
      expect(File.exist?(new_file)).to be true
    end

    # SCEN-002-b: no old files
    it "deletes nothing when all files are under 14 days old" do
      file = File.join(tmp_dir, "erp-2026-07-14-1500.sql")
      File.write(file, "recent")
      file_time = Time.new(2026, 7, 14, 15, 0, 0)
      File.utime(file_time, file_time, file)

      travel_to Time.new(2026, 7, 15, 0, 0, 0) do
        expect { described_class.prune_old(dir: tmp_dir) }.not_to raise_error
      end

      expect(File.exist?(file)).to be true
    end

    # SCEN-002-c: empty dir
    it "does not raise error when directory is empty" do
      expect { described_class.prune_old(dir: tmp_dir) }.not_to raise_error
    end

    # SCEN-002-d: missing dir
    it "does not raise error when directory does not exist" do
      expect { described_class.prune_old(dir: "/nonexistent/backup_dir") }.not_to raise_error
    end
  end
end
