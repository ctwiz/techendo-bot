require_relative './base'

class HelpAction < BaseAction
  def self.help_description
    '!help : prints the commands this bot will respond to'
  end

  def self.args
    [:message, '!help']
  end

  def self.action(m)
    m.user.send 'Hello, I am the techendo bot. You can interact with me via these commands:'

    BaseAction.subclasses.each do |klass|
      message = klass.help_description
      m.user.send message unless message.nil? || message.empty?
    end
  end
end
