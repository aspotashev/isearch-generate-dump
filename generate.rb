#!/usr/bin/ruby

require 'active_record'
require './lib.rb'
require 'iconv'

def dump_message_text(m)
# TODO: dump more

	s = m['msgid'] + m['msgstr'][0]
	Iconv.iconv('UCS-2', 'utf-8', s)[0]
end

$conf = YAML::load(File.open('config.yml'))
input_files = `ls #{$conf['prefix']}/#{$conf['filemask']}`.split("\n")

$f_dump = File.open('../dump.dat', 'w')
$f_mapping = File.open('../dump-map.txt', 'w')

`rm ../dump-index.dat` # remove old index, need to regenerate it

$pos = 0   # number of unicode chars dumped

ActiveRecord::Base.establish_connection(YAML::load(File.open('database.yml')))

class CreateDb < ActiveRecord::Migration
	def self.up
		create_table :po_messages do |t|
			t.string :filename
			t.integer :index

			t.text :msgid
			t.text :msgstr0
			t.text :msgstr1
			t.text :msgstr2
			t.text :msgstr3
		end

		add_index :po_messages, [:filename, :index]
	end

	def self.down
		drop_table :po_messages if table_exists?(:po_messages)
	end
end

CreateDb.migrate(:down)
CreateDb.migrate(:up)

def dump_message_to_isearch(i_file, x, index)
	# Dump message to .dat file (for isearch)
	dump_text = dump_message_text(x)
	$f_dump.write dump_text
	$f_mapping.puts "#{$pos} #{i_file}:#{index}"
	$pos += dump_text.size / 2

	if ((dump_text.size % 2) != 0)
		p dump_text.size
		p dump_text
		raise
	end
end

def load_messages_valid(i_file_full)
	a = load_messages(i_file_full)

	# Completely ignore obsolete and fuzzy messages
	a = a.select {|x| x['obsolete'] != true && x['fuzzy'] != true && x['msgid'] != '' }

	a.each do |x|
		if not [1, 4].include?(x['msgstr'].size) # number of plural forms
			#raise

			puts "Warning: wrong number of plural forms"
		end
	end

	a
end

class PoMessageEntry < ActiveRecord::Base
	set_table_name "po_messages"
end

input_files.each do |i_file_full|
	i_file = i_file_full.sub($conf['prefix'], '').sub(/\/*/, '')

	puts "Parsing " + i_file_full

	load_messages_valid(i_file_full).each do |x|
		dump_message_to_isearch(i_file, x, x['index'])

		# Dump message to database
		PoMessageEntry.create(
			:filename => i_file,
			:index => x['index'],

			:msgid => x['msgid'],
			:msgstr0 => x['msgstr'][0],
			:msgstr1 => x['msgstr'][1],
			:msgstr2 => x['msgstr'][2],
			:msgstr3 => x['msgstr'][3])
	end
end

