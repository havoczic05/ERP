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
      return Result.failure(nil, [ PG_DUMP_MISSING ])
    end

    stdout, stderr, status = Open3.capture3(env, "pg_dump", *pg_dump_args)

    if status.success?
      Result.success(stdout)
    else
      Result.failure(nil, [ sanitize_error(stderr) ])
    end
  end

  # Write pg_dump output to a .sql file on disk, streaming via Open3.popen3
  # to avoid holding the entire dump in RAM.
  def self.dump_to_file(dir = backup_dir)
    unless pg_dump_available?
      return Result.failure(nil, [ PG_DUMP_MISSING ])
    end

    FileUtils.mkdir_p(dir)
    filename = "erp-#{Time.current.strftime('%Y-%m-%d-%H%M')}.sql"
    filepath = File.join(dir, filename)

    Open3.popen3(env, "pg_dump", *pg_dump_args) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      File.open(filepath, "w") { |f| IO.copy_stream(stdout, f) }
      unless wait_thr.value.success?
        File.delete(filepath) rescue nil
        return Result.failure(nil, [ sanitize_error(stderr.read) ])
      end
    end

    Result.success(filepath)
  end

  # Return recent .sql backup files sorted by mtime descending.
  def self.list_recent(dir = backup_dir, limit: 20)
    return [] unless Dir.exist?(dir)

    Dir.glob(File.join(dir, "*.sql"))
       .map { |f| { filename: File.basename(f), size: File.size(f), mtime: File.mtime(f) } }
       .sort_by { |h| h[:mtime] }
       .reverse
       .first(limit)
  end

  # Delete .sql backup files older than +days+ days.
  def self.prune_old(days: 14, dir: backup_dir)
    return unless Dir.exist?(dir)

    threshold = Time.current - days.days
    Dir.glob(File.join(dir, "*.sql")).each do |file|
      File.delete(file) if File.mtime(file) < threshold
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
      args = [ "--format=plain", "--no-owner", "--no-acl", "--no-password" ]
      config = db_config

      args += [ "--host",     config["host"] ]     if config["host"].present?
      args += [ "--port",     config["port"].to_s ] if config["port"].present?
      args += [ "--username", config["username"] ]  if config["username"].present?
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

    def backup_dir
      Rails.root.join("db", "backups").to_s
    end
  end

  private_class_method :pg_dump_available?, :pg_dump_args, :env, :db_config, :backup_dir
end
