require "rspec/expectations"

def resolve_command(cmd)
  if cmd.start_with?("el ") && File.exist?("./el")
    "./#{cmd}"
  else
    cmd
  end
end

def run_el_command(cmd)
  resolved = resolve_command(cmd)
  `#{resolved} 2>&1`.strip
end

When(/^I run el (\S+) in background$/) do |name|
  cmd = "el #{name}"
  resolved = resolve_command(cmd)

  system("#{resolved} > /dev/null 2>&1 &")

  daemon_file = File.expand_path("~/.el/daemon_node")
  tries = 0
  max_tries = 60

  until File.exist?(daemon_file) || tries >= max_tries
    sleep 0.5
    tries += 1
  end

  sleep 2
end

When(/^I run el (\S+) (\w+)$/) do |name, action|
  cmd = "el #{name} #{action}"
  @output = run_el_command(cmd)
end

Then(/^el ls should show (.+)$/) do |text|
  tries = 0
  max_tries = 10

  loop do
    @output = run_el_command("el ls")

    if text.start_with?("(") && text.end_with?(")")
      name = text[1..-2]
      break if !@output.include?(name)
    else
      break if @output.include?(text)
    end

    tries += 1
    break if tries >= max_tries
    sleep 0.5
  end

  if text.start_with?("(") && text.end_with?(")")
    name = text[1..-2]
    expect(@output).not_to include(name)
  else
    expect(@output).to include(text)
  end
end
