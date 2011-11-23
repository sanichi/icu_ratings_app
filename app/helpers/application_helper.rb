module ApplicationHelper
  def flash_messages
    render "shared/flash", flash: flash
  end

  def score_html(score, args={})
    str = case score
    when 0.0, 0 then '0'
    when 0.5    then '&frac12;'
    when 1.0, 1 then '1'
    else score.floor.to_s + (score.*(2).to_i.odd? ? '&frac12;' : '')
    end
    if !args[:rateable].nil? && !args[:rateable] && score <= 1.0
      str = case str
          when '0' then '-'
          when '1' then '+'
          else '='
      end
    end
    if args[:rounds]
      str+= '/'
      str+= args[:rounds].to_s
    end
    str.html_safe
  end

  def federation_menu(opt = { top: 'IRL', none: 'None' })
    menu = ICU::Federation.menu(opt)
    menu.insert(1, [opt[:irl_unk], "IR?"]) if opt[:irl_unk]
    menu.insert(1, [opt[:unknown], "???"]) if opt[:unknown]
    menu.insert(1, [opt[:foreign], "XXX"]) if opt[:foreign]
    menu
  end

  def club_menu(opt = { any: "Any", none: "None" })
    menu = IcuPlayer.unscoped.select("DISTINCT(club)").where("club IS NOT NULL").order("club").map { |c| [c.club, c.club] }
    menu.unshift([opt[:none], "None"]) if opt[:none]
    menu.unshift([opt[:any], ""]) if opt[:any]
    menu
  end

  def colour_menu(none=nil)
    menu = [["White", "W"], ["Black", "B"]]
    menu.unshift([none, ""]) if none
    menu
  end

  def fide_rating_list_menu(any=nil)
    menu = FideRating.periods.map { |period| [year_month(period), period]}
    menu.unshift([any, ""]) if any
    menu
  end

  def gender_menu(none=nil)
    menu = [["Male", "M"], ["Female", "F"]]
    menu.unshift([none, ""]) if none
    menu
  end

  def icu_rating_list_menu(any=nil)
    menu = IcuRating.lists.map { |list| [year_month(list), list]}
    menu.unshift([any, ""]) if any
    menu
  end

  def rating_type_menu(any=nil)
    menu = [["Full", "full"], ["Provisional", "provisional"]]
    menu.unshift([any, ""]) if any
    menu
  end

  def problem_menu(any=nil)
    menu = Login::PROBLEMS.map { |r| [r.capitalize, r] }
    menu.unshift([any, ""]) if any
    menu
  end

  def published_menu(any=nil)
    menu = [["Yes", "true"], ["No", "false"]]
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
    menu = User::ROLES.map { |r| [r.capitalize, r] }
    menu.unshift([none, ""]) if none
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

  def tournament_stage_update_menu
    Tournament::STAGE_UPDATABLE.map{ |s| [t(s), s] }
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

  # Turn a date into a year-month (e.g. 2011-11-01 => 2011 Nov)
  def year_month(date)
    "%d %s" % [date.year, %w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)[date.month-1]]
  end

  # Returns links to objects on some specific external sites.
  def foreign_url_for(obj, opt={})
    host, path = nil, nil
    text, target = opt.values_at(:text, :target)
    case obj
    when IcuPlayer
      host = "www.icu.ie"
      path = "players/display.php?id=#{obj.id}"
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

  # Returns a plain link to the main ICU site.
  def link_to_icu(label, path="")
    link_to label, "http://www.icu.ie/#{path}", target: "_icu_ie", class: "external"
  end

  # Returns an ICU email link.
  def mail_to_icu(officer=:ratings)
    name = case officer.to_sym
      when :chairperson then "Chairperson"
      when :membership  then "Membership Officer"
      when :treasurer   then "Treasurer"
      when :ratings     then "Rating Officer"
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
    render "shared/dialog.html", id: "icu_player_details", width: 800, button: false, cancel: "Dismiss", title: "ICU Player"
  end
  def fide_player_details_dialog
    render "shared/dialog.html", id: "fide_player_details", width: 800, button: false, cancel: "Dismiss", title: "FIDE Player"
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
      summary << "; updated <span>#{I18n.l(updated, format: format)}<span>"
    end
    raw summary
  end

  # Returns copyright text (e.g. "&copy; ICU 2011-2013").
  def copyright
    start = 2011
    finish = Date.today.year
    raw "&copy; ICU %s" % (finish > start ? "#{start}-#{finish}" : start.to_s)
  end

  # A HAML specific way of adding attributes to rowspan cells (see shared/_rowspan.html.haml).
  def rowspan_attrs(rows, attrs)
    attrs[:rowspan] = rows if rows > 1
    attrs
  end
end
