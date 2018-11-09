require_relative "spec_helper"
require "fileutils"

RSpec.describe "extract", skip: true do
  it "extracts Metanorma XML" do
    FileUtils.rm_rf "spec/assets/out"
    FileUtils.mkdir_p "spec/assets/out"
    system "relaton extract spec/assets/metanorma-xml spec/assets/out"
    expect(File.exist?("spec/assets/out/CC-18001.rxl")).to be true
    expect(File.exist?("spec/assets/out/cc-18002.rxl")).to be false
    expect(File.exist?("spec/assets/out/cc-amd-86003.rxl")).to be false
    expect(File.exist?("spec/assets/out/cc-cor-12990-3.rxl")).to be true
    file = File.read("spec/assets/out/cc-18001.rxl", encoding: "utf-8")
    expect(file).to include "<bibdata"
  end

  it "extracts Metanorma XML with a different extension" do
    FileUtils.rm_rf "spec/assets/out"
    FileUtils.mkdir_p "spec/assets/out"
    system "relaton extract -x rxml spec/assets/metanorma-xml spec/assets/out"
    expect(File.exist?("spec/assets/out/CC-18001.rxl")).to be false
    expect(File.exist?("spec/assets/out/CC-18001.rxml")).to be true
    expect(File.exist?("spec/assets/out/cc-cor-12990-3.rxl")).to be false
    expect(File.exist?("spec/assets/out/cc-cor-12990-3.rxml")).to be true
  end
end

RSpec.describe "xml2html", skip: true do
  it "converts Relaton XML to HTML" do
    FileUtils.rm_rf "spec/assets/collection.html"
    system "relaton xml2html spec/assets/collection.xml spec/assets/index-style.css spec/assets/templates"
    expect(File.exist?("spec/assets/collection.html")).to be true
    html = File.read("spec/assets/collection.html", encoding: "utf-8")
    expect(html).to include "I AM A SAMPLE STYLESHEET"
    expect(html).to include %(<a href="csd/cc-r-3101.html">CalConnect XLIII -- Position on the European Union daylight-savings timezone change</a>)
  end
end

RSpec.describe "yaml2html", skip: true do
  it "converts Relaton YAML to HTML" do
    FileUtils.rm_rf "spec/assets/relaton-yaml/collection.html"
    system "relaton yaml2html spec/assets/relaton-yaml/collection.yaml spec/assets/index-style.css spec/assets/templates"
    expect(File.exist?("spec/assets/relaton-yaml/collection.html")).to be true
    html = File.read("spec/assets/relaton-yaml/collection.html", encoding: "utf-8")
    expect(html).to include "I AM A SAMPLE STYLESHEET"
    expect(html).to include %(<a href="">CC 34000</a>)
  end
end

RSpec.describe "concatenate", skip: true do
  it "concatenates YAML and RXL into a collection" do
    FileUtils.rm_rf "spec/assets/rxl"
    FileUtils.mkdir_p "spec/assets/rxl"
    FileUtils.rm_f "spec/assets/concatenate.rxl"
    FileUtils.cp "spec/assets/relaton-yaml/single.yaml", "spec/assets/rxl"
    FileUtils.cp "spec/assets/relaton-xml/CC-18001.rxl", "spec/assets/rxl"
    FileUtils.cp "spec/assets/index.xml", "spec/assets/rxl"
    system "relaton concatenate spec/assets/rxl spec/assets/concatenate.rxl"
    expect(File.exist?("spec/assets/concatenate.rxl")).to be true
    xml = File.read("spec/assets/concatenate.rxl")
    expect(xml).to include "<docidentifier>CC 36000</docidentifier>"
    expect(xml).to include "<docidentifier>CC 18001</docidentifier>"
    expect(xml).not_to include "<docidentifier>CC/R 3101</docidentifier>"
    expect(xml).not_to include %(<uri type='xml'>spec/assets/rxl/CC-18001.xml</uri>)
    expect(xml).not_to include %(<uri type='html'>spec/assets/rxl/CC-18001.html</uri>)
    expect(xml).not_to include %(<uri type='pdf'>spec/assets/rxl/CC-18001.pdf</uri>)
    expect(xml).not_to include %(<uri type='doc'>spec/assets/rxl/CC-18001.doc</uri>)
    xmldoc = Nokogiri::XML(xml)
    expect(xmldoc.root.at("./xmlns:title")).to be_nil
    expect(xmldoc.root.at("./xmlns:contributor")).to be_nil
  end

  it "creates document links dynamically" do
    FileUtils.rm_rf "spec/assets/rxl"
    FileUtils.mkdir_p "spec/assets/rxl"
    FileUtils.rm_f "spec/assets/concatenate.rxl"
    FileUtils.cp "spec/assets/relaton-xml/CC-18001.rxl", "spec/assets/rxl"
    File.open("spec/assets/rxl/CC-18001.xml", "w") { |f| f.write "..." }
    File.open("spec/assets/rxl/CC-18001.pdf", "w") { |f| f.write "..." }
    File.open("spec/assets/rxl/CC-18001.doc", "w") { |f| f.write "..." }
    File.open("spec/assets/rxl/CC-18001.html", "w") { |f| f.write "..." }
    system "relaton concatenate spec/assets/rxl spec/assets/concatenate.rxl"
    expect(File.exist?("spec/assets/concatenate.rxl")).to be true
    xml = File.read("spec/assets/concatenate.rxl")
    expect(xml).to include %(<uri type='xml'>spec/assets/rxl/CC-18001.xml</uri>)
    expect(xml).to include %(<uri type='html'>spec/assets/rxl/CC-18001.html</uri>)
    expect(xml).to include %(<uri type='pdf'>spec/assets/rxl/CC-18001.pdf</uri>)
    expect(xml).to include %(<uri type='doc'>spec/assets/rxl/CC-18001.doc</uri>)
  end

  it "creates collection with title and author" do
    FileUtils.rm_rf "spec/assets/rxl"
    FileUtils.mkdir_p "spec/assets/rxl"
    FileUtils.rm_f "spec/assets/concatenate.rxl"
    FileUtils.cp "spec/assets/relaton-xml/CC-18001.rxl", "spec/assets/rxl"
    system "relaton concatenate -t TITLE -g ORG spec/assets/rxl spec/assets/concatenate.rxl"
    expect(File.exist?("spec/assets/concatenate.rxl")).to be true
    xml = File.read("spec/assets/concatenate.rxl")
    xmldoc = Nokogiri::XML(xml)
    expect(xmldoc.root.at("./xmlns:title")).not_to be_nil
    expect(xmldoc.root.at("./xmlns:contributor")).not_to be_nil
    expect(xmldoc.root.at("./xmlns:title").text).to eq "TITLE"
    expect(xmldoc.root.at("./xmlns:contributor/xmlns:organization/xmlns:name").text).to eq "ORG"
  end
end