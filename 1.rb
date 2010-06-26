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
		res << parse while not pnil?(res.last)
		res.pop
		res

		raise if c != ']'
		forward
	end

	def parse_hash
		forward   # skip '{'

		res = {}
		while true
			res_key = parse

			break if pnil?(res_key)

			raise "heh #{c(0..1)}" if c(0..1) != ': '
			forward(2)

			res_value = parse

			raise if pnil?(res_value)

			raise if res.has_key?(res_key)
			res[res_key] = res_value
		end

		res
	end

	def parse_string(quote_char)
		forward   # skip quoting char

		res = ''
		while c != quote_char
			if c == '\\'
				raise
			else
				res += c
			end

			forward
		end

		forward
		res
	end

	def parse
		if c == '['
			parse_array
		elsif c == '{'
			parse_hash
		elsif c == '\''
			parse_string(c)
		else
			raise "Unexpected char: '#{c}'"
		end
	end
end

dump = `python dump-po.py /home/sasha/messages/kdebase/plasma_runner_recentdocuments.po`
print dump
#p YAML::load(dump)

dump.pyload

