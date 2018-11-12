require "nokogiri"
require "liquid"
require 'pp'

module Relaton::Cli
  class XmlToHtmlRenderer

    def initialize(options)
      @liquid_dir = options[:liquid_dir]
      @stylesheet = File.read(options[:stylesheet], encoding: "utf-8")

      puts "HTML html_template_dir #{@liquid_dir}"
      @file_system = Liquid::LocalFileSystem.new(@liquid_dir)
      @template = File.read(@file_system.full_path("index"), encoding: "utf-8")
      Liquid::Template.file_system = @file_system
    end

    def ns(xpath)
      xpath.gsub(%r{/([a-zA-z])}, "/xmlns:\\1").
        gsub(%r{::([a-zA-z])}, "::xmlns:\\1").
        gsub(%r{\[([a-zA-z][a-z0-9A-Z@/]* ?=)}, "[xmlns:\\1").
        gsub(%r{\[([a-zA-z][a-z0-9A-Z@/]*\])}, "[xmlns:\\1")
    end

    def empty2nil(v)
      return nil if !v.nil? && v.is_a?(String) && v.empty?
      v
    end

    # TODO: This should be recursive, but it's not
    def hash_to_liquid(hash)
      hash.map { |k, v| [k.to_s, empty2nil(v)] }.to_h
    end

    def render(index_xml)
      source = Nokogiri::XML(index_xml)
      bibcollection = ::Relaton::Bibcollection.from_xml(source)
      locals = {
        css: @stylesheet,
        title: bibcollection.title,
        author: bibcollection.author,
        documents: bibcollection.to_h["root"]["items"].map { |i| hash_to_liquid(i) },
        depth: 2
      }
      Liquid::Template.parse(@template).render(hash_to_liquid(locals))
    end

    def uri_for_extension(uri, extension)
      return nil if uri.nil?
      uri.sub(/\.[^.]+$/, ".#{extension.to_s}")
    end

    def self.render(file, options)
      new(options).render(file)
    end
  end
end
