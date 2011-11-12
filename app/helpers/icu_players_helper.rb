module IcuPlayersHelper
  def summarize(player, how)
    parts = Array.new

    case how
    when :personal
      { dob: "DOB", gender: nil, club: nil }.each_pair do |attr, label|
        value = player.send(attr)
        parts.push "#{label || attr}: #{value}" unless value.blank?
      end
    when :icu
      parts.push "ICU ID #{foreign_url_for(player)}"
      parts.push "joined: #{player.joined}" if player.joined.present?
    when :fide
      fide_player = player.fide_player
      if fide_player
        link = link_to fide_player.id, fide_player, remote: true
        parts.push "FIDE ID: #{link}, #{foreign_url_for(fide_player)}"
      end
      { fed: "federation", title: nil }.each_pair do |attr, label|
        value = player.send(attr)
        parts.push "#{label || attr}: #{value}" unless value.blank?
      end
    when :phones
      parts.push "Phones: #{player.phone_numbers}" if player.phone_numbers.present?
    when :email
      parts.push %Q{Email: <a href="mailto: #{player.email}">#{player.email}</a>} if player.email.present?
    when :address
      parts.push "Address: #{player.address}" if player.address.present?
    when :duplicate
      parts.push "This record is a duplicate of #{player.master_id}" if player.master_id.present?
    when :deceased
      parts.push "Deceased" if player.deceased
    when :note
      note = player.note
      note.sub!(/\s*From Access database.*$/m, '') if note.present?  # This common bit of text is not worth the extra space.
      parts.push "Note: #{note}" if note.present?
    when :old_rating
      old = player.old_rating
      parts.push "Old rating: %d (%s, %s)" % [old.rating, old.type, pluralize(old.games, "game")] if old
    end

    return nil unless parts.size > 0

    raw parts.join(", ")
  end
end