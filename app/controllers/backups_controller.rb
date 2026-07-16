class BackupsController < ApplicationController
  FILENAME_REGEX = /\Aerp-\d{4}-\d{2}-\d{2}-\d{4}\.sql\z/

  def new
    authorize :backup
    @backups = BackupService.list_recent
  end

  def create
    authorize :backup
    result = BackupService.call

    if result.success?
      # Save a copy to disk before streaming (best-effort).
      dump_result = BackupService.dump_to_file rescue nil
      if dump_result.nil? || dump_result.failure?
        Rails.logger.warn "[Backup] No se pudo guardar el respaldo en disco: #{dump_result&.errors&.join(', ')}"
      end

      send_data result.record,
                filename: "erp-#{Date.current}.sql",
                type: "application/sql",
                disposition: "attachment"
    else
      flash.now[:alert] = result.errors.first
      render :new, status: :unprocessable_content
    end
  end

  def download
    authorize :backup, :download?

    raw = params[:filename].to_s
    unless raw.match?(FILENAME_REGEX)
      return head :bad_request
    end

    filename = File.basename(raw)
    filepath = Rails.root.join("db", "backups", filename)
    unless File.exist?(filepath)
      return head :not_found
    end

    send_file filepath,
              type: "application/sql",
              disposition: "attachment",
              filename: filename
  end
end
