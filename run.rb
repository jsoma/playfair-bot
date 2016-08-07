require './playfair_bot'
require 'pry'
require 'slack'

BOT = PlayfairBot::Bot.new()

i = BOT.issues[0]

def g(id) 
  BOT.issues.find{ |issue| issue.get("number") == id }
end

#BOT.notify_slack
BOT.process_issues

# binding.pry
