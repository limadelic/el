require 'timeout'

Around do |scenario, block|
  Timeout.timeout(10) { block.call }
rescue Timeout::Error
  raise "Scenario '#{scenario.name}' timed out after 10s"
end

Before do |scenario|
  scenario.tags.map(&:name).grep(/^@el_(.+)$/) { el("#{$1} -m haiku") }
end

After do |scenario|
  scenario.tags.map(&:name).grep(/^@el_(.+)$/) { el("#{$1} exit") }
end
