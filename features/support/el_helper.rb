module ElHelper
  def el(args = "")
    bin = ENV["DEV"] ? "./el" : "/opt/homebrew/bin/el"
    `#{bin} #{args}`.chomp
  end

  def el_verify(args, table)
    verify_table(table, el(args))
  end
end

World(ElHelper)
