require "rspec/expectations"

When(/^> (.+)$/) do |command, table|
  @output = `#{command} 2>&1`.strip

  table.raw.each do |row|
    row.each do |cell|
      cell = cell.strip
      if cell.start_with?("(") && cell.end_with?(")")
        expect(@output).not_to include(cell[1..-2])
      else
        expect(@output).to include(cell)
      end
    end
  end if table
end
