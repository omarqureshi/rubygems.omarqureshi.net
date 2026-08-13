# frozen_string_literal: true

# Which published gem has documentation, and where.
#
# The feed lists gems by gem name — aws-cdk-lib, jsii-ruby-runtime — while the
# documentation is published under module names: AWSCDK, Jsii. Nothing derives
# one from the other. The pairing is a naming decision each library made in its
# own profile, and those profiles live in other repositories.
#
# So it is recorded here, in the one place that serves both the feed and the
# documentation. A gem with no entry gets no link, and an entry whose pages are
# not published yet gets no link either — sending a reader to a 403 is worse
# than leaving the name plain.
module DocsLinks
  # gem name => documentation module
  MODULES = {
    'aws-cdk-lib' => 'AWSCDK',
    'cdk8s' => 'CDK8s',
    'cdk8s-plus-27' => 'CDK8s',
    'constructs' => 'Constructs',
    'jsii-ruby-runtime' => 'Jsii',
  }.freeze

  # @param gem_name [String]
  # @param documented [Array<String>] modules that actually have published pages
  # @return [String, nil] a path to link to, or nil to leave the name plain
  def self.for(gem_name, documented)
    mod = MODULES[gem_name]
    return nil if mod.nil? || !documented.include?(mod)

    "/docs/#{mod}/"
  end
end
