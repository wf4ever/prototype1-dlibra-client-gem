#
#
# Author Stian Soiland-Reyes <soiland-reyes@cs.manchester.ac.uk>

require 'rubygems'
require 'uri'
require 'net/https'
require 'date'
require 'rdf'
require 'rdf/rdfxml'



module DlibraClient
    APPLICATION_RDF_XML="application/rdf+xml"
    APPLICATION_ZIP="application/zip"
    TEXT_PLAIN="text/plain"
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
            Net::HTTP.start(resource_uri.host, resource_uri.port) do |http|
                req = Net::HTTP::Get.new(resource_uri.path)
                req.basic_auth @workspace.username, @workspace.password
                req.add_field "Accept", APPLICATION_RDF_XML
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
				req.add_field "Accept", APPLICATION_RDF_XML
				response = http.request(req)
				if response.is_a? Net::HTTPNotFound
					return false
				end
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
            uri = URI.join(base_uri+"/", "workspaces/", workspace_id)
            Net::HTTP.start(uri.host, uri.port) {|http|
                req = Net::HTTP::Put.new(uri.path)
                req.basic_auth admin_user,admin_password 
                req.body = workspace_password
                req.add_field "Content-Type", "text/plain"

                response = http.request(req)
                if ! response.is_a? Net::HTTPCreated 
                   raise CreationError.new(uri, response)
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
                   raise CreationError.new(ro_uri, response)
                end
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
            req.add_field "Accept", APPLICATION_RDF_XML
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
            version_uri = URI.parse(@uri.to_s + "/") + name
            Net::HTTP.start(version_uri.host, version_uri.port) {|http|
                # FIXME: Why is this POST instead of PUT?
                req = Net::HTTP::Post.new(version_uri.path)
                req.basic_auth workspace.username, workspace.password
                response = http.request(req)
                if ! response.is_a? Net::HTTPCreated 
                   raise CreationError.new(version_uri, response)
                end
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
                req.add_field "Accept", APPLICATION_RDF_XML
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
                req.add_field "Accept", APPLICATION_RDF_XML
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
                req = Net::HTTP::Get.new(uri.path)
                req.basic_auth workspace.username, workspace.password
                req.add_field "Accept", APPLICATION_ZIP
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
        	version_uri = URI.parse(@ro.uri.to_s + "/") + name
            Net::HTTP.start(version_uri.host, version_uri.port) do |http|
                req = Net::HTTP::Post.new(version_uri.path)
                req.basic_auth workspace.username, workspace.password
                req.content_type = TEXT_PLAIN
                req.body = self.uri.to_s
                response = http.request(req)
                if ! response.is_a? Net::HTTPCreated 
                   raise CreationError.new(version_uri, response)
                end
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
