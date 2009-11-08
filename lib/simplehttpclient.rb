#!/usr/bin/env ruby

require 'zlib'
require 'stringio'
require 'net/http'

require File.dirname(__FILE__) + '/uri_utilities'

class SimpleHttpClient 

  def initialize(user_agent='', timeout=nil)
    @user_agent = user_agent
    @timeout = timeout
  end

  def get(uri, headers={}, limit=5)
    raise RuntimeError, 'HTTP redirect too deep' if limit == 0

    u = URIUtilities.clean(uri)
    return if u.nil?

    req = (u.query.nil?) ? u.path : "#{u.path}?#{u.query}"

    http = Net::HTTP.new(u.host, u.port)
    request = Net::HTTP::Get.new(req)

    # Set timeouts if needed.
    if @timeout
      http.open_timeout = @timeout
      http.read_timeout = @timeout
    end

    request = set_headers(request, headers)
    response = http.request(request)

    case response
    when Net::HTTPSuccess
      response['location'] = u.to_s
      uncompress_content(response)
    when Net::HTTPNotModified
      response['location'] = u.to_s
      uncompress_content(response)
    when Net::HTTPRedirection
      get(URIUtilities.absolute(response['location'], u), {}, limit -1)
    else
      response
    end
  end

  def head(uri, headers={})
    u = URIUtilities.clean(uri)
    return if u.nil?

    req = (u.query.nil?) ? u.path : "#{u.path}?#{u.query}"

    http = Net::HTTP.new(u.host, u.port)
    request = Net::HTTP::Head.new(req)

    # Set timeouts if needed.
    if @timeout
      http.open_timeout = @timeout
      http.read_timeout = @timeout
    end

    request = set_headers(request, headers)
    response = http.request(request)
    response['location'] = u.to_s
    response
  end

  private

  # Check to make sure that any compression is dealt with.
  def uncompress_content(response)

    body = StringIO.new
    body.write(response.body)
    body.rewind

    if response['content-encoding']
      case response['content-encoding'].downcase
      when 'gzip'
        begin
          new_body = Zlib::GzipReader.new(body).read
          response.delete("content-encoding")
        rescue Zlib::GzipFile::Error
          # If there is an error assume the content-encoding is wrong and return as is.
          body.rewind
          new_body = body.read
        end
      when 'deflate'
        begin
          new_body = Zlib::Inflate.inflate(body.read)
        rescue Zlib::DataError
          # no luck with Zlib decompression. Let's try with
          # raw deflate, like some broken browsers do.
          # See http://www.ruby-forum.com/topic/136825
          body.rewind
          new_body = Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(body.read);
        end
        response.delete("content-encoding")
      when "identity"
        new_body = body.read
      end
    else
      new_body = body.read
    end
    return response, new_body
  end

  # Sets up the various headers. By default it sets up compression,
  # language, charset, user-agent and does the right things with
  # Last-Modified and Etag. Any supplied headers will be applied as is
  def set_headers(request,headers)

    # Downcase all headers. This means that the user of this class can
    # give headers in either case without it causing a problem.
    headers = headers.inject({}) { |h, v| h[v.first.downcase] = v.last; h }

    request.add_field('accept-encoding', 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3')
    request.add_field('accept-language', 'en-us,en;q=0.5')
    request.add_field('accept-charset', 'ISO-8859-1,utf-8;q=0.7,*;q=0.7')

    request.add_field('user-agent', @user_agent) if @user_agent

    last_modified = headers.delete('last-modified')
    etag = headers.delete('etag')

    request.add_field('if-modified-since', last_modified) if last_modified
    request.add_field('etag', etag) if etag

    # Add any remaining headers
    headers.each_pair { |k,v| request.add_field(k, v) }

    return request
  end
end

if $PROGRAM_NAME == __FILE__

  require 'pp'

  uri = ARGV[0]
  if uri.nil?
    puts "usage: #{$0}: <uri>"
    exit(1)
  end

  User_agent = "Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.6) Gecko/20070725 Firefox/2.0.0.6"

  agent = SimpleHttpClient.new(User_agent, 20.0)

  headers = agent.head(uri)
  pp headers
  pp headers['content-type']
  pp headers.to_hash

  headers = { "Last-Modified" => "Thu, 07 Feb 2008 03:29:21 GMT", "etag" => "d78447-31f40-14582640" }
  response, response_body = agent.get(uri, headers)

  pp response.to_hash
  pp response.class
  File.open("body", "w") do |f|
    f.puts response_body
  end
end
