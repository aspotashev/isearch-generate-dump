
require 'yaml'
require 'iconv'

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

	def unicode_to_char(code)
		Iconv.iconv('utf-8', 'UCS-2', code[2..3].hex.chr + code[0..1].hex.chr)[0]
	end

	def parse_string(quote_char)
		forward   # skip quoting char

		res = ''
		while c != quote_char
			if c == '\\'
				forward

				if c == 'u'
					res << unicode_to_char(c(1..4))
					forward(5)
				elsif c == 'x'
					res << unicode_to_char('00' + c(1..2))
					forward(3)
				elsif c == 't'
					res << "\t"
					forward
				else
					raise "Symbol: #{c}"
				end
			else
				res += c
				forward
			end
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
		if c(0..1) == 'u"'
			forward
			return parse_string('"')
		end

		res = ''
		while true
			if c =~ /[a-zA-Z]/
				res += c
				forward
			else
				break
			end
		end

		if res == 'None'
			nil
		elsif res == 'False'
			false
		elsif res == 'True'
			true
		else
			raise "Unknown ident: [#{res}], #{c(0..10)}"
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

def load_messages(file)
	`python dump-po.py #{file}`.pyload
end

