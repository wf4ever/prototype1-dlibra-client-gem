#
#
# Author Stian Soiland-Reyes <soiland-reyes@cs.manchester.ac.uk>

require 'rubygems'
require 'uri'
require 'net/https'
require 'dlibra_client/constants'
require 'dlibra_client/metadata'
require 'dlibra_client/version'

module DlibraClient
  class ResearchObject < MetaData
    attr_reader :workspace
    alias :parent :workspace 
    
    def initialize(workspace, uri)
      @workspace = workspace
      @uri = uri
    end

    def [](name)
      ro_uri = @uri.to_s + "/" + name
      version = Version.new(workspace, self, ro_uri)
      if version.exists?
      return version
      end
    end

    def versions
      # FIXME: I'm sure there's a cleverer way to do this in Ruby!
      versions = []
      for v in self
        versions << v
      end
      return versions
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
        metadata.query([uri, ORE.aggregates, nil]) do |s,p,version|
          yield Version.new(workspace, self, URI.parse(version))
        end
      }
    end

    def create_version(name)

      Net::HTTP.start(uri.host, uri.port) {|http|
      # FIXME: Why is this POST instead of PUT?
        req = Net::HTTP::Post.new(uri.path)
        req.body = name
        req.content_type = TEXT_PLAIN
        req.basic_auth workspace.username, workspace.password
        response = http.request(req)
        if ! response.is_a? Net::HTTPCreated
          raise CreationError.new(uri, response)
        end
        # FIXME: Get this from Location header, hardcoded due to WFE-62
        version_uri = @uri.to_s + "/" + name
        return Version.new(workspace, self, version_uri)
      }
    end

    # Special case due to virtual /ROs/
    def name
      parent_uri = self.parent.uri.to_s
      if not parent_uri.end_with?("/ROs/")
        # Evil hack
        parent_uri += "/ROs/"
      end
      return URI.parse(parent_uri).route_to(self.uri.to_s).to_s
    end


  end

end
