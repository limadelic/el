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

    missing_words = []

    expected_lines.each do |expected_line|
      stripped = strip_box_chars(expected_line)
      words = stripped.split.reject { |w| w == "…" }

      next if words.empty?

      words.each do |word|
        unless output.downcase.include?(word.downcase)
          missing_words << { word: word, source_line: expected_line }
        end
      end
    end

    unless missing_words.empty?
      message = "Missing words in actual output:\n"
      missing_words.each do |entry|
        message += "  \"#{entry[:word]}\" (from line: \"#{entry[:source_line]}\")\n"
      end
      message += "\nActual output:\n#{output}"
      raise message
    end
  end

  private

  def strip_box_chars(line)
    line.gsub(/[│─╭╮╰╯]/, '').strip
  end
end

World(ElHelper)
