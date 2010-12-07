#!/usr/bin/ruby18

# TODO: rewrite in C to improve performance
# http://www.gnu.org/software/gettext/manual/gettext.html#libgettextpo


require 'active_record'
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

ActiveRecord::Base.establish_connection(YAML::load(File.open('database.yml')))

class CreateDb < ActiveRecord::Migration
	def self.up
		create_table :po_messages do |t|
			t.string :filename
			t.integer :index

			t.string :msgid
			t.string :msgstr
		end
	end

	def self.down
		drop_table :po_messages if table_exists?(:po_messages)
	end
end

CreateDb.migrate(:down)
CreateDb.migrate(:up)

class PoMessageEntry < ActiveRecord::Base
	set_table_name "po_messages"
end

input_files.each do |i_file|
	puts "Parsing " + i_file

	a = load_messages(i_file)
	a.each_with_index do |x,index|
		# Dump message to .dat file (for isearch)
		dump_text = dump_message_text(x)
		f_dump.write dump_text
		f_mapping.puts "#{pos} #{i_file}:#{index}"
		pos += dump_text.size / 2

		if ((dump_text.size % 2) != 0)
			p dump_text.size
			p dump_text
			raise
		end

		# Dump message to database
		PoMessageEntry.create(:filename => i_file, :index => index, :msgid => x['msgid'], :msgstr => x['msgstr'])
	end
end

