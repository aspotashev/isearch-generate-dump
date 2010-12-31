#!/usr/bin/ruby

require 'active_record'
require './lib.rb'
require 'iconv'
require 'digest/sha1'


def load_messages_valid(i_file_full)
	a = load_messages(i_file_full)

	# Completely ignore obsolete and fuzzy messages
	a = a.select {|x| x['obsolete'] != true && x['fuzzy'] != true && x['msgid'] != '' }

	a.each do |x|
		if not [1, 4].include?(x['msgstr'].size) # number of plural forms
			puts "Warning: wrong number of plural forms:"
			print '    '
			p i_file_full
			print '    '
			p x
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

	def calc_sha1
		hashfunc = Digest::SHA1.new
		hashfunc.update(File.open(@file_full).read)
		hashfunc.hexdigest
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
	f.data.each do |x|
		dumper.dump_message_to_isearch(f.file, x, x['index'])
	end
end

#=== update database of strings ====================================================

if $conf['fill-db']
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

	def remove_file_from_database(i_file)
		PoMessageEntry.delete_all(["filename = ?", i_file])
		PoFile.delete_all(["filename = ?", i_file])
	end

	def insert_messages_into_database(f)
		f.data.each do |x|
			PoMessageEntry.create(
				:filename => f.file,
				:index => x['index'],

				:msgid => x['msgid'],
				:msgstr0 => x['msgstr'][0],
				:msgstr1 => x['msgstr'][1],
				:msgstr2 => x['msgstr'][2],
				:msgstr3 => x['msgstr'][3])
		end
	end


	if not PoMessageEntry.table_exists? or not PoFile.table_exists?
		CreateDb.migrate(:down)
		CreateDb.migrate(:up)
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

		new_sha1 = f.calc_sha1


		if existing_sha1 == new_sha1
			puts "File did not change: " + f.file_full
		else
			puts "Parsing " + f.file_full

			remove_file_from_database(f.file)
			insert_messages_into_database(f)
			PoFile.create({:filename => f.file, :sha1 => new_sha1})
		end
	end
else
	puts "Direct database update is disabled"
end

#=== create database sql dump ====================================================

class SqlDumpFile < File
	def comment(s)
		puts '--'
		puts '-- ' + s
		puts '--'
	end

	def create_table(name, fields)
		comment "Name: #{name}; Type: TABLE; Schema: public; Owner: kde-ru; Tablespace: "
		puts
		puts "CREATE TABLE #{name} ("
		fields.each_with_index do |s,index|
			puts "    " + s + (index == fields.size-1 ? '' : ',')
		end

		puts ');'
		puts
		puts
		puts "ALTER TABLE public.#{name} OWNER TO \"kde-ru\";"
	end

	def create_table_id_seq(name, id_seq)
		comment "Name: #{name}_id_seq; Type: SEQUENCE; Schema: public; Owner: kde-ru"
		puts
		puts "\
CREATE SEQUENCE #{name}_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;"
		puts
		puts
		puts "ALTER TABLE public.#{name}_id_seq OWNER TO \"kde-ru\";"
		puts
		comment "Name: #{name}_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: kde-ru"
		puts
		puts "ALTER SEQUENCE #{name}_id_seq OWNED BY #{name}.id;"
		puts
		puts
		comment "Name: #{name}_id_seq; Type: SEQUENCE SET; Schema: public; Owner: kde-ru"
		puts
		puts "SELECT pg_catalog.setval('#{name}_id_seq', #{id_seq}, true);"
		puts
		puts
	end

	def create_table_id_seq_conn(name)
		comment "Name: id; Type: DEFAULT; Schema: public; Owner: kde-ru"
		puts
		puts "ALTER TABLE #{name} ALTER COLUMN id SET DEFAULT nextval('#{name}_id_seq'::regclass);"
		puts
		puts
	end

	def create_table_pkey(name)
		comment "Name: #{name}_pkey; Type: CONSTRAINT; Schema: public; Owner: kde-ru; Tablespace: "
		puts
		puts "ALTER TABLE ONLY #{name}"
		puts "    ADD CONSTRAINT #{name}_pkey PRIMARY KEY (id);"
		puts
		puts
	end

	def esc_field(x)
		if x.nil?
			"\\N"
		elsif x.is_a?(Fixnum)
			x.to_s
		elsif x.is_a?(String)
			x.
				gsub("\\", "\\\\\\").
				gsub("\n", "\\n").
				gsub("\t", "\\t")
		else
			p x
			raise
		end
	end

	def print_row(a)
		puts a.map {|x| esc_field(x) }.join("\t")
	end
