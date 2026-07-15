require "open3"

# On-demand PostgreSQL backup via pg_dump.
#
# BackupService.call validates pg_dump availability and spawns pg_dump via
# Open3.capture3, returning the SQL dump inline (no disk persistence).
# Authorisation is enforced upstream by BackupsController + BackupPolicy.
#
#   result = BackupService.call
#   if result.success?
#     send_data result.record, filename: "erp-2026-07-15.sql", type: "application/sql"
#   else
#     flash[:alert] = result.errors.first
#   end
class BackupService
  PG_DUMP_MISSING = "pg_dump no está disponible en el sistema"

  # -------------------------------------------------------------------
  # Public API
  # -------------------------------------------------------------------

  def self.call
    unless pg_dump_available?
      return Result.failure(nil, [PG_DUMP_MISSING])
    end

    stdout, stderr, status = Open3.capture3(env, "pg_dump", *pg_dump_args)

    if status.success?
      Result.success(stdout)
    else
      Result.failure(nil, [sanitize_error(stderr)])
    end
  end

  def self.sanitize_error(message)
    return "" if message.nil?

    message.gsub(/PGPASSWORD=\S+/, "PGPASSWORD=[REDACTED]")
  end

  # -------------------------------------------------------------------
  # Private helpers
  # -------------------------------------------------------------------

  class << self
    private

    def pg_dump_available?
      system("pg_dump --version")
    end

    def pg_dump_args
      args = ["--format=plain", "--no-owner", "--no-acl", "--no-password"]
      config = db_config

      args += ["--host",     config["host"]]     if config["host"].present?
      args += ["--port",     config["port"].to_s] if config["port"].present?
      args += ["--username", config["username"]]  if config["username"].present?
      args << config["database"]

      args
    end

    def env
      pw = db_config["password"]
      pw.present? ? { "PGPASSWORD" => pw } : {}
    end

    def db_config
      @db_config ||= ActiveRecord::Base.connection_db_config.configuration_hash.with_indifferent_access
    end
  end

  private_class_method :pg_dump_available?, :pg_dump_args, :env, :db_config
end
