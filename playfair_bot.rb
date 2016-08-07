require 'logging'
require 'octokit'
require 'aasm'
require './config'
require './src/models'
require 'slack'

module PlayfairBot
  class Bot
    attr_accessor :issues

    def initialize()
      @slack_client = Slack::Web::Client.new
    end

    def all_issues
      # Auto paginate must be set to true
      # We did this in configure
      @all_issues ||= PlayfairBot.config.client.issues(
        PlayfairBot.config.repo_path, { state: :all }
      ).map { |gh_issue|
        Issue.new(gh_issue)
      }
    end

    def process_all_issues
      all_issues.each do |issue|
        issue.process
      end
    end

    def process_issues
      issues.each do |issue|
        issue.process
      end
    end

    def issues
      # Auto paginate must be set to true
      # We did this in configure
      @issues ||= PlayfairBot.config.client.issues(
        PlayfairBot.config.repo_path,
      ).map { |gh_issue|
        Issue.new(gh_issue)
      }
    end

    def feedback_type(issue)
      if issue.pitch? and issue.has_label?(:peer_review)
        "Pitch Feedback"
      elsif issue.has_label?(:peer_review)
        "Draft Feedback"
      elsif issue.has_label?(:peer_review_revision)
        "Revision Feedback"
      end
    end

    def issues_that_need_feedback
      issues.reject{ |issue| feedback_type(issue).nil? }
    end

    def notify_slack
      client = Slack::Web::Client.new
      client.chat_postMessage channel: "#data-studio-critique", text: slack_message, as_user: true
    end

    def slack_message
      <<~HEREDOC
      *FEEDBACK ROLL CALL!*
      
      *Who needs feedback?* Don't fret, buddies, I'll tell ya. As of #{Time.new.strftime("%A, %B %-d at around %-I%p")}, it looks something like...
      #{issues_that_need_feedback.group_by{ |issue|
        feedback_type(issue)
      }.map{ |group, issues|
        [ "", "*#{group} Needed*:" ] + issues.sort_by{ |issue| 
          issue.get("number") 
        }.map{ |issue|
          "<#{issue.url}|#{issue.get("title")}> / #{issue.author}"
        }
      }.flatten.join("\n")}

      And remember, pitches and stories both need *two comments of feedback* (not counting bots or editors!). Click a few, add your thoughts, and help your classmates out!
      HEREDOC
    end

  end
end