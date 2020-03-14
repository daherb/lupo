class PrefixSerializer
  include FastJsonapi::ObjectSerializer
  set_key_transform :camel_lower
  set_type :prefixes
  set_id :uid

  attributes :prefix, :created_at

  attribute :prefix do |object|
    object.uid
  end

  has_many :clients, record_type: :clients
  has_many :providers, record_type: :providers
end
