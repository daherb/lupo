# frozen_string_literal: true

class OrganizationType < BaseObject
  description "Information about organizations"

  field :id, ID, null: true, description: "ROR ID"
  field :type, String, null: false, description: "The type of the item."
  field :name, String, null: false, description: "The name of the organization."
  field :alternate_name, [String], null: true, description: "An alias for the organization."
  field :identifiers, [IdentifierType], null: true, description: "The identifier(s) for the organization."
  field :url, [String], null: true, hash_key: "links", description: "URL of the organization."
  field :address, AddressType, null: true, description: "Physical address of the organization."
  field :view_count, Integer, null: true, description: "The number of views according to the Counter Code of Practice."
  field :download_count, Integer, null: true, description: "The number of downloads according to the Counter Code of Practice."
  field :citation_count, Integer, null: true, description: "The number of citations."

  field :datasets, DatasetConnectionType, null: true, description: "Datasets from this organization", connection: true do
    argument :query, String, required: false
    argument :ids, [String], required: false
    argument :user_id, String, required: false
    argument :funder_id, String, required: false
    argument :repository_id, String, required: false
    argument :member_id, String, required: false
    argument :has_citations, Int, required: false
    argument :has_parts, Int, required: false
    argument :has_versions, Int, required: false
    argument :has_views, Int, required: false
    argument :has_downloads, Int, required: false
    argument :first, Int, required: false, default_value: 25
  end

  field :publications, PublicationConnectionType, null: true, description: "Publications from this organization", connection: true do
    argument :query, String, required: false
    argument :ids, [String], required: false
    argument :user_id, String, required: false
    argument :funder_id, String, required: false
    argument :repository_id, String, required: false
    argument :member_id, String, required: false
    argument :has_citations, Int, required: false
    argument :has_parts, Int, required: false
    argument :has_versions, Int, required: false
    argument :has_views, Int, required: false
    argument :has_downloads, Int, required: false
    argument :first, Int, required: false, default_value: 25
  end

  field :softwares, SoftwareConnectionType, null: true, description: "Software from this organization", connection: true do
    argument :query, String, required: false
    argument :ids, [String], required: false
    argument :user_id, String, required: false
    argument :funder_id, String, required: false
    argument :repository_id, String, required: false
    argument :member_id, String, required: false
    argument :has_citations, Int, required: false
    argument :has_parts, Int, required: false
    argument :has_versions, Int, required: false
    argument :has_views, Int, required: false
    argument :has_downloads, Int, required: false
    argument :first, Int, required: false, default_value: 25
  end

  field :works, WorkConnectionType, null: true, description: "Works from this organization", connection: true do
    argument :query, String, required: false
    argument :ids, [String], required: false
    argument :user_id, String, required: false
    argument :funder_id, String, required: false
    argument :repository_id, String, required: false
    argument :member_id, String, required: false
    argument :has_citations, Int, required: false
    argument :has_parts, Int, required: false
    argument :has_versions, Int, required: false
    argument :has_views, Int, required: false
    argument :has_downloads, Int, required: false
    argument :first, Int, required: false, default_value: 25
  end

  def alternate_name
    object.aliases + object.acronyms
  end

  def identifiers
    Array.wrap(object.id).map { |o| { "identifier_type" => "ROR", "identifier" => o } } + 
    Array.wrap(object.fund_ref).map { |o| { "identifier_type" => "fundRef", "identifier" => o } } + 
    Array.wrap(object.wikidata).map { |o| { "identifier_type" => "wikidata", "identifier" => o } } + 
    Array.wrap(object.grid).map { |o| { "identifier_type" => "grid", "identifier" => o } } + 
    Array.wrap(object.wikipedia_url).map { |o| { "identifier_type" => "wikipedia", "identifier" => o } }
  end

  def address
    { "type" => "postalAddress",
      "country" => object.country.to_h.fetch("name", nil) }
  end

  def publications(**args)
    args[:resource_type_id] = "Text"
    r = response(args)

    r.results.to_a
  end

  def datasets(**args)
    args[:resource_type_id] = "Dataset"
    r = response(args)

    r.results.to_a
  end

  def softwares(**args)
    args[:resource_type_id] = "Software"
    r = response(args)

    r.results.to_a
  end

  def works(**args)
    r = response(args)

    r.results.to_a
  end

  def view_count
    args = { first: 0 }
    r = response(args)
    r.results.total.positive? ? aggregate_count(r.response.aggregations.views.buckets) : 0
  end

  def download_count
    args = { first: 0 }
    r = response(args)
    r.results.total.positive? ? aggregate_count(r.response.aggregations.downloads.buckets) : 0
  end

  def citation_count
    args = { first: 0 }
    r = response(args)
    r.results.total.positive? ? aggregate_count(r.response.aggregations.citations.buckets) : 0
  end

  def response(**args)
    Doi.query(args[:query], ids: args[:ids], affiliation_id: object[:id], user_id: args[:user_id], client_id: args[:repository_id], provider_id: args[:member_id], funder_id: args[:funder_id], resource_type_id: args[:resource_type_id], has_person: args[:has_person], has_funder: args[:has_funder], has_citations: args[:has_citations], has_parts: args[:has_parts], has_versions: args[:has_versions], has_views: args[:has_views], has_downloads: args[:has_downloads], state: "findable", page: { number: 1, size: args[:first] })
  end
end
