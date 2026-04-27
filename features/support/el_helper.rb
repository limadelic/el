module ElHelper
  def el(args = "")
    bin = ENV["DEV"] ? "./el" : "/opt/homebrew/bin/el"
    `#{bin} #{args}`.chomp
  end

  def el_verify(args, table, timeout: 15)
    retry_until(timeout) { assert_table(table, el(args)) }
  end

  private

  def retry_until(timeout)
    deadline = Time.now + timeout
    loop { return yield rescue (raise if Time.now >= deadline; sleep 0.5) }
  end

  def assert_table(table, output)
    cells(table).each { |cell| assert_cell(cell, output) }
  end

  def cells(table)
    table.raw.flatten.map(&:strip).reject(&:empty?)
  end

  def assert_cell(cell, output)
    negated?(cell) ? refute_match(cell[1..-2], output) : assert_match(cell, output)
  end

  def negated?(cell)
    cell.start_with?("(") && cell.end_with?(")")
  end

  def assert_match(expected, output)
    expected.split.each { |w| raise "Expected '#{w}' in:\n#{output}" unless output.downcase.include?(w.downcase) }
  end

  def refute_match(unexpected, output)
    raise "Expected '#{unexpected}' NOT in:\n#{output}" if output.downcase.include?(unexpected.downcase)
  end
end

World(ElHelper)
