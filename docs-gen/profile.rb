# frozen_string_literal: true

require 'json'

# Ruby naming for an assembly, supplied alongside it rather than baked into it.
#
# The documentation generators need two things from a jsii assembly: its
# structure — which submodules exist and which contain types — and its Ruby
# naming. A published assembly has the first and not the second: `targets.ruby`
# is absent, because Ruby is not one of the languages these libraries publish.
# The naming lives in a *profile*, owned by whoever distributes the bindings.
#
# The alternative was to ship a modified copy of the published assembly with the
# names merged in. That would put two artifacts with the same name and version
# but different contents into the world, and the kernel resolves assemblies by
# name and version — the same ambiguity that makes a duplicate load present
# itself as an error about an unrelated type, in an unrelated library. Not worth
# it to carry a handful of strings.
#
# So the merge happens here, in memory, at the point of use.
module DocsProfile
  # Read a profile file, if one was given.
  #
  # @param path [String, nil] path to the profile JSON.
  # @return [Hash] the profile, or an empty one when no path was given.
  def self.load(path)
    return {} if path.nil? || path.empty?

    JSON.parse(File.read(path)).reject { |key, _| key.start_with?('_') }
  end

  # Merge a profile's Ruby naming into a parsed assembly, in place.
  #
  # Only naming is written: structure is the assembly's to state, and a profile
  # naming a submodule this version does not have is ignored rather than
  # conjuring one into the index.
  #
  # @param assembly [Hash] a parsed jsii assembly.
  # @param profile  [Hash] a profile keyed by assembly name.
  # @return [Hash] the same assembly, mutated.
  def self.apply!(assembly, profile)
    entry = profile[assembly['name']]
    return assembly if entry.nil?

    naming = entry.reject { |key, _| key.start_with?('_') || key == 'submodules' }
    assembly['targets'] ||= {}
    assembly['targets']['ruby'] = (assembly['targets']['ruby'] || {}).merge(naming)

    (entry['submodules'] || {}).each do |fqn, sub_naming|
      submodule = assembly.dig('submodules', fqn)
      next if submodule.nil? # the profile outlived this submodule

      submodule['targets'] ||= {}
      submodule['targets']['ruby'] =
        (submodule['targets']['ruby'] || {}).merge(sub_naming.reject { |k, _| k.start_with?('_') })
    end

    assembly
  end
end
