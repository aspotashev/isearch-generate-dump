#!/usr/bin/ruby

require 'active_record'
require './lib.rb'
require './common-lib.rb'
require 'iconv'
require 'digest/sha1'

$conf = YAML::load(File.open('config.yml'))
input_files = `ls #{$conf['prefix']}/#{$conf['filemask']}`.split("\n")


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

def each_file_with_rel(input_files, &block)
	input_files.each do |i_file_full|
		i_file = i_file_full.sub($conf['prefix'], '').sub(/\/*/, '')

		block[i_file_full, i_file]
	end
end

def map_file_to_rel(input_files)
	res = []

	each_file_with_rel(input_files) do |i_file_full, i_file|
		res << i_file
	end

	res
end

#=== dump for isearch ==============================================================
class ISearchDump
	def initialize
		@pos = 0 # number of unicode chars dumped

		@f_dump = File.open($conf['dump'], 'w')
		@f_mapping = File.open($conf['dump-map'], 'w')
	end

	def dump_message_text(m)
		# TODO: dump more
		# TODO: lowercase (to make search case-insensitive)

		s = m['msgid'] + m['msgstr'][0]
		Iconv.iconv('UCS-2', 'utf-8', s)[0]
	end

	def dump_message_to_isearch(i_file, x, index)
		# Dump message to .dat file (for isearch)
		dump_text = dump_message_text(x)
		@f_dump.write dump_text
		@f_mapping.puts "#{@pos} #{i_file}:#{index}"
		@pos += dump_text.size / 2

		if ((dump_text.size % 2) != 0)
			p dump_text.size
			p dump_text
			raise
		end
	end
end

dumper = ISearchDump.new
`rm -f #{$conf['dump-index']}` # remove old index, need to regenerate it

puts "Generating dump for isearch..."
each_file_with_rel(input_files) do |i_file_full, i_file|
	load_messages_valid(i_file_full).each do |x|
		dumper.dump_message_to_isearch(i_file, x, x['index'])
	end
end

#=== update database of strings ====================================================
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

		create_table :po_files do |t|
			t.string :filename
			t.string :sha1
		end

		add_index :po_messages, [:filename, :index]
	end

	def self.down
		drop_table :po_messages if table_exists?(:po_messages)
		drop_table :po_files if table_exists?(:po_files)
	end
end

class PoMessageEntry < ActiveRecord::Base
	set_table_name "po_messages"
end

class PoFile < ActiveRecord::Base
end

if not PoMessageEntry.table_exists? or not PoFile.table_exists?
	CreateDb.migrate(:down)
	CreateDb.migrate(:up)
end

def remove_file_from_database(i_file)
	PoMessageEntry.delete_all(["filename = ?", i_file])
	PoFile.delete_all(["filename = ?", i_file])
end

def insert_messages_into_database(i_file_full, i_file)
	load_messages_valid(i_file_full).each do |x|
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


# files removed from disk, but still existing in the database
puts "Removing obsolete files from database..."
(PoFile.find(:all).map(&:filename) - map_file_to_rel(input_files)).each do |i_file|
	remove_file_from_database(i_file)
end

puts "Updating database..."
each_file_with_rel(input_files) do |i_file_full, i_file|
	existing_sha1 = PoFile.find_by_filename(i_file)
	existing_sha1 = existing_sha1.sha1 if existing_sha1

	new_sha1 = calc_sha1(i_file_full)


	if existing_sha1 == new_sha1
		puts "File did not change: " + i_file_full
	else
		puts "Parsing " + i_file_full

		remove_file_from_database(i_file)
		insert_messages_into_database(i_file_full, i_file)
		PoFile.create({:filename => i_file, :sha1 => new_sha1})
	end
end

