require "fileutils"
require "spec_helper"

RSpec.describe Relaton::Cli::RelatonFile do
  describe ".extract" do
    before { FileUtils.mkdir_p("./tmp/output") }
    after { FileUtils.rm_rf("./tmp/output") }

    context "with Metanorma XML" do
      it "extracts Metanorma XML in the output directory" do
        Relaton::Cli::RelatonFile.extract(
          "spec/assets/metanorma-xml", "./tmp/output"
        )

        content = File.read("./tmp/output/a.rxl")

        expect(file_exist?("cc-amd-86003.rxl")).to be false
        expect(file_exist?("cc-cor-12990-3.rxl")).to be true
        expect(content).to include("<bibdata type='standard'>")
      end
    end

    context "with Metanorma XML and different extension" do
      it "extracts XML in output directory with provided extension" do
        Relaton::Cli::RelatonFile.extract(
          "spec/assets/metanorma-xml", "./tmp/output", extension: "rxml"
        )

        expect(file_exist?("a.rxl")).to be false
        expect(file_exist?("a.rxml")).to be true
        expect(file_exist?("cc-cor-12990-3.rxl")).to be false
        expect(file_exist?("cc-cor-12990-3.rxml")).to be true
      end
    end

    context "with single Metanorma XML file" do
      it "extracts the XML in the output directory" do
        Relaton::Cli::RelatonFile.extract(
          "spec/assets/metanorma-xml/a.xml", "./tmp/output"
        )

        content = File.read("./tmp/output/a.rxl")

        expect(file_exist?("a.rxl")).to be_truthy
        expect(file_exist?("cc-cor-12990-3.rxl")).to be_falsey
        expect(content).to include("<bibdata type='standard'>")
      end
    end
  end

  describe ".concatenate" do
    context "with YAML & RXL files in source directory" do
      it "combines both type of files into a collection" do
        Relaton::Cli::RelatonFile.concatenate(
          "spec/fixtures", "./tmp/concatenate.rxl"
        )

        xml = File.read("./tmp/concatenate.rxl")
        xmldoc = Nokogiri::XML(xml)

        expect(xmldoc.root.at("./xmlns:title")).to be_nil
        expect(xmldoc.root.at("./xmlns:contributor")).to be_nil

        expect(xml).to include("<docidentifier>CC 18001</docidentifier>")
        expect(xml).to include("<docidentifier>CC 36000</docidentifier>")
        expect(xml).not_to include("'xml'>spec/fixtures/sample-collection")
      end
    end

    context "with YAML, RXL files and custom options" do
      it "combines both type of files and usages the options" do
        Relaton::Cli::RelatonFile.concatenate(
          "spec/fixtures",
          "./tmp/concatenate.rxl",
          title: "collection title",
          organization: "Ribose Inc",
        )

        xml = File.read("./tmp/concatenate.rxl")
        xmldoc = Nokogiri::XML(xml)

        doc_title = xmldoc.root.at("./xmlns:title").text
        doc_contributor = xmldoc.root.at(
          "./xmlns:contributor/xmlns:organization/xmlns:name",
        ).text

        expect(doc_title).to eq("collection title")
        expect(doc_contributor).to eq("Ribose Inc")
        expect(xml).to include("<docidentifier>CC 36000</docidentifier>")
      end
    end

    context "with YAML, RXL and linked documents" do
      it "combines documents and also add dynamic links" do
        file_types = ["xml", "pdf", "doc", "html"]
        create_fixture_files("sample", file_types)

        Relaton::Cli::RelatonFile.concatenate(
          "spec/fixtures", "./tmp/concatenate.rxl"
        )

        cleanup_fixture_files("sample", file_types)
        xml = File.read("./tmp/concatenate.rxl")
        xmldoc = Nokogiri::XML(xml)

        expect(xmldoc.root.at("./xmlns:title")).to be_nil
        expect(xmldoc.root.at("./xmlns:contributor")).to be_nil

        expect(xml).to include("<docidentifier>CC 18001</docidentifier>")
        expect(xml).to include("<uri type='xml'>spec/fixtures/sample.xml")
        expect(xml).to include("<uri type='pdf'>spec/fixtures/sample.pdf")
        expect(xml).to include("<uri type='doc'>spec/fixtures/sample.doc")
        expect(xml).to include("<uri type='html'>spec/fixtures/sample.html")
      end
    end
  end

  describe "split" do
    before { FileUtils.mkdir_p("./tmp/output") }
    after { FileUtils.rm_rf("./tmp/output") }

    context "with valid collection and output dir" do
      it "split the relaton collection into multiple files" do
        output_dir = "./tmp/output"
        collection_file = "spec/fixtures/sample-collection.xml"

        Relaton::Cli::RelatonFile.split(collection_file, output_dir)
        content = File.read([output_dir, "cc-34000.rxl"].join("/"))

        expect(file_exist?("cc-34000.rxl")).to be true
        expect(Dir["#{output_dir}/**"].length).to eq(7)
        expect(content).to include("<bibdata type='standard'>")
        expect(content).to include("<title>Date and time -- Concepts")
      end
    end
  end

  def file_exist?(file, directory = "./tmp/output")
    File.exist?([directory, file].join("/"))
  end

  def cleanup_fixture_files(name, types = [])
    types.each { |type| FileUtils.rm("spec/fixtures/#{name}.#{type}") }
  end

  def create_fixture_files(name, types = [])
    types.each do |type|
      FileUtils.cp("spec/fixtures/sample.rxl", "spec/fixtures/#{name}.#{type}")
    end
  end
end
