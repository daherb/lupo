class DoiSerializer
  include FastJsonapi::ObjectSerializer

  set_key_transform :camel_lower
  set_type :dois
  set_id :uid
  # don't cache dois, as works are cached using the doi model

  attributes :doi, :prefix, :suffix, :identifiers, :alternate_identifiers, :creators, :titles, :publisher, :container, :publication_year, :subjects, :contributors, :dates, :language, :types, :related_identifiers, :sizes, :formats, :version, :rights_list, :descriptions, :geo_locations, :funding_references, :xml, :url, :content_url, :metadata_version, :schema_version, :source, :is_active, :state, :reason, :landing_page, :view_count, :views_over_time, :download_count, :downloads_over_time, :reference_count, :citation_count, :citations_over_time, :part_count, :part_of_count, :version_count, :version_of_count, :created, :registered, :published, :updated
  attributes :prefix, :suffix, :views_over_time, :downloads_over_time, :citations_over_time, if: Proc.new { |object, params| params && params[:detail] }
  
  belongs_to :client, record_type: :clients
  has_many :media, record_type: :media, id_method_name: :uid, if: Proc.new { |object, params| params && params[:detail] && !params[:is_collection]}
  has_many :references, record_type: :dois, serializer: DoiSerializer, object_method_name: :indexed_references, if: Proc.new { |object, params| params && params[:detail] }
  has_many :citations, record_type: :dois, serializer: DoiSerializer, object_method_name: :indexed_citations, if: Proc.new { |object, params| params && params[:detail] }
  has_many :parts, record_type: :dois, serializer: DoiSerializer, object_method_name: :indexed_parts, if: Proc.new { |object, params| params && params[:detail] }
  has_many :part_of, record_type: :dois, serializer: DoiSerializer, object_method_name: :indexed_part_of, if: Proc.new { |object, params| params && params[:detail] }
  has_many :versions, record_type: :dois, serializer: DoiSerializer, object_method_name: :indexed_versions, if: Proc.new { |object, params| params && params[:detail] }
  has_many :version_of, record_type: :dois, serializer: DoiSerializer, object_method_name: :indexed_version_of, if: Proc.new { |object, params| params && params[:detail] }

  attribute :xml, if: Proc.new { |object, params| params && params[:detail] } do |object|
    begin
      Base64.strict_encode64(object.xml) if object.xml.present?
    rescue ArgumentError
      nil
    end
  end

  attribute :doi do |object|
    object.uid
  end

  attribute :creators do |object, params|
    # Always return an array of creators and affiliations
    # use new array format only if affiliation param present
    Array.wrap(object.creators).map do |c|
      c["affiliation"] = Array.wrap(c["affiliation"]).map do |a|
        if params[:affiliation]
          a
        else
          a["name"] 
        end
      end.compact
      c
    end.compact
  end

  attribute :contributors, if: Proc.new { |object, params| params && params[:composite].blank? } do |object, params|
    # Always return an array of contributors and affiliations
    # use new array format only if param present
    Array.wrap(object.contributors).map do |c|
      c["affiliation"] = Array.wrap(c["affiliation"]).map do |a|
        if params[:affiliation]
          a
        else
          a["name"] 
        end
      end.compact
      c
    end.compact
  end

  attribute :rights_list do |object|
    Array.wrap(object.rights_list)
  end

  attribute :funding_references, if: Proc.new { |object, params| params && params[:composite].blank? } do |object|
    Array.wrap(object.funding_references)
  end

  attribute :identifiers do |object|
    Array.wrap(object.identifiers).select { |r| r["identifierType"] != "DOI" }
  end

  attribute :alternate_identifiers, if: Proc.new { |object, params| params && params[:detail] } do |object|
    Array.wrap(object.identifiers).select { |r| r["identifierType"] != "DOI" }.map do |a|
      { "alternateIdentifierType" => a["identifierType"], "alternateIdentifier" => a["identifier"] }
    end.compact
  end

  attribute :related_identifiers, if: Proc.new { |object, params| params && params[:composite].blank? } do |object|
    Array.wrap(object.related_identifiers)
  end

  attribute :geo_locations, if: Proc.new { |object, params| params && params[:composite].blank? } do |object|
    Array.wrap(object.geo_locations)
  end

  attribute :dates do |object|
    Array.wrap(object.dates)
  end

  attribute :subjects, if: Proc.new { |object, params| params && params[:composite].blank? } do |object|
    Array.wrap(object.subjects)
  end

  attribute :sizes do |object|
    Array.wrap(object.sizes)
  end

  attribute :formats do |object|
    Array.wrap(object.formats)
  end

  attribute :container do |object|
    object.container || {}
  end

  attribute :types do |object|
    object.types || {}
  end

  attribute :state do |object|
    object.aasm_state
  end

  attribute :version do |object|
    object.version_info
  end

  attribute :published do |object|
    object.respond_to?(:published) ? object.published : nil
  end

  attribute :is_active do |object|
    object.is_active.to_s.getbyte(0) == 1 ? true : false
  end

  attribute :landing_page, if: Proc.new { |object, params| params[:current_ability] && params[:current_ability].can?(:read_landing_page_results, object) == true } do |object|
    object.landing_page
  end
end
