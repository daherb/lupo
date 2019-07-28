class Client < ActiveRecord::Base

  # include helper module for caching infrequently changing resources
  include Cacheable

  # include helper module for managing associated users
  include Userable

  # include helper module for setting password
  include Passwordable

  # include helper module for authentication
  include Authenticable

  # include helper module for Elasticsearch
  include Indexable

  # include helper module for sending emails
  include Mailable

  include Elasticsearch::Model

  # define table and attribute names
  # uid is used as unique identifier, mapped to id in serializer
  self.table_name = "datacentre"

  alias_attribute :flipper_id, :symbol
  alias_attribute :created_at, :created
  alias_attribute :updated_at, :updated
  attr_readonly :symbol
  delegate :symbol, to: :provider, prefix: true
  attr_accessor :password_input

  validates_presence_of :symbol, :name, :contact_name, :contact_email
  validates_uniqueness_of :symbol, message: "This Client ID has already been taken"
  validates_format_of :contact_email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  validates_inclusion_of :role_name, :in => %w( ROLE_DATACENTRE ), :message => "Role %s is not included in the list"
  validates_inclusion_of :client_type, :in => %w( repository periodical ), :message => "Client type %s is not included in the list", if: :client_type?
  validates_associated :provider
  validate :check_id, :on => :create
  validate :freeze_symbol, :on => :update
  validate :check_issn, if: :issn?
  validate :check_certificate, if: :certificate?
  strip_attributes

  belongs_to :provider, foreign_key: :allocator, touch: true
  has_many :dois, foreign_key: :datacentre
  has_many :client_prefixes, foreign_key: :datacentre, dependent: :destroy
  has_many :prefixes, through: :client_prefixes
  has_many :provider_prefixes, through: :client_prefixes

  before_validation :set_defaults
  before_create { self.created = Time.zone.now.utc.iso8601 }
  before_save { self.updated = Time.zone.now.utc.iso8601 }

  after_create :send_welcome_email, unless: Proc.new { Rails.env.test? }

  attr_accessor :target_id

  # use different index for testing
  index_name Rails.env.test? ? "clients-test" : "clients"

  settings index: {
    analysis: {
      analyzer: {
        string_lowercase: { tokenizer: 'keyword', filter: %w(lowercase ascii_folding) }
      },
      normalizer: {
        keyword_lowercase: { type: "custom", filter: %w(lowercase) }
      },
      filter: { 
        ascii_folding: { type: 'asciifolding', preserve_original: true } 
      }
    }
  } do
    mapping dynamic: 'false' do
      indexes :id,            type: :keyword
      indexes :symbol,        type: :keyword
      indexes :provider_id,   type: :keyword
      indexes :re3data_id,    type: :keyword
      indexes :opendoar_id,   type: :integer
      indexes :issn,          type: :keyword
      indexes :prefix_ids,    type: :keyword
      indexes :name,          type: :text, fields: { keyword: { type: "keyword" }, raw: { type: "text", analyzer: "string_lowercase", "fielddata": true }}
      indexes :alternate_name, type: :text, fields: { keyword: { type: "keyword" }, raw: { type: "text", analyzer: "string_lowercase", "fielddata": true }}
      indexes :description,   type: :text
      indexes :contact_name,  type: :text
      indexes :contact_email, type: :text, fields: { keyword: { type: "keyword" }}
      indexes :certificate,   type: :keyword
      indexes :language,      type: :keyword
      indexes :version,       type: :integer
      indexes :is_active,     type: :keyword
      indexes :domains,       type: :text
      indexes :year,          type: :integer
      indexes :url,           type: :text, fields: { keyword: { type: "keyword" }}
      indexes :software,      type: :text, fields: { keyword: { type: "keyword" }, raw: { type: "text", analyzer: "string_lowercase", "fielddata": true }}
      indexes :cache_key,     type: :keyword
      indexes :client_type,   type: :keyword
      indexes :created,       type: :date
      indexes :updated,       type: :date
      indexes :deleted_at,    type: :date
      indexes :cumulative_years, type: :integer, index: "false"

      # include parent objects
      indexes :provider,      type: :object
      indexes :repository,    type: :object
    end
  end

  def as_indexed_json(options={})
    {
      "id" => uid,
      "uid" => uid,
      "provider_id" => provider_id,
      "re3data_id" => re3data_id,
      "opendoar_id" => opendoar_id,
      "issn" => Array.wrap(issn),
      "prefix_ids" => prefix_ids,
      "name" => name,
      "alternate_name" => alternate_name,
      "description" => description,
      "certificate" => Array.wrap(certificate),
      "symbol" => symbol,
      "year" => year,
      "language" => language,
      "contact_name" => contact_name,
      "contact_email" => contact_email,
      "domains" => domains,
      "url" => url,
      "software" => software,
      "is_active" => is_active,
      "password" => password,
      "cache_key" => cache_key,
      "client_type" => client_type,
      "created" => created,
      "updated" => updated,
      "deleted_at" => deleted_at,
      "cumulative_years" => cumulative_years,
      "provider" => provider.as_indexed_json,
      "repository" => cached_repository
    }
  end

  def self.query_fields
    ['uid^10', 'symbol^10', 'name^5', 'description^5', 'contact_name^5', 'contact_email^5', 'domains', 'url', 'software^3', 'repository.subjects.text^3', 'repository.certificates.text^3', '_all']
  end

  def self.query_aggregations
    {
      years: { date_histogram: { field: 'created', interval: 'year', min_doc_count: 1 } },
      cumulative_years: { terms: { field: 'cumulative_years', min_doc_count: 1, order: { _count: "asc" } } },
      providers: { terms: { field: 'provider_id', size: 15, min_doc_count: 1 } },
      software: { terms: { field: 'software.keyword', size: 15, min_doc_count: 1 } },
      client_types: { terms: { field: 'client_type', size: 15, min_doc_count: 1 } },
      certificates: { terms: { field: 'certificate', size: 15, min_doc_count: 1 } }
    }
  end

  def uid
    symbol.downcase
  end

  # workaround for non-standard database column names and association
  def provider_id
    provider_symbol.downcase
  end

  def provider_id=(value)
    r = Provider.where(symbol: value).first
    return nil unless r.present?

    write_attribute(:allocator, r.id)
  end

  def prefix_ids
    prefixes.pluck(:prefix)
  end

  def cached_repository
    cached_repository_response(re3data) if re3data.present?
  end

  def repository
    OpenStruct.new(cached_repository)
  end

  def target_id=(value)
    c = self.class.find_by_id(value)
    return nil unless c.present?

    target = c.records.first

    Doi.transfer(client_id: symbol.downcase, target_id: target.id)
  end

  def index_all_dois
    Doi.index(from_date: "2011-01-01", client_id: id)
  end

  def import_all_dois
    Doi.import_all(from_date: "2011-01-01", client_id: id)
  end

  def import_missing_dois
    Doi.import_missing(from_date: "2011-01-01", client_id: id)
  end

  def cache_key
    "clients/#{uid}-#{updated.iso8601}"
  end

  def password_input=(value)
    write_attribute(:password, encrypt_password_sha256(value)) if value.present?
  end

  # backwards compatibility
  def member
    Provider.where(symbol: provider_id).first if provider_id.present?
  end

  def year
    created_at.year if created_at.present?
  end

  # count years account has been active. Ignore if deleted the same year as created
  def cumulative_years
    if deleted_at && deleted_at.year > created_at.year
      (created_at.year...deleted_at.year).to_a
    elsif deleted_at
      []
    else
      (created_at.year..Date.today.year).to_a
    end
  end

  # attributes to be sent to elasticsearch index
  def to_jsonapi
    attributes = {
      "symbol" => symbol,
      "name" => name,
      "contact-name" => contact_name,
      "contact-email" => contact_email,
      "url" => url,
      "re3data" => re3data,
      "domains" => domains,
      "provider-id" => provider_id,
      "prefixes" => prefixes.map { |p| p.prefix },
      "is-active" => is_active.getbyte(0) == 1,
      "version" => version,
      "created" => created.iso8601,
      "updated" => updated.iso8601,
      "deleted_at" => deleted_at ? deleted_at.iso8601 : nil }

    { "id" => symbol.downcase, "type" => "clients", "attributes" => attributes }
  end

  protected

  def check_issn
    Array.wrap(issn).each do |i|
      errors.add(:issn, "ISSN #{i} is in the wrong format.") unless /\A\d{4}(-)?\d{3}[0-9X]+\z/.match(i)
    end
  end

  def check_certificate
    Array.wrap(certificate).each do |c|
      errors.add(:certificate, "Certificate #{c} is not included in the list of supported certificates.") unless %w(CoreTrustSeal DSA WDS DINI).include?(c)
    end
  end

  def freeze_symbol
    errors.add(:symbol, "cannot be changed") if symbol_changed?
  end

  def check_id
    if symbol && symbol.split(".").first != provider.symbol
      errors.add(:symbol, ", Your Client ID must include the name of your provider. Separated by a dot '.' ")
    end
  end

  def user_url
    ENV["VOLPINO_URL"] + "/users?client-id=" + symbol.downcase
  end

  private

  def set_defaults
    self.contact_name = "" unless contact_name.present?
    self.domains = "*" unless domains.present?
    self.issn = [] if issn.blank? || client_type == "repository"
    self.certificate = [] if certificate.blank? || client_type == "periodical"
    self.is_active = is_active ? "\x01" : "\x00"
    self.version = version.present? ? version + 1 : 0
    self.role_name = "ROLE_DATACENTRE" unless role_name.present?
    self.doi_quota_used = 0 unless doi_quota_used.to_i > 0
    self.doi_quota_allowed = -1 unless doi_quota_allowed.to_i > 0
  end
end
