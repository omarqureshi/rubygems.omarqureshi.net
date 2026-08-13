# frozen_string_literal: true

require_relative 'render'

# The page at /docs.
#
# It redirected to AWSCDK, which was correct when aws-cdk-lib was the only
# library documented and wrong the moment a second one was: a reader arriving at
# /docs had no way to learn that constructs or the runtime were documented at
# all.
#
# Built from the libraries actually published, so a new one appears here by
# being published rather than by somebody remembering to add it.
module DocsLanding
  module_function

  # What each library is, for readers who do not already know.
  #
  # Only a nicety — a library with no entry still appears, because the list
  # comes from the bucket and this is decoration. Keyed by module name, which is
  # what the published prefix is named after.
  BLURBS = {
    'AWSCDK' => 'Define AWS infrastructure in Ruby and synthesize CloudFormation.',
    'CDK8s' => 'Define Kubernetes manifests in Ruby.',
    'Constructs' => 'The base library both of the above are built on.',
    'Jsii' => 'The runtime every generated gem uses to talk to the jsii kernel.',
  }.freeze

  # @param libraries [Hash{String=>String}] module name => current version
  # @return [String] the rendered page
  def render(libraries)
    rows = libraries.sort_by { |name, _| name }.map do |name, version|
      { name: name, version: version, blurb: BLURBS[name] }
    end
    Render.page('docs-landing', libraries: rows)
  end
end
