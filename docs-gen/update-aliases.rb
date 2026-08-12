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
require_relative 'aliases'

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

  targets = { '' => newest }
  DocsAliases.per_minor(versions).each { |minor, patch| targets["#{minor}/"] = patch }

  targets.each do |suffix, version|
    key = "docs/#{library}/#{suffix}index.html"
    # A minor alias sits one level deeper, so its relative target needs to climb
    # back out to the library root before descending into the version.
    relative = suffix.empty? ? version : "../#{version}"
    body = DocsAliases.redirect_to(relative)
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

puts "#{dry_run ? 'would write' : 'wrote'} #{wrote} alias(es) across #{libraries.size} librar#{libraries.size == 1 ? 'y' : 'ies'}"
