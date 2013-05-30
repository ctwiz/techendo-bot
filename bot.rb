#!/usr/bin/env ruby
require 'cinch'
require 'active_record'
require './topic'

db = URI.parse(ENV['DATABASE_URL'] || 'postgres://localhost/mydb')

ActiveRecord::Base.establish_connection(
  :adapter  => db.scheme == 'postgres' ? 'postgresql' : db.scheme,
  :host     => db.host,
  :port     => db.port,
  :username => db.user,
  :password => db.password,
  :database => db.path[1..-1],
  :encoding => 'utf8'
)

puts "creating topics table"

begin
  ActiveRecord::Schema.define do
    create_table :topics do |table|
      table.column :id, :integer
      table.column :created_at, :datetime, :null => false, :default => Time.now
      table.column :author, :string
      table.column :description, :string
    end
  end
rescue Exception
  puts "No worries. Database already created."
end

Cinch::Bot.new do
  configure do |c|
    c.server = 'irc.freenode.org'
    c.channels = ['#techendo']
    c.nick = 'techendo-pal'
  end

  on(:join) do |m|
    m.reply "Hi, everyone. How's it going?"
  end

  on(:message, 'you there, techendo-pal?') do |m|
    m.reply "Yes. I believe so, #{m.user.name}. I visualize a time when we will be to robots what dogs are to humans, and I'm rooting for the machines."
  end

  on(:message, /^!topic (.+*)$/) do |m, message|
    unless Topic.create(:description => message, :author => m.user.nick)
      m.reply "Sorry, that didn't work. There must be something wrong with me today."
    else 
      m.reply "Recorded topic: #{message}, by author: #{m.user.nick} at #{Time.now}"
    end
  end

  on(:message, '!topics') do |m|
    topics = Topic.find(:all)
    topics.each do |t|
      m.reply "#{t.id} : #{t.description} (submitted by #{t.author})"
    end
  end

  on(:message, /^!delete ([\d])$/) do |m, id|
    topic = Topic.find(id)
    if topic.author == m.user.nick || m.user.nick == "dpg"
      Topic.destroy(id)
      m.reply "Successfully destroyed #{topic.id}, by #{topic.author}"
    end
  end



end.start
