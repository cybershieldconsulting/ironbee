#!/usr/bin/env ruby

OUTPUT = 'modules.adoc'
GLOB = 'module-*.adoc'

File.open(OUTPUT, 'w') do |w|
  w.puts "////"
  w.puts "Autogenerated via #{$0}"
  w.puts "////"

  Dir.glob(GLOB).sort.each do |file|
    if not file =~ /^module-index-/
      w.puts
      w.puts "include::#{file}[]"
    end
  end
end