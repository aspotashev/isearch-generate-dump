#!/usr/bin/ruby

require 'lib.rb'

def dump_message_text(m)
	s = m['msgid'] + m['msgstr']['*'][0]
	Iconv.iconv('UCS-2', 'utf-8', s)
end

a = load_messages('/home/sasha/messages/kdebase/plasma_applet_pager.po')

f_dump = File.open('../dump.dat', 'w')
f_dump.write a.map {|x| dump_message_text(x) }.join

