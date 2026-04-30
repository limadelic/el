require "rspec/expectations"

puts "=== mix release --overwrite ==="
output = `mix release --overwrite 2>&1`
abort("mix release failed:\n#{output}") unless output.include?("Release created")

puts "=== ./el exit ==="
system("./el exit") or abort("./el exit failed")

puts "=== ./el restart ==="
system("./el restart") or abort("./el restart failed")

puts "=== boot complete ==="
