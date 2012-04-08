class Download < ActiveRecord::Base
  extend ICU::Util::Pagination
  include ICU::Util::Model

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
