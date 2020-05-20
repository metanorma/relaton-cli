require "nokogiri"
require "liquid"
require 'pp'

module Relaton::Cli
  class XmlToHtmlRenderer
    def initialize(liquid_dir: nil, stylesheet: nil)
      @liquid_dir = liquid_dir
      @stylesheet = read_file(stylesheet)
      init_liquid_template_and_filesystem
    end

    def render(index_xml)
      Liquid::Template.
        parse(template).
        render(build_liquid_document(index_xml))
    end

    def uri_for_extension(uri, extension)
      unless uri.nil?
        uri.sub(/\.[^.]+$/, ".#{extension.to_s}")
      end
    end

    # Render HTML
    #
    # This interface allow us to convert a Relaton XML to HTML
    # using the specified liquid template and stylesheets. It
    # also do some minor clean during this conversion.
    #
    def self.render(file, options)
      new(options).render(file)
    end

    private

    attr_reader :stylesheet, :liquid_dir, :template

    def read_file(file)
      File.read(file, encoding: "utf-8")
    end

    def build_liquid_document(source)
      bibcollection = build_bibcollection(source)

      hash_to_liquid({
        depth: 2,
        css: stylesheet,
        title: bibcollection.title,
        author: bibcollection.author,
        documents: document_items(bibcollection)
      })
    end

    def init_liquid_template_and_filesystem
      file_system = Liquid::LocalFileSystem.new(liquid_dir)
      @template = read_file(file_system.full_path("index"))

      Liquid::Template.file_system = file_system
    end

    # TODO: This should be recursive, but it's not
    def hash_to_liquid(hash)
      hash.map do |key, value|
        case key
        when "title"
          if value.is_a?(Array)
            title = value.detect { |t| t["type"] == "main" } || value.first
            v = title ? title["content"] : nil
          elsif value.is_a?(Hash) then v = value["content"]
          else v = value
          end
        when "docid"
          if value.is_a?(Array)
            v = value.detect { |did| did["id"] !~ /^(http|https):\/\// } || value.first
          else v = value
          end
        else v = value
        end
        [key.to_s, empty2nil(v)]
      end.to_h
    end

    def empty2nil(value)
      value unless value.is_a?(String) && value.empty? && !value.nil?
    end

    def build_bibcollection(source)
      Relaton::Bibcollection.from_xml(Nokogiri::XML(source))
    end

    def document_items(bibcollection)
      bibcollection.to_h["root"]["items"].map { |item| hash_to_liquid(item) }
    end
  end
end
