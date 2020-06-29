# frozen_string_literal: true

class BaseConnection < GraphQL::Types::Relay::BaseConnection
  REGIONS = {
    "APAC" => "Asia and Pacific",
    "EMEA" => "Europe, Middle East and Africa",
    "AMER" => "Americas"
  }

  REGISTRATION_AGENCIES = {
    "airiti" =>   "Airiti",
    "cnki" =>     "CNKI",
    "crossref" => "Crossref",
    "datacite" => "DataCite",
    "istic" =>    "ISTIC",
    "jalc" =>     "JaLC",
    "kisti" =>    "KISTI",
    "medra" =>    "mEDRA",
    "op" =>       "OP"
  }
  
  def doi_from_url(url)
    if /\A(?:(http|https):\/\/(dx\.)?(doi.org|handle.test.datacite.org)\/)?(doi:)?(10\.\d{4,5}\/.+)\z/.match?(url)
      uri = Addressable::URI.parse(url)
      uri.path.gsub(/^\//, "").downcase
    end
  end

  def orcid_from_url(url)
    if /\A(?:(http|https):\/\/(orcid.org)\/)(.+)\z/.match?(url)
      uri = Addressable::URI.parse(url)
      uri.path.gsub(/^\//, "").downcase
    end
  end

  def facet_by_year(arr)
    arr.map do |hsh|
      { "id" => hsh["key_as_string"][0..3],
        "title" => hsh["key_as_string"][0..3],
        "count" => hsh["doc_count"] }
    end
  end

  def facet_by_key(arr)
    arr.map do |hsh|
      { "id" => hsh["key"],
        "title" => hsh["key"].titleize,
        "count" => hsh["doc_count"] }
    end
  end

  def facet_by_resource_type(arr)
    arr.map do |hsh|
      { "id" => hsh["key"].underscore.dasherize,
        "title" => hsh["key"],
        "count" => hsh["doc_count"] }
    end
  end

  def facet_by_software(arr)
    arr.map do |hsh|
      { "id" => hsh["key"].parameterize(separator: '_'),
        "title" => hsh["key"],
        "count" => hsh["doc_count"] }
    end
  end

  def facet_by_combined_key(arr)
    arr.map do |hsh|
      id, title = hsh["key"].split(":", 2)

      { "id" => id,
        "title" => title,
        "count" => hsh["doc_count"] }
    end
  end

  def facet_by_region(arr)
    arr.map do |hsh|
      { "id" => hsh["key"].downcase,
        "title" => REGIONS[hsh["key"]] || hsh["key"],
        "count" => hsh["doc_count"] }
    end
  end

  def facet_by_fos(arr)
    arr.map do |hsh|
      title = hsh["key"].gsub("FOS: ", "")
      { "id" => title.parameterize(separator: '_'),
        "title" => title,
        "count" => hsh["doc_count"] }
    end
  end

  def facet_by_registration_agency(arr)
    arr.map do |hsh|
      { "id" => hsh["key"],
        "title" => REGISTRATION_AGENCIES[hsh["key"]] || hsh["key"],
        "count" => hsh["doc_count"] }
    end
  end

  # remove years in the future and only keep 10 most recent years
  def facet_by_range(arr)
    arr.select { |a| a["key_as_string"].to_i <= 2020 }[0..9].map do |hsh|
      { "id" => hsh["key_as_string"],
        "title" => hsh["key_as_string"],
        "count" => hsh["doc_count"] }
    end
  end

  def facet_by_language(arr)
    arr.map do |hsh|
      la = ISO_639.find_by_code(hsh["key"])
      { "id" => hsh["key"],
        "title" => la.english_name,
        "count" => hsh["doc_count"] }
    end
  end
end
