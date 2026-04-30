require 'timeout'

Around do |scenario, block|
  Timeout.timeout(20) { block.call }
rescue Timeout::Error
  raise "Scenario '#{scenario.name}' timed out after 20s"
end

Before do |scenario|
  scenario.tags.map(&:name).grep(/^@el_(.+)$/) { el($1) }
end

After do |scenario|
  scenario.tags.map(&:name).grep(/^@el_(.+)$/) { el("#{$1} exit") }
end
