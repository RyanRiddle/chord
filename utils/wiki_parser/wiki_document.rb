#######################################################################
# This class was written to help parse an archive of wikipedia.
# It connects to the node at localhost:50000 and starts making requests
# to store articles.  You should edit the connection parameters etc to
# suit your needs.
#######################################################################

require 'chord'
require 'nokogiri'

NONE = 0
TITLE = 1
TEXT = 2

# Articles I wanted to make sure made it into the DHT.
# If you do not want to limit the articles that are stored
# make changes to end_element.
ARTICLES = [
	"AWK",
	"Apple II",
	"C language",
	"Church-Turing thesis",
	"Raphael Finkel",
	"Chord (peer-to-peer)",
	"Distributed hash table",
	"Computer science",
	"University of Kentucky"
]

class WikiDocument < Nokogiri::XML::SAX::Document
	def initialize
		@title = ""
		@text = ""
		@n_articles = 0
		@parent = ""
		@dht = NodeReference.new 'localhost', 50000
	end

	def write title, text
		filename = "#{sha1 title}_#{title}"
		filename.sub! "/", ""
		begin
			File.open("/home/ryan/research/data/#{filename}", File::CREAT|File::TRUNC|File::WRONLY) do |f|
				f.write text
			end
		rescue Errno::ENOENT
		rescue Errno::EISDIR
		rescue Exception
			puts "could not write #{filename}"
		end
	end

	def start_element name, attrs = []
		if name == "page"
			@n_articles += 1
		elsif name == "title"
			@parent = TITLE
		elsif name == "text"
			@parent = TEXT
		end
	end

	def end_element name
		if name == "page"
			if ARTICLES.include? @title
				puts "storing #{@title}"
				@dht.store @title, @text
			end
=begin
			if @n_articles > 1000
				exit
			end
=end
			#write @title, @text
			@title = ""
			@text = ""
			if @n_articles % 100000 == 0
				puts "#{@n_articles} processed"
			end
		elsif name == "title"
			@parent = NONE
		elsif name == "text"
			@parent = NONE
		end
	end

	def characters string
		if @parent == TITLE
			@title += string
		elsif @parent == TEXT
			@text += string
		end	
	end

	def end_document
		puts "Parsed #{@n_articles} articles!!!"
	end
end
