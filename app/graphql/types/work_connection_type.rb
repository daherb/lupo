# frozen_string_literal: true

class WorkConnectionType < BaseConnection
  edge_type(WorkEdgeType)
  field_class GraphQL::Cache::Field

  field :total_count, Integer, null: false, cache: true
  field :years, [FacetType], null: true, cache: true
  field :resource_types, [FacetType], null: true, cache: true

  def total_count
    args = prepare_args(object.arguments)

    response(args).results.total  
  end

  def years
    args = prepare_args(object.arguments)
    
    res = response(args)
    res.results.total.positive? ? facet_by_year(res.response.aggregations.years.buckets) : []
  end

  def resource_types
    args = prepare_args(object.arguments)

    res = response(args)
    res.results.total.positive? ? facet_by_resource_type(res.response.aggregations.resource_types.buckets) : []
  end

  def response(**args)
    Doi.query(args[:query],
              ids: args[:ids],
              user_id: args[:user_id], 
              client_id: args[:repository_id], 
              provider_id: args[:member_id],
              funder_id: args[:funder_id], 
              affiliation_id: args[:affiliation_id],
              re3data_id: args[:re3data_id], 
              year: args[:year], 
              resource_type_id: args[:resource_type_id],
              has_person: args[:has_person],
              has_funder: args[:has_funder], 
              has_organization: args[:has_organization], 
              has_citations: args[:has_citations],
              has_parts: args[:has_parts],
              has_versions: args[:has_versions],
              has_views: args[:has_views], 
              has_downloads: args[:has_downloads], 
              page: { number: 1, size: 0 })
  end
end
