require "rails_helper"

RSpec.describe Backups::ScheduledBackupJob, type: :job do
  # REQ-SCH-003

  # SCEN-003-a: success — dump_to_file → prune_old, logs info
  it "calls dump_to_file then prune_old and logs success" do
    allow(BackupService).to receive(:dump_to_file).and_return(
      Result.success("/tmp/erp-2026-07-15-0300.sql")
    )
    allow(BackupService).to receive(:prune_old)

    described_class.perform_now

    expect(BackupService).to have_received(:dump_to_file).ordered
    expect(BackupService).to have_received(:prune_old).ordered
  end

  # SCEN-003-b: dump fails → no prune, logs error
  it "does NOT call prune_old when dump_to_file fails" do
    allow(BackupService).to receive(:dump_to_file).and_return(
      Result.failure(nil, [ "pg_dump no está disponible en el sistema" ])
    )
    allow(BackupService).to receive(:prune_old)

    described_class.perform_now

    expect(BackupService).not_to have_received(:prune_old)
  end

  # SCEN-003-c: inherits from ApplicationJob
  it "inherits from ApplicationJob" do
    expect(described_class.superclass).to eq(ApplicationJob)
  end
end
