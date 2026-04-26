When(/^> el\s*([^:]+)?$/) do |args|
  @last_output = el((args || "").strip)
end

When(/^> el\s*(.*):$/) do |args, table|
  el_verify(args.strip, table)
end
