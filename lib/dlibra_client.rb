#
#
# Author Stian Soiland-Reyes <soiland-reyes@cs.manchester.ac.uk>

require 'rubygems'
require 'uri'
require 'net/https'
require 'rdf'
require 'rdf/rdfxml'


module DlibraClient
    APPLICATION_RDF_XML="application/rdf+xml"
    DC = RDF::Vocabulary.new("http://purl.org/dc/elements/1.1/")
    ORE = RDF::Vocabulary.new("http://www.openarchives.org/ore/terms/")    
    DCTERMS = RDF::Vocabulary.new("http://purl.org/dc/terms/")
    OXDS = RDF::Vocabulary.new("http://vocab.ox.ac.uk/dataset/schema#")


    # A connection to a Dlibra SRS Workspace
    class Workspace

        attr_reader :uri
        attr_reader :base_uri
        attr_reader :username
        attr_reader :password

        def initialize(base_uri, workspace_id, password) 
            @base_uri = base_uri
            @uri = URI.join(base_uri+"/", "workspaces/", workspace_id)
            @uri_slash = URI.join(base_uri+"/", "workspaces/", workspace_id+"/")
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
            ro_uri = @uri_slash + "ROs/" + name
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

        def research_objects 
            ros_uri = @uri_slash + "ROs" 
            Net::HTTP.start(ros_uri.host, ros_uri.port) {|http|
                req = Net::HTTP::Get.new(ros_uri.path)
                req.basic_auth @username, @password
                response = http.request(req)
                if ! response.is_a? Net::HTTPOK
                   raise ResearchObjectRetrievalError.new(ros_uri, response)
                end

                ros = []
                for ro_uri in URI.extract(response.body) do
                    ros << ResearchObject.new(self, URI.parse(ro_uri))
                end
                return ros
            }
        end

        def delete!(admin_user, admin_password)
            Net::HTTP.start(uri.host, uri.port) {|http|
                req = Net::HTTP::Delete.new(uri.path)
                req.basic_auth admin_user, admin_password
                response = http.request(req)
                if ! response.is_a? Net::HTTPNoContent
                   raise WorkspaceDeletionError.new(uri, response)
                end
            }
        end


    end

    class ResearchObject
        attr_reader :workspace
        attr_reader :uri
        def initialize(workspace, uri)
            @workspace = workspace
            @uri = uri
        end    

        def versions
            Net::HTTP.start(uri.host, uri.port) {|http|
                req = Net::HTTP::Get.new(uri.path)
                req.basic_auth workspace.username, workspace.password
                req.add_field "Accept", APPLICATION_RDF_XML
                response = http.request(req)
                if ! response.is_a? Net::HTTPOK
                   raise ResearchObjectRetrievalError.new(uri, response)
                end

                versions = []
                if response.body
                    graph = load_rdf_graph(response.body)
                    ro_uri = RDF::URI(uri)
                    graph.query([ro_uri, ORE.aggregates, nil]) do |s,p,version| 
                        versions << Version.new(workspace, self, URI.parse(version))
                    end
                end
                return versions
            }
        end

        def load_rdf_graph(body)
            graph = RDF::Graph.new()
            RDF::Reader.for(:rdfxml).new(body) do |reader|
                reader.each_statement do |statement|
                    graph << statement
                end
            end
            return graph
        end

        def create_version(name)
            version_uri = URI.parse(@uri.to_s + "/") + name
            Net::HTTP.start(version_uri.host, version_uri.port) {|http|
                req = Net::HTTP::Post.new(version_uri.path)
                req.basic_auth workspace.username, workspace.password
                response = http.request(req)
                if ! response.is_a? Net::HTTPCreated 
                   raise VersionCreationError.new(version_uri, response)
                end
                return Version.new(workspace, self, version_uri)
            }
        end

        def delete!
            Net::HTTP.start(uri.host, uri.port) {|http|
                req = Net::HTTP::Delete.new(uri.path)
                req.basic_auth workspace.username, workspace.password
                response = http.request(req)
                if ! response.is_a? Net::HTTPNoContent
                   raise ResearchObjectDeletionError.new(uri, response)
                end
            }
        end
    end

    class Version
        attr_reader :workspace
        attr_reader :ro
        attr_reader :uri
        def initialize(workspace, ro, uri)
            @workspace = workspace
            @ro = ro
            @uri = uri
        end    
        def delete!
            Net::HTTP.start(uri.host, uri.port) {|http|
                req = Net::HTTP::Delete.new(uri.path)
                req.basic_auth workspace.username, workspace.password
                response = http.request(req)
                if ! response.is_a? Net::HTTPNoContent
                   raise VersionDeletionError.new(uri, response)
                end
            }
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
    class ResearchObjectCreationError < CreationError
    end
    class VersionCreationError < CreationError
    end

    class DeletionError < DlibraHttpError
    end
    class WorkspaceDeletionError < DeletionError
    end
    class ResearchObjectDeletionError < DeletionError
    end
    class VersionDeletionError < DeletionError
    end

    class RetrievalError < DlibraHttpError
    end
    class WorkspaceRetrievalError < RetrievalError
    end
    class ResearchObjectRetrievalError < RetrievalError
    end
    class VersionRetrievalError < RetrievalError
    end

end
