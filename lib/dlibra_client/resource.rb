#
#
# Author Stian Soiland-Reyes <soiland-reyes@cs.manchester.ac.uk>

require 'rubygems'
require 'uri'
require 'net/https'
require 'date'

require 'dlibra_client/errors'
require 'dlibra_client/constants'

module DlibraClient

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


   
end
