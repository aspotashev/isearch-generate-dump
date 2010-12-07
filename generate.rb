#!/usr/bin/ruby18

# TODO: rewrite in C to improve performance
# http://www.gnu.org/software/gettext/manual/gettext.html#libgettextpo


require 'lib.rb'

def dump_message_text(m)
	s = m['msgid'] + m['msgstr']['*'][0]
	Iconv.iconv('UCS-2', 'utf-8', s)[0]
end

#input_files = ['/home/sasha/messages/kdebase/plasma_applet_pager.po']
input_files = `ls /home/sasha/messages/kdeutils/*.po`.split("\n")

f_dump = File.open('../dump.dat', 'w')
f_mapping = File.open('../dump-map.txt', 'w')

pos = 0   # number of unicode chars dumped

input_files.each do |i_file|
	puts "Parsing " + i_file

	a = load_messages(i_file)
	a.each_with_index do |x,index|
		dump_text = dump_message_text(x)
		f_dump.write dump_text
		f_mapping.puts "#{pos} #{i_file}:#{index}"
		pos += dump_text.size / 2

		if ((dump_text.size % 2) != 0)
			p dump_text.size
			p dump_text
			raise
		end
	end
end

