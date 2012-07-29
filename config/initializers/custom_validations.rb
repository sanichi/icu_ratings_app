class ListDateValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    record.errors.add(attribute, "should be 1st day of month") unless value.day == 1
    record.errors.add(attribute, "should be Jan, May or Sep")  unless [1, 5, 9].include?(value.month)
  end
end