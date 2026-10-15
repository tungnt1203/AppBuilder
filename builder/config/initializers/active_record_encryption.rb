# Keys for `encrypts` (the owner's business settings: Stripe, Printify, Meta), derived from
# secret_key_base so the builder needs no encryption keys in its credentials. If secret_key_base
# ever changes, encrypted values can't be read and owners enter them again.
Rails.application.config.to_prepare do
  generator = Rails.application.key_generator
  ActiveRecord::Encryption.configure(
    primary_key: generator.generate_key("active_record_encryption/primary_key", 32).unpack1("H*"),
    deterministic_key: generator.generate_key("active_record_encryption/deterministic_key", 32).unpack1("H*"),
    key_derivation_salt: generator.generate_key("active_record_encryption/key_derivation_salt", 32).unpack1("H*")
  )
end
