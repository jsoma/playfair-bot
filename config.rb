require 'octokit'
require 'yaml'
require 'slack'

options = YAML.load_file("config.yml")

Slack.configure do |config|
  config.token = options['slack_token']
end

module PlayfairBot
  class << self
    attr_writer :config
  end

  def self.config
    @config ||= Config.new
  end

  def self.configure
    yield(config)
  end

  class Config
    attr_accessor :client, :repo_path
  end
end

PlayfairBot.configure do |config|
  config.client = Octokit::Client.new(access_token: options['github_token'], auto_paginate: true)
  config.repo_path = options['repo_path']
end