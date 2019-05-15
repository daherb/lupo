class Organization
  def self.find_by_id(id)
    ror_id = ror_id_from_url(id)
    return {} unless ror_id.present?

    url = "https://api.ror.org/organizations/#{ror_id}"
    response = Maremma.get(url, host: true)

    return {} if response.status != 200
    
    message = response.body.fetch("data", {})
    data = [parse_message(id: id, message: message)]

    errors = response.body.fetch("errors", nil)

    { data: data, errors: errors }
  end

  def self.query(query, options={})
    # rows = options[:limit] || 25

    if query.present?
      url = "https://api.ror.org/organizations?query=#{query}&qp"
    else
      url = "https://api.ror.org/organizations"
    end

    response = Maremma.get(url, host: true)

    return [] if response.status != 200
    
    data = Array.wrap(response.body.dig("data", "items")).map do |message|
      parse_message(id: message["id"], message: message)
    end
    meta = { "total" => response.body.dig("data", "number_of_results") }
    errors = response.body.fetch("errors", nil)

    { data: data, meta: meta, errors: errors }
  end

  def self.parse_message(id: nil, message: nil)
    country = {
      code: message.dig("country", "country_code"),
      name: message.dig("country", "country_name") }.compact

    labels = Array.wrap(message["labels"]).map do |label|
      code = label["iso639"].present? ? label["iso639"].upcase : nil
      {
        code: code,
        name: label["label"] }.compact
    end
    
    {
      id: id,
      name: message["name"],
      aliases: message["aliases"],
      acronyms: message["acronyms"],
      labels: labels,
      links: message["links"],
      wikipedia_url: message["wikipedia_url"],
      country: country,
      isni: message.dig("ISNI", "all"),
      fund_ref: message.dig("FundRef", "all"),
      wikidata: message.dig("Wikidata", "all"),
      grid: message.dig("GRID", "all") }.compact
  end

  def self.ror_id_from_url(url)
    Array(/\A(http|https):\/\/(ror\.org\/0\w{6}\d{2})\z/.match(url)).last
  end
end
