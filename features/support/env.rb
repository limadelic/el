require "rspec/expectations"

BeforeAll do
  bin = ENV["DEV"] ? "./el" : "/opt/homebrew/bin/el"

  if ENV["DEV"]
    puts "=== mix release --overwrite ==="
    output = `mix release --overwrite 2>&1`
    abort("mix release failed:\n#{output}") unless output.include?("Release created")
  end

  puts "=== #{bin} exit ==="
  system("#{bin} exit") or abort("#{bin} exit failed")

  puts "=== #{bin} restart ==="
  system("#{bin} restart") or abort("#{bin} restart failed")

  puts "=== boot complete ==="
end
