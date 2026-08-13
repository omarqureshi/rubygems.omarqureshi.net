# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../docs-gen/docs_landing'

# The page at /docs.
#
# It redirected to AWSCDK, which was right when aws-cdk-lib was the only
# library documented and wrong the moment a second one was: a reader landing on
# /docs had no way to discover that constructs or the runtime were documented
# at all.
#
# Built from the libraries that are actually published, so a new one appears by
# being published rather than by somebody remembering to add it here.
class DocsLandingTest < Minitest::Test
  def libraries
    {
      'AWSCDK' => '2.263.0',
      'Constructs' => '10.8.1',
      'Jsii' => '0.1.0',
    }
  end

  def test_lists_every_published_library
    html = DocsLanding.render(libraries)
    %w[AWSCDK Constructs Jsii].each { |name| assert_includes html, name }
  end

  def test_links_to_the_bare_alias_not_a_pinned_version
    # The alias resolves to whatever is current; linking a version here would
    # freeze this page at the moment it was written.
    html = DocsLanding.render(libraries)
    assert_includes html, 'href="AWSCDK/"'
    refute_includes html, 'href="AWSCDK/2.263.0/"'
  end

  def test_shows_the_current_version_as_text
    html = DocsLanding.render(libraries)
    assert_includes html, '2.263.0'
  end

  def test_orders_libraries_predictably
    # Whatever order the bucket lists them in, the page should not reshuffle
    # between refreshes for no reason.
    a = DocsLanding.render(libraries)
    b = DocsLanding.render({ 'Jsii' => '0.1.0', 'AWSCDK' => '2.263.0', 'Constructs' => '10.8.1' })
    assert_equal a, b
  end

  def test_describes_the_libraries_it_knows
    html = DocsLanding.render(libraries)
    assert_includes html, 'runtime'
  end

  def test_survives_a_library_it_has_no_description_for
    # A new library must appear even before anyone writes a blurb for it.
    html = DocsLanding.render({ 'Whatever' => '1.0.0' })
    assert_includes html, 'Whatever'
    assert_includes html, '1.0.0'
  end

  def test_escapes_library_names
    html = DocsLanding.render({ 'A&B' => '1.0.0' })
    assert_includes html, 'A&amp;B'
  end
end
