# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../docs-gen/crosslink'

# Linking references to types documented in another library's tree.
#
# YARD only turns a type reference into a link if that type was in its registry
# when the page was rendered. Each library is rendered on its own, so a
# reference to a type from a *different* library comes out as plain text:
# aws-cdk-lib's pages mention Constructs::Construct thousands of times and link
# to it never.
#
# Rendering everything in one YARD run would fix it and is not an option — it
# would tie every library's publishing to every other's. So the links are added
# afterwards, once the pages exist, which works across independently published
# trees.
class CrosslinkTest < Minitest::Test
  def page(body)
    dir = Dir.mktmpdir('crosslink-')
    FileUtils.mkdir_p(File.join(dir, 'AWSCDK', 'S3'))
    path = File.join(dir, 'AWSCDK', 'S3', 'Bucket.html')
    File.write(path, body)
    [dir, path]
  end

  # Constructs 10.8.1 documented, as it would be after publishing.
  def targets
    { 'Constructs' => { version: '10.8.1', types: %w[Construct IConstruct Node] } }
  end

  def test_links_a_reference_to_a_documented_type
    dir, path = page('<p>Returns Constructs::Construct here.</p>')
    Crosslink.apply!(dir, targets)
    html = File.read(path)
    assert_includes html, '/docs/Constructs/10.8.1/Constructs/Construct.html'
    assert_includes html, '>Constructs::Construct</a>'
  end

  def test_leaves_a_type_that_is_not_documented
    # Linking to a page that does not exist is worse than not linking.
    dir, path = page('<p>Returns Constructs::NotDocumented here.</p>')
    Crosslink.apply!(dir, targets)
    assert_equal '<p>Returns Constructs::NotDocumented here.</p>', File.read(path)
  end

  def test_does_not_touch_a_reference_that_is_already_a_link
    # YARD linked this one itself; rewriting would nest anchors.
    original = '<a href="../../x.html">Constructs::Construct</a>'
    dir, path = page(original)
    Crosslink.apply!(dir, targets)
    assert_equal original, File.read(path)
  end

  def test_does_not_link_inside_a_code_block
    # An example showing `Constructs::Construct` is source, not a cross
    # reference; YARD marks up its own tokens and a link inside would corrupt
    # the highlighting.
    original = "<pre class=\"code\"><span class='const'>Constructs::Construct</span></pre>"
    dir, path = page(original)
    Crosslink.apply!(dir, targets)
    assert_equal original, File.read(path)
  end

  def test_does_not_link_inside_an_attribute
    # `title="Constructs::Construct"` is not text a reader clicks.
    original = '<a href="x" title="Constructs::Construct">something</a>'
    dir, path = page(original)
    Crosslink.apply!(dir, targets)
    assert_equal original, File.read(path)
  end

  def test_links_every_occurrence_on_a_page
    dir, path = page('<p>Constructs::Construct and Constructs::Node</p>')
    Crosslink.apply!(dir, targets)
    html = File.read(path)
    assert_includes html, 'Constructs/Construct.html'
    assert_includes html, 'Constructs/Node.html'
  end

  def test_reports_how_many_it_linked
    dir, = page('<p>Constructs::Construct twice: Constructs::Construct</p>')
    assert_equal 2, Crosslink.apply!(dir, targets)
  end

  def test_types_reads_a_published_tree
    # The set of linkable types comes from what was actually published, not a
    # hand-maintained list that would drift.
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'Constructs'))
      %w[Construct.html IConstruct.html index.html].each do |f|
        File.write(File.join(dir, 'Constructs', f), 'x')
      end
      assert_equal %w[Construct IConstruct], Crosslink.documented_types(dir, 'Constructs').sort
    end
  end
end
