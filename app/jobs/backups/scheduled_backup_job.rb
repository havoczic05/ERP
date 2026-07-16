module Backups
  # solid_queue recurring job: runs BackupService.dump_to_file then prune_old.
  # Scheduled at 03:00 and 15:00 America/Lima via config/recurring.yml.
  class ScheduledBackupJob < ApplicationJob
    queue_as :default

    def perform
      result = BackupService.dump_to_file

      if result.success?
        Rails.logger.info "[Backup] Backup completado: #{result.record}"
        BackupService.prune_old
      else
        Rails.logger.error "[Backup] Error en backup: #{result.errors.join(', ')}"
      end
    end
  end
end
