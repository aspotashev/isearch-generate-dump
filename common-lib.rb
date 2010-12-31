
# TODO: move to class PoFileContent
def calc_sha1(i_file_full)
	hashfunc = Digest::SHA1.new
	hashfunc.update(File.open(i_file_full).read)
	hashfunc.hexdigest
end


