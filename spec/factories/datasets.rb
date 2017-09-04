FactoryGirl.define do
  factory :dataset do
    created {Faker::Time.backward(14, :evening)}
    doi { "10.4122/" + Faker::Internet.password(8) }
    updated {Faker::Time.backward(5, :evening)}
    version 1
    is_active 1
    minted {Faker::Time.backward(15, :evening)}
    datacenter_id  { datacentre.symbol }

    association :datacentre, factory: :datacenter, strategy: :create
  end
end
