module FIDE
  # Used in models/fide_player_file.rb to make it more idiomatic Ruby and less C-like.
  class ExportedPlayer
    attr_reader :id, :name, :dob, :sex, :updates, :fide_player, :icu_player

    def initialize(id, name, dob, sex)
      @id      = id.to_i if id.to_i > 0
      @name    = name    if name.present?
      @dob     = dob     if dob.present? && dob.match(/\A(19|20)\d{2}-\d\d-\d\d\z/)
      @sex     = sex     if sex.match(/\A[MF]\z/)
      @updates = []
    end

    # Search for the player's ID in a hash of FidePlayer objects.
    def search(db_records)
      if id && db_records[id]
        @fide_player = db_records[id]
        @icu_player = @fide_player.icu_player
      end
    end

    def to_s
      return @_to_s if @_to_s
      parts = []
      parts.push md_name || "Unknown, Unknown"
      ids = []
      ids.push sex || "no sex"
      ids.push id || "no ID"
      ids.push "DUPLICATE" if category == :duplicate
      ids.push icu_player.id if icu_player
      parts.push "(#{ids.join(', ')})"
      parts.push dob || "no DOB"
      parts.push "(#{updates.join(', ')})" unless updates.empty?
      @_to_s = parts.join(" ")
    end

    # Escape FIDE backticks for markdown.
    def md_name
      return "Unknown, Unknown" unless name
      return @_md_name if @_md_name
      @_md_name = name.gsub(/`/, "'")
    end

    def fide_name_mismatch
      return false unless name && fide_player
      return @_fide_name_mismatch unless @_fide_name_mismatch.nil?
      @_fide_name_mismatch = !ICU::Name.new(name).match(fide_player.name)
    end

    def fide_dob_mismatch
      return false unless dob && fide_player && fide_player.born
      return @_fide_dob_mismatch unless @_fide_dob_mismatch.nil?
      @_fide_dob_mismatch = dob.index(fide_player.born.to_s) != 0
    end

    def fide_sex_mismatch
      return false unless sex && fide_player && fide_player.gender
      return @_fide_sex_mismatch unless @_fide_sex_mismatch.nil?
      @_fide_sex_mismatch = sex != fide_player.gender
    end

    def fide_mismatch
      return false unless fide_player
      fide_name_mismatch || fide_dob_mismatch || fide_sex_mismatch
    end

    def icu_name_mismatch
      return false unless name && icu_player
      return @_icu_name_mismatch unless @_icu_name_mismatch.nil?
      @_icu_name_mismatch = !ICU::Name.new(name).match(icu_player.name)
    end

    def icu_dob_mismatch
      return false unless dob && icu_player && icu_player.dob
      return @_icu_dob_mismatch unless @_icu_dob_mismatch.nil?
      @_icu_dob_mismatch = dob != icu_player.dob.to_s(:db)
    end

    def icu_sex_mismatch
      return false unless sex && icu_player && icu_player.gender
      return @_icu_sex_mismatch unless @_icu_sex_mismatch.nil?
      @_icu_sex_mismatch = sex != icu_player.gender
    end

    def icu_mismatch
      return false unless icu_player
      icu_name_mismatch || icu_dob_mismatch || icu_sex_mismatch
    end

    def icu_suggestions
      return [] unless dob && name && !icu_player
      return @_icu_suggestions if @_icu_suggestions
      @_icu_suggestions = IcuPlayer.where(dob: dob, master_id: nil).select do |p|
        ICU::Name.new(name).match(p.name)
      end
    end

    def transferable_dob
      return false unless dob && icu_player
      return @_transferable_dob unless @_transferable_dob.nil?
      @_transferable_dob = (dob.match(/^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])\z/) && !icu_player.dob) || (!dob && icu_player.dob)
    end

    def category
      return @_category unless @_category.nil?
      if id && name
        if fide_player && icu_player
          if fide_mismatch && icu_mismatch
            @_category = :both_fide_icu
          elsif fide_mismatch
            @_category = :both_fide
          elsif icu_mismatch
            @_category = :both_icu
          else
            @_category = transferable_dob ? :both_match_one_dob : :both_perfect
          end
        elsif fide_player
          if icu_suggestions.size > 0
            @_category = fide_mismatch ? :fide_suggestions : :perfect_suggestions
          else
            @_category = fide_mismatch ? :fide : :perfect
          end
        else
          @_category = icu_suggestions.size > 0 ? :none_suggestions : :none
        end
      else
        @_category = :error
      end
      @_category
    end
    
    def duplicate
      @_category = :duplicate
    end
    
    def update_db
      new_fide_record, new_icu_mapping = false, false
    
      if category == :none_suggestions
        name = ICU::Name.new(self.name)
        born = $1.to_i if dob && dob.match(/\A((19|20)\d\d)/)
        hash = {id: id, first_name: name.first, last_name: name.last, fed: "IRL", born: born, gender: sex}
        hash[:icu_id] = icu_suggestions[0].id if icu_suggestions.size == 1
        if FidePlayer.create(hash, without_protection: true)
          new_fide_record = true
          updates.push("created new FIDE record")
          if hash[:icu_id]
            new_icu_mapping = true
            updates.push("created new ICU mapping")
          end
        else
          updates.push("ERROR: failed to create new FIDE record")
        end
      elsif category == :perfect_suggestions && icu_suggestions.size == 1
        fide_player.icu_id = icu_suggestions[0].id
        if fide_player.save
          new_icu_mapping = true
          updates.push("created new ICU mapping")
        else
          updates.push("ERROR: failed to create new ICU mapping")
        end
      end
    
      [new_fide_record, new_icu_mapping]
    end
  end
end
