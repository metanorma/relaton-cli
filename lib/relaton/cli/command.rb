require "relaton"
require "nokogiri"
require "yaml"
require "thor"
require "fileutils"
require "pathname"
require "fcntl"

module Relaton
  module Cli
    class Command < Thor

      desc "fetch CODE", "Fetch Relaton XML for Standard identifier CODE"
      option :type, aliases: :t, required: true, desc: "Type of standard to get bibliographic entry for"
      option :year, aliases: :y, type: :numeric, desc: "Year the standard was published"

      def fetch(code)
        Relaton::Cli.relaton
        say(fetch_document(code, options) || supported_type_message)
      end

      desc "extract Metanorma-XML-Directory Relaton-XML-Directory", "Extract Relaton XML from folder of Metanorma XML"

      option :extension, :required => false, :desc => "File extension of Relaton XML files, defaults to 'rxl'", :aliases => :x, :default => "rxl"

      def extract(source_dir, outdir)
        Dir[ File.join(source_dir, '**', '*.xml') ].reject { |p| File.directory? p }.each do |f|
          xml = Nokogiri::XML(File.read(f, encoding: "utf-8")).remove_namespaces!
          bib = xml.at("//bibdata") || next
          bib.add_namespace(nil, "")
          docidentifier = bib&.at("./docidentifier")&.text ||
            Pathname.new(File.basename(f, ".xml")).to_s
          fn = docidentifier.sub(/^\s+/, "").sub(/\s+$/, "").gsub(/\s+/, "-") +
            ".#{options[:extension]}"
          File.open("#{outdir}/#{fn}", "w:UTF-8") { |f| f.write bib.to_xml }
        end
      end

      desc "concatenate SOURCE-DIR COLLECTION-FILE", "Concatenate entries in DIRECTORY (containing Relaton-XML or YAML) into a Relaton Collection"

      option :title, :required => false, :desc => "Title of resulting Relaton collection", :aliases => :t
      option :organization, :required => false, :desc => "Organization owner of Relaton collection", :aliases => :g

      def concatenate(source_dir, outfile)

        Dir[ File.join(source_dir, '**', '*.yaml') ].reject { |p| File.directory? p }.each do |f|
          yaml2xml(f, nil, "rxl")
        end

        bibdatas = []
        Dir[ File.join(source_dir, '**', '*.{rxl}') ].reject { |p| File.directory? p }.each do |f|
          file = File.read(f, encoding: "utf-8")
          bibdata_doc = Nokogiri.XML(file)
          # Skip if this XML isn't a Relaton XML
          next unless bibdata_doc.root.name == "bibdata"
          # Force a namespace otherwise Nokogiri won't parse.
          # The reason is we use Bibcollection's from_xml, but that one has an xmlns.
          # We don't want to change the code for bibdata hence this hack
          #bibdata_doc.root['xmlns'] = "xmlns"
          bibdata_doc.remove_namespaces!
          bibdata_doc.root.add_namespace(nil, "xmlns")
          bibdata_doc = Nokogiri.XML(bibdata_doc.to_xml)

          bibdata = Relaton::Bibdata.from_xml(bibdata_doc.root)
          # XML relaton file must already exist
          bibdata.relaton = f
          xml = Pathname.new(f).sub_ext('.xml')
          bibdata.xml = xml if File.file?(xml) && f.match(/\.rxl$/)
          pdf = Pathname.new(f).sub_ext('.pdf')
          bibdata.pdf = pdf if File.file?(pdf)
          doc = Pathname.new(f).sub_ext('.doc')
          bibdata.doc = doc if File.file?(doc)
          html = Pathname.new(f).sub_ext('.html')
          bibdata.html = html if File.file?(html)
          bibdatas << bibdata
        end

        bibcollection = ::Relaton::Bibcollection.new(
          title: options[:title],
          # doctype: options[:doctype],
          author: options[:organization],
          items: bibdatas
        )
        File.open(outfile, "w:UTF-8") do |f|
          f.write bibcollection.to_xml
        end
      end

      desc "yaml2xml YAML", "Convert Relaton YAML into Relaton Collection XML or separate files"
      option :extension, :required => false, :desc => "File extension of Relaton XML files, defaults to 'rxl'", :aliases => :x, :default => "rxl"
      option :prefix, :required => false, :desc => "Filename prefix of individual Relaton XML files, defaults to empty", :aliases => :p
      option :outdir, :required => false, :desc => "Output to the specified directory with individual Relaton Bibdata XML files", :aliases => :o
      option :require, :required => false, :desc => "Require LIBRARY prior to execution", :aliases => :r, :type => :array

      def yaml2xml(filename, outdir = options[:outdir], ext = nil)
        ext ||= options[:extension]
        if options[:require]
          options[:require].each do |r|
            require r
          end
        end
        index_input = YAML.load_file(filename)

        if index_input.has_key?("root")
          # this is a collection
          # TODO real lookup of namespaces and root elements
          index_collection = ::Relaton::Bibcollection.new(index_input["root"])
          outfilename = Pathname.new(filename).sub_ext(".#{ext}")
          File.open(outfilename, "w:utf-8") { |f| f.write index_collection.to_xml }
          return unless outdir
          FileUtils.mkdir_p(outdir)

          index_collection.items_flattened.each do |item|
            filename = File.join(
              outdir,
              "#{options[:prefix]}#{item.docidentifier_code}.#{ext}"
            )
            File.open(filename, "w:UTF-8") { |f| f.write(item.to_xml) }
          end
        else
          # this is a single entry
          index_entry = ::Relaton::Bibdata.new(index_input)
          outfilename = Pathname.new(filename).sub_ext(".#{ext}")
          File.open(outfilename, "w:utf-8") { |f| f.write index_entry.to_xml }
        end
      end

      desc "xml2yaml XML", "Convert Relaton YAML into Relaton Bibcollection YAML (and separate files)"
      option :extension, :required => false, :desc => "File extension of Relaton YAML files, defaults to 'yaml'", :aliases => :x, :default => "yaml"
      option :prefix, :required => false, :desc => "Filename prefix of Relaton XML files, defaults to empty", :aliases => :p
      option :outdir, :required => false, :desc => "Output to the specified directory with individual Relaton Bibdata YAML files", :aliases => :o
      option :require, :required => false, :desc => "Require LIBRARY prior to execution", :aliases => :r, :type => :array

      def xml2yaml(filename)
        if options[:require]
          options[:require].each do |r|
            require r
          end
        end

        index_input = File.read(filename, encoding: "utf-8")
        bibdata_doc = Nokogiri.XML(index_input)
        index_collection = ::Relaton::Bibcollection.from_xml(bibdata_doc)

        # TODO real lookup of namespaces and root elements
        outfilename = Pathname.new(filename).sub_ext('.yaml')
        File.open(outfilename, "w:utf-8") { |f| f.write index_collection.to_yaml }

        outdir = options[:outdir]
        return unless outdir
        FileUtils.mkdir_p(outdir)

        index_collection.items_flattened.each do |item|
          filename = File.join(
            outdir,
            "#{options[:prefix]}#{item.docidentifier_code}.#{options[:extension]}"
          )
          File.open(filename, "w:UTF-8") { |f| f.write(item.to_yaml) }
        end
      end

      desc "xml2html RELATON-INDEX-XML STYLESHEET LIQUID-TEMPLATE-DIR", "Convert Relaton Collection XML into HTML"

      def xml2html(filename, stylesheet, liquid_dir)
        file = File.read(filename, encoding: "utf-8")
        xml_to_html = Relaton::Cli::XmlToHtmlRenderer.new({
          stylesheet: stylesheet,
          liquid_dir: liquid_dir,
        })
        html_filename = Pathname.new(filename).sub_ext('.html')
        File.open(html_filename, "w:UTF-8") do |f|
          f.write(xml_to_html.render(file))
        end
      end

      desc "yaml2html YAML STYLESHEET LIQUID-TEMPLATE-DIR", "Concatenate Relaton YAML into HTML"

      def yaml2html(filename, stylesheet, liquid_dir)
        yaml2xml(filename, nil, "xml")
        outfilename = Pathname.new(filename).sub_ext('.xml')
        xml2html(outfilename, stylesheet, liquid_dir)
      end

      private

      def fetch_document(code, options)
        if registered_types.include?(options[:type])
          doc = Cli.relaton.fetch_std(code, options[:year], options[:type])
          doc ? doc.to_xml : "No matching bibliographic entry found"
        end
      end

      def supported_type_message
        ["Recognised types:", registered_types.sort.join(", ")].join(" ")
      end

      def registered_types
        @registered_types ||=
          Relaton::Registry.instance.processors.each.map { |_n, pr| pr.prefix }
      end
    end
  end
end
