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
    # Background the process in a way that truly frees the parent
    out_err = "/tmp/el_#{Time.now.to_i}.log"
    cmd_without_amp = command.chomp("&").strip
    # Use disown to truly background: (cmd > log 2>&1 & disown)
    system("(#{cmd_without_amp} >> #{out_err} 2>&1 & disown) 2>/dev/null")
    sleep 3  # Give process time to initialize Erlang node
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
