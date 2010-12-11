require './ruby-ext/poreader'

def load_messages(filename)
	PoReader.read_po_file(filename)
end

