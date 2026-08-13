#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Point every bare documentation URL at the right version.
#
#   update-aliases.rb <bucket> [--dry-run]
#
# Documentation is published to immutable versioned prefixes by whichever
# repository owns that library. This walks what has actually been published and
# writes the redirects:
#
#   docs/AWSCDK/index.html        -> the highest stable version
#   docs/AWSCDK/2.263/index.html  -> the highest patch in that minor
#
# Computed from the listing rather than written by a publisher, so publishing is
# order-independent: a patch to an older minor does not drag the top-level alias
# backwards, versions can be rebuilt, and nothing accumulates state that could
# drift from what is really there.
#
# Owned by this repository because these paths are shared: several libraries
# publish under docs/, and shared objects need exactly one writer.
require 'json'
require 'open3'
require 'tmpdir'
require 'tempfile'
require_relative 'aliases'
require_relative 'docs_landing'

bucket = ARGV[0] or abort 'usage: update-aliases.rb <bucket> [--dry-run]'
dry_run = ARGV.include?('--dry-run')

def s3(*args)
  out, err, status = Open3.capture3('aws', *args)
  abort "aws #{args.first} failed: #{err}" unless status.success?
  out
end

# One listing per level, delimited — so this reads a few dozen keys rather than
# enumerating every one of the ~20k files under a docs tree.
def prefixes(bucket, prefix)
  raw = s3('s3api', 'list-objects-v2', '--bucket', bucket, '--prefix', prefix,
           '--delimiter', '/', '--query', 'CommonPrefixes[].Prefix', '--output', 'json')
  (JSON.parse(raw) || []).map { |p| p.delete_prefix(prefix).chomp('/') }
end

libraries = prefixes(bucket, 'docs/')
abort 'no libraries published under docs/' if libraries.empty?

wrote = 0
newest_by_library = {}
libraries.each do |library|
  versions = prefixes(bucket, "docs/#{library}/")
  newest = DocsAliases.newest(versions)
  if newest.nil?
    # Not every prefix under docs/ is a library. YARD's shared assets (css/,
    # js/) sit alongside, and the pre-versioning layout left a flat tree of
    # module directories. A prefix with no version-shaped child is simply not
    # something to alias.
    puts "  #{library}: not a versioned library, skipping"
    next
  end

  newest_by_library[library] = newest
  targets = { '' => newest }
  DocsAliases.per_minor(versions).each { |minor, patch| targets["#{minor}/"] = patch }

  targets.each do |suffix, version|
    key = "docs/#{library}/#{suffix}index.html"
    # A minor alias sits one level deeper, so its relative target needs to climb
    # back out to the library root before descending into the version.
    relative = suffix.empty? ? version : "../#{version}"
    body = DocsAliases.redirect_to(relative)

    # Already correct? Then leave it alone. This runs on a timer, and rewriting
    # an identical object every time would re-PUT it and, worse, make every run
    # look like a change — which is what decides whether the CloudFront cache is
    # invalidated. Doing nothing has to be observable as nothing.
    published = begin
      out, _, status = Open3.capture3('aws', 's3', 'cp', "s3://#{bucket}/#{key}", '-')
      status.success? ? out : nil
    end
    if published == body
      puts "  #{key} -> #{version} (unchanged)"
      next
    end

    if dry_run
      puts "  would write #{key} -> #{version}"
    else
      Dir.mktmpdir do |dir|
        file = File.join(dir, 'index.html')
        File.write(file, body)
        s3('s3', 'cp', file, "s3://#{bucket}/#{key}",
           '--content-type', 'text/html', '--cache-control', 'max-age=60', '--no-progress')
      end
      puts "  #{key} -> #{version}"
    end
    wrote += 1
  end
end

# The page at /docs, listing what is published. Written here because this is
# where the answer already is: the same walk that decides each library's alias
# knows every library and its current version. A separate pass would be a second
# source of truth for the same question.
landing = DocsLanding.render(newest_by_library)
landing_key = 'docs/index.html'
if newest_by_library.empty?
  puts '  no versioned libraries; leaving docs/index.html alone'
elsif dry_run
  puts "  would write #{landing_key} listing #{newest_by_library.size} librar#{newest_by_library.size == 1 ? 'y' : 'ies'}"
else
  existing = begin
    out, _, status = Open3.capture3('aws', 's3', 'cp', "s3://#{bucket}/#{landing_key}", '-')
    status.success? ? out : nil
  end
  if existing == landing
    puts "  #{landing_key} (unchanged)"
  else
    Tempfile.create(['docs-landing', '.html']) do |f|
      f.write(landing)
      f.flush
      s3('s3', 'cp', f.path, "s3://#{bucket}/#{landing_key}",
         '--content-type', 'text/html', '--cache-control', 'public, max-age=300')
    end
    wrote += 1
    puts "  #{landing_key}: #{newest_by_library.keys.sort.join(', ')}"
  end
end

puts "#{dry_run ? 'would write' : 'wrote'} #{wrote} alias(es) across #{libraries.size} librar#{libraries.size == 1 ? 'y' : 'ies'}"

# Tell the caller whether anything actually changed, so it can skip a cache
# invalidation nobody needs.
if ENV['GITHUB_ENV']
  File.write(ENV['GITHUB_ENV'], "ALIASES_CHANGED=#{wrote.positive?}\n", mode: 'a')
end
