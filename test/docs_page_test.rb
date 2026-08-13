# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../docs-gen/render'

# The landing page inside a built tree, at <Library>/<version>/<Module>/index.html.
#
# It was written for aws-cdk-lib and hardcoded to it: the title, the breadcrumb,
# the heading, the naming conventions, and an `AWSCDK::` prefix on every module
# link. Publishing constructs produced a page announcing "AWS CDK for Ruby",
# telling readers to write a cdk.json and run `cdk deploy`, and prefixing every
# constructs type with AWSCDK::.
#
# Prose about a library is library data, the same as its naming, so it comes
# from the profile — from the repository that owns the library. What the
# profile does not supply is simply not rendered, rather than defaulted to
# another library's.
class DocsPageTest < Minitest::Test
  def constructs
    {
      root_module: 'Constructs',
      title: 'constructs',
      tagline: 'A programming model for software-defined state.',
      intro_html: nil,
      getting_started: nil,
      conventions: [],
      modules: [],
      core_groups: [],
      core_count: 0,
      generated_on: 'Wed Aug 13 00:00:00 2026',
    }
  end

  def test_names_the_library_it_documents
    html = Render.page('docs-index', **constructs)
    assert_includes html, 'constructs'
    assert_includes html, 'A programming model for software-defined state.'
  end

  def test_does_not_announce_a_different_library
    html = Render.page('docs-index', **constructs)
    refute_includes html, 'AWS CDK'
    refute_includes html, 'aws-cdk-lib'
  end

  def test_omits_getting_started_when_the_profile_supplies_none
    # Better a page with no instructions than one with another library's.
    html = Render.page('docs-index', **constructs)
    refute_includes html, 'cdk.json'
    refute_includes html, 'cdk deploy'
  end

  def test_prefixes_core_types_with_this_tree_s_module
    # Core types are listed as Module::Type. Submodule links carry their own
    # full name already, so only these take the prefix — and it was AWSCDK::
    # regardless of which library was being documented.
    page = constructs.merge(
      core_groups: [{ label: 'Classes', count: 1, items: [{ name: 'Construct', href: 'Construct.html' }] }],
      core_count: 1,
    )
    html = Render.page('docs-index', **page)
    assert_includes html, 'Constructs::Construct'
    refute_includes html, 'AWSCDK::Construct'
  end

  def test_renders_getting_started_when_the_profile_does_supply_it
    page = constructs.merge(
      title: 'aws-cdk-lib',
      getting_started: { 'Gemfile' => '<pre>gem "aws-cdk-lib"</pre>' },
    )
    html = Render.page('docs-index', **page)
    assert_includes html, 'Gemfile'
    # Passed through as-is: the snippet is already syntax-highlighted markup.
    assert_includes html, '<pre>gem "aws-cdk-lib"</pre>'
  end

  def test_renders_conventions_when_supplied
    page = constructs.merge(conventions: ['Modules are PascalCase.'])
    html = Render.page('docs-index', **page)
    assert_includes html, 'Modules are PascalCase.'
  end
end
