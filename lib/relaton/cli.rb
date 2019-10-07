require "thor"
require "relaton"
require "relaton/xml_document"
require_relative "cli/command"

module Relaton
  module Cli
    def self.start(arguments)
      Relaton::Cli::Command.start(arguments)
    end

    # Relaton
    #
    # Based on current setup, we need to initiate a Db instance to
    # register all of it's supported processor backends. To make it
    # easier we have added it as a class method so we can use this
    # whenever necessary.
    #
    def self.relaton
      @relaton ||= Relaton::Db.new("#{Dir.home}/.relaton/cache", nil)
    end

    # @param content [Nokogiri::XML::Document]
    # @return [RelatonBib::BibliographicItem, RelatonIsoBib::IsoBibliongraphicItem]
    def self.parse_xml(doc)
      if (processor = Relaton::Registry.instance.by_type(Relaton::Cli.doctype(doc)))
        processor.from_xml(doc.to_s)
      else
        RelatonBib::XMLParser.from_xml(doc.to_s)
      end
    end

    # @param content [Nokogiri::XML::Document] Document
    # @return [String] Type prefix
    def self.doctype(doc)
      docid = doc.at "docidentifier"
      return docid[:type] if docid && docid[:type]

      docid&.text&.match(/^\w+/)&.to_s
    end
  end
end
