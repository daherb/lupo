# require 'github/markdown'
# require 'rouge'
require 'jwt'

module ApplicationHelper
  def icon(icon, text = nil, html_options = {})
    text, html_options = nil, text if text.is_a?(Hash)

    content_class = "fa fa-#{icon}"
    content_class << " #{html_options[:class]}" if html_options.key?(:class)
    html_options[:class] = content_class

    html = content_tag(:i, nil, html_options)
    html << ' ' << text.to_s unless text.blank?
    html
  end

  def markdown(text)
    text = GitHub::Markdown.render_gfm(text)
    syntax_highlighter(text).html_safe
  end

  def syntax_highlighter(html)
    formatter = Rouge::Formatters::HTML.new(:css_class => 'hll')
    lexer = Rouge::Lexers::Shell.new

    doc = Nokogiri::HTML::DocumentFragment.parse(html)
    doc.search("//pre").each { |pre| pre.replace formatter.format(lexer.lex(pre.text)) }
    doc.to_s
  end

  def formatted_class_name(string)
    return string if string.length < 25

    string.split("::", 2).last
  end

  def states
     %w(waiting working failed done)
  end

  def state_label(state)
    case state
    when "working" then '<span class="label label-success">working</span>'
    when "inactive" then '<span class="label label-info">inactive</span>'
    when "disabled" then '<span class="label label-warning">disabled</span>'
    when "available" then '<span class="label label-default">available</span>'
    when "retired" then '<span class="label label-primary">retired</span>'
    else state
    end
  end

  def level_label(level)
    case level
    when 1 then '<span class="label label-info">Info</span>'
    when 2 then '<span class="label label-warning">Warn</span>'
    when 3 then '<span class="label label-danger">Error</span>'
    when 4 then '<span class="label label-fatal">Fatal</span>'
    else '<span class="label label-default">Other</span>'
    end
  end

  def worker_label(status)
    case status
    when "working" then "panel-success"
    when "waiting" then "panel-default"
    else "panel-warning"
    end
  end

  def status_label(name, status)
    case status
    when "OK" then name
    else "<span class='label label-warning'>#{name}</span>"
    end
  end

  def number_hiding_zero(number)
    (number.nil? || number == 0 ? "" : number_with_delimiter(number))
  end

  def sources
    Source.order("group_id, title")
  end

  def data_centers
    DataCenters.active.order("name")
  end

  def contributors
    Person.order("family_name")
  end

  def people
    Person.order("family_name")
  end

  def author_format(author)
    author = [author] if author.is_a?(Hash)
    authors = Array(author).map do |a|
      if a.is_a?(Hash)
        name = [a.fetch("given", nil), a.fetch("family", nil)].compact.join(' ')
        if a["ORCID"].present?
          pid_short = CGI.escape(a["ORCID"].gsub(/(http|https):\/+(\w+)/, '\2'))
          "<a href=\"/people/#{pid_short}\">#{name}</a>"
        else
          name
        end
      else
        nil
      end
    end.compact

    fa = case authors.length
         when 0..2 then authors.join(" & ")
         when 3..20 then authors[0..-2].join(", ") + " & " + authors.last
         else authors[0..19].join(", ") + " … & " + authors.last
         end
    fa.html_safe
  end

  def date_format(work)
    if work.day
      :long
    elsif work.month
      :month
    else
      :year
    end
  end

  def date_from_iso8601(date)
    DateTime.parse(date).to_s(:short)
  end

  def description_with_link(report)
    if report.name == 'work_statistics_report'
      h(report.description) #+ link_to("Download", work_statistics_report_path, :class => 'pull-right')
    else
      h(report.description)
    end
  end

  def work_notifications
    %w(EventCountDecreasingError EventCountIncreasingTooFastError ApiResponseTooSlowError HtmlRatioTooHighError WorkNotUpdatedError CitationMilestoneAlert)
  end

  def documents
    %w(Installation Deployment Setup - Agents Deposits Rake Notifications Styleguide - Releases Roadmap Contributors)
  end

  def roles
    %w(user contributor staff admin)
  end

  def settings
    Settings[ENV['MODE']]
  end

  # def current_user
  #   @current_user ||= cookies[:jwt].present? ? User.new((JWT.decode cookies[:jwt], ENV['JWT_SECRET_KEY']).first) : nil
  # end

  def user_signed_in?
    !!current_user
  end

  def is_admin_or_staff?
    current_user && current_user.is_admin_or_staff?
  end
end
