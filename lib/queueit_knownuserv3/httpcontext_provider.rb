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
    @request

    def initialize(request)
      @request = request
    end

    def userAgent
      return @request.user_agent
    end

    def headers
      return @request.headers
    end

    def url
      return @request.env["rack.url_scheme"] + "://" + @request.env["HTTP_HOST"] + @request.original_fullpath
    end

    def userHostAddress
      return @request.remote_ip
    end

    def cookieManager
      cookieManager = CookieManager.new(@request.cookie_jar)
      return cookieManager
    end

    def requestBodyAsString
      return ''
    end

  end

  # Used to initialize SDK for each request
  class SDKInitializer

    def self.setHttpContext(httpContext)
      if (httpContext.class < IHttpContext)
        HttpContextProvider.setHttpContext(httpContext)
      else
        raise "httpContext must be a subclass of IHttpContext (e.g. MyHttpContext < IHttpContext)"
      end
    end

  end

  class HttpContextProvider
    @@httpContext

    def self.httpContext
      if (defined?(@@httpContext))
        return @@httpContext
      else
        raise "Please initialize the SDK using SDKInitializer.setHttpContext(httpContext) method"
      end
    end

    def self.setHttpContext(httpContext)
      @@httpContext = httpContext
    end

  end
end
