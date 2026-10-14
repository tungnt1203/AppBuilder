# Where a US ZIP code is: its state's code and its city, for checkout to fill them in as soon as
# the buyer types the ZIP. From GeoNames' postal codes (lib/shop/data/us_zip_codes.tsv, CC BY 4.0),
# read once on the first lookup.
#
#   ZipCode.lookup("78701") # => { state: "TX", city: "Austin" }
module ZipCode
  FILE = Shop::Engine.root.join("lib/shop/data/us_zip_codes.tsv")

  # nil for anything that isn't a known 5-digit ZIP ("78701-1234" counts as 78701).
  def self.lookup(zip)
    zip = zip.to_s.strip[/\A(\d{5})(?:-\d{4})?\z/, 1] or return
    table[zip]
  end

  def self.table
    @table ||= FILE.each_line.with_object({}) do |line, table|
      next if line.start_with?("#")

      zip, state, city = line.chomp.split("\t", 3)
      table[zip] ||= { state:, city: }.freeze
    end.freeze
  end
end
