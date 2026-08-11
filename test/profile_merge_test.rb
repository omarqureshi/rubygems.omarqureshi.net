# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require_relative '../docs-gen/profile'

# The documentation generators read two different things out of a jsii
# assembly: its *structure* (which submodules exist, which have types) and its
# Ruby *naming* (what each one is called). A published assembly carries the
# first and not the second — Ruby naming lives in the profile, which is the
# whole reason profiles exist.
#
# Rather than mint a modified copy of a published assembly to carry the names —
# which would mean two artifacts sharing a name and version but not content,
# the ambiguity that makes duplicate-load bugs so hard to place — the profile is
# merged into the parsed assembly in memory, here.
class ProfileMergeTest < Minitest::Test
  def assembly
    {
      'name' => 'cdk8s',
      'targets' => { 'python' => { 'module' => 'cdk8s' } },
      'submodules' => { 'cdk8s.plus' => { 'targets' => {} } },
      'types' => { 'cdk8s.ApiObject' => { 'kind' => 'class' } },
    }
  end

  def profile
    {
      'cdk8s' => {
        'module' => 'CDK8s',
        'submodules' => { 'cdk8s.plus' => { 'module' => 'CDK8s::Plus' } },
      },
    }
  end

  def test_names_the_root_module
    a = assembly
    DocsProfile.apply!(a, profile)
    assert_equal 'CDK8s', a.dig('targets', 'ruby', 'module')
  end

  def test_names_submodules
    a = assembly
    DocsProfile.apply!(a, profile)
    assert_equal 'CDK8s::Plus', a.dig('submodules', 'cdk8s.plus', 'targets', 'ruby', 'module')
  end

  def test_leaves_other_languages_alone
    # The generators only add Ruby; anything else in the assembly is untouched.
    a = assembly
    DocsProfile.apply!(a, profile)
    assert_equal 'cdk8s', a.dig('targets', 'python', 'module')
  end

  def test_leaves_structure_alone
    # Structure comes from the assembly and must not be invented here.
    a = assembly
    DocsProfile.apply!(a, profile)
    assert_equal ['cdk8s.ApiObject'], a['types'].keys
    assert_equal ['cdk8s.plus'], a['submodules'].keys
  end

  def test_ignores_a_profile_for_a_different_assembly
    a = assembly
    DocsProfile.apply!(a, { 'some-other-lib' => { 'module' => 'Nope' } })
    assert_nil a.dig('targets', 'ruby')
  end

  def test_ignores_submodules_this_version_does_not_have
    # A profile outliving a submodule must not conjure one into the index.
    a = assembly
    DocsProfile.apply!(a, {
      'cdk8s' => { 'module' => 'CDK8s', 'submodules' => { 'cdk8s.gone' => { 'module' => 'X' } } },
    })
    assert_equal ['cdk8s.plus'], a['submodules'].keys
  end

  def test_the_assemblys_own_ruby_naming_wins_when_no_profile_says_otherwise
    a = assembly
    a['targets']['ruby'] = { 'module' => 'Existing' }
    DocsProfile.apply!(a, {})
    assert_equal 'Existing', a.dig('targets', 'ruby', 'module')
  end

  def test_a_profile_overrides_the_assemblys_own_naming
    # The profile is the explicit instruction for this generation.
    a = assembly
    a['targets']['ruby'] = { 'module' => 'Stale' }
    DocsProfile.apply!(a, profile)
    assert_equal 'CDK8s', a.dig('targets', 'ruby', 'module')
  end
end
