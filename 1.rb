#!/usr/bin/ruby

require 'lib.rb'

def dump_message_text(m)
	s = m['msgid'] + m['msgstr']['*'][0]
	Iconv.iconv('UCS-2', 'utf-8', s)[0]
end

a = load_messages('/home/sasha/messages/kdebase/plasma_applet_pager.po')

f_dump = File.open('../dump.dat', 'w')
f_mapping = File.open('../dump-map.txt', 'w')

pos = 0   # number of unicode chars dumped
a.each_with_index do |x,index|
	dump_text = dump_message_text(x)
	f_dump.write dump_text
	f_mapping.puts "#{pos} something.po:#{index}"
	pos += dump_text.size / 2

	if ((dump_text.size % 2) != 0)
		p dump_text.size
		p dump_text
		raise
	end
end

