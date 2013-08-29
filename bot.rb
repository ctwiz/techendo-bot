#!/usr/bin/env ruby
require 'uri'
require 'cinch'
require 'active_record'
require './topic'
require './vote'
require './tutorial'
require './idea'
require './database'
require './links'
require './actions/help_action'

DatabaseHelper.connect
DatabaseHelper.migrate!

actions = [HelpAction]

Cinch::Bot.new do
  @last_failure = nil
  @last_exception = nil

  configure do |c|
    c.server = 'irc.freenode.org'
    c.channels = ['#techendo']
    c.nick = 'techendo-pal'
  end

  actions.each do |a|
    on(*a.args) do |args|
      if failure = a.action.call(*args)
        @last_exception = failure
        @last_failure = a.args.join(', ')
      end
    end
  end

  on(:message, '!errors') do |m|
    unless @last_failure.nil?
      user = User(m.user.nick)
      user.send "Last failure was #{@last_failure}. Result : #{@last_exception.message}"
      user.send @last_exception.backtrace

      @last_failure = nil
      @last_exception = nil
    else
      m.reply "All systems operational"
    end
  end

  on(:message, /techendo\-pal/) do |m|
    m.reply "I know you're not talking about me"
  end

  on(:message, 'you there, techendo-pal?') do |m|
    m.reply "Yes. I believe so, #{m.user.name}. I visualize a time when we will be to robots what dogs are to humans, and I'm rooting for the machines."
  end

  on(:message, /^!idea (.+)$/) do |m, message|
    unless Idea.create(:description => message, :author => m.user.nick)
      m.reply "Techendo is broken. Alert the authorities"
    else
      m.reply "Recorded techendo idea: #{message}, by author: #{m.user.nick} at #{Time.now}"
    end
  end

  on(:message, /^!ideas( --spam)?$/) do |m, spam_channel|
    user = User(m.user.nick)
    ideas = Idea.find(:all)
    ideas.each do |t|
      message = "#{t.id} : #{t.description} (submitted by #{t.author})"
      if spam_channel
        m.reply message
      else
        user.send message
      end
    end
  end

  on(:message, /^!topic (.+)$/) do |m, message|
    unless Topic.create(:description => message, :author => m.user.nick)
      m.reply "Sorry, that didn't work. There must be something wrong with me today."
    else
      m.reply "Recorded topic: #{message}, by author: #{m.user.nick} at #{Time.now}"
    end
  end

  on(:message, /^!topics( --spam)?$/) do |m, spam_channel|
    user = User(m.user.nick)

    topics = Topic.find(:all)
    topics.each do |t|
      message = "#{t.id} : #{t.description} (submitted by #{t.author})"
      if spam_channel
        m.reply message
      else
        user.send message
      end
    end
  end

  on(:message, /^!delete topic (\d+)$/) do |m, id|
    topic = Topic.find(id)
    if topic && (topic.author == m.user.nick || m.user.nick == "dpg")
      votes = [Vote.find_by_topic_id(id)].flatten
      votes.each(&:destroy)

      topic.destroy
      m.reply "Successfully destroyed #{topic.id}, by #{topic.author}"
    end
  end

  on(:message, /^!tutorial (.+)$/) do |m, message|
    unless Tutorial.create(:description => message, :author => m.user.nick)
      m.reply "Sorry, that didn't work. There must be something wrong with me today."
    else
      m.reply "Recorded tutorial: #{message}, by author: #{m.user.nick} at #{Time.now}"
    end
  end

  on(:message, /^\!tutorials( --spam)?$/) do |m, spam_channel|
    Tutorial.find(:all).each do |t|
      message = "#{t.id} : #{t.description} (submitted by #{t.author})"

      if spam_channel
        m.reply message
      else
        m.user.send message
      end
    end
  end

  on(:message, /^!delete tutorial (\d+)$/) do |m, id|
    tut = Tutorial.find(id)
    if tut.author == m.user.nick || m.user.nick == "dpg"
      Tutorial.destroy(id)
      m.reply "Successfully destroyed tutorial: #{tut.id}, by #{tut.author}"
    end
  end

  on(:message, /^!vote (\d+)$/) do |m, id|
    topic = Topic.find(id)
    unless topic
      return m.reply("sorry, I can't find that topic (#{id}), #{m.user.nick}")
    end

    votes = [Vote.find_by_topic_id(id) || []].flatten
    if votes.empty? || !votes.map(&:whom).include?(m.user.nick)
      Vote.create(
        :topic_id => id,
        :whom => m.user.nick
      )
      m.reply "#{m.user.nick} voted for topic #{id}"
    else
      m.reply "#{m.user.nick} already voted for topic #{id}"
    end
  end

  on(:message, /^!votes( --spam)?$/) do |m, should_spam|
    user = User(m.user.nick)

    all_votes = Vote.find(:all).to_a.inject({}) do |acc, v|
      acc[v.topic_id] ||= 0
      acc[v.topic_id] += 1
      acc
    end

    all_votes.sort_by {|k, v| v }.reverse.each do |topic, votes|
      message = "Topic (#{topic}) has #{votes} votes"

      if should_spam
        m.reply message
      else
        user.send message
      end
    end
  end

  #munching on URLs Prism style - fails for URLs with parameters
  on(:catchall, /https?:\/\/([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/) do |m|
    #checks for !link command and skips if present
    if m.message.match(/^!link/)
    else
      links = URI.extract(m.message)
      links.each { |link|
        Link.create(
            :url => link,
            :author => m.user.nick,
            :showlink => false
          )
      log "We added #{link} from #{m.user.nick} to our URL repo at #{Time.now}."
      }
    end #end Check for !link
  end #end LinkCatching

  #capture links for Techendo via PM
  on(:message, /^!link (.+)$/) do |m, url|
    log url
    if (/^https?:\/\/([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/.match url)
      Link.create(
          :url => url,
          :author => m.user.nick,
          :showlink => true
        )
      m.reply "Logged #{url} from #{m.user.nick}. Spanx!"
    else
      m.reply "Yo link don't jive with my insides."
    end #end links if
  end #end LinkCatching

  #print the last 20 links submitted by date
  on(:message, /^!(mylinks|prismlinks)$/) do |m|
    user = User(m.user.nick)

    #messages you the past 20 links you submitted
    if m.message.match(/^!mylinks$/)
      links = Link.where(showlink: true, author: m.user.nick).last(10)
      links.each do |link|
        message = "#{link.url} : #{link.created_at} (submitted by #{link.author})"
          user.send message
        #end spam if else
      end #links printing

    #messages you the past 30 links logged and submitted
    else m.message.match(/^!prismlinks$/)
      links = Link.last(30)
      links.each do |link|
        message = "#{link.url} : #{link.created_at} (submitted by #{link.author})"
          user.send message
      end #links printing
    end #end sorting print command
  end #end printing do

  on(:message, /^!links( .+)?$/) do |m, nick_name|
    user = User(m.user.nick)

    if nick_name
      #messages you the past 10 links submitted
      nick_name = nick_name.strip
      links = Link.where(showlink: true, author: nick_name).last(10)
    else
      #messages you the past 20 links submitted. Probably is going to trigger flood protection.
      links = Link.where(showlink: true).last(20)
    end

      links.each do |link|
      message = "#{link.url} : #{link.created_at} (submitted by #{link.author})"
      user.send message
      end #links printing
  end #end showing links
end.start
