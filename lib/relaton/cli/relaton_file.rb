require "nokogiri"
require "pathname"

module Relaton
  module Cli
    class RelatonFile
      def initialize(source, options = {})
        @source = source
        @options = options
        @outdir = options.fetch(:outdir, nil)
        @outfile = options.fetch(:outfile, nil)
      end

      def extract
        extract_and_write_to_files
      end

      def concatenate
        write_to_file(bibcollection.to_xml)
      end

      def split
        split_and_write_to_files
      end

      # Extract files
      #
      # This interface expect us to provide a source file / directory,
      # output directory and custom configuration options. Then it wll
      # extract Relaton XML file / files to output directory from the
      # source file / directory. During this process it will use custom
      # options when available.
      #
      # @param source [Dir] The source directory for files
      # @param outdir [Dir] The output directory for files
      # @param options [Hash] Options as hash key value pair
      #
      def self.extract(source, outdir, options = {})
        new(source, options.merge(outdir: outdir)).extract
      end

      # Concatenate files
      #
      # This interface expect us to provide a source directory, output
      # file and custom configuration options. Normally, this expect the
      # source directory to contain RXL fles, but it also converts any
      # YAML files to RXL and then finally combines those together.
      #
      # This interface also allow us to provdie options like title and
      # organization and then it usage those details to generate the
      # collection file.
      #
      # @param source [Dir] The source directory for files
      # @param output [String] The collection output file
      # @param options [Hash] Options as hash key value pair
      #
      def self.concatenate(source, outfile, options = {})
        new(source, options.merge(outfile: outfile)).concatenate
      end

      # Split collection
      #
      # This interface expects us to provide a Relaton Collection
      # file and also an output directory, then it will split that
      # collection into multiple files.
      #
      # By default it usages `rxl` extension for these new files,
      # but we can also customize that by providing the correct
      # one as `extension` option parameter.
      #
      # @param source [File] The source collection file
      # @param output [Dir] The output directory for files
      # @param options [Hash] Options as hash key value pair
      #
      def self.split(source, outdir = nil, options = {})
        new(source, options.merge(outdir: outdir)).split
      end

      private

      attr_reader :source, :options, :outdir, :outfile

      def bibcollection
        ::Relaton::Bibcollection.new(
          title: options[:title],
          items: concatenate_files,
          doctype: options[:doctype],
          author: options[:organization],
        )
      end

      def nokogiri_document(document, file = nil)
        document ||= File.read(file, encoding: "utf-8")
        Nokogiri.XML(document)
      end

      def select_source_files
        if File.file?(source)
          [source]
        else
          select_files_with("xml")
        end
      end

      def relaton_collection
        @relaton_collection ||=
          Relaton::Bibcollection.from_xml(nokogiri_document(nil, source))
      end

      def extract_and_write_to_files
        select_source_files.each do |file|
          xml = nokogiri_document(nil, file)
          xml.remove_namespaces!

          bib = xml.at("//bibdata") || next

          bib = nokogiri_document(bib.to_xml)
          bib.remove_namespaces!
          bib.root.add_namespace(nil, "xmlns")

          bibdata = Relaton::Bibdata.from_xml(bib.root)
          build_bibdata_relaton(bibdata, file)

          write_to_file(bibdata.to_xml, outdir, build_filename(file))
        end
      end

      def concatenate_files
        xml_files = [convert_rxl_to_xml, convert_yamls_to_xml]

        xml_files.flatten.map do |xml|
          doc = nokogiri_document(xml[:content])
          bibdata_instance(doc, xml[:file]) if doc.root.name == "bibdata"
        end.compact
      end

      def split_and_write_to_files
        output_dir = outdir || build_dirname(source)
        write_to_collection_file(relaton_collection.to_yaml, output_dir)

        relaton_collection.items.each do |content|
          name = build_filename(nil, content.docidentifier)
          write_to_file(content.to_xml, output_dir, name)
        end
      end

      def bibdata_instance(document, file)
        document = clean_nokogiri_document(document)
        bibdata = Relaton::Bibdata.from_xml(document.root)
        build_bibdata_relaton(bibdata, file)

        bibdata
      end

      def build_bibdata_relaton(bibdata, file)
        ["xml", "pdf", "doc", "html", "rxl"].each do |type|
          file = Pathname.new(file).sub_ext(".#{type}")
          bibdata.send("#{type}=", file) if File.file?(file)
        end
      end

      # Force a namespace otherwise Nokogiri won't parse.
      # The reason is we use Bibcollection's from_xml, but that one
      # has an xmlns. We don't want to change the code for bibdata
      # hence this hack #bibdata_doc.root['xmlns'] = "xmlns"
      #
      def clean_nokogiri_document(document)
        document.remove_namespaces!
        document.root.add_namespace(nil, "xmlns")
        nokogiri_document(document.to_xml)
      end

      def convert_rxl_to_xml
        select_files_with("{rxl}").map do |file|
          { file: file, content: File.read(file, encoding: "utf-8") }
        end
      end

      def convert_yamls_to_xml
        select_files_with("yaml").map do |file|
          { file: file, content: YAMLConvertor.to_xml(file, write: false) }
        end
      end

      def select_files_with(extension)
        files = File.join(source, "**", "*.#{extension}")
        Dir[files].reject { |file| File.directory?(file) }
      end

      def write_to_file(content, directory = nil, output_file = nil)
        file_with_dir = [directory, output_file || outfile].compact.join("/")
        File.open(file_with_dir, "w:utf-8") { |file| file.write(content) }
      end

      def write_to_collection_file(content, directory)
        write_to_file(content, directory, build_filename(source, nil, "yaml"))
      end

      def build_dirname(filename)
        basename = File.basename(filename)&.gsub(/.(xml|rxl)/, "")
        directory_name = sanitize_string(basename)
        Dir.mkdir(directory_name) unless File.exists?(directory_name)

        directory_name
      end

      def build_filename(file, identifier = nil, ext = "rxl")
        identifier ||= Pathname.new(File.basename(file, ".xml")).to_s
        [sanitize_string(identifier), options[:extension] || ext].join(".")
      end

      def sanitize_string(string)
        string.downcase.gsub("/", " ").gsub(/^\s+/, "").gsub(/\s+$/, "").
          gsub(/\s+/, "-")
      end
    end
  end
end
