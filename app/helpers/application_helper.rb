# encoding: UTF-8

module ApplicationHelper
  def flash_messages
    render "shared/flash", flash: flash
  end

  def score_html(score, args={})
    str = case score
    when 0.0, 0 then "0"
    when 0.5    then "½"
    when 1.0, 1 then "1"
    else score.floor.to_s + (score.*(2).to_i.odd? ? "½" : "")
    end
    if !args[:rateable].nil? && !args[:rateable] && score <= 1.0
      str = case str
      when "0" then "−"
      when "1" then "+"
      else "="
      end
    end
    if args[:rounds]
      str+= '/'
      str+= args[:rounds].to_s
    end
    str
  end

  # Round a floating point number for display. Input of nil allowed.
  def round(num, decimals=3)
    return "" unless num
    "%.#{decimals}f" % num
  end

  # A signed integer (e.g "-10", "+125", "0"). Nil allowed, float input allowed.
  def sign(num, opt={space: false})
    return "" unless num
    sgn = num == 0 ? (opt[:space] ? "+" : "") : (num > 0 ? "+" : "−")
    spc = opt[:space] ? " " : ""
    num = num.abs.round
    "#{sgn}#{spc}#{num}"
  end

  def club_menu(none="None", any="Any")
    menu = IcuPlayer.unscoped.select("DISTINCT(club)").where("club IS NOT NULL").order("club").map{ |c| [c.club, c.club] }
    menu.unshift([none, "None"]) if none
    menu.unshift([any, ""]) if any
    menu
  end

  def colour_menu(none=nil)
    menu = [["White", "W"], ["Black", "B"]]
    menu.unshift([none, ""]) if none
    menu
  end

  def federation_menu(opt = { top: 'IRL', none: 'None' })
    menu = ICU::Federation.menu(opt)
    drop = (opt[:top] ? 1 : 0) + (opt[:none] ? 1 : 0)
    menu.insert(drop, [opt[:unknown], "???"]) if opt[:unknown]
    menu.insert(drop, [opt[:foreign], "XXX"]) if opt[:foreign]
    menu.insert(drop, [opt[:irl_unk], "IR?"]) if opt[:irl_unk]
    menu
  end

  def fee_used_menu(any=nil)
    menu = [["Yes", "true"], ["No", "false"]]
    menu.unshift([any, ""]) if any
    menu
  end

  def fee_status_menu(any=nil)
    menu = %w[Completed Refunded PartRefund].map{ |s| [t("fees.#{s}"), s] }
    menu.unshift([any, ""]) if any
    menu
  end

  def fide_rated_menu(any=nil)
    menu = [["Rated", "true"], ["Not Rated", "false"]]
    menu.unshift([any, ""]) if any
    menu
  end

  def fide_rating_list_menu(any=nil)
    menu = FideRating.lists.map{ |list| [year_month(list), list] }
    menu.unshift([any, ""]) if any
    menu
  end

  def gender_menu(none=nil)
    menu = [["Male", "M"], ["Female", "F"]]
    menu.unshift([none, ""]) if none
    menu
  end

  def icu_rating_list_menu(any=nil)
    menu = IcuRating.lists.map { |list| [year_month(list), list] }
    menu.unshift([any, ""]) if any
    menu
  end

  def icu_player_order
    [["Name", "default"], ["ID", "id"], ["Last Updated", "update"], ["Last Created", "create"]]
  end

  def old_players_status_menu(any=nil)
    menu = OldPlayer::STATUS.map{ |s| [s, s] }
    menu.unshift([any, ""]) if any
    menu
  end

  def rating_type_menu(any=nil)
    menu = [["Full", "full"], ["Provisional", "provisional"]]
    menu.unshift([any, ""]) if any
    menu
  end

  def problem_menu(any=nil)
    menu = Login::PROBLEMS.map{ |r| [r.capitalize, r] }
    menu.unshift([any, ""]) if any
    menu
  end

  def published_menu(any=nil)
    menu = [["Yes", "true"], ["No", "false"]]
    menu.unshift([any, ""]) if any
    menu
  end

  def rating_list_year_menu(any=nil)
    menu = (2012..Date.today.year).map { |y| [y, y] }
    menu.unshift([any, ""]) if any
    menu
  end

  def rating_run_status_menu(any=nil)
    menu = RatingRun::STATUS.map{ |s| [s, s] }
    menu.unshift([any, ""]) if any
    menu
  end

  def result_menu
    %w[Draw Win Loss].map{ |r| [r, r[0]] }
  end

  def reporter_menu
    User.where("role != 'member'").order("icu_players.last_name, icu_players.first_name").map{ |u| [u.icu_player.name, u.id] }
  end

  def role_menu(none=nil)
    menu = User::ROLES.map{ |r| [r.capitalize, r] }
    menu.unshift([none, ""]) if none
    menu
  end

  def sub_category_menu(any=nil)
    menu = Subscription::CATEGORY.map{ |c| [t("subs.#{c}"), c] }
    menu.unshift([any, ""]) if any
    menu
  end

  def sub_season_menu(any=nil)
    menu = Subscription.group(:season).map{ |s| s.season }.reject{ |s| s.blank? }.sort.reverse
    menu.push(Subscription.season) if menu.size == 0
    menu.map! { |s| [s, s] }
    menu.unshift([any, ""]) if any
    menu
  end

  def title_menu(none=nil)
    menu = %w[GM IM FM CM NM WGM WIM WFM WCM WNM].map{ |t| Array.new(2, t) }
    menu.unshift([none, ""]) if none
    menu
  end

  def tournament_status_menu(any=nil)
    menu = [["OK", "ok"], ["Problems", "problems"]]
    menu.unshift([any, ""]) if any
    menu
  end

  def tournament_stage_menu(any=nil)
    menu = Tournament::STAGE.map{ |s| [t(s), s] }
    menu.unshift([any, ""]) if any
    menu
  end

  def tournament_lock_menu(any=nil)
    menu = [["On", "true"], ["Off", "false"]]
    menu.unshift([any, ""]) if any
    menu
  end

  def upload_format_menu(any=nil)
    menu = Upload::FORMATS.dup
    menu.unshift([any, ""]) if any
    menu
  end

  def user_menu(table, any=nil)
    menu = User.joins(table).group(:user_id).map{ |u| [u.name, u.id] }.sort{ |a,b| a[0] <=> b[0] }
    menu.unshift([any, ""]) if any
    menu
  end

  def user_status_menu(any=nil)
    menu = User::STATUS.map{ |r| [r == "ok" ? "OK" : r.capitalize, r] }
    menu.unshift([any, ""]) if any
    menu
  end

  def markdown(text)
    return "" unless text
    renderer = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, strikethrough: true, superscript: true, no_intra_emphasis: true)
    renderer.render(text).html_safe
  end

  # Return a abbreviated form of a title (e.g. WFM => wf).
  def short_title(title)
    return "" unless title.present?
    case title
    when "IM"  then "m"
    when "WIM" then "wm"
    else title.sub(/M$/, "").downcase
    end
  end

  # Turn a date into a year-month (e.g. 2011-11-01 => 2011 Nov).
  def year_month(date, fmt="yyyy mmm")
    yyyy = date.year.to_s
    mmm = %w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)[date.month-1]
    case fmt
    when "mmm-yy"   then "%s-%s" % [mmm, yyyy[2, 2]]
    when "mmm yyyy" then "%s %s" % [mmm, yyyy]
    else "%s %s" % [yyyy, mmm]
    end
  end

  # Returns links to objects on some specific external sites.
  def foreign_url_for(obj, opt={})
    host, path = nil, nil
    text, target = opt.values_at(:text, :target)
    case obj
    when IcuPlayer
      host = "www.icu.ie"
      path = "admin/players/#{obj.id}"
      text ||= obj.id
      target ||= "_icu_ie"
    when FidePlayer
      host = "ratings.fide.com"
      path = "card.phtml?event=#{obj.id}"
      text ||= obj.id
      target ||= "_fide_com"
    end
    return nil unless host && path
    link_to text, "http://#{host}/#{path}", target: target, class: "external"
  end

  # General foreign link.
  def foreign_url(text, url, target=nil)
    opt = { class: "external" }
    unless target
      target = case url
        when /^https?:\/\/(www\.)?icu\.ie/i   then "_icu_ie"
        when /^https?:\/\/(\w+\.)?fide\.com/i then "_fide_com"
      end
    end
    opt[:target] = target if target
    link_to text, url, opt
  end

  # Returns a plain link to the main ICU site.
  def link_to_icu(label, path="", style="external")
    link_to label, "http://www.icu.ie/#{path}", target: "_icu_ie", class: style
  end

  # Returns an ICU email link.
  def mail_to_icu(officer=:ratings)
    name = case officer.to_sym
      when :admin       then "Webmaster"
      when :chairperson then "Chairperson"
      when :membership  then "Membership Officer"
      when :ratings     then "Rating Officer"
      when :treasurer   then "Treasurer"
      else "ICU"
    end
    mail_to "#{officer}@icu.ie", name, encode: "hex"
  end

  # Returns a string showing results displayed plus next and previous links.
  def pagination_links(pager)
    links = Array.new
    links.push(link_to "next", pager.next_page, remote: true) if pager.before_end
    links.push(link_to "prev", pager.prev_page, remote: true) if pager.after_start
    raw "#{pager.sequence} of #{pluralize(pager.total, "match")}#{links.size > 0 ? ": " : ""}#{links.join(", ")}"
  end

  # These dialogs are used in more than one place so are defined here.
  def icu_player_details_dialog
    render "shared/dialog", id: "icu_player_details", width: 800, button: false, cancel: "Dismiss", title: "ICU Player"
  end
  def fide_player_details_dialog
    render "shared/dialog", id: "fide_player_details", width: 800, button: false, cancel: "Dismiss", title: "FIDE Player"
  end

  # Returns a summary of created and updated datetimes.
  def timestamps_summary(object, opts={})
    created = object.created_at
    updated = object.updated_at
    unless opts[:time]
      created = created.to_date
      updated = updated.to_date
    end
    summary = "created <span>#{I18n.l(created, format: :long)}</span>"
    unless updated == created
      format = created.year == updated.year ? :short : :long
      summary << "; last updated <span>#{I18n.l(updated, format: format)}<span>"
    end
    raw summary
  end

  # Returns copyright text (e.g. "© ICU 2011-2013").
  def copyright
    start = 2011
    finish = Date.today.year
    "© ICU %s" % (finish > start ? "#{start}-#{finish}" : start.to_s)
  end

  # A HAML specific way of adding attributes to rowspan cells (see shared/_rowspan.html.haml).
  def rowspan_attrs(rows, attrs)
    attrs[:rowspan] = rows if rows > 1
    attrs
  end

  # Shortcut for creating image tags involving icons.
  def icon_tag(image, alt, opts={})
    image+= ".png" unless image.match(/\.[a-z]+$/)
    image_tag "icons/#{image}", { alt: alt, title: alt, size: "16x16" }.merge(opts)
  end

  # Is an administrator logged in?
  def admin?
    current_user && current_user.role?("admin")
  end

  # The default ID to use for search forms that submit remotely onchange.
  def handle_remote_id
    "_search_id"
  end

  # The JavaScript that submits forms remotely.
  def handle_remote(form_id = nil)
    form_id ||= handle_remote_id
    "$.rails.handleRemote($('##{form_id}'))"
  end

  # Add a link, icon and text to display at the top in the header.
  def add_top_link(link, icon, text)
    @top_links ||= []
    @top_links.unshift([link, icon, text])
  end

  # Output top links in the header (display code should be in supplied block).
  def add_top_links
    return unless @top_links
    @top_links.each { |top_link| yield top_link }
  end
end
