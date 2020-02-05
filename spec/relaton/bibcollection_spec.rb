require "spec_helper"

RSpec.describe Relaton::Bibcollection do
  describe ".from_xml" do
    it "instantiate a new object from xml" do
      document = Relaton::Bibcollection.from_xml(
        Nokogiri.XML(File.read("spec/fixtures/sample-collection.xml")),
      )

      expect(document.title).to eq("CalConnect Standards Registry")
      expect(document.author).to eq("The Calendaring and Scheduling Consortium")
      expect(document.items[0].title[0].title.content).to include("Date and time -- Concepts")
      expect(document.items[1].title[0].title.content).to include("Date and time -- Timezones")
    end
  end
end
