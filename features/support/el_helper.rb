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
    output_lines = output.split("\n").map(&:strip)

    missing = expected_lines.reject do |expected_line|
      output_lines.any? { |actual_line| actual_line.downcase.include?(expected_line.downcase) }
    end

    unless missing.empty?
      raise "Expected lines not found in output:\n#{missing.join("\n")}\n\nActual output:\n#{output}"
    end
  end
end

World(ElHelper)
