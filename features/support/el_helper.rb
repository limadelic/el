module ElHelper
  def el(args = "")
    bin = ENV["DEV"] ? "./el" : "/opt/homebrew/bin/el"
    `#{bin} #{args}`.chomp
  end

  def el_verify(args, table)
    verify_table(table, el(args))
  end

  def verify_docstring(args, expected)
    output = el(args).strip
    expected_lines = expected.strip.split("\n").reject(&:empty?)

    missing = expected_lines.reject do |expected_line|
      stripped = strip_box_chars(expected_line)
      words = stripped.split

      next true if words.empty?

      words.all? { |word| output.downcase.include?(word.downcase) }
    end

    unless missing.empty?
      raise "Expected lines not found in output:\n#{missing.join("\n")}\n\nActual output:\n#{output}"
    end
  end

  private

  def strip_box_chars(line)
    line.gsub(/[│─╭╮╰╯]/, '').strip
  end
end

World(ElHelper)
