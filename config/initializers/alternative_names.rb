# Load the default alternatives for the ICU::Name class.
%w[first last].each do |type|
  ICU::Name.load_alternatives(type)
end
