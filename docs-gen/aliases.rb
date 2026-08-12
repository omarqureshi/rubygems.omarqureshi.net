# frozen_string_literal: true

require 'cgi'

# Which version a bare documentation URL points at.
#
# Documentation is published to immutable versioned prefixes —
# `/docs/AWSCDK/2.263.0/` — and `/docs/AWSCDK/` is a redirect to one of them.
#
# The redirect cannot be written by a publisher from its own version. Publishing
# a patch to an older minor must not drag the alias backwards, and a publish job
# only knows about itself. So the alias is *computed* from the versions that
# exist, which makes publishing order-independent: releases can land in any
# order, an old version can be rebuilt, and the aliases still come out right
# because nothing accumulates state.
module DocsAliases
  module_function

  # The version a bare URL should redirect to: the highest stable one, or the
  # highest prerelease if stable versions do not exist yet.
  #
  # @param versions [Array<String>] version directory names, as listed.
  # @return [String, nil] the chosen version, or nil when there are none.
  def newest(versions)
    parsed = parse(versions)
    return nil if parsed.empty?

    stable = parsed.reject { |v| v.prerelease? }
    (stable.empty? ? parsed : stable).max.to_s
  end

  # The highest patch in each minor line: {"2.263" => "2.263.1", ...}.
  #
  # Lets a reader pin documentation to the minor they depend on without naming
  # a patch. Prereleases are excluded for the same reason as above.
  #
  # @param versions [Array<String>]
  # @return [Hash{String=>String}]
  def per_minor(versions)
    parse(versions).reject(&:prerelease?).group_by { |v| v.segments[0, 2].join('.') }
                   .transform_values { |vs| vs.max.to_s }
  end

  # The redirect page for an alias.
  #
  # A meta refresh rather than an S3 redirect object, so the alias survives
  # being copied, mirrored or served from a plain static host. The canonical
  # link keeps the alias from competing with the versioned page it points at.
  #
  # @param version [String] the version to point at.
  # @return [String] a complete HTML document.
  def redirect_to(version)
    target = CGI.escapeHTML("#{version}/index.html")
    <<~HTML
      <!doctype html>
      <html lang="en"><head><meta charset="utf-8">
      <meta http-equiv="refresh" content="0; url=#{target}">
      <link rel="canonical" href="#{target}">
      <title>#{CGI.escapeHTML(version)}</title></head>
      <body><a href="#{target}">#{CGI.escapeHTML(version)}</a></body></html>
    HTML
  end

  # Version strings that are actually versions.
  #
  # The input is an S3 listing, so it contains whatever is under the prefix —
  # a stray `latest/` directory, a half-finished upload. Anything Gem::Version
  # will not accept is not a version and is ignored rather than crashing the
  # alias update for every library.
  def parse(versions)
    versions.filter_map do |v|
      Gem::Version.new(v.to_s.chomp('/'))
    rescue ArgumentError
      nil
    end
  end
  private_class_method :parse
end
