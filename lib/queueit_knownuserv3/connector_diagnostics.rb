module QueueIt
    class ConnectorDiagnostics
        attr_accessor :isEnabled
        attr_accessor :hasError
        attr_accessor :validationResult

        def initialize
            @isEnabled = false
            @hasError = false
            @validationResult = nil
        end

        def setStateWithTokenError(customerId, errorCode)
            @hasError = true
            @validationResult = RequestValidationResult.new(
                "ConnectorDiagnosticsRedirect",
                nil, nil, 
                "https://" + customerId + ".api2.queue-it.net/" + customerId + "/diagnostics/connector/error/?code=" + errorCode, 
                nil, nil)
        end

        def setStateWithSetupError()
            @hasError = true
            @validationResult = RequestValidationResult.new(
                "ConnectorDiagnosticsRedirect",
                nil, nil, 
                "https://api2.queue-it.net/diagnostics/connector/error/?code=setup", 
                nil, nil)
        end

        def self.verify(customerId, secretKey, queueitToken)
            diagnostics = ConnectorDiagnostics.new

            qParams = QueueUrlParams.extractQueueParams(queueitToken)

            if(qParams == nil)
                return diagnostics
            end

            if(qParams.redirectType == nil)
                return diagnostics
            end

            if(not qParams.redirectType.upcase.eql?("DEBUG"))
                return diagnostics
            end

            if(Utils.isNilOrEmpty(customerId) or Utils.isNilOrEmpty(secretKey))
                diagnostics.setStateWithSetupError()
                return diagnostics
            end

            calculatedHash = OpenSSL::HMAC.hexdigest('sha256', secretKey, qParams.queueITTokenWithoutHash)
            if(not qParams.hashCode.eql?(calculatedHash))
                diagnostics.setStateWithTokenError(customerId, "hash")
                return diagnostics
            end
                
            if(qParams.timeStamp < Time.now.getutc.tv_sec)
                diagnostics.setStateWithTokenError(customerId, "timestamp")
                return diagnostics
			end
            
            diagnostics.isEnabled = true

            return diagnostics
        end            
    end
end