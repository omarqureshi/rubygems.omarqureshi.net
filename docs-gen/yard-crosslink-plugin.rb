# frozen_string_literal: true

# Make YARD link to another library's published pages.
#
# Loaded with `yard doc -e`, alongside that library's sources so its types are
# in the registry. YARD then resolves references to them properly — it knows a
# type from a method, so it produces things text matching cannot reach:
#
#   <a href="…/APIObjectMetadata.html#initialize-instance_method">new</a>
#
# What it gets wrong for us is only the URL. YARD assumes one output tree and
# emits `../CDK8s/Duration.html`, which would mean publishing a copy of the
# cdk8s pages inside every cdk8s-plus tree, pinned together — the coupling that
# versioned prefixes exist to avoid. So the address is rewritten and nothing
# else is.
#
# Configured by YARD_CROSSLINK, e.g. "CDK8s=2.70.91,Constructs=10.8.1".
# A module not listed is local and keeps YARD's own relative link.
module YardCrosslink
  def self.foreign
    @foreign ||= (ENV['YARD_CROSSLINK'] || '').split(',').to_h do |pair|
      mod, version = pair.split('=', 2)
      [mod.to_s.strip, version.to_s.strip]
    end.reject { |mod, version| mod.empty? || version.empty? }
  end

  # The published path for an object belonging to another library.
  #
  # Returns nil for anything local, so the caller falls through to YARD.
  def self.url_for_foreign(object, anchor)
    return nil if foreign.empty?

    path = object.respond_to?(:path) ? object.path.to_s : object.to_s
    root = path.split('::').first
    version = foreign[root]
    return nil if version.nil?

    # A method lives on a page named for its namespace, with the method as an
    # anchor — which is how YARD reaches `new` on APIObjectMetadata.
    page, fragment =
      if object.respond_to?(:type) && %i[method attribute constant].include?(object.type)
        [object.namespace.path.to_s, anchor || default_anchor(object)]
      else
        [path, anchor]
      end

    # A bare module reference has no page of its own in a published tree:
    # YARD writes CDK8s.html beside the directory, but what is published is the
    # generated landing at CDK8s/index.html — the other one is not deployed, and
    # linking to it 403s.
    segments = page.split('::')
    href =
      if segments.length == 1
        "/docs/#{root}/#{version}/#{root}/index.html"
      else
        "/docs/#{root}/#{version}/#{segments.join('/')}.html"
      end
    fragment.to_s.empty? ? href : "#{href}##{fragment}"
  end

  def self.default_anchor(object)
    return nil unless object.respond_to?(:type) && object.type == :method

    scope = object.scope == :class ? 'class' : 'instance'
    "#{object.name}-#{scope}_method"
  end

  # Prepended to YARD's HTML helper so the rewrite happens wherever YARD builds
  # a link — type annotations, docstring references, summary signatures.
  module HtmlHelper
    def url_for(obj, anchor = nil, relative = true)
      YardCrosslink.url_for_foreign(obj, anchor) || super
    end

    def url_for_object(obj, anchor = nil, relative = true)
      YardCrosslink.url_for_foreign(obj, anchor) || super
    end
  end
end

YARD::Templates::Helpers::HtmlHelper.prepend(YardCrosslink::HtmlHelper)
