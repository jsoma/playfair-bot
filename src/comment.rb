module PlayfairBot
  class Comment
    include PlayfairBot::ContentHolder

    EDITORS = %w(jsoma nickyforster)

    def initialize(comment_data, issue)
      @data = comment_data
      @issue = issue
    end

    def author
      get("user/login")
    end

    def by_owner?
      author == @issue.author
    end

    def by_bot?
      author == "playfairbot"
    end

    def by_editor?
      EDITORS.include? author
    end

    def by_peer?
      !by_editor? and !by_owner? and !by_bot?
    end

    def has_image?
      get("body") =~ /!\[.*\]\(.*\)/
    end

    def is_update?
      by_owner? and has_image?
    end

  end
end