require_relative './safe_action'

class ChatResponseAction < SafeAction
  def self.args
    [:message, /techendo\-pal/]
  end

  def self._action(m, message)
    if message.match(/you there, techendo\-pal\?/)
      m.reply "Yes. I believe so, #{m.user.name}. I visualize a time when we will be to robots what dogs are to humans, and I'm rooting for the machines."
    else
      m.reply "You know I can hear you talking about me, right?"
    end
  end
end