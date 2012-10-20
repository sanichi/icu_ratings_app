module ActiveRecord
  class Base
    # Like update_column, but saves on SQL if the value hasn't changed.
    def update_column_if_changed(name, value)
      update_column(name, value) unless self.send(name) == value
    end
  end
end

class Array
  def examples(n=4)
    if size <= n
      map(&:to_s).join(", ")
    else
      self[0..n-1].map(&:to_s).join(", ") + " ... #{last}"
    end
  end
end
