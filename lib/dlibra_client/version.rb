#
#
# Author Stian Soiland-Reyes <soiland-reyes@cs.manchester.ac.uk>

require 'rubygems'
require 'uri'
require 'net/https'
require 'date'
require 'rdf'
require 'rdf/rdfxml'
require 'dlibra_client/constants'
require 'dlibra_client/errors'
require 'dlibra_client/metadata'
require 'dlibra_client/resource'

module DlibraClient
  class Version < MetaData
    attr_reader :workspace
    attr_reader :ro
    def initialize(workspace, ro, uri)
      @workspace = workspace
      @ro = ro
      @uri = uri
    end

    def [](path)
      if path[0] != "/"
        path = "/" + path
      end
      resource_uri = @uri.to_s + path
      #puts "Resource " + resource_uri
      resource = Resource.new(workspace, ro, self, resource_uri)
      if resource.exists?
      return resource
      end
    end

    def resources
      # FIXME: I'm sure there's a cleverer way to do this in Ruby!
      resources = []
      for r in self
        resources << r
      end
      return resources
    end

    def each
      Net::HTTP.start(uri.host, uri.port) {|http|
        req = Net::HTTP::Get.new(uri.path)
        req.basic_auth workspace.username, workspace.password
        req["Accept"] = APPLICATION_RDF_XML
        response = http.request(req)
        if ! response.is_a? Net::HTTPOK
          raise RetrievalError.new(uri, response)
        end
        graph = load_rdf_graph(response.body)
        graph.query([uri, ORE.aggregates, nil]) do |s,p,resource|
          yield Resource.new(workspace, ro, self, resource)
        end
      }
    end

    def upload_resource(ro_path, content_type, data)
      resource_uri = URI.parse(uri.to_s + "/") + ro_path
      Net::HTTP.start(resource_uri.host, resource_uri.port) {|http|
      # FIXME: Why is this POST instead of PUT?
        req = Net::HTTP::Post.new(resource_uri.path)
        req.basic_auth workspace.username, workspace.password
        req.content_type = content_type
        req.body = data
        response = http.request(req)
        # FIXME: Why doesn't the server return HTTPNoContent ?
        if ! response.is_a? Net::HTTPSuccess
          raise CreationError.new(resource_uri, response)
        end
        return Resource.new(workspace, ro, self, resource_uri)
      }
    end

    def manifest
      return load_rdf_graph(manifest_rdf)
    end

    def manifest=(annotations)
      rdf_graph = case annotations
      when RDF::Graph then annotations
      else annotations.graph
      end

      rdf_xml = RDF::RDFXML::Writer.buffer do |writer|
        rdf_graph.each_statement do |statement|
          writer << statement
        end
      end
      self.manifest_rdf=rdf_xml
    end

    def manifest_rdf
      resource_uri = URI.parse(uri.to_s + "/manifest.rdf")
      Net::HTTP.start(resource_uri.host, resource_uri.port) {|http|
        req = Net::HTTP::Get.new(resource_uri.path)
        req.basic_auth workspace.username, workspace.password
        req["Accept"] = APPLICATION_RDF_XML
        response = http.request(req)
        if ! response.is_a? Net::HTTPOK
          raise RetrievalError.new(resource_uri, response)
        end
        return response.body
      }
    end

    def manifest_rdf=(rdf_xml)
      resource_uri = URI.parse(uri.to_s + "/manifest.rdf")
      upload_resource(resource_uri, APPLICATION_RDF_XML, rdf_xml)
    end

    def to_zip(file=nil)
      Net::HTTP.start(uri.host, uri.port) do |http|
        req = Net::HTTP::Get.new(uri.path + "?content=true")
        req.basic_auth workspace.username, workspace.password
        req["Accept"] = APPLICATION_ZIP
        http.request(req) do |response|
          if ! response.is_a? Net::HTTPOK
            raise RetrievalError.new(uri, response)
          end
          if (! file)
          return response.body
          end
          response.read_body do |segment|
            file.write(segment)
          end
        end
      end
    end

    def clone(name)

      Net::HTTP.start(@ro.uri.host, @ro.uri.port) do |http|
        req = Net::HTTP::Post.new(@ro.uri.path)
        req.basic_auth workspace.username, workspace.password
        req.content_type = TEXT_PLAIN
        req.body = name + "\n" + self.uri.to_s
        response = http.request(req)
        #puts "Body", req.body
        #puts "Req", req.to_hash
        #puts "Response", response.to_hash
        if ! response.is_a? Net::HTTPCreated
          raise CreationError.new(version_uri, response)
        end
        # FIXME: Created version should be returned from service, workaround due to WFE-62
        version_uri = URI.parse(@ro.uri.to_s + "/") + name
        return Version.new(workspace, self, version_uri)
      end
    end

  end

end
