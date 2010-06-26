#!/usr/bin/ruby

require 'yaml'

String.class_eval do
	def pyload
		StringPyParser.new(self).parse
	end
end

class StringPyParser
	class StringPyParser::Nil ; end

	def initialize(s)
		@s = s
		@i = 0
	end

	def pnil?(x) # parser nil
		x.is_a?(StringPyParser::Nil)
	end

	def c(x = nil)
		if x.nil?
			@s[@i..@i]
		elsif x.is_a?(Range)
			@s[(@i + x.first)..(@i + x.last)]
		elsif x.is_a?(Integer)
			@s[(@i + x)..(@i + x)]
		else
			raise
		end
	end


	def forward(d = 1)
		@i += d
	end

	def parse_array
		forward   # skip '['

		res = []
		while true
			if c(0..1) == ', '
				forward(2)
			elsif c == ']'
				break
			end

			res_new = parse
			res << res_new

			p res
		end

		raise if c != ']'
		forward   # skip ']'
		res
	end

	def parse_hash
		forward   # skip '{'

		res = {}
		while true
			res_key = parse

			raise "heh #{c(0..1)}, #{@i}" if c(0..1) != ': '
			forward(2)

			res_value = parse

			raise if res.has_key?(res_key)
			res[res_key] = res_value

			if c(0..1) == ', '
				forward(2)
			elsif c == '}'
				break
			end
		end

		raise if c != '}'
		forward   # skip '}'
		res
	end

	def parse_string(quote_char)
		forward   # skip quoting char

		res = ''
		while c != quote_char
			if c == '\\'
				forward

				if c == 'u'
					code = c(1..5)
					forward(5)

					res << "<<<hehe, #{code}>>>"
				else
					raise
				end
			else
				res += c
			end

			forward
		end

		forward
		res
	end

	def parse_number
		res = ''
		while true
			if c =~ /[0-9\.]/
				res += c
				forward
			else
				raise if res.match(/\./)
				return res.to_i
			end
		end
	end

	def parse_ident
		if c(0..1) == 'u\''
			forward
			return parse_string('\'')
		end

		res = ''
		while true
			if c =~ /[a-zA-Z]/
				res += c
				forward
			else
				return res
			end
		end
	end

	def parse
		if c == '['
			parse_array
		elsif c == '{'
			parse_hash
		elsif c == '\''
			parse_string(c)
		elsif c =~ /[0-9]/
			parse_number
		elsif c == '}' or c == ']'
			StringPyParser::Nil.new
		elsif c =~ /[a-zA-Z]/
			parse_ident
		else
			raise "Unexpected char: '#{c}', pos #{@i}"
		end
	end
end

dump = `python dump-po.py /home/sasha/messages/kdebase/plasma_runner_recentdocuments.po`
print dump
#p YAML::load(dump)

dump.pyload

