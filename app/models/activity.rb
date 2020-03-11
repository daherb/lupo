class Activity < Audited::Audit
  include Elasticsearch::Model

  # include helper module for Elasticsearch
  include Indexable

  alias_attribute :created, :created_at
  alias_attribute :doi_id, :uid
  alias_attribute :changes, :audited_changes

  belongs_to :auditable, polymorphic: true

  def after_audit
    IndexJob.perform_later(self)
  end

  # use different index for testing
  index_name Rails.env.test? ? "activities-test" : "activities"

  mapping dynamic: 'false' do
    indexes :id,                             type: :keyword
    indexes :auditable_id,                   type: :keyword
    indexes :uid,                            type: :keyword
    indexes :auditable_type,                 type: :keyword
    indexes :username,                       type: :keyword
    indexes :action,                         type: :keyword
    indexes :version,                        type: :keyword
    indexes :request_uuid,                   type: :keyword
    indexes :changes,                        type: :object
    indexes :created,                        type: :date, ignore_malformed: true

    # include parent objects
    #indexes :doi,                            type: :object
  end

  def as_indexed_json(options={})
    {
      "id" => id,
      "auditable_id" => auditable_id,
      "uid" => uid,
      "auditable_type" => auditable_type,
      "username" => username,
      "action" => action,
      "version" => version,
      "request_uuid" => request_uuid,
      "changes" => changes,
      "was_derived_from" => was_derived_from,
      "was_attributed_to" => was_attributed_to,
      "was_generated_by" => was_generated_by,
      "created" => created
    }
  end

  def self.query_aggregations
    {}
  end

  def self.import_by_ids(options={})
    from_id = (options[:from_id] || Activity.minimum(:id)).to_i
    until_id = (options[:until_id] || Activity.maximum(:id)).to_i

    # get every id between from_id and end_id
    (from_id..until_id).step(500).each do |id|
      ActivityImportByIdJob.perform_later(options.merge(id: id))
    end

    (from_id..until_id).to_a.length
  end

  def self.import_by_id(options={})
    return nil if options[:id].blank?

    id = options[:id].to_i
    index = if Rails.env.test?
      "activities-test"
    elsif options[:index].present?
      options[:index]
    else
      self.inactive_index
    end
    errors = 0
    count = 0

    Activity.where(id: id..(id + 499)).find_in_batches(batch_size: 500) do |activities|
      response = Activity.__elasticsearch__.client.bulk \
        index:   index,
        type:    Activity.document_type,
        body:    activities.map { |activity| { index: { _id: activity.id, data: activity.as_indexed_json } } }

      # log errors
      errors += response['items'].map { |k, v| k.values.first['error'] }.compact.length
      response['items'].select { |k, v| k.values.first['error'].present? }.each do |err|
        Rails.logger.error "[Elasticsearch] " + err.inspect
      end

      count += activities.length
    end

    if errors > 1
      Rails.logger.error "[Elasticsearch] #{errors} errors importing #{count} activities with IDs #{id} - #{(id + 499)}."
    elsif count.positive?
      Rails.logger.info "[Elasticsearch] Imported #{count} activities with IDs #{id} - #{(id + 499)}."
    end

    count
  rescue Elasticsearch::Transport::Transport::Errors::RequestEntityTooLarge, Faraday::ConnectionFailed, ActiveRecord::LockWaitTimeout => error
    Rails.logger.error "[Elasticsearch] Error #{error.message} importing activities with IDs #{id} - #{(id + 499)}."

    count = 0

    Activity.where(id: id..(id + 499)).find_each do |activity|
      IndexJob.perform_later(activity)
      count += 1
    end

    Rails.logger.info "[Elasticsearch] Imported #{count} activities with IDs #{id} - #{(id + 499)}."

    count
  end

  def self.convert_affiliations(options={})
    from_id = (options[:from_id] || Doi.minimum(:id)).to_i
    until_id = (options[:until_id] || Doi.maximum(:id)).to_i

    # get every id between from_id and end_id
    (from_id..until_id).step(500).each do |id|
      ActivityConvertAffiliationByIdJob.perform_later(options.merge(id: id))
      Logger.info "Queued converting affiliations for activities with IDs starting with #{id}." unless Rails.env.test?
    end

    (from_id..until_id).to_a.length
  end

  def self.convert_affiliation_by_id(options={})
    return nil unless options[:id].present?

    id = options[:id].to_i
    count = 0

    Activity.where(id: id..(id + 499)).find_each do |activity|
      should_update = false
      audited_changes = activity.audited_changes
      creators = Array.wrap(audited_changes["creators"]).map do |c|
        # c is an array if there are changes
        return [] if c.blank?
        c = c.last if c.is_a?(Array)

        if c["affiliation"].nil?
          c["affiliation"] = []
          should_update = true
        elsif c["affiliation"].is_a?(String)
          c["affiliation"] = [{ "name" => c["affiliation"] }] 
          should_update = true
        else c["affiliation"].is_a?(Hash)
          c["affiliation"] = Array.wrap(c["affiliation"])
          should_update = true
        end

        c
      end
      contributors = Array.wrap(audited_changes["contributors"]).map do |c|
        # c is an array if there are changes
        return [] if c.blank?

        c = c.last if c.is_a?(Array)

        if c["affiliation"].nil?
          c["affiliation"] = []
        elsif c["affiliation"].is_a?(String)
          c["affiliation"] = [{ "name" => c["affiliation"] }] 
        else c["affiliation"].is_a?(Hash)
          c["affiliation"] = Array.wrap(c["affiliation"])
        end

        should_update = true
        c
      end

      if should_update
        audited_changes["creators"] = creators
        audited_changes["contributors"] = contributors
        activity.update_attributes(audited_changes: audited_changes)
        count += 1
      end
    end

    Rails.logger.info "[Elasticsearch] Converted affiliations for #{count} activities with IDs #{id} - #{(id + 499)}." if count > 0

    count
  rescue Elasticsearch::Transport::Transport::Errors::RequestEntityTooLarge, Faraday::ConnectionFailed, ActiveRecord::LockWaitTimeout => error
    Rails.logger.info "[Elasticsearch] Error #{error.message} converting affiliations for DOIs with IDs #{id} - #{(id + 499)}."
  end

  def uid
    auditable.uid
  end

  def url
    Rails.env.production? ? "https://api.datacite.org" : "https://api.test.datacite.org"
  end

  def was_derived_from
    if auditable_type == "Doi"
      handle_url = Rails.env.production? ? "https://doi.org/" : "https://handle.test.datacite.org/"
      handle_url + uid
    elsif auditable_type == "Provider"
      url + "/providers/" + uid
    elsif auditable_type == "Client"
      url + "/repositories/" + uid
    end
  end

  def was_attributed_to
    if username.present?
      username.include?(".") ? url + "/repositories/" + username : url + "/providers/" + username
    end
  end

  def was_generated_by
    url + "/activities/" + request_uuid
  end
end
