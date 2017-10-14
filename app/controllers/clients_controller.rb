class ClientsController < ApplicationController
  before_action :set_client, only: [:show, :update, :destroy, :getpassword]
  before_action :authenticate_user_from_token!
  before_action :set_include
  load_and_authorize_resource :except => [:index, :show]

  def index
    # support nested routes
    if params[:provider_id].present?
      provider = Provider.where('allocator.symbol = ?', params[:provider_id]).first
      collection = provider.present? ? provider.clients : Client.none
    else
      collection = Client
    end

    if params[:id].present?
      collection = collection.where(symbol: params[:id])
    elsif params[:query].present?
      collection = collection.query(params[:query])
    end

    # cache prefixes for faster queries
    if params[:prefix].present?
      prefix = cached_prefix_response(params[:prefix])
      collection = collection.includes(:prefixes).where('prefix.id' => prefix.id)
    end

    collection = collection.where('YEAR(datacentre.created) = ?', params[:year]) if params[:year].present?

    # calculate facet counts after filtering

    providers = collection.joins(:provider).select('allocator.symbol, allocator.name, count(allocator.id) as count').order('count DESC').group('allocator.id')
    # workaround, as selecting allocator.symbol as id doesn't work
    providers = providers.map { |p| { id: p.symbol, title: p.name, count: p.count } }

    if params[:year].present?
      years = [{ id: params[:year],
                 title: params[:year],
                 count: collection.where('YEAR(datacentre.created) = ?', params[:year]).count }]
    else
      years = collection.where.not(created: nil).order("YEAR(datacentre.created) DESC").group("YEAR(datacentre.created)").count
      years = years.map { |k,v| { id: k.to_s, title: k.to_s, count: v } }
    end

    page = params[:page] || {}
    page[:number] = page[:number] && page[:number].to_i > 0 ? page[:number].to_i : 1
    page[:size] = page[:size] && (1..1000).include?(page[:size].to_i) ? page[:size].to_i : 25
    total = collection.count

    order = case params[:sort]
            when "name" then "datacentre.name"
            when "-name" then "datacentre.name DESC"
            when "created" then "datacentre.created"
            else "datacentre.created DESC"
            end

    @clients = collection.order(order).page(page[:number]).per(page[:size])

    meta = { total: total,
             total_pages: @clients.total_pages,
             page: page[:number].to_i,
             providers: providers,
             years: years }

    render jsonapi: @clients, meta: meta, include: @include
  end

  # GET /clients/1
  def show
    meta = { dois: @client.doi_count }

    render jsonapi: @client, meta: meta, include: @include
  end

  # POST /clients
  def create
    @client = Client.new(safe_params)
    authorize! :create, @client

    if @client.save
      render jsonapi: @client, status: :created
    else
      Rails.logger.warn @client.errors.inspect
      render jsonapi: serialize(@client.errors), status: :unprocessable_entity
    end
  end

  # PATCH/PUT /clients/1
  def update
    Rails.logger.warn safe_params.inspect
    if @client.update_attributes(safe_params)
      render jsonapi: @client
    else
      Rails.logger.warn @client.errors.inspect
      render json: serialize(@client.errors), status: :unprocessable_entity
    end
  end

  # don't delete, but set deleted_at timestamp
  # a client with dois or prefixes can't be deleted
  def destroy
    if @client.datasets.present?
      message = "Can't delete client that has DOIs."
      status = 400
      Rails.logger.warn message
      render json: { errors: [{ status: status.to_s, title: message }] }.to_json, status: status
    elsif @client.update_attributes(is_active: "\x00", deleted_at: Time.zone.now)
      head :no_content
    else
      Rails.logger.warn @client.errors.inspect
      render jsonapi: serialize(@client.errors), status: :unprocessable_entity
    end
  end

  def getpassword
    phrase = Password.new(current_user, @client)
    response.headers['X-Consumer-Role'] = current_user && current_user.role_id || 'anonymous'
    r = {password: phrase.string }
    render jsonapi: @client, meta: r , include: @include
  end

  protected

  def set_include
    if params[:include].present?
      @include = params[:include].split(",").map { |i| i.downcase.underscore }.join(",")
      @include = [@include]
    else
      @include = ["provider", "repository"]
    end
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_client
    # params[:id] = params[:id][/.+?(?=\/)/]
    @client = Client.where(symbol: params[:id]).first
    fail ActiveRecord::RecordNotFound unless @client.present?
  end

  private

  def safe_params
    fail JSON::ParserError, "You need to provide a payload following the JSONAPI spec" unless params[:data].present?
    Rails.logger.warn params
    ActiveModelSerializers::Deserialization.jsonapi_parse!(
      params, only: [:symbol, :name, :contact_name, :contact_email, :domains, :provider, :repository, :is_active, :deleted_at]
    )
  end
end
