# == Schema Information
#
# Table name: fide_player_files
#
# text     "description"
# integer  "players_in_file",  :limit => 2, :default => 0
# integer  "new_fide_records", :limit => 2, :default => 0
# integer  "new_icu_mappings", :limit => 2, :default => 0
# integer  "user_id"
# datetime "created_at"
#

class FidePlayerFile < ActiveRecord::Base
  extend ICU::Util::Pagination
  FPFError = Class.new(StandardError)

  belongs_to :user

  attr_accessor :file, :update

  before_validation :analyse_file
  validates :description, presence: true
  validates :user_id, numericality: { only_integer: true, greater_than: 0 }

  def self.search(params, path)
    matches = includes(user: :icu_player)
    matches = matches.where("fide_player_files.created_at LIKE ?", "#{params[:created_at]}%") if params[:created_at].present?
    matches = matches.where("new_fide_records > 0 OR new_icu_mappings > 0") if params[:updates].present?
    matches = matches.order("fide_player_files.created_at DESC")
    paginate(matches, path, params)
  end

  def db_updated?
    new_fide_records > 0 || new_icu_mappings > 0
  end

  private

  # <playerslist>
  #   <player FIDEID="2507242">
  #     <name>Smith, John</name>
  #     <country>IRL</country>
  #     <sex>M</sex>
  #     <title></title>
  #     <rating></rating>
  #     <flag></flag>
  #     <birthday>2000-01-01</birthday>
  #   </player>
  def analyse_file
    # The description will be created by joining lines added to this array.
    desc = []

    # Sanity checks and basic information.
    raise FPFError.new("Please choose a file to upload") unless file
    size = file.size
    raise FPFError.new("The uploaded file is empty") if size == 0
    raise FPFError.new("The uploaded file is too large (#{size} bytes)") if size > 1.megabyte
    name = file.original_filename
    desc.push "### Summary"
    desc.push "* File name: #{name}"
    desc.push "* File size: #{size}"
    doc = Nokogiri.XML(file)
    players = doc.xpath("/playerslist/player[country='IRL']")
    raise FPFError.new("Uploaded XML contains no Irish players") unless players.count > 0
    desc.push "* Players in file: #{players.size}"
    self.players_in_file = players.size
    self.update = update == "1" # check_box default "on" value
    desc.push "* Update option: #{update ? "on" : "off"}"

    # Before processing the records, get all the Irish FIDE players currently in the database.
    db_records = FidePlayer.where(fed: "IRL").includes(:icu_player).inject({}) do |hash, p|
      hash[p.id] = p
      hash
    end
    desc.push "* Players in database: #{db_records.size}"

    # Also before processing the records fully, quickly find out if there are any duplicates.
    duplicate = Hash.new(0)
    players.each do |fp|
      id = fp["FIDEID"]
      duplicate[id] += 1
    end
    desc.push "* Duplicate IDs: #{duplicate.select{|k,v| v > 1}.keys.sort.join(', ')}"

    # Process the records, dividing them into categories (matched, mismatched, error etc).
    categories = Hash.new { |h,k| h[k] = [] }
    players.each do |fp|
      id   = fp["FIDEID"]
      name = fp.at_xpath("name").try(:content)
      dob  = fp.at_xpath("birthday").try(:content)
      sex  = fp.at_xpath("sex").try(:content)
      fep  = FIDE::ExportedPlayer.new(id, name, dob, sex)
      fep.search(db_records)
      fep.duplicate if duplicate[id] > 1
      if self.update
        new_fide_record, new_icu_mapping = fep.update_db
        self.new_fide_records += 1 if new_fide_record
        self.new_icu_mappings += 1 if new_icu_mapping
      end
      items = []
      items.push "* #{fep.to_s}"
      items.push " * FIDE name #{fep.fide_player.name}"        if fep.fide_name_mismatch
      items.push " * FIDE born #{fep.fide_player.born}"        if fep.fide_dob_mismatch
      items.push " * FIDE sex #{fep.fide_player.gender}"       if fep.fide_sex_mismatch
      items.push " * ICU name #{fep.icu_player.name}"          if fep.icu_name_mismatch
      items.push " * ICU DOB #{fep.icu_player.dob.to_s(:db)}"  if fep.icu_dob_mismatch
      items.push " * ICU sex #{fep.icu_player.gender}"         if fep.icu_sex_mismatch
      items.push " * #{dob || fep.icu_player.dob.to_s(:db)}"   if fep.transferable_dob
      if fep.icu_suggestions.size > 0
        fep.icu_suggestions.each { |s| items.push " * #{s.name} (#{s.id}) #{s.dob}"}
      end
      categories[fep.category] << items
    end

    # Order and label the categories.
    orla = Hash.new { |h, k| h[k] = [0, k.to_s] }
    orla[:error]               = [90, "Errors"]
    orla[:duplicate]           = [80, "Duplicates"]
    orla[:none]                = [75, "No FIDE match and no ICU suggested matches"]
    orla[:none_suggestions]    = [70, "No FIDE match with ICU suggested matches"]
    orla[:fide_suggestions]    = [65, "FIDE mismatch with ICU suggested matches"]
    orla[:perfect_suggestions] = [60, "FIDE match with ICU suggested matches"]
    orla[:fide]                = [55, "FIDE mismatch and no ICU suggested matches"]
    orla[:perfect]             = [50, "FIDE match but no ICU match"]
    orla[:both_fide_icu]       = [40, "FIDE and ICU mismatch"]
    orla[:both_fide]           = [30, "FIDE mismatch but ICU match"]
    orla[:both_icu]            = [20, "FIDE match but ICU mismatch"]
    orla[:both_match_one_dob]  = [15, "FIDE and ICU match but only one DOB"]
    orla[:both_perfect]        = [10, "FIDE and ICU match"]

    # Get the sorted categories.
    sorted_cats = categories.keys.sort { |a,b| orla[b][0] <=> orla[a][0] }

    # Add more summary items.
    desc.push "* #{categories.values.inject(0){|t,i| t += i.size}} players split into #{categories.size} #{'category'.pluralize(categories.size)}"
    sorted_cats.each do |category|
      items = categories[category]
      desc.push " * #{orla[category][1]}: #{items.size}"
    end
    if update
      desc.push "* new FIDE records created: #{new_fide_records}"
      desc.push "* new ICU mappings created: #{new_icu_mappings}"
    end

    # Output the records in each category in a new section with header.
    sorted_cats.each do |category|
      items = categories[category].flatten
      desc.push "\n"
      desc.push "### #{orla[category][1]}"
      items.each { |item| desc.push item }
    end
    
    # Collect the snippets gathered into the full description.
    self.description = desc.join("\n")
  rescue FPFError => e
    errors[:base] << e.message
  rescue => e
    errors[:base] << e.message
    errors[:base] << e.backtrace[0]
  end
end
