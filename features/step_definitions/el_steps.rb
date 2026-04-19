require "rspec/expectations"

def resolve_command(cmd)
  # Use ./el if binary exists locally, otherwise trust PATH
  if cmd.start_with?("el ") && File.exist?("./el")
    "./#{cmd}"
  else
    cmd
  end
end

When(/^> (.+)$/) do |*args|
  command = args[0]
  table = args[1]
  command = resolve_command(command)

  if command.end_with?("&")
    # Background the process by forking — & needs to be passed as argument
    out_err = "/tmp/el_#{Time.now.to_i}.log"
    cmd_without_amp = command.chomp("&").strip

    # Parse command into parts
    parts = cmd_without_amp.split(" ")
    parts << "&"  # Add & as literal argument

    # Fork and exec with & as argument
    @pid = Process.fork do
      # Redirect stdout/stderr to log file
      File.open(out_err, "a") do |log|
        $stdout.reopen(log)
        $stderr.reopen(log)
      end
      # Exec with & as argument
      exec(*parts)
    end

    # Parent: wait a bit for child to start, then return (don't wait for child)
    sleep 3
  else
    @output = `#{command} 2>&1`.strip

    if table
      table.raw.flatten.each do |cell|
        cell = cell.strip
        if cell.start_with?("(") && cell.end_with?(")")
          expect(@output).not_to include(cell[1..-2])
        else
          expect(@output).to include(cell)
        end
      end
    end
  end
end
