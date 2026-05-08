RSpec.describe "Cucumber hooks" do
  context "tag matching" do
    it "matches el_ tags without @ symbol" do
      tag_names = ["el_donny", "test"]
      matches = tag_names.grep(/^el_(.+)$/)
      expect(matches).to eq(["el_donny"])
    end

    it "extracts tag name correctly" do
      tag_names = ["el_donny"]
      tag_names.grep(/^el_(.+)$/) { |match| @name = $1 }
      expect(@name).to eq("donny")
    end

    it "does not match with @ symbol in regex" do
      tag_names = ["el_donny", "test"]
      matches = tag_names.grep(/^@el_(.+)$/)
      expect(matches).to be_empty
    end
  end
end
