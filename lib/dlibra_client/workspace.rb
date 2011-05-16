#
#
# Author Stian Soiland-Reyes <soiland-reyes@cs.manchester.ac.uk>

require 'rubygems'
require 'uri'
require 'net/https'
require 'dlibra_client/constants'
require 'dlibra_client/errors'
require 'dlibra_client/abstract'
require 'dlibra_client/research_object'

module DlibraClient
  # A connection to a Dlibra SRS Workspace
  class Workspace < Abstract

    attr_reader :base_uri
    attr_reader :username
    attr_reader :password
    def initialize(base_uri, workspace_id, password)
      @base_uri = base_uri
      @uri = URI.join(base_uri+"/", "workspaces/", workspace_id)
      @uri_slash = URI.join(base_uri+"/", "workspaces/", workspace_id+"/")
      @username = workspace_id
      @password = password
      @workspace = self
    end

    def self.create(base_uri, workspace_id, workspace_password, admin_user, admin_password)
      uri = URI.join(base_uri+"/", "workspaces/")
      Net::HTTP.start(uri.host, uri.port) {|http|
        req = Net::HTTP::Post.new(uri.path)
        req.basic_auth admin_user,admin_password
        req.body = workspace_id  + "\n" + workspace_password
        req.content_type = TEXT_PLAIN

        response = http.request(req)
        if ! response.is_a? Net::HTTPCreated
          raise CreationError.new(uri, response)
        end
        # FIXME: Should be picked up from Location header, workaround due to WFE-62
        workspace_uri = URI.join(base_uri+"/", "workspaces/" + workspace_id )
        return Workspace.new(base_uri, workspace_id, workspace_password)
      }

    end

    def create_research_object(name)
      uri = @uri_slash + "ROs"
      Net::HTTP.start(uri.host, uri.port) {|http|
        req = Net::HTTP::Post.new(uri.path)
        req.basic_auth @username, @password
        req.body = name
        req.content_type = TEXT_PLAIN
        response = http.request(req)
        if ! response.is_a? Net::HTTPCreated
          raise CreationError.new(uri, response)
        end
        # FIXME: Should be picked up from Location header, workaround due to WFE-62
        ro_uri = uri.to_s + "/" + name
        return ResearchObject.new(self, ro_uri)
      }
    end

    def [](name)
      ro_uri = @uri_slash + "ROs/" + name
      ro = ResearchObject.new(self, ro_uri)
      if ro.exists?
      return ro
      end
    end

    def each
      ros_uri = @uri_slash + "ROs"
      Net::HTTP.start(ros_uri.host, ros_uri.port) do |http|
        req = Net::HTTP::Get.new(ros_uri.path)
        req.basic_auth @username, @password
        response = http.request(req)
        if ! response.is_a? Net::HTTPOK
          raise RetrievalError.new(ros_uri, response)
        end
        for ro_uri in URI.extract(response.body) do
          yield ResearchObject.new(self, URI.parse(ro_uri))
        end
      end
    end

    def research_objects
      # FIXME: I'm sure there's a cleverer way to do this in Ruby!
      ros = []
      for ro in self
        ros << ro
      end
      return ros
    end

    def delete!(admin_user, admin_password)
      Net::HTTP.start(uri.host, uri.port) {|http|
        req = Net::HTTP::Delete.new(uri.path)
        req.basic_auth admin_user, admin_password
        response = http.request(req)
        if ! response.is_a? Net::HTTPNoContent
          raise DeletionError.new(uri, response)
        end
      }
    end

  end

end
