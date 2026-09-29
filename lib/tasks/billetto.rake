namespace :billetto do
  desc "Import public events from the Billetto API (optional MAX_PAGES, 100 events per page)"
  task import: :environment do
    max_pages = ENV["MAX_PAGES"].presence&.to_i
    result = Events::Import.call(max_pages: max_pages)
    puts "Fetched #{result.fetched}, imported #{result.imported}, skipped #{result.skipped} events."
  rescue Billetto::Client::Error => e
    abort "Billetto import failed: #{e.class.name.demodulize}: #{e.message}"
  end
end
