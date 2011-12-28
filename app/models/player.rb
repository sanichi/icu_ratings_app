class Player < ActiveRecord::Base
  FEDS = ICU::Federation.codes
  TITLES = %w[GM IM FM CM NM WGM WIM WFM WCM WNM]
  GENDERS = %w[M F]
  CATEGORY = %w[icu_player foreign_player new_player]

  belongs_to :tournament, include: :players
  belongs_to :icu_player, foreign_key: "icu_id"
  belongs_to :fide_player, foreign_key: "fide_id"
  has_many :results, dependent: :destroy, include: :opponent

  attr_accessible :first_name, :last_name, :icu_id, :fide_id, :fed, :title, :gender, :dob, :icu_rating, :fide_rating

  before_validation :normalise_attributes, :canonicalize_names, :deduce_category_and_status

  validates_presence_of     :first_name, :last_name, :original_name
  validates_numericality_of :icu_id, :original_icu_id, only_integer: true, greater_than: 0, allow_nil: true
  validates_numericality_of :fide_id, :original_fide_id, only_integer: true, greater_than: 0, allow_nil: true
  validates_inclusion_of    :fed, :original_fed, in: FEDS, allow_nil: true, message: "(%{value}) is invalid"
  validates_inclusion_of    :title, :original_title, in: TITLES, allow_nil: true, message: "(%{value}) is invalid"
  validates_inclusion_of    :gender, :original_gender, in: GENDERS, allow_nil: true, message: "(%{value}) should be #{GENDERS.join(' or ')}"
  validates_date            :dob, :original_dob, after: "1910-01-01", on_or_before: :today, allow_nil: true
  validates_numericality_of :icu_rating, :original_icu_rating, :fide_rating, :original_fide_rating, only_integer: true, greater_than: 0, allow_nil: true
  validates_numericality_of :rank, only_integer: true, greater_than: 0, allow_nil: true
  validates_numericality_of :num, only_integer: true, greater_than: 0
  validates_inclusion_of    :category, in: CATEGORY, allow_nil: true, message: "(%{value}) is invalid"
  validates_presence_of     :status

  def self.build_from_icut(icup, tournament)
    # Build basic player from an attribute hash (these must be unprotected attributes).
    attrs = {}
    %w[first_name last_name fide_id fed title gender dob fide_rating].each do |key|
      attrs[key.to_sym] = icup.send(key) unless icup.send(key).blank?
    end
    attrs[:icu_id] = icup.id unless icup.id.blank?
    attrs[:icu_rating] = icup.rating unless icup.rating.blank?
    player = tournament.players.build(attrs)

    # Set protected (by attr_accessible or attr_protected) attributes.
    player.num = icup.num
    player.rank = icup.rank unless icup.rank.blank?

    # Set original data (also protected as it should never change).
    player.original_name = icup.original_name
    player.original_icu_id = icup.id unless icup.id.blank?
    player.original_icu_rating = icup.rating unless icup.rating.blank?
    %w[fide_id fed title gender dob fide_rating].each do |key|
      player.send("original_#{key}=", icup.send(key)) unless icup.send(key).blank?
    end

    # Results.
    icup.results.each do |icur|
      Result.build_from_icut(icur, player)
    end
  end

  def name(last_first=true)
    last_first ? "#{last_name}, #{first_name}" : "#{first_name} #{last_name}"
  end

  def status_ok?
    status == "ok"
  end

  def score
    results.inject(0.0) { |s,r| s+= r.score }
  end

  def result_in_round(n)
    results.detect{ |r| r.round == n }
  end

  def original_data
    data = Array.new
    %w[name icu_id fide_id fed title gender dob icu_rating fide_rating].each do |key|
      val = self.send("original_#{key}")
      data.push val if val.present?
    end
    data.join(", ")
  end

  def changed_from_original?(opt={})
    keys = %w[name icu_id fide_id fed title gender dob icu_rating fide_rating]
    case
    when opt[:only]
      only = opt[:only].instance_of?(Array) ? opt[:only].map(&:to_s) : [opt[:only].to_s]
      keys = keys & only
    when opt[:except]
      expt = opt[:except].instance_of?(Array) ? opt[:except].map(&:to_s) : [opt[:except].to_s]
      keys = keys - expt
    end
    keys.each do |key|
      case key
      when "name"
        return true if original_name != name && original_name != name(false)
      else
        return true if self.send(key) != self.send("original_#{key}")
      end
    end
    false
  end

  private

  # Correlated with the Help text in admin/players/show.
  def deduce_category_and_status
    errors = Array.new
    category = nil
    
    # Check for FIDE errors, no longer used for category.
    match_fide(errors)
    
    # Determine category.
    case
    when match_icu(errors)
      category = "icu_player"
    when fide_rating.present? && fed.present? && fed != "IRL"
      category = "foreign_player"
    when icu_id.blank? && fide_id.blank? && icu_rating.blank? && fide_rating.blank?
      category = "new_player"
    else
      errors.push "cannot determine category"
    end

    if errors.empty?
      self.status   = "ok"
      self.category = category
    else
      self.status   = errors.join("|")
      self.category = nil
    end
  end

  def match_icu(errors)
    return false if icu_id.blank?
    match = true
    if icu_player
      cname = ICU::Name.new(icu_player.first_name, icu_player.last_name)
      unless cname.match(first_name, last_name)
        match = false
        errors.push "ICU name mismatch: #{icu_player.name}"
      end
      if icu_player.master_id
        match = false
        errors.push("Match with duplicate ICU player")
      else
        %w[dob fed gender title].each do |attr|
          a = icu_player.send(attr).presence || next
          b = self.send(attr).presence || next
          unless a == b
            match = false unless attr == "title"  # title may change over time, so we just warn about it
            errors.push("ICU #{attr} mismatch: #{a}")
          end
        end
      end
    else
      match = false
      errors.push "#{icu_id}: no such ICU player"
    end
    match
  end

  def match_fide(errors)
    return false if fide_id.blank?
    match = true
    if fide_player
      cname = ICU::Name.new(fide_player.first_name, fide_player.last_name)
      unless cname.match(first_name, last_name)
        match = false
        errors.push "FIDE name mismatch: #{fide_player.name}" if fed == "IRL"  # TODO: relax when we get all FIDE players
      end
      %w[fed gender title].each do |attr|
        a = fide_player.send(attr).presence || next
        b = self.send(attr).presence || next
        unless a == b
          match = false unless attr == "title"  # title may change over time, so we just warn about it
          errors.push("FIDE #{attr} mismatch: #{fide_player.send(attr)}") unless fide_player.send(attr) == self.send(attr)
        end
      end
      if fide_player.born.present? && self.dob.present?
        unless fide_player.born == self.dob.year
          match = false
          errors.push("FIDE year of birth mismatch: #{fide_player.born}")
        end
      end
    else
      match = false
      errors.push "#{fide_id}: no such FIDE player"
    end
    match
  end

  def normalise_attributes
    %w[fed title gender dob].each do |attr|
      self.send("#{attr}=", nil) if self.send(attr).to_s.match(/^\s*$/)
    end
  end

  def canonicalize_names
    name = ICU::Name.new(first_name, last_name)
    self.first_name = name.first(chars: "US-ASCII")
    self.last_name = name.last(chars: "US-ASCII")
  end
end
