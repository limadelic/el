When(/^> el\s*([^:]+)?$/) do |args|
  @last_output = el((args || "").strip)
end

When(/^> el\s*(.*):$/) do |args, content|
  case content
  when String then verify_docstring(args.strip, content)
  else el_verify(args.strip, content)
  end
end
