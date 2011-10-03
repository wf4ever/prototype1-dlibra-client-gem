#
#
# Author Stian Soiland-Reyes <soiland-reyes@cs.manchester.ac.uk>

require 'rubygems'
require 'net/https'
require 'dlibra_client/errors'
require 'dlibra_client/constants'
require 'dlibra_client/abstract'

module DlibraClient
  class MetaData < Abstract
    def metadata
      return load_rdf_graph(metadata_rdf)
    end

    #        def metadata=(rdf_graph)
    #            rdf_xml = RDF::RDFXML::Writer.buffer do |writer|
    #              rdf_graph.each_statement do |statement|
    #                writer << statement
    #              end
    #            end
    #            self.metadata_rdf=rdf_xml
    #        end

    def metadata_rdf
      resource_uri = uri
      #puts "Getting metadata for ", uri
      Net::HTTP.start(resource_uri.host, resource_uri.port) do |http|
        req = Net::HTTP::Get.new(resource_uri.path)
        req.basic_auth @workspace.username, @workspace.password
        req["Accept"] = APPLICATION_RDF_XML
        response = http.request(req)
        if ! response.is_a? Net::HTTPOK
          raise RetrievalError.new(resource_uri, response)
        end
        return response.body
      end
    end

    #        def metadata_rdf=(rdf_xml)
    #            resource_uri = uri
    #            Net::HTTP.start(resource_uri.host, resource_uri.port) do |http|
    #                req = Net::HTTP::Post.new(resource_uri.path)
    #                req.basic_auth @workspace.username, @workspace.password
    #                req.content_type = APPLICATION_RDF_XML
    #                req.body = rdf_xml
    #                response = http.request(req)
    #                if ! response.is_a? Net::HTTPSuccess
    #                   raise CreationError.new(resource_uri, response)
    #                end
    #            end
    #        end

    def exists?
      Net::HTTP.start(uri.host, uri.port) do |http|
        req = Net::HTTP::Head.new(uri.path)
        req.basic_auth @workspace.username, @workspace.password
        req["Accept"] = APPLICATION_RDF_XML
        response = http.request(req)
        if response.is_a? Net::HTTPNotFound
          return false
        end
        #puts "Checking " + uri.to_s
        #puts response
        #puts response.to_hash
        if ! response.is_a? Net::HTTPOK
          raise RetrievalError.new(uri, response)
        end
        return true
      end
    end
    
    def name
      parent_uri = @parent.uri.to_s
      if not parent_uri.end_width? "/" do
        # Evil hack
        parent_uri += "/"
      end
      return URI.parse(parent_uri).route_to(self.uri.to_s)
    end
    end

  end

end
