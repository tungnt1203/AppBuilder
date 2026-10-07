# Countries checkout can ship to: ISO 3166-1 alpha-2 codes and their names.
# Add any country the shop needs; the code is what orders store.
module Country
  NAMES = {
    "AR" => "Argentina",
    "AU" => "Australia",
    "AT" => "Austria",
    "BE" => "Belgium",
    "BR" => "Brazil",
    "BG" => "Bulgaria",
    "CA" => "Canada",
    "CL" => "Chile",
    "CO" => "Colombia",
    "HR" => "Croatia",
    "CY" => "Cyprus",
    "CZ" => "Czechia",
    "DK" => "Denmark",
    "EE" => "Estonia",
    "FI" => "Finland",
    "FR" => "France",
    "DE" => "Germany",
    "GR" => "Greece",
    "HK" => "Hong Kong",
    "HU" => "Hungary",
    "IS" => "Iceland",
    "IN" => "India",
    "ID" => "Indonesia",
    "IE" => "Ireland",
    "IL" => "Israel",
    "IT" => "Italy",
    "JP" => "Japan",
    "LV" => "Latvia",
    "LT" => "Lithuania",
    "LU" => "Luxembourg",
    "MY" => "Malaysia",
    "MT" => "Malta",
    "MX" => "Mexico",
    "NL" => "Netherlands",
    "NZ" => "New Zealand",
    "NO" => "Norway",
    "PE" => "Peru",
    "PH" => "Philippines",
    "PL" => "Poland",
    "PT" => "Portugal",
    "PR" => "Puerto Rico",
    "RO" => "Romania",
    "SA" => "Saudi Arabia",
    "SG" => "Singapore",
    "SK" => "Slovakia",
    "SI" => "Slovenia",
    "ZA" => "South Africa",
    "KR" => "South Korea",
    "ES" => "Spain",
    "SE" => "Sweden",
    "CH" => "Switzerland",
    "TW" => "Taiwan",
    "TH" => "Thailand",
    "TR" => "Türkiye",
    "AE" => "United Arab Emirates",
    "GB" => "United Kingdom",
    "US" => "United States",
    "VN" => "Vietnam"
  }.freeze

  def self.codes
    NAMES.keys
  end

  def self.name_for(code)
    NAMES.fetch(code.to_s.upcase, code.to_s)
  end

  # [[name, code], …] for a select, in name order.
  def self.options(codes = self.codes)
    codes.map { |code| [ name_for(code), code ] }.sort_by(&:first)
  end
end
