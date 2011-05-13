#
#
# Author Stian Soiland-Reyes <soiland-reyes@cs.manchester.ac.uk>

require 'rubygems'
require 'uri'
require 'net/https'
require 'date'
require 'rdf'
require 'rdf/rdfxml'

require 'dlibra_client/annotation_graph.rb'

module DlibraClient
    APPLICATION_RDF_XML="application/rdf+xml"
    APPLICATION_ZIP="application/zip"
    TEXT_PLAIN="text/plain"



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
            Net::HTTP.start(uri.host, uri.port) {|http|
                req = Net::HTTP::Delete.new(uri.path)
                req.basic_auth workspace.username, workspace.password
                response = http.request(req)
                if ! response.is_a? Net::HTTPNoContent
                   raise DeletionError.new(uri, response)
                end
            }
        end
        def uri
        	return RDF::URI.new(@uri)
        end
	end
	
	class MetaData < Abstract
		def metadata
            return load_rdf_graph(metadata_rdf)      	
        end
        
#        def metadata=(rdf_graph)        	
#			rdf_xml = RDF::RDFXML::Writer.buffer do |writer|
#			  rdf_graph.each_statement do |statement|
#			    writer << statement
#			  end
#			end
#        	self.metadata_rdf=rdf_xml
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
#    	end
		
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
		
		
	end

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

    class ResearchObject < MetaData
        attr_reader :workspace
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

  
    end

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



    class Resource < MetaData
        attr_reader :workspace
        attr_reader :ro
        attr_reader :version
        def initialize(workspace, ro, version, uri)
            @workspace = workspace
            @ro = ro
            @version = version
            @uri = uri
        end
        
        def content(file=nil)
            resource_uri = URI.parse(uri.to_s + "?content=true")
        	Net::HTTP.start(resource_uri.host, resource_uri.port) do |http|
                req = Net::HTTP::Get.new(resource_uri.path + "?content=true")
                req.basic_auth workspace.username, workspace.password
                http.request(req) do |response|                
	                if ! response.is_a? Net::HTTPOK
	                   raise RetrievalError.new(resource_uri, response)
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
        
        def content=(value, type=content_type)
        	resource_uri = uri            
             Net::HTTP.start(resource_uri.host, resource_uri.port) do |http|
                req = Net::HTTP::Post.new(resource_uri.path)
                req.basic_auth workspace.username, workspace.password
                req.content_type = type                
                req.body = value
                response = http.request(req)
                if ! response.is_a? Net::HTTPSuccess
                   raise CreationError.new(resource_uri, response)
                end
            end
        end
        

		def content_type
			return metadata.first_value([uri, DlibraClient::DCTERMS.type])
		end

		def size
			return metadata.first_value([uri, DlibraClient::DCTERMS.extent]).to_i
		end

		def modified
			date = metadata.first_value([uri, DlibraClient::DCTERMS.modified])
			return DateTime.parse(date)
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
        
        attr_reader :uri
        attr_reader :response
    end


    class CreationError < DlibraHttpError
    end

    class DeletionError < DlibraHttpError
    end

    class RetrievalError < DlibraHttpError
    end
   
end
