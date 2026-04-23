module PricingResolver
  # Unit-price lookup for a trade + snake_case pricing key.
  #
  # In Jesse's main repo this will resolve contractor_pricings -> default_pricings
  # -> regional multiplier. In this sandbox the DB layers do not exist yet, so it
  # returns the caller-supplied default (the legacy JS fallback). Signature is
  # stable — swap the implementation when the DB lands without touching callers.
  def self.price(trade:, key:, contractor_id: nil, default:)
    _ = trade
    _ = key
    _ = contractor_id
    default
  end
end
