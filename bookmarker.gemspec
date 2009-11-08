spec = Gem::Specification.new do |s|
  s.name = 'bookmarker'
  s.version = '0.1'
  s.date = '2009-11-09'
  s.summary = 'Simple bookmark with full text index'
  s.email = "filterfish@roughage.com.au"
  s.homepage = "http://github.com/filterfish/bookmarker/"
  s.description = "Bookmarker that uses the xapian full text index and can be used offline"
  s.has_rdoc = false

  s.authors = ["Richard Heycock"]
  s.add_dependency "extlib"
  s.add_dependency "nokogiri"
  s.add_dependency "couchrest"
  s.add_dependency "addressable"

  s.executables = Dir::glob("bin/*").map{|exe| File::basename exe}

  s.files = Dir.glob("{bin/*,lib/**/*}")
end
