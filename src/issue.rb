require 'logger'

module PlayfairBot
  class Issue
    include PlayfairBot::ContentHolder

    COMMENT_CHECKS = {
      checklist: {
        label: :bot_request_checklist,
        test: :has_checklist?,
        comment: "Hi there, I'm the Playfair Bot!\n\nWould you mind **posting the appropriate checklist** in the main body of your issue? You might have posted it as the first comment, but it turns out it works *way better* in the actual body of the issue - just go up to the veeery top right and click the **pencil icon** to edit. You'll probably want to edit the comment to copy the checklist, then edit the original issue to paste it in.\n\nThanks! :pray:"
      },
      image: {
        label: :bot_request_image,
        test: :has_image?,
        comment: "Hi there, I'm the Playfair Bot!\n\nThanks for posting your story issue, but would you mind adding editing the original issue to **add the first draft of your image?** You have my sincere apologies, but it's easier for dumb robots like me when the comments are only used for updates.\n\nThanks! :pray:"
      },
      category: {
        label: :bot_request_category,
        test: :has_category?,
        comment: "Hi there, I'm the Playfair Bot!\n\nWould you mind **adding a category to your issue title?** Something like [Pitch] or [Story], or maybe [Meta] if it happens to be a bug. That way we can organize things nice and neat.\n\nThanks! :pray:"
      },
      story_link: {
        label: :bot_request_story_link,
        test: :has_issue_link?,
        comment: "Hi there, I'm the Playfair Bot!\n\nWould you mind **linking to your story issue** by using the '#1' method (but with your actual story issue number)? It'll hopefully help us keep things neat and organized.\n\nThanks a zillion! :pray:"
      },
      pitch_link: {
        label: :bot_request_pitch_link,
        test: :has_issue_link?,
        comment: "Hi there, I'm the Playfair Bot!\n\nWould you mind **linking to your pitch issue** by using the '#1' method (but with your actual pitch issue number)? It'll hopefully help us keep things neat and organized.\n\nThanks a zillion! :pray:"
      }
    } 

    LABEL_MAP =
    {
      'pitch': 'Type: Pitch',
      'story': 'Type: Story',
      'peer_review': 'Peer: Feedback Required',
      'editor_review': 'Editor: Feedback Required',
      'peer_review_revision': 'Peer: Revision Feedback Required',
      'editor_review_revision': 'Editor: Revision Feedback Required',
      'update': 'Update Requested',
      'bot_request_checklist': 'Bot Request: Checklist',
      'bot_request_image': 'Bot Request: Image',
      'bot_request_category': 'Bot Request: Category',
      'bot_request_pitch_link': 'Bot Request: Link Pitch Issue',
      'bot_request_story_link': 'Bot Request: Link Story Issue',
      'data request': 'Request: Data',
      'project 1': 'Project 1',
      'project 2': 'Project 2',
      'project 3': 'Project 3',
      'project 4': 'Project 4',
      'project 5': 'Project 5',
      'project 6': 'Project 6',
      'project 7': 'Project 7',
      'project 8': 'Project 8',
      'project 9': 'Project 9',
      'meta': 'Type: Meta',
      'pull_request': 'Type: Pull Request',
      'unknown': 'Type: Unknown',
    }

    def initialize(issue_data)
      @data = issue_data
      @logger = Logging.logger(STDOUT)
      @logger.level = :info
    end

    def log(content, level = :debug)
      @logger.send(level, "#{get("number")}: #{content}")
    end

    def has_label?(command)
      label_names.include? LABEL_MAP[command]
    end

    def add_label!(command)
      log("+label #{command}")
      add_label_by_name!(LABEL_MAP[command])
    end

    def remove_label!(command)
      log("-label #{command}")
      remove_label_by_name!(LABEL_MAP[command])
    end

    def add_label_by_name!(label)
      return if label_names.include? label
      update!(labels: label_names << label)
    end

    def remove_label_by_name!(label)
      return if !label_names.include? label
      update!(labels: label_names - [ label ])
    end

    #
    # .update!({title: "new title", tags: ["Type: Story", "Project 2"] })
    #
    def update!(options)
      log("UPDATING: #{options.inspect}", :info)
      options[:title] = "Untitled" if options[:title] == ""

      return if debug_mode?
      @data = PlayfairBot.config.client.update_issue(
                PlayfairBot.config.repo_path,
                get("number"),
                options
              )
    end

    def close!
      log("CLOSING")
      return if debug_mode?
      update!({state: "closed"})
    end

    def add_comment!(body)
      log("COMMENTING: #{body}", :info)
      return if debug_mode?
      PlayfairBot.config.client.add_comment(
        PlayfairBot.config.repo_path,
        get("number"),
        body
      )
      @comments = nil
    end

    def debug_mode?
      false
    end

    def comments
      @comments ||= PlayfairBot.config.client.issue_comments(
                      PlayfairBot.config.repo_path,
                      get("number")
                    ).map{ |c| Comment.new(c, self) }
    end

    # This is a title [Pitch]
    # Returns [:pitch]
    def found_labels
      found = get("title").scan(/\[(.*?)\]/).map { |label_arr|
        label = label_arr[0].downcase
        label.to_sym
      }.select{ |label|
        LABEL_MAP.keys.include? label
      }
    end

    # If it found [Pitch], found_labels got [:pitch]
    # this one looks at LABEL_MAP and send back "Type: Pitch"
    def new_labels
      found_labels.map{ |label| LABEL_MAP[label] }
    end

    def replacement_title
      found_labels.map(&:to_s).inject(get("title")) { |memo, obj|
        memo.gsub(/\[#{obj}\]/i,'')
      }.strip
    end

    def label_names
      get("labels").map{ |label| label.name }
    end

    def update_labels_from_title!
      return if new_labels.empty?
      update!({
        labels: label_names + new_labels,
        title: replacement_title
      })
    end

    def label_as_pull_request_if_needed!
      return if pull_request? or get("pull_request").nil?
      add_label!(:pull_request)
    end

    # 
    # What kind of story is it?
    # defines pitch? story? meta? and pull_request?

    %w(pitch story meta pull_request).each do |tagname|
      define_method "#{tagname}?" do
      label_names.include?(LABEL_MAP[tagname.to_sym])
      end
    end

    def needs_category_tag?
      category.nil?
    end

    def has_peer_review?(review_count = 2)
      self.comments.select{ |comment| comment.by_peer? }.length >= review_count
    end

    def has_peer_review_after_update?(review_count = 2)
      update_index = self.comments.find_index{ |comment| comment.is_update? }
      return false if update_index.nil? or update_index == self.comments.length - 1
      self.comments[update_index..-1].select{ |comment| comment.by_peer? }.length >= review_count
    end

    def has_editor_review_after_update?(review_count = 1)
      update_index = self.comments.find_index{ |comment| comment.is_update? }
      return false if update_index.nil? or update_index == self.comments.length - 1
      self.comments[update_index..-1].select{ |comment| comment.by_editor? }.length >= 1
    end

    def has_editor_review?(review_count = 1)
      self.comments.select{ |comment| comment.by_editor? }.length >= review_count
    end

    def has_update?
      !self.comments.select{ |comment| comment.is_update? }.empty?
    end

    def has_project_label?
      !self.label_names.select{ |label| label =~ /Project \d/ }.empty?
    end

    def has_checklist?
      !["[ ]", "[x]", "[X]"].select{ |check| get("body").include?(check) }.empty?
    end

    def category
      if story?
        :story
      elsif pitch?
        :pitch
      elsif pull_request?
        :pull_request
      elsif meta?
        :meta
      end        
    end

    def has_issue_link?
      get("body") =~ / \#(\d+)/
    end

    def url
      "https://github.com/#{PlayfairBot.config.repo_path}/issues/#{get("number")}"
    end

    def close_linked_if_needed(id)
      linked_issue = Issue.new(PlayfairBot.config.client.issue(PlayfairBot.config.repo_path, id))

      if story? and linked_issue.pitch? and linked_issue.get("state") == "open"
        log("This is a story, closing the associated pitch #{linked_issue.get("number")}")
        linked_issue.add_comment!("Closing pitch since story has been opened at ##{get("number")}")
        linked_issue.close!
      end

      if pull_request? and get("state") == "closed" and (linked_issue.story? or linked_issue.pitch?) and linked_issue.get("state") == "open"
        log("This is a successful pull request, closing the associated issue #{linked_issue.get("number")}")
        linked_issue.add_comment!("Closing since pull request ##{get("number")} has been accepted")
        linked_issue.close!
      end
    rescue
      log("FAILED to pull linked issue #{id}")
    end

    def close_linked_issues_if_needed!
      issue_ids = get("body").scan(/\#(\d+)/)
      return if issue_ids.nil?
      issue_ids.flatten.each { |id| close_linked_if_needed(id) }
    end

    def has_category?
      !category.nil?
    end

    def run_check(type)
      log("Running check #{type}")
      options = COMMENT_CHECKS[type]
      if has_label?(options[:label])
        if self.send(options[:test])
          log("Passes now, so removing label")
          remove_label!(options[:label]) 
        else
          log("Already tagged, but still fails")
        end
        return
      end

      if !self.send(options[:test])
        log("Doesn't pass, commenting and labeling")
        add_comment!(options[:comment])
        add_label!(options[:label])
      end
    end

    def process
      log("Processing ##{get("number")}: #{author} / #{category} / #{get("title")}", :info)
      log("https://github.com/jsoma/playfair-projects/issues/#{get("number")}")

      update_labels_from_title!
      label_as_pull_request_if_needed!

      if get("state") == "closed"
        close_linked_issues_if_needed!
        return
      end

      run_check(:category)

      if pitch?
        run_check(:checklist)
        
        if !has_peer_review?
          add_label!(:peer_review) 
        else
          remove_label!(:peer_review)
        end

        if has_peer_review? and !has_editor_review?
          add_label!(:editor_review)
        end
        
        remove_label!(:editor_review) if has_editor_review?
      elsif story?
        run_check(:checklist)
        run_check(:image)
        run_check(:pitch_link)

        remove_label!(:peer_review) if has_peer_review?
        remove_label!(:editor_review) if has_editor_review?
        remove_label!(:peer_review_revision) if has_peer_review_after_update?
        remove_label!(:editor_review_revision) if has_editor_review_after_update?

        add_label!(:peer_review) if !has_peer_review?
        if has_peer_review?
          add_label!(:editor_review) if !has_editor_review?
          add_label!(:update) if !has_update?
          if has_update?
            add_label!(:peer_review_revision) if !has_peer_review_after_update?
            add_label!(:editor_review_revision) if !has_editor_review_after_update?
          end          
        end
      elsif pull_request?
        run_check(:checklist)
        run_check(:story_link)
      elsif meta?
         puts "#### It's meta"
      end

      close_linked_issues_if_needed!

    end

  end
end