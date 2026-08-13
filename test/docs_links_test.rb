# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../docs-gen/docs_links'

# Which published gem has documentation, and where.
#
# The feed lists gems by gem name (aws-cdk-lib, jsii-ruby-runtime); the
# documentation is published under module names (AWSCDK, Jsii). Nothing derives
# one from the other — the pairing is a naming decision each library made in its
# own profile, and those profiles live in other repositories.
#
# So it is recorded here, in the one place that serves both, and a gem with no
# entry simply gets no link rather than a guess.
class DocsLinksTest < Minitest::Test
  def documented
    %w[AWSCDK Constructs Jsii]
  end

  def test_links_a_gem_whose_docs_are_published
    assert_equal '/docs/AWSCDK/', DocsLinks.for('aws-cdk-lib', documented)
  end

  def test_links_the_runtime_to_its_module
    assert_equal '/docs/Jsii/', DocsLinks.for('jsii-ruby-runtime', documented)
  end

  def test_does_not_link_a_gem_whose_docs_are_not_published_yet
    # cdk8s has a documentation workflow but has not published; linking to it
    # would send readers to a 403.
    assert_nil DocsLinks.for('cdk8s', documented)
  end

  def test_links_cdk8s_once_its_docs_exist
    assert_equal '/docs/CDK8s/', DocsLinks.for('cdk8s', documented + ['CDK8s'])
  end

  def test_does_not_guess_for_a_gem_it_does_not_know
    assert_nil DocsLinks.for('some-other-gem', documented)
  end
end
