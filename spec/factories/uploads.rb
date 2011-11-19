Factory.define :upload do |u|
  u.name          "tournament.txt"
  u.size          { Random.new.rand(1000..10000) }
  u.tournament_id 1
  u.user_id       1
  u.error         nil
  u.created_at    { Time.now }
  u.format do
    case name
      when /\.csv$/ then "ForeignCSV"
      when /\.tab$/ then "Krause"
      when /\.zip$/ then "SwissPerfect"
      else "SPExport"
    end
  end
  u.content_type do
    case name
      when /\.zip$/ then "application/zip"
      else "text/plain"
    end
  end
  u.file_type do
    case name
      when /\.zip$/ then "Zip archive data, at least v2.0 to extract"
      else "ASCII text, with CRLF line terminators"
    end
  end
end