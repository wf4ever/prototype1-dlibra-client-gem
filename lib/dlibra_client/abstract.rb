#
#
# Author Stian Soiland-Reyes <soiland-reyes@cs.manchester.ac.uk>

require 'rubygems'
require 'uri'
require 'net/https'
require 'rdf'
require 'rdf/rdfxml'
require 'dlibra_client/constants'
require 'dlibra_client/errors'
require 'dlibra_client/annotation_graph'

module DlibraClient
  class Abstract
    def load_rdf_graph(body)
      graph = AnnotationGraph.new(uri)
      #graph = RDF::Graph.new(uri)
      RDF::Reader.for(:rdfxml).new(body) do |reader|
        reader.each_statement do |statement|
          graph << statement
        end
      end
      return graph
    end

    def delete!
      Net::HTTP.start(uri.host, uri.port) do |http|
        req = Net::HTTP::Delete.new(uri.path)
        req.basic_auth workspace.username, workspace.password
        response = http.request(req)
        if ! response.is_a? Net::HTTPNoContent
          raise DeletionError.new(uri, response)
        end
      end
    end

    def uri
      return RDF::URI.new(@uri)
    end
    
  end

end
