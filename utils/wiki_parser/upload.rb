################################################################
# This script was written to help parse an archive of wikipedia
# and store the articles in a distributed hash table.  It might
# be useful if you want to do the same.  You need to provide
# your own xml file.  Also wiki_document might need to be edited.
#################################################################


#!/usr/bin/ruby

require_relative 'wiki_document'

parser = Nokogiri::XML::SAX::Parser.new WikiDocument.new
parser.parse File.open "enwiki-20140707-pages-articles.xml"
