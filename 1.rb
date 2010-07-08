#!/usr/bin/ruby

require 'lib.rb'

def dump_message_text(m)
	m['msgid'] + m['msgstr']['*'][0]
end

a = load_messages('/home/sasha/messages/kdebase/plasma_applet_pager.po')
puts a.map {|x| dump_message_text(x) }.join

