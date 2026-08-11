# Walk the parse tree rather than the text: `require_relative` also appears
# inside the getting-started code samples, and a regex cannot tell a sample
# from a statement.
bad = 0
def walk(node, &blk)
  return unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)
  blk.call(node)
  node.children.each { |c| walk(c, &blk) }
end
Dir['docs-gen/*.rb'].sort.each do |f|
  tree = RubyVM::AbstractSyntaxTree.parse_file(f)
  walk(tree) do |n|
    next unless %i[FCALL VCALL CALL].include?(n.type)
    name = n.children.find { |c| c.is_a?(Symbol) }
    next unless name == :require_relative
    args = n.children.compact.find { |c| c.is_a?(RubyVM::AbstractSyntaxTree::Node) && c.type == :LIST }
    dep = args&.children&.first
    next unless dep.is_a?(RubyVM::AbstractSyntaxTree::Node) && dep.type == :STR
    path = dep.children.first
    target = File.expand_path(path, File.dirname(f))
    next if File.exist?(target) || File.exist?("#{target}.rb")
    warn "#{f}: require_relative #{path.inspect} does not resolve"
    bad += 1
  end
end
warn "#{bad} unresolved require(s)"
exit(bad.zero? ? 0 : 1)
