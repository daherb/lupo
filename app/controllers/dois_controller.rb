require 'uri'

class DoisController < ApplicationController
  prepend_before_action :authenticate_user!
  before_action :set_doi, only: [:show, :destroy, :get_url]
  before_action :set_include, only: [:index, :show, :create, :update]
  before_bugsnag_notify :add_metadata_to_bugsnag

  def index
    authorize! :read, Doi

    if Rails.env.production?
      # don't use elasticsearch

      # support nested routes
      if params[:client_id].present?
        client = Client.where('datacentre.symbol = ?', params[:client_id]).first
        collection = client.present? ? client.dois : Doi.none
        total = client.cached_doi_count.reduce(0) { |sum, d| sum + d[:count].to_i }
      elsif params[:provider_id].present? && params[:provider_id] != "admin"
        provider = Provider.where('allocator.symbol = ?', params[:provider_id]).first
        collection = provider.present? ? Doi.joins(:client).where("datacentre.allocator = ?", provider.id) : Doi.none
        total = provider.cached_doi_count.reduce(0) { |sum, d| sum + d[:count].to_i }
      elsif params[:id].present?
        collection = Doi.where(doi: params[:id])
        total = collection.all.size
      else
        provider = Provider.unscoped.where('allocator.symbol = ?', "ADMIN").first
        total = provider.present? ? provider.cached_doi_count.reduce(0) { |sum, d| sum + d[:count].to_i } : 0
        collection = Doi
      end

      if params[:query].present?
        collection = Doi.query(params[:query])
        total = collection.all.size
      end

      page = params[:page] || {}
      page[:number] = page[:number] && page[:number].to_i > 0 ? page[:number].to_i : 1
      page[:size] = page[:size] && (1..1000).include?(page[:size].to_i) ? page[:size].to_i : 25
      total_pages = (total.to_f / page[:size]).ceil

      order = case params[:sort]
              when "name" then "dataset.doi"
              when "-name" then "dataset.doi DESC"
              when "created" then "dataset.created"
              else "dataset.created DESC"
              end

      @dois = collection.order(order).page(page[:number]).per(page[:size]).without_count

      meta = { total: total,
              total_pages: total_pages,
              page: page[:number].to_i }

      render jsonapi: @dois, meta: meta, include: @include, each_serializer: DoiSerializer
    else
      page = (params.dig(:page, :number) || 1).to_i
      size = (params.dig(:page, :size) || 25).to_i
      from = (page - 1) * size

      # limit pagination
      from = 10000 - size if from + size > 10000

      sort = case params[:sort]
            when "name" then { "doi" => { order: 'asc' }}
            when "-name" then { "doi" => { order: 'desc' }}
            when "created" then { created: { order: 'asc' }}
            when "relevance" then { "_score": { "order": "desc" }}
            else { created: { order: 'desc' }}
            end

      if params[:id].present?
        response = Doi.find_by_id(params[:id]) 
      elsif params[:ids].present?
        response = Doi.find_by_ids(params[:ids], from: from, size: size, sort: sort)
      else
        response = Doi.query(params[:query], 
                            state: params[:state], 
                            year: params[:year], 
                            registered: params[:registered], 
                            provider_id: params[:provider_id], 
                            client_id: params[:client_id], 
                            person_id: params[:person_id], 
                            resource_type_id: camelize_str(params[:resource_type_id]), 
                            schema_version: params[:schema_version], 
                            from: from, 
                            size: size, 
                            sort: sort)
      end

      total = response.results.total
      total_pages = (total.to_f / size).ceil

      states = total > 0 ? facet_by_key(response.response.aggregations.states.buckets) : nil
      resource_types = total > 0 ? facet_by_resource_type(response.response.aggregations.resource_types.buckets) : nil
      years = total > 0 ? facet_by_year(response.response.aggregations.years.buckets) : nil
      registered = total > 0 ? facet_by_year(response.response.aggregations.registered.buckets) : nil
      providers = total > 0 ? facet_by_provider(response.response.aggregations.providers.buckets) : nil
      clients = total > 0 ? facet_by_client(response.response.aggregations.clients.buckets) : nil
      schema_versions = total > 0 ? facet_by_schema(response.response.aggregations.schema_versions.buckets) : nil

      #@clients = Kaminari.paginate_array(response.results, total_count: total).page(page).per(size)
      @dois = response.page(page).per(size).records

      meta = {
        total: total,
        total_pages: total_pages,
        page: page,
        states: states,
        resource_types: resource_types,
        years: years,
        registered: registered,
        providers: providers,
        clients: clients,
        schema_versions: schema_versions
      }.compact

      render jsonapi: @dois, meta: meta, include: @include
    end
  end

  def show
    authorize! :read, @doi

    render jsonapi: @doi, include: @include, serializer: DoiSerializer
  end

  def validate
    # Rails.logger.info safe_params.inspect
    @doi = Doi.new(safe_params)
    authorize! :create, @doi

    if @doi.errors.present?
      Rails.logger.info @doi.errors.inspect
      render jsonapi: serialize(@doi.errors), status: :ok
    elsif @doi.validation_errors?
      Rails.logger.info @doi.validation_errors.inspect
      render jsonapi: serialize(@doi.validation_errors), status: :ok
    else
      render jsonapi: @doi, serializer: DoiSerializer
    end
  end

  def create
   #  Rails.logger.info safe_params.inspect
    @doi = Doi.new(safe_params.merge(event: safe_params[:event] || "start"))
    authorize! :create, @doi

    # capture username and password for reuse in the handle system
    @doi.current_user = current_user

    if safe_params[:xml] && @doi.aasm_state != "draft" && @doi.validation_errors?
      Rails.logger.error @doi.validation_errors.inspect
      render jsonapi: serialize(@doi.validation_errors), status: :unprocessable_entity
    elsif @doi.save
      render jsonapi: @doi, status: :created, location: @doi
    else
      Rails.logger.warn @doi.errors.inspect
      render jsonapi: serialize(@doi.errors), include: @include, status: :unprocessable_entity
    end
  end

  def update
    #  Rails.logger.info safe_params.inspect
    @doi = Doi.where(doi: params[:id]).first
    exists = @doi.present?

    if exists
      @doi.assign_attributes(safe_params.except(:doi))
    else
      doi_id = validate_doi(params[:id])
      fail ActiveRecord::RecordNotFound unless doi_id.present?

      event = safe_params[:validate] ? "start" : safe_params[:event].presence || "start"
      @doi = Doi.new(safe_params.merge(doi: doi_id, event: event))
    end

    if safe_params[:xml].present? || safe_params[:url].present? || safe_params[:event].present?
      authorize! :update, @doi
    else
      authorize! :transfer, @doi
    end

    # capture username and password for reuse in the handle system
    @doi.current_user = current_user

    if safe_params[:xml] && (@doi.aasm_state != "draft" || safe_params[:validate]) && @doi.validation_errors?
      Rails.logger.error @doi.validation_errors.inspect
      render jsonapi: serialize(@doi.validation_errors), status: :unprocessable_entity
    elsif @doi.save
      render jsonapi: @doi, status: exists ? :ok : :created
    else
      Rails.logger.warn @doi.errors.inspect
      render jsonapi: serialize(@doi.errors), include: @include, status: :unprocessable_entity
    end
  end

  def destroy
    authorize! :destroy, @doi

    if @doi.draft?
      if @doi.destroy
        head :no_content
      else
        Rails.logger.warn @doi.errors.inspect
        render jsonapi: serialize(@doi.errors), status: :unprocessable_entity
      end
    else
      response.headers["Allow"] = "HEAD, GET, POST, PATCH, PUT, OPTIONS"
      render json: { errors: [{ status: "405", title: "Method not allowed" }] }.to_json, status: :method_not_allowed
    end
  end

  def status
    doi = Doi.where(doi: params[:id]).first
    status = Doi.get_landing_page_info(doi: doi, url: params[:url])
    render json: status.to_json, status: :ok
  end

  def random
    prefix = params[:prefix].presence || "10.5072"
    doi = generate_random_doi(prefix, number: params[:number])

    render json: { doi: doi }.to_json
  end

  def set_state
    authorize! :set_state, Doi
    Doi.set_state
    render json: { message: "DOI state updated." }.to_json, status: :ok
  end

  def get_url
    authorize! :get_url, @doi

    if @doi.aasm_state == "draft"
      url = @doi.url
      response = OpenStruct.new(status: 404, body: { "errors" => [{ "title" => "No URL found." }] })
    else
      response = @doi.get_url(username: current_user.uid.upcase, password: current_user.password)

      if ENV['HANDLE_URL'].blank?
        url = response.body["data"]
      elsif response.status == 200
        url = response.body.dig("data", "values", 0, "data", "value")
      elsif response.status == 400 && response.body.dig("errors", 0, "title", "responseCode") == 301 
        response = OpenStruct.new(status: 500, body: { "errors" => [{ "status" => 500, "title" => "SERVER NOT RESPONSIBLE FOR HANDLE" }] })
        url = nil
      else
        url = nil
      end
    end

    if url.present?
      render json: { url: url }.to_json, status: :ok
    else
      render json: response.body.to_json, status: response.status || :bad_request
    end
  end

  def get_dois
    authorize! :get_urls, Doi

    if ENV['HANDLE_URL'].present?
      client = Client.where('datacentre.symbol = ?', current_user.uid.upcase).first
      client_prefix = client.prefixes.where.not('prefix.prefix = ?', "10.5072").first
      head :no_content and return unless client_prefix.present?

      response = Doi.get_dois(prefix: client_prefix.prefix, username: current_user.uid.upcase, password: current_user.password)
      if response.status == 200
        render json: { dois: response.body.dig("data", "handles") }.to_json, status: :ok
      elsif response.status == 204
        head :no_content
      else
        render json: serialize(response.body["errors"]), status: :bad_request
      end
    else
      response = Doi.get_dois(username: current_user.uid.upcase, password: current_user.password)
      if response.status == 200
        render json: { dois: response.body["data"].split("\n") }.to_json, status: :ok
      elsif response.status == 204
        head :no_content
      else
        render json: serialize(response.body["errors"]), status: :bad_request
      end
    end
  end

  def set_minted
    authorize! :set_minted, Doi
    Doi.set_minted
    render json: { message: "DOI minted timestamp added." }.to_json, status: :ok
  end

  def set_url
    authorize! :set_url, Doi
    from_date = Time.zone.now - 1.day
    Doi.where(url: nil).where(aasm_state: ["registered", "findable"]).where("updated >= ?", from_date).find_each do |doi|
      UrlJob.perform_later(doi)
    end
    render json: { message: "Adding missing URLs queued." }.to_json, status: :ok
  end

  def delete_test_dois
    authorize! :delete_test_dois, Doi
    Doi.delete_test_dois
    render json: { message: "Test DOIs deleted." }.to_json, status: :ok
  end

  protected

  def set_doi
    @doi = Doi.where(doi: params[:id]).first
    fail ActiveRecord::RecordNotFound unless @doi.present?

    # capture username and password for reuse in the handle system
    @doi.current_user = current_user
  end

  def set_include
    if params[:include].present?
      @include = params[:include].split(",").map { |i| i.downcase.underscore }.join(",")
      @include = [@include]
    else
      @include = ["client,provider,resource_type"]
    end
  end

  private

  def safe_params
    fail JSON::ParserError, "You need to provide a payload following the JSONAPI spec" unless params[:data].present?
    attributes = [:doi, "confirm-doi", :identifier, :url, :title, :publisher, :published, :created, :prefix, :suffix, "resource-type-subtype", "last-landing-page", "last-landing-page-status", "last-landing-page-status-check", "last-landing-page-content-type", :description, :license, :xml, :validate, :version, "metadata-version", "schema-version", :state, "is-active", :reason, :registered, :updated, :mode, :event, :regenerate, :client, "resource_type", author: [:type, :id, :name, "given-name", "family-name"]]
    relationships = [{ client: [data: [:type, :id]] },  { provider: [data: [:type, :id]] }, { "resource-type" => [:data, data: [:type, :id]] }]
    p = params.require(:data).permit(:type, :id, attributes: attributes, relationships: relationships)
    p = p.fetch("attributes").merge(client_id: p.dig("relationships", "client", "data", "id"), resource_type_general: camelize_str(p.dig("relationships", "resource-type", "data", "id")))
    p.merge(
      additional_type: p["resource-type-subtype"],
      schema_version: p["schema-version"],
      last_landing_page: p["last-landing-page"],
      last_landing_page_status: p["last-landing-page-status"],
      last_landing_page_status_check: p["last-landing-page-status-check"],
      last_landing_page_content_type: p["last-landing-page-content-type"]
    ).except("confirm-doi", :identifier, :prefix, :suffix, "resource-type-subtype", "metadata-version", "schema-version", :state, "is-active", :created, :registered, :updated, :mode, "last-landing-page", "last-landing-page-status", "last-landing-page-status-check", "last-landing-page-content-type")
  end

  def underscore_str(str)
    return str unless str.present?

    str.underscore
  end

  def camelize_str(str)
    return str unless str.present?

    str.underscore.camelize
  end

  def add_metadata_to_bugsnag(report)
    return nil unless params.dig(:data, :attributes, :xml).present?

    report.add_tab(:metadata, {
      metadata: Base64.decode64(params.dig(:data, :attributes, :xml))
    })
  end
end
