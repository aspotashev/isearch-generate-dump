
# /* http://www.rubyinside.com/how-to-create-a-ruby-extension-in-c-in-under-5-minutes-100.html */
require 'mkmf'
extension_name = 'poreader'
dir_config(extension_name)
$libs = append_library($libs, "gettextpo")
create_makefile(extension_name)
