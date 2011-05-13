#
#
# Author Stian Soiland-Reyes <soiland-reyes@cs.manchester.ac.uk>

require 'rubygems'
require 'rdf'
require 'rdf/rdfxml'


module DlibraClient

    DC = RDF::Vocabulary.new("http://purl.org/dc/elements/1.1/")
    ORE = RDF::Vocabulary.new("http://www.openarchives.org/ore/terms/")    
    OXDS = RDF::Vocabulary.new("http://vocab.ox.ac.uk/dataset/schema#")
    DCTERMS = RDF::DC

    class Annotations
      
      attr_reader :graph
      attr_reader :resource
      
      def initialize(resource=RDF::Node.uuid, graph=RDF::Graph.new)
        @graph = graph        
        @resource = case resource
          when RDF::Resource then resource
          else RDF::URI.parse(resource.to_s)
      end
      end

      def method_missing(property, *args, &block)
          if args.empty?
                # getter
            p = self[property]
                if p.size < 2
                    # unpack singleton list or return nil
                    return p[0]
                else 
                    return p
                end
          elsif args.size == 1 && property.to_s.end_with?("=")
                # setter
            name = property[0..-2]
                value = args[0]
                if ! name.respond_to?(:each) 
                    # wrap it
                    value = [value]
                end
        self[name] = value
                return args[0]
          else
                super # fail
          end
      end

        def each
            graph.query([resource]).each do |s,p,o|
                yield uri_to_key(p), resolve_object(o)
            end
        end
    
    def [](name)
      pred = parse_qname(name)
      results = []
      graph.query([resource, pred]).each do |s,p,o|
                results << resolve_object(o)
      end
            results
    end
    
    def []=(name, values)
      pred = parse_qname(name)
            graph.delete( [resource, pred] )
            for value in values
                if value.is_a? Annotations
                    value = value.resource
                end
                graph << [ resource, pred, value]
            end
            return values
    end

        def keys
            preds = {}
            graph.query([resource]).each do |s,p,o|
               preds[p] = p 
            end
            keys = []
            for k in preds.keys
                keys << uri_to_key(k)
            end
            return keys
        end

        def to_hash
            hash = {}
            for k,v in self
                hash[k] = v
            end
            return hash
        end

        def to_s
            return "<" + resource.to_s + ">"
        end
        def to_str
            return resource.to_str
        end
        def inspect
            return self.to_s + " " + keys.to_s
        end
    
    :protected
        def uri_to_key(uri)
            k = uri.to_s
            for prefix, ns in graph.namespaces
                ns = ns.to_uri.to_s
                if k.start_with?ns
                    return prefix.to_s + "_" + k[ns.size..-1]
                end
            end
            return uri 
        end

    def parse_qname(qname)
      if qname.is_a?(RDF::URI) 
        return qname
      end
      prefix,suffix = qname.to_s.split(/:|_|\./, 2)
      if suffix.nil?
        suffix = prefix
        prefix = ""
      end
      ns = graph.namespaces[prefix.to_sym]
            # Note - method_missing in vocab.rb doesn't like ==
      if nil == ns
        ns = graph.namespaces[:default]
      end
      if nil == ns
        return RDF::URI.parse(qname.to_s)
      end
      return ns[suffix]
    end

        def resolve_object(o)
            case o
                when RDF::Literal then o.object
                else graph.annotations(o)
            end     
        end

      
    end


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
