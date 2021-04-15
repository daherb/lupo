# frozen_string_literal: true

class MemberConnectionWithTotalType < BaseConnection
  edge_type(MemberEdgeType)
  field_class GraphQL::Cache::Field

  field :total_count, Integer, null: false, cache: true
  field :years, [FacetType], null: true, cache: true
  field :regions, [FacetType], null: true, cache: true
  field :member_types, [FacetType], null: true, cache: true
  field :organization_types, [FacetType], null: true, cache: true
  field :focus_areas, [FacetType], null: true, cache: true
  field :non_profit_statuses, [FacetType], null: true, cache: true
  field :has_required_contacts, [FacetType], null: true, cache: true

  def total_count
    object.total_count
  end

  def years
    facet_by_year(object.aggregations.years.buckets)
  end

  def regions
    facet_by_region(object.aggregations.regions.buckets)
  end

  def member_types
    facet_by_key(object.aggregations.member_types.buckets)
  end

  def organization_types
    facet_by_key(object.aggregations.organization_types.buckets)
  end

  def focus_areas
    facet_by_key(object.aggregations.focus_areas.buckets)
  end

  def non_profit_statuses
    facet_by_key(object.aggregations.non_profit_statuses.buckets)
  end

  def has_required_contacts
    facet_by_key(object.aggregations.has_required_contacts.buckets)
  end
end
