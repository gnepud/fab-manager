# frozen_string_literal: true

require 'pathname'
require 'set'
require 'yaml'

def strings(value)
  case value
  when Hash then strings(value.values)
  when Array then value.flat_map { |item| strings(item) }
  when String then [value]
  else []
  end
end

def quoted_labels(directory, quotes)
  directory.glob('*.md').sort.flat_map do |file|
    file.readlines.each_with_index.flat_map do |line, index|
      line.scan(quotes).map { |(label)| [label, file.basename, index + 1] }
    end
  end
end

def check_labels(root, locale, directory, quotes)
  values = root.glob("config/locales/{#{locale},*.#{locale}}.yml").flat_map do |file|
    strings(YAML.safe_load_file(file, permitted_classes: [Symbol], aliases: true))
  end.to_set
  labels = quoted_labels(directory, quotes)
  abort "No quoted #{locale} labels found" if labels.empty?

  missing = labels.reject { |label, _file, _line| values.include?(label) }
  missing.each do |label, file, line|
    warn "#{directory.relative_path_from(root)}/#{file}:#{line}: no #{locale} locale value for #{label.inspect}"
  end
  puts "#{locale}: #{labels.size - missing.size}/#{labels.size} quoted labels match locale values"
  missing.empty?
end

root = Pathname.new(File.expand_path('../..', __dir__))
results = [
  check_labels(root, 'en', root.join('doc/testing'), /“([^”]+)”/),
  check_labels(root, 'fr', root.join('doc/fr/testing'), /«\s*([^»]+?)\s*»/)
]
exit(results.all?)
