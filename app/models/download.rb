# == Schema Information
#
# Table name: downloads
#
#  id           :integer(4)      not null, primary key
#  comment      :string(255)
#  file_name    :string(255)
#  content_type :string(255)
#  data         :binary(16777215)
#  created_at   :datetime
#  updated_at   :datetime
#

class Download < ActiveRecord::Base
  extend ICU::Util::Pagination
  include ICU::Util::Model

  attr_accessible :comment, :uploaded_file
  validates_presence_of :data, :content_type, :file_name
  validates_length_of   :data, maximum: 1.megabyte
  validates_length_of   :comment, maximum: 80
  
  def uploaded_file=(file)
    self.file_name    = base_part_of(file.original_filename)
    self.content_type = file.content_type.chomp
    self.data         = file.read
  end

  def self.search(params, path)
    matches = order("updated_at DESC")
    paginate(matches, path, params)
  end
end
