#!/usr/bin/env ruby
# frozen_string_literal: true

# Link a built documentation tree to the trees it references.
#
#   crosslink-tree.rb <tree> <bucket> CDK8s=2.70.91 Constructs=10.8.1
#
# YARD links a type only if it was in the registry when the page rendered, and
# each library renders alone — so a cdk8s-plus page names CDK8s::APIObjectMetadata
# twenty times and links it never.
#
# The set of linkable types is read from what is *published*, by listing the
# target prefix, rather than derived from an assembly. Two reasons: the
# dependency's assembly carries no type list (only a version range), and the
# page names are Ruby names the generator chose, so anything derived here would
# be a second opinion about naming. Listing the pages that exist cannot produce
# a link to a page that does not.

require 'open3'
require_relative 'crosslink'

tree, bucket, *pairs = ARGV
abort('usage: crosslink-tree.rb <tree> <bucket> Module=version...') if tree.nil? || bucket.nil?
abort("no such tree: #{tree}") unless File.directory?(tree)

targets = {}
pairs.each do |pair|
  mod, version = pair.split('=', 2)
  if version.to_s.empty?
    warn "  #{mod}: no version given, skipping"
    next
  end

  prefix = "s3://#{bucket}/docs/#{mod}/#{version}/#{mod}/"
  out, _, status = Open3.capture3('aws', 's3', 'ls', prefix)
  unless status.success?
    warn "  #{mod} #{version}: nothing published at #{prefix}, skipping"
    next
  end

  types = out.lines.filter_map do |line|
    name = line.split.last.to_s
    next unless name.end_with?('.html')

    base = File.basename(name, '.html')
    base unless base == 'index' || base.start_with?('_')
  end

  if types.empty?
    warn "  #{mod} #{version}: no type pages found, skipping"
    next
  end

  targets[mod] = { version: version, types: types }
  puts "  #{mod} #{version}: #{types.size} linkable types"
end

if targets.empty?
  puts 'nothing to link against'
  exit 0
end

linked = Crosslink.apply!(tree, targets)
puts "linked #{linked} cross-library reference(s)"
