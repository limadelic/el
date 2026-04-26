Before do |scenario|
  scenario.tags.map(&:name).grep(/^@el_(.+)$/) { el($1) }
end

After do |scenario|
  scenario.tags.map(&:name).grep(/^@el_(.+)$/) { el("#{$1} exit") }
end
