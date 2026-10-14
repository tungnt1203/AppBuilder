# States, provinces and territories of the countries whose carriers (and Printify) need the
# region as its code: "CA" for California, "ON" for Ontario. Checkout offers them as a list and
# turns a name typed in full into its code.
module Region
  NAMES = {
    "US" => {
      "AL" => "Alabama", "AK" => "Alaska", "AZ" => "Arizona", "AR" => "Arkansas", "CA" => "California",
      "CO" => "Colorado", "CT" => "Connecticut", "DE" => "Delaware", "DC" => "District of Columbia",
      "FL" => "Florida", "GA" => "Georgia", "HI" => "Hawaii", "ID" => "Idaho", "IL" => "Illinois",
      "IN" => "Indiana", "IA" => "Iowa", "KS" => "Kansas", "KY" => "Kentucky", "LA" => "Louisiana",
      "ME" => "Maine", "MD" => "Maryland", "MA" => "Massachusetts", "MI" => "Michigan", "MN" => "Minnesota",
      "MS" => "Mississippi", "MO" => "Missouri", "MT" => "Montana", "NE" => "Nebraska", "NV" => "Nevada",
      "NH" => "New Hampshire", "NJ" => "New Jersey", "NM" => "New Mexico", "NY" => "New York",
      "NC" => "North Carolina", "ND" => "North Dakota", "OH" => "Ohio", "OK" => "Oklahoma", "OR" => "Oregon",
      "PA" => "Pennsylvania", "RI" => "Rhode Island", "SC" => "South Carolina", "SD" => "South Dakota",
      "TN" => "Tennessee", "TX" => "Texas", "UT" => "Utah", "VT" => "Vermont", "VA" => "Virginia",
      "WA" => "Washington", "WV" => "West Virginia", "WI" => "Wisconsin", "WY" => "Wyoming",
      "PR" => "Puerto Rico", "AA" => "Armed Forces Americas", "AE" => "Armed Forces Europe", "AP" => "Armed Forces Pacific"
    },
    "CA" => {
      "AB" => "Alberta", "BC" => "British Columbia", "MB" => "Manitoba", "NB" => "New Brunswick",
      "NL" => "Newfoundland and Labrador", "NS" => "Nova Scotia", "NT" => "Northwest Territories",
      "NU" => "Nunavut", "ON" => "Ontario", "PE" => "Prince Edward Island", "QC" => "Quebec",
      "SK" => "Saskatchewan", "YT" => "Yukon"
    },
    "AU" => {
      "ACT" => "Australian Capital Territory", "NSW" => "New South Wales", "NT" => "Northern Territory",
      "QLD" => "Queensland", "SA" => "South Australia", "TAS" => "Tasmania", "VIC" => "Victoria",
      "WA" => "Western Australia"
    }
  }.freeze

  # The country's regions ({ "CA" => "California", … }), or nil when it has none to pick from.
  def self.for(country)
    NAMES[country.to_s.upcase]
  end

  # The region's code from its code or its name, in any case ("california", "Ca" => "CA"); nil
  # when the country has no list or the region isn't on it.
  def self.code_for(country, value)
    regions = self.for(country) or return
    value = value.to_s.squish.downcase.delete(".")
    regions.find { |code, name| code.downcase == value || name.downcase == value }&.first
  end
end
