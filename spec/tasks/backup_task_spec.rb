require "rails_helper"
require "rake"

RSpec.describe "erp:backup:create", type: :task do
  before(:all) do
    Rails.application.load_tasks
  end

  after do
    Rake::Task["erp:backup:create"].reenable
  end

  it "invokes BackupService.call and outputs success" do
    allow(BackupService).to receive(:call).and_return(
      Result.success("-- PostgreSQL dump\n")
    )
    expect { Rake::Task["erp:backup:create"].invoke }
      .to output(/Respaldo completado/).to_stdout
  end

  it "invokes BackupService.call and outputs failure" do
    allow(BackupService).to receive(:call).and_return(
      Result.failure(nil, ["pg_dump no está disponible en el sistema"])
    )
    expect { Rake::Task["erp:backup:create"].invoke }
      .to output(/Error/).to_stdout
  end
end
