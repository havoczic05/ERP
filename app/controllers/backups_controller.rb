class BackupsController < ApplicationController
  def new
    authorize :backup
  end

  def create
    authorize :backup
    result = BackupService.call

    if result.success?
      send_data result.record,
                filename: "erp-#{Date.current}.sql",
                type: "application/sql",
                disposition: "attachment"
    else
      flash.now[:alert] = result.errors.first
      render :new, status: :unprocessable_content
    end
  end
end
