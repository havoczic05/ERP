namespace :erp do
  namespace :backup do
    desc "Crea un respaldo completo de la base de datos PostgreSQL vía pg_dump"
    task create: :environment do
      result = BackupService.call

      if result.success?
        puts "Respaldo completado: #{result.record.bytesize} bytes generados."
      else
        puts "Error: #{result.errors.first}"
        exit 1
      end
    end
  end
end
