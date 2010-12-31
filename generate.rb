#!/usr/bin/ruby

require 'active_record'
require './lib.rb'
require './common-lib.rb'
require 'iconv'
require 'digest/sha1'


def load_messages_valid(i_file_full)
	a = load_messages(i_file_full)

	# Completely ignore obsolete and fuzzy messages
	a = a.select {|x| x['obsolete'] != true && x['fuzzy'] != true && x['msgid'] != '' }

	a.each do |x|
		if not [1, 4].include?(x['msgstr'].size) # number of plural forms
			puts "Warning: wrong number of plural forms"
			#raise
		end
	end

	a
end

class PoFileContent
	attr_accessor :file, :file_full

	def initialize(full)
		@file_full = full
		@file = @file_full.sub($conf['prefix'], '').sub(/\/*/, '')
	end

	def data
		load_messages_valid(file_full)
	end
end

#=== init ==========================================================================
$conf = YAML::load(File.open('config.yml'))
input_files = `ls #{$conf['prefix']}/#{$conf['filemask']}`.split("\n").
	map {|full| PoFileContent.new(full) }

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
input_files.each do |f|
	load_messages_valid(f.file_full).each do |x|
		dumper.dump_message_to_isearch(f.file, x, x['index'])
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
(PoFile.find(:all).map(&:filename) - input_files.map(&:file)).each do |i_file|
	remove_file_from_database(i_file)
end

puts "Updating database..."
input_files.each do |f|
	existing_sha1 = PoFile.find_by_filename(f.file)
	existing_sha1 = existing_sha1.sha1 if existing_sha1

	new_sha1 = calc_sha1(f.file_full)


	if existing_sha1 == new_sha1
		puts "File did not change: " + f.file_full
	else
		puts "Parsing " + f.file_full

		remove_file_from_database(f.file)
		insert_messages_into_database(f.file_full, f.file)
		PoFile.create({:filename => f.file, :sha1 => new_sha1})
	end
end

#=== create database sql dump ====================================================


