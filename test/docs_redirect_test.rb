# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../docs-gen/render'

# The redirect written at the root of a built documentation tree.
#
# Every tree gets one: it sends /docs/<Library>/<version>/ to the module page
# inside it. The module differs per library — AWSCDK, Constructs, CDK8s — and
# the redirect has to name the one in the tree it is being written into.
#
# It hardcoded AWSCDK, which was invisible while aws-cdk-lib was the only
# library published. The moment constructs was, /docs/Constructs/ redirected
# readers to /docs/Constructs/10.8.1/AWSCDK/index.html and they got a 403.
class DocsRedirectTest < Minitest::Test
  def test_points_at_the_root_module_it_is_given
    html = Render.page('docs-redirect', root_module: 'Constructs', title: 'constructs')
    assert_includes html, 'url=Constructs/index.html'
    assert_includes html, 'href="Constructs/index.html"'
    refute_includes html, 'AWSCDK'
  end

  def test_still_serves_the_cdk_tree
    html = Render.page('docs-redirect', root_module: 'AWSCDK', title: 'AWS CDK for Ruby')
    assert_includes html, 'url=AWSCDK/index.html'
    assert_includes html, 'AWS CDK for Ruby'
  end

  def test_escapes_the_title
    # The title comes from a profile, which is data this repository does not own.
    html = Render.page('docs-redirect', root_module: 'X', title: 'a & b')
    assert_includes html, 'a &amp; b'
  end
end
