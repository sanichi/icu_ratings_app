class DateValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    constraints = options.each_with_object({}) do |(k,v), h|
      h[k.to_sym] = v if k.to_s.match(/\A(on_or_)?(after|before)\z/)
    end
    date = ICU::Date.new(value, constraints)
    unless date.valid?
      record.errors[attribute] << (options[:message] || I18n.t(*date.reasons));
    end
  end
end
