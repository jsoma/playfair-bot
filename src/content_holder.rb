module PlayfairBot
  module ContentHolder

    # get("number")
    # get("author/login")
    def get(target)
      target.split("/").map(&:to_sym).inject(@data) { |memo, obj| memo[obj] }
    end

    def all_data
      @data
    end

    def author
      get("user/login")
    end

    def has_image?
      get("body") =~ /!\[.*\]\(.*\)/
    end


  end
end