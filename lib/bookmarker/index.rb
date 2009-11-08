require 'xapian'

class Index
  def initialize(path)

    @path = path
    @prefixes = {'title' => "S", 'url' => "T"}
  end

  def open_for_writing
    FileUtils.mkdir_p(File.dirname(@path)) unless File.exists?(File.dirname(@path))

    @database = Xapian::WritableDatabase.new(@path, Xapian::DB_CREATE_OR_OPEN)
    @indexer = Xapian::TermGenerator.new()
    @indexer.set_flags(Xapian::TermGenerator::FLAG_SPELLING, 0)
    @indexer.database = @database
  end

  def open_for_reading
    @database = Xapian::Database.new(@path)
    @enquire = Xapian::Enquire.new(@database)

    @query_parser = Xapian::QueryParser.new
    @query_parser.database = @database
    @query_parser.add_boolean_prefix('title', @prefixes['title'])
    @query_parser.add_boolean_prefix('url', @prefixes['url'])
  end

  def add(document)
    doc = Xapian::Document.new()

    doc.data = JSON(document)
    @indexer.document = doc
    @indexer.index_text(document[:url], 10, @prefixes['url'])
    @indexer.index_text(document[:body])
    @indexer.index_text(document[:title], 10, @prefixes['title'])
    @database.add_document(doc)
  end

  def run_query(query, number_of_results=100)
    query = @query_parser.parse_query(query,
                        Xapian::QueryParser::FLAG_BOOLEAN | Xapian::QueryParser::FLAG_PHRASE |
                        Xapian::QueryParser::FLAG_LOVEHATE | Xapian::QueryParser::FLAG_WILDCARD)

    @enquire.query = query
    @enquire.sort_by_relevance!
    @matchset = @enquire.mset(0, number_of_results)
    @matchset
  end

  def results(threshold=0.0)
    @matchset.matches.each do |m|
      # break if m.percent < max_score * threshold
      yield m
    end
  end
end

