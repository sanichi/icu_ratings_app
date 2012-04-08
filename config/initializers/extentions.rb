module ActiveRecord
  class Base
    # Like update_column, but saves on SQL if the value hasn't changed.
    def update_column_if_changed(name, value)
      update_column(name, value) unless self.send(name) == value
    end
  end
end
