require "rspec/expectations"

EL_BIN = "/opt/homebrew/bin/el"

When(/^> (.+[^:])$/) do |cmd|
  @last_output = run_el(cmd)
end

When(/^> (.+):$/) do |cmd, table|
  verify_with_retry(cmd, table)
end

def run_el(cmd)
  rest = cmd.sub(/^el\s*/, "")
  `#{EL_BIN} #{rest}`.chomp
end

def verify_with_retry(cmd, table, timeout: 5)
  deadline = Time.now + timeout
  last_error = nil
  loop do
    output = run_el(cmd)
    begin
      verify_table(table, output)
      return
    rescue => e
      last_error = e
      raise if Time.now >= deadline
      sleep 0.2
    end
  end
end

def verify_table(table, output)
  table.raw.flatten.each do |row|
    row = row.strip
    if row.start_with?("(") && row.end_with?(")")
      val = row[1..-2]
      raise "Expected '#{val}' NOT in output:\n#{output}" if output.include?(val)
    else
      raise "Expected '#{row}' in output:\n#{output}" unless row.split.all? { |word| output.include?(word) }
    end
  end
end
