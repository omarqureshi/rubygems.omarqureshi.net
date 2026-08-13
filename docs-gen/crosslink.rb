# frozen_string_literal: true

# Links references to types documented in another library's tree.
#
# YARD turns a type reference into a link only when that type was in its
# registry as the page was rendered. Each library is rendered on its own, so a
# reference to a type from a *different* library comes out as plain text —
# aws-cdk-lib's pages mention `Constructs::Construct` thousands of times and
# link to it never, because `constructs` was not in the registry.
#
# Rendering every library in one YARD run would fix that, and would tie each
# library's publishing to every other's — one slow build, one shared cadence,
# one failure taking them all down. So the links are added afterwards, once the
# pages exist, which works across trees published independently and at
# different times.
module Crosslink
  module_function

  # Types a published documentation tree actually contains.
  #
  # Read from the tree rather than from a list somebody maintains, because a
  # list would drift: linking to a page that does not exist is worse than not
  # linking at all.
  #
  # @param tree   [String] a built docs tree (the directory holding <Module>/).
  # @param module_name [String] the root module directory within it.
  # @return [Array<String>] type names with a page.
  def documented_types(tree, module_name)
    dir = File.join(tree, module_name)
    return [] unless File.directory?(dir)

    Dir.children(dir).filter_map do |entry|
      next unless entry.end_with?('.html')

      name = File.basename(entry, '.html')
      # index.html is the landing page, not a type.
      name unless name == 'index' || name.start_with?('_')
    end
  end

  # Rewrite plain references into links, in place.
  #
  # @param tree    [String] the docs tree to rewrite (one library's pages).
  # @param targets [Hash] {"Constructs" => {version:, types: [...]}}
  # @return [Integer] how many references were linked.
  def apply!(tree, targets)
    linked = 0
    Dir.glob(File.join(tree, '**', '*.html')).each do |path|
      html = File.read(path)
      updated = link(html, targets) { linked += 1 }
      File.write(path, updated) unless updated == html
    end
    linked
  end

  # The rewrite for one page.
  #
  # Deliberately conservative. A reference is linked only when it is plain text
  # between tags: never inside an attribute (`title="Constructs::Construct"` is
  # not something a reader clicks), never inside an existing anchor (nested
  # anchors are invalid and YARD may have linked it already), and never inside
  # highlighted source, where an example mentioning the type is code rather than
  # a cross reference and a link would corrupt the markup around it.
  def link(html, targets, &counted)
    # Split on tags so only the text between them is considered, then skip the
    # spans that are inside something a link must not enter.
    depth_anchor = 0
    depth_code = 0
    html.split(/(<[^>]+>)/).map do |part|
      if part.start_with?('<')
        case part
        when %r{\A<a\b}i then depth_anchor += 1
        when %r{\A</a>}i then depth_anchor -= 1
        when %r{\A<(pre|code)\b}i then depth_code += 1
        when %r{\A</(pre|code)>}i then depth_code -= 1
        end
        part
      elsif depth_anchor.positive? || depth_code.positive?
        part
      else
        substitute(part, targets, &counted)
      end
    end.join
  end

  def substitute(text, targets)
    targets.reduce(text) do |acc, (module_name, info)|
      documented = info[:types].to_set rescue info[:types]
      acc.gsub(/\b#{Regexp.escape(module_name)}::([A-Z][A-Za-z0-9_]*)\b/) do
        type = Regexp.last_match(1)
        if documented.include?(type)
          yield if block_given?
          # Absolute, because the depth of the referring page varies and these
          # trees are served from one site.
          href = "/docs/#{module_name}/#{info[:version]}/#{module_name}/#{type}.html"
          %(<a href="#{href}" title="#{module_name}::#{type}">#{module_name}::#{type}</a>)
        else
          Regexp.last_match(0)
        end
      end
    end
  end
end
