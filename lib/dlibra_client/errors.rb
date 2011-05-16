#
#
# Author Stian Soiland-Reyes <soiland-reyes@cs.manchester.ac.uk>

module DlibraClient

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
