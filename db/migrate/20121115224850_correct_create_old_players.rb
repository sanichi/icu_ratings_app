class CorrectCreateOldPlayers < ActiveRecord::Migration
  def up
    OldPlayer.where("note LIKE '%former%'").each do |p|
      new_note = p.note.dup
      while match = new_note.match(/\[(\d+)\]\(\/admin\/old_players\/\1\)/)
        icu_id = match[1].to_i
        id = OldPlayer.find_by_icu_id(icu_id).try(:id)
        if (id && id != icu_id)
          new_note.sub!(/\/admin\/old_players\/#{icu_id}/, "/admin/old_players/#{id}")
        else
          new_note.sub!(/\[#{icu_id}\]\(\/admin\/old_players\/#{icu_id}\)/, "#{icu_id}")
        end
      end
      p.note = new_note
      p.save
    end
  end

  def down
  end
end
