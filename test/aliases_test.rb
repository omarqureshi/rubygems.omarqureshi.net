# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../docs-gen/aliases'

# Which version a bare documentation URL should point at.
#
# Documentation is published to immutable, versioned prefixes
# (/docs/AWSCDK/2.263.0/), and /docs/AWSCDK/ is a redirect to one of them. The
# redirect cannot be written by the publisher from its own version: publishing
# a patch to an older minor must not drag the alias backwards, and a publisher
# only knows about itself. So it is computed from the versions that exist.
class AliasesTest < Minitest::Test
  def test_points_at_the_highest_version
    assert_equal '2.263.0', DocsAliases.newest(%w[2.60.0 2.263.0 2.260.5])
  end

  def test_orders_numerically_not_lexicographically
    # The bug this exists to avoid: as strings, "2.9.5" > "2.263.0".
    assert_equal '2.263.0', DocsAliases.newest(%w[2.9.5 2.263.0])
  end

  def test_a_patch_to_an_older_minor_does_not_move_the_alias
    before = DocsAliases.newest(%w[2.260.5 2.263.0])
    after  = DocsAliases.newest(%w[2.260.5 2.263.0 2.260.6])
    assert_equal '2.263.0', before
    assert_equal '2.263.0', after, 'patching an old minor moved the top-level alias'
  end

  def test_ignores_prereleases
    # Publishing an rc must not capture the alias.
    assert_equal '2.263.0', DocsAliases.newest(%w[2.263.0 2.264.0-rc.1])
  end

  def test_falls_back_to_a_prerelease_when_there_is_nothing_else
    # A library with only previews published still deserves a landing page.
    assert_equal '0.0.0.pre.2', DocsAliases.newest(%w[0.0.0.pre.1 0.0.0.pre.2])
  end

  def test_no_versions_at_all
    assert_nil DocsAliases.newest([])
  end

  def test_ignores_entries_that_are_not_versions
    # An S3 listing of /docs/AWSCDK/ may contain anything someone put there.
    assert_equal '1.2.0', DocsAliases.newest(%w[1.2.0 latest not-a-version])
  end

  def test_per_minor_aliases_point_at_the_highest_patch_in_their_line
    got = DocsAliases.per_minor(%w[2.260.5 2.260.6 2.263.0 2.263.1])
    assert_equal({ '2.260' => '2.260.6', '2.263' => '2.263.1' }, got)
  end

  def test_per_minor_excludes_prereleases_too
    got = DocsAliases.per_minor(%w[2.263.0 2.263.1-rc.1])
    assert_equal({ '2.263' => '2.263.0' }, got)
  end

  def test_redirect_html_points_where_it_says
    html = DocsAliases.redirect_to('2.263.0')
    assert_includes html, '2.263.0/index.html'
    assert_includes html, 'http-equiv="refresh"'
    # A canonical link as well, so the alias does not compete with the versioned
    # page in search results.
    assert_includes html, 'rel="canonical"'
  end

  def test_redirect_html_escapes_its_target
    # The version comes from an S3 listing; nothing guarantees it is tame.
    html = DocsAliases.redirect_to('1.0.0"><script>alert(1)</script>')
    refute_includes html, '<script>'
  end
end
