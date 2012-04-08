FactoryGirl.define do
  factory :upload do
    name          "tournament.txt"
    size          { Random.new.rand(1000..10000) }
    tournament_id 1
    user_id       1
    error         nil
    created_at    { Time.now }
    format do
      case name
        when /\.csv$/ then "ForeignCSV"
        when /\.tab$/ then "Krause"
        when /\.zip$/ then "SwissPerfect"
        else "SPExport"
      end
    end
    content_type do
      case name
        when /\.zip$/ then "application/zip"
        else "text/plain"
      end
    end
    file_type do
      case name
        when /\.zip$/ then "Zip archive data, at least v2.0 to extract"
        else "ASCII text, with CRLF line terminators"
      end
    end
  end
end