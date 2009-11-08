require 'addressable/uri'

class URIUtilities

  IMAGE_REGEX = /\bjpeg\b|\bjpg\b|\bgif\b|\bpng\b|\bapng\b|\bmng\b|\btiff\b|\bsvg\b/i
  VIDEO_REGEX = /\bavi\b|\bmpg\b|\bmpeg\b|\bm1v\b|\bmp2\b|\bmp3\b|\bmpa\b|\bmpe\b|\bmpv2\b|\basf\b|\bwma\b|\bwmv\b|\bivf\b|\brm\b|\bra\b|\bram\b|\bmov\b|\bqt\b/

  EXTENSION_REGEXS = [IMAGE_REGEX, VIDEO_REGEX]

  # This is a very simple method that ensures that the supplied uri
  # looks like a uri and converts it to an Addressable::URI.
  def self.clean(uri)
    # Make sure it's not already an Addressable::URI
    return uri if uri.is_a?(Addressable::URI) || uri.nil?

    (u = (/^http:\/\//.match(uri)) ? Addressable::URI.parse(uri) : Addressable::URI.heuristic_parse(uri)) rescue return nil
    u.path = '/' if u.path.length == 0
    return u
  end

  def self.absolute(uri, parent_uri)
    uri = Addressable::URI.parse(uri) unless uri.is_a? Addressable::URI rescue return nil
    parent_uri = Addressable::URI.parse(parent_uri) unless parent_uri.is_a? Addressable::URI

    if uri.nil? || uri.scheme == "mailto"
      return nil
    elsif !uri.absolute?
      if absolute_path?(uri.path)
        path = uri.path
      else
        # This has been coded according to the spec in http://htmlhelp.com/faq/html/basics.html
        parent_path = (/\/$/.match(parent_uri.path)) ? parent_uri.path : File.dirname(parent_uri.path)
        parent_path = File.expand_path(parent_path)

        path = File.expand_path(File.join(parent_path, uri.path))

        # Make sure that a slash is appended unless there is a . in the basename of the uri
        path = File.join(path, "/") unless File.basename(path).index(".")
      end

      cleaned_uri = parent_uri.dup
      cleaned_uri.path = path
      cleaned_uri.query = uri.query
      cleaned_uri.fragment = uri.fragment

      return cleaned_uri
    else
      return uri
    end
  end

  # I wanted to write these dynamically but I don't how to dynamically create class methods
  def self.is_an_image?(uri)
    is_a?(IMAGE_REGEX, uri)
  end

  def self.is_a_video?(uri)
    is_a?(VIDEO_REGEX, uri)
  end

  def self.absolute_path?(path)
    !Regexp.new(/^\//).match(path).nil?
  end

  private
  def self.is_a?(regex, uri)
    uri = Addressable::URI.parse(uri) unless uri.is_a? Addressable::URI
    regex.match(get_extension(uri.path)) != nil
  end

  def self.get_extension(path)
    File.extname(path).sub(/^\./, '')
  end
end

if $PROGRAM_NAME == __FILE__
  puts URIUtilities.clean("smh.com.au")
  puts URIUtilities.clean("www.smh.com.au")
  puts URIUtilities.clean("http://smh.com.au")
  puts URIUtilities.clean("smh.com.au/?poo")

  puts URIUtilities.absolute("bob", "http://smh.com.au")
  puts URIUtilities.absolute("one/two/", "http://www.foxsports.com.au/rss")
end
