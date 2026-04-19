# TEA-157 — Purge junk rows left by the on-demand BigBox API path.
#
# The on-demand loader (BigboxDataLoaderService, source: "bigbox_loader",
# zip_code: "10001") was leaking rows into material_prices with no price and
# wrong trade categorization. The 4 known-bad rows as of 2026-04-19:
#
#   hvac        | 4068 Bi-fold Door           | sku 202532598
#   electrical  | Ceramic Cabinet Knob        | sku 100212074
#   roofing     | Homasote 440-SoundBarrier   | sku 202090212
#   roofing     | Fakro FX301L Skylight       | sku 203003641
#
# Fingerprint: source = "bigbox_loader" AND price IS NULL. This task deletes
# every row matching that fingerprint (not just the 4 named ones) so any
# future leak from the same path gets cleaned up too.
#
# Usage (dry-run by default):
#   bin/rails bigbox:purge_junk_rows
#
# Actually delete (on Railway):
#   railway run bin/rails bigbox:purge_junk_rows CONFIRM=yes
#
namespace :bigbox do
  desc "Purge on-demand-loader junk rows from material_prices (dry-run by default; CONFIRM=yes to delete)"
  task purge_junk_rows: :environment do
    scope = MaterialPrice.where(source: "bigbox_loader").where(price: nil)

    count = scope.count
    puts "[bigbox:purge_junk_rows] Found #{count} row(s) matching junk fingerprint " \
         "(source = 'bigbox_loader' AND price IS NULL):"

    scope.order(:trade, :sku).each do |row|
      puts "  id=#{row.id}  trade=#{row.trade.to_s.ljust(10)}  sku=#{row.sku.to_s.ljust(12)}  " \
           "zip=#{row.zip_code.to_s.ljust(9)}  name=#{row.name}"
    end

    if ENV["CONFIRM"].to_s.strip.downcase == "yes"
      deleted = scope.destroy_all.size
      puts ""
      puts "[bigbox:purge_junk_rows] Deleted #{deleted} row(s)."
      remaining = MaterialPrice.where(source: "bigbox_loader").where(price: nil).count
      if remaining.positive?
        warn "[bigbox:purge_junk_rows] WARNING: #{remaining} row(s) still match the fingerprint after destroy_all."
      else
        puts "[bigbox:purge_junk_rows] Fingerprint is now clean."
      end
    else
      puts ""
      puts "[bigbox:purge_junk_rows] DRY RUN — nothing deleted. Re-run with CONFIRM=yes to purge."
    end
  end
end
