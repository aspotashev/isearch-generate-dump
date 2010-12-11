#!/usr/bin/ruby

require './poreader'

String.class_eval do
	def inspect
		"\"" + self + "\""
	end
end

p PoReader.read_po_file('/home/sasha/messages/kdepim/akonadi_maildispatcher_agent.po')[1..2]


__END__
"msgid"=>"Sending messages (1 item in queue)...",
"msgid_plural"=>"Sending messages (%1 items in queue)...",

"msgid_previous"=>nil,
"msgid_plural_previous"=>nil,

"msgstr"=>["Отправка писем (%1 элемент в очереди)...", "Отправка писем (%1 элемента в очереди)...", "Отправка писем (%1 элементов в очереди)...", "Отправка писем (%1 элемент в очереди)..."]
"obsolete"=>false,

// ============ Left to do: ==============
"manual_comment"=>[],
"msgctxt_previous"=>nil,
"msgctxt"=>nil,
"refentry"=>1,
"refline"=>28,
"auto_comment"=>[],
"flag"=>["kde-format"],
"source"=>[{"second"=>140, "first"=>"maildispatcheragent.cpp"}, {"second"=>308, "first"=>"maildispatcheragent.cpp"}]

