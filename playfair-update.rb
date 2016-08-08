require './playfair_bot'
require 'pry'
require 'slack'
require 'optparse'

options = { slack: false, github: false }
OptionParser.new do |opts|
  opts.banner = "Usage: playfair-update --github --slack"

  opts.on("--slack", "Notify the Slack channel") do |v|
    options[:slack] = true
  end

  opts.on("--github", "Update the GitHub repo") do |v|
    options[:github] = true
  end
end.parse!

bot = PlayfairBot::Bot.new()

bot.process_all_issues if options[:github]
bot.notify_slack if options[:slack]

# binding.pry
