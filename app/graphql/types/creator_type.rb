# frozen_string_literal: true

class CreatorType < BaseObject
  description "A creator."

  field :id, ID, null: true, description: "The ID of the creator."
  field :type, String, null: false, description: "The type of the item."
  field :name, String, null: true, description: "The name of the creator."
  field :given_name, String, null: true, description: "Given name. In the U.S., the first name of a Person."
  field :family_name, String, null: true, description: "Family name. In the U.S., the last name of an Person."
  field :affiliation, [AffiliationType], null: true, description: "The organizational or institutional affiliation of the creator."

  def type
    object.name_type == "Organizational" ? "Organization" : "Person"
  end
end
