# Keys for `encrypts` (the shop's Stripe secret key), derived from secret_key_base so a new app
# needs no credentials file: ONCE gives every app its own SECRET_KEY_BASE and keeps it across
# updates. If it ever changes, encrypted values can't be read and the owner enters them again.
Rails.application.config.to_prepare do
  generator = Rails.application.key_generator
  ActiveRecord::Encryption.configure(
    primary_key: generator.generate_key("active_record_encryption/primary_key", 32).unpack1("H*"),
    deterministic_key: generator.generate_key("active_record_encryption/deterministic_key", 32).unpack1("H*"),
    key_derivation_salt: generator.generate_key("active_record_encryption/key_derivation_salt", 32).unpack1("H*")
  )
end
