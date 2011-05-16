#
#
# Author Stian Soiland-Reyes <soiland-reyes@cs.manchester.ac.uk>

require 'rubygems'
require 'rdf'

require 'annotations.rb'

module DlibraClient

    DC = RDF::Vocabulary.new("http://purl.org/dc/elements/1.1/")
    ORE = RDF::Vocabulary.new("http://www.openarchives.org/ore/terms/")    
    OXDS = RDF::Vocabulary.new("http://vocab.ox.ac.uk/dataset/schema#")
    DCTERMS = RDF::DC

    class AnnotationGraph < RDF::Graph
        attr_reader :uri
      attr_reader :namespaces

        def self.default_namespaces
            {
             :dc => RDF::DC,
             :ore => ORE,
             :oxds => OXDS,
             :rdf => RDF,
             :dcterms => RDF::DC,
             :rdfs => RDF::RDFS,
             :owl => RDF::OWL,
             :xsd => RDF::XSD,
             :foaf => RDF::FOAF,
             :geo => RDF::GEO,

             :default => RDF::DC,
            }
        end
        def initialize(uri, namespaces=AnnotationGraph.default_namespaces)
            super
            @uri = RDF::URI.new(uri)    
            @namespaces = namespaces
        end
        def annotations(path=nil)
            if path == nil
                annotation_uri = uri  
            elsif path.is_a? RDF::Resource
                annotation_uri = path
            else 
                annotation_uri = RDF::URI.new(URI.join(uri, path))
            end 
            return Annotations.new(annotation_uri, self)           
        end
    end
end
