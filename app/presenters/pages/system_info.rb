module Pages
  class SystemInfo
    def environment
      return @e if @e
      @e = ENV.keys.sort.inject({}) do |h, k|
        v = ENV[k].dup
        v = v.split(/:/).map{ |p| p == "" ? "(blank)" : p }.join("<br/>").html_safe if k.match(/PATH/)
        h[k] = v
        h
      end
    end
  end
end