end

puts "Generating SQL dump for PostgreSQL..."
f = SqlDumpFile.open($conf['sql-dump-path'], 'w')
# intro
f.comment 'PostgreSQL database dump'
f.puts
f.puts "\
SET statement_timeout = 0;
SET client_encoding = 'SQL_ASCII';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;"
f.puts
f.comment 'Name: plpgsql; Type: PROCEDURAL LANGUAGE; Schema: -; Owner: postgres'
f.puts
f.puts 'CREATE OR REPLACE PROCEDURAL LANGUAGE plpgsql;'
f.puts
f.puts
f.puts 'ALTER PROCEDURAL LANGUAGE plpgsql OWNER TO postgres;'
f.puts
f.puts 'SET search_path = public, pg_catalog;'
f.puts
f.puts "SET default_tablespace = '';"
f.puts
f.puts 'SET default_with_oids = false;'
f.puts

# create table
f.create_table('po_files', ['id integer NOT NULL', 'filename character varying(255)', 'sha1 character varying(255)'])
f.puts

# id seq
f.create_table_id_seq('po_files', 10000000) # we won't add new rows to database anyway

# create table
f.create_table('po_messages', [
	'id integer NOT NULL',
	'filename character varying(255)',
	'index integer',
	'msgid text',
	'msgstr0 text',
	'msgstr1 text',
	'msgstr2 text',
	'msgstr3 text'])
f.puts

# id seq
f.create_table_id_seq('po_messages', 10000000) # we won't add new rows to database anyway

# connect id seq
f.create_table_id_seq_conn('po_files')
f.create_table_id_seq_conn('po_messages')

# data for po_files
f.comment "Data for Name: po_files; Type: TABLE DATA; Schema: public; Owner: kde-ru"
f.puts
f.puts "COPY po_files (id, filename, sha1) FROM stdin;"
input_files.each_with_index do |file, index|
	f.print_row [index+1, file.file, file.calc_sha1]
end
f.puts "\\."
f.puts
f.puts

# data for po_messages
f.comment "Data for Name: po_messages; Type: TABLE DATA; Schema: public; Owner: kde-ru"
f.puts
f.puts "COPY po_messages (id, filename, index, msgid, msgstr0, msgstr1, msgstr2, msgstr3) FROM stdin;"

index = 1
input_files.each do |file|
	file.data.each do |x|
		f.print_row [index, file.file, x['index'], x['msgid'], x['msgstr'][0], x['msgstr'][1], x['msgstr'][2], x['msgstr'][3]]
		index += 1
	end
end
f.puts "\\."
f.puts
f.puts

# primary keys
f.create_table_pkey('po_files')
f.create_table_pkey('po_messages')

# index
f.comment "Name: index_po_messages_on_filename_and_index; Type: INDEX; Schema: public; Owner: kde-ru; Tablespace: "
f.puts
f.puts "CREATE INDEX index_po_messages_on_filename_and_index ON po_messages USING btree (filename, index);"
f.puts
f.puts

# permissions
f.comment "Name: public; Type: ACL; Schema: -; Owner: postgres"
f.puts
f.puts "REVOKE ALL ON SCHEMA public FROM PUBLIC;"
f.puts "REVOKE ALL ON SCHEMA public FROM postgres;"
f.puts "GRANT ALL ON SCHEMA public TO postgres;"
f.puts "GRANT ALL ON SCHEMA public TO PUBLIC;"
f.puts
f.puts

f.comment "PostgreSQL database dump complete"
f.puts

