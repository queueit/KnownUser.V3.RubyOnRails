module QueueIt
  class IHttpContext
    def userAgent
      raise 'userAgent not implemented'
    end

    def headers
      raise 'headers not implemented'
    end

    def url
      raise 'url not implemented'
    end

    def userHostAddress
      raise 'userHostAddress not implemented'
    end

    def cookieManager
      raise 'cookieManager not implemented'
    end

    def requestBodyAsString
      raise 'requestBodyAsString not implemented'
    end
  end

  class RailsHttpContext < IHttpContext
    def initialize(request)
      @request = request
    end

    def userAgent
      @request.user_agent
    end

    def headers
      @request.headers
    end

    def url
      @request.env["rack.url_scheme"] + "://" + @request.env["HTTP_HOST"] + @request.original_fullpath
    end

    def userHostAddress
      @request.remote_ip
    end

    def cookieManager
      CookieManager.new(@request.cookie_jar)
    end

    def requestBodyAsString
      ''
    end
  end


  class HttpContextProvider

		def initialize(httpContext, userInQueueService = nil)
			@httpContext = httpContext
			@userInQueueService = userInQueueService
		end

    def httpContext
      @httpContext
    end

    def userInQueueService
      @userInQueueService
    end
  end
end