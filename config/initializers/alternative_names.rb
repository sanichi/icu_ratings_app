# Load our own versions of alternative first and last names for the ICU::Name class.
%w{first last}.each do |type|
  file = File.expand_path(File.dirname(__FILE__) + "/alternative_#{type}_names.yaml")
  data = File.open(file) { |fd| YAML.load(fd) }
  ICU::Name.load_alternatives(type, data)
end