#
#
# Author Stian Soiland-Reyes <soiland-reyes@cs.manchester.ac.uk>

require 'rubygems'
require 'uri'
require 'net/https'

module DlibraClient
    # A connection to a Dlibra SRS Workspace
    class Workspace

        attr_reader :uri
        attr_reader :base_uri

        def initialize(base_uri, workspace_id, password) 
            @base_uri = base_uri
            @uri = URI.join(base_uri+"/", "workspaces/", workspace_id+"/")
            @username = workspace_id
            @password = password
        end

        def self.create(base_uri, workspace_id, workspace_password, admin_user, admin_password)
            uri = URI.join(base_uri+"/", "workspaces/", workspace_id)
            Net::HTTP.start(uri.host, uri.port) {|http|
                req = Net::HTTP::Put.new(uri.path)
                req.basic_auth admin_user,admin_password 
                req.body = workspace_password
                req.add_field "Content-Type", "text/plain"

                response = http.request(req)
                if ! response.is_a? Net::HTTPCreated 
                   raise WorkspaceCreationError.new(uri, response)
                end
                return Workspace.new(base_uri, workspace_id, workspace_password)
            }

        end

        def create_research_object(name)
            ro_uri = uri + "ROs/" + name
            Net::HTTP.start(ro_uri.host, ro_uri.port) {|http|
                req = Net::HTTP::Put.new(ro_uri.path)
                req.basic_auth @username, @password
                response = http.request(req)
                if ! response.is_a? Net::HTTPCreated 
                   raise ResearchObjectCreationError.new(ro_uri, response)
                end
                return ResearchObject.new(self, ro_uri)
            }
        end

             

        def research_objects() 
            return []
        end
    end

    class ResearchObject
        attr_reader :workspace
        attr_reader :uri
        def initialize(workspace, uri)
            @workspace = workspace
            @uri = uri
        end    
    end

    class DlibraError < StandardError
    end

    class DlibraHttpError < DlibraError
        def initialize(uri, response)
            @uri = uri
            @response = response
            super "#{response.code} from #{uri}: #{response.body}"
        end
        
        attr :uri
        attr :response
    end

    class CreationError < DlibraHttpError
    end
    class WorkspaceCreationError < CreationError
    end
    class ResearchCreationError < CreationError
    end


end
