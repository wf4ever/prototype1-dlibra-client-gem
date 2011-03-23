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

        def initialize(workspace_uri, username, password) 
            @uri = URI.parse(workspace_uri)
            @username = username
            @password = password
        end

        def research_objects() 
            return []
        end
    end

end
