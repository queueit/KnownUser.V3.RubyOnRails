# KnownUser.V3.RubyOnRails
Before getting started please read the [documentation](https://github.com/queueit/Documentation/tree/main/serverside-connectors) to get acquainted with server-side connectors.

This connector supports Ruby v.1.9.3+ and Rails v.3.2+.

## Installation
Queue-it KnownUser V3 is distributed as a gem, which is how it should be used in your app.

Include the gem in your Gemfile:

```ruby
gem "queueit_knownuserv3"
```

You can find the latest released version [here](https://github.com/queueit/KnownUser.V3.RubyOnRails/releases/latest) and distributed 
gem [here](https://rubygems.org/gems/queueit_knownuserv3).


## Implementation
If we have the `integrationconfig.json` copied in the rails app folder then 
the following example of a controller is all that is needed to validate that a user has been through the queue:

```ruby
class ResourceController < ApplicationController
  def index
    begin
	
      configJson = File.read('integrationconfig.json')
      customerId = "" # Your Queue-it customer ID
      secretKey = "" # Your 72 char secret key as specified in Go Queue-it self-service platform
		
      requestUrl = request.original_url
      pattern = Regexp.new("([\\?&])(" + QueueIt::KnownUser::QUEUEIT_TOKEN_KEY + "=[^&]*)", Regexp::IGNORECASE)
      requestUrlWithoutToken = requestUrl.gsub(pattern, '')
      # The requestUrlWithoutToken is used to match Triggers and as the Target url (where to return the users to).
      # It is therefor important that this is exactly the url of the users browsers. So, if your webserver is 
      # behind e.g. a load balancer that modifies the host name or port, reformat requestUrlWithoutToken before proceeding.		
      # Example of replacing host from requestUrlWithoutToken  
      #requestUriNoToken = URI.parse(requestUrlWithoutToken)
      #requestUriNoToken.host = "INSERT-REPLACEMENT-HOST-HERE"
      #requestUrlWithoutToken = requestUriNoToken.to_s
			
      queueitToken = request.query_parameters[QueueIt::KnownUser::QUEUEIT_TOKEN_KEY.to_sym]

      # Verify if the user has been through the queue
      validationResult = QueueIt::KnownUser.validateRequestByIntegrationConfig(
	                   requestUrlWithoutToken,
			   queueitToken,
			   configJson,
			   customerId,
			   secretKey,			   
			   request)

      if(validationResult.doRedirect)      
        #Adding no cache headers to prevent browsers to cache requests
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, max-age=0"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
        #end
        
        if(!validationResult.isAjaxResult)
            # Send the user to the queue - either becuase hash was missing or becuase is was invalid
            redirect_to validationResult.redirectUrl
        else
            head :ok
            response.headers[validationResult.getAjaxQueueRedirectHeaderKey()] = validationResult.getAjaxRedirectUrl()
        end        
      else
        # Request can continue, we remove queueittoken from url to avoid sharing of user specific token	
	if(requestUrl != requestUrlWithoutToken && validationResult.actionType == "Queue")	
          redirect_to requestUrlWithoutToken
	end
      end
    
    rescue StandardError => stdErr
      # There was an error validating the request
      # Use your own logging framework to log the error
      # This was a configuration error, so we let the user continue
      puts stdErr.message
    end
  end
end
```


## Implementation using inline queue configuration
Specify the configuration in code without using the Trigger/Action paradigm. In this case it is important *only to queue-up page requests* and not requests for resources. 
This can be done by adding custom filtering logic before caling the `QueueIt::KnownUser.resolveQueueRequestByLocalConfig` method. 

The following is an example of how to specify the configuration in code:

```ruby
class ResourceController < ApplicationController	
  def index	
    begin 	  
     
      customerId = "" # Your Queue-it customer ID
      secretKey = "" # Your 72 char secret key as specified in Go Queue-it self-service platform		
      eventConfig = QueueIt::QueueEventConfig.new
      eventConfig.eventId = "" # ID of the queue to use
      eventConfig.queueDomain = "xxx.queue-it.net" # Domain name of the queue.
      # eventConfig.cookieDomain = ".my-shop.com" # Optional - Domain name where the Queue-it session cookie should be saved
      eventConfig.cookieValidityMinute = 15 # Validity of the Queue-it session cookie should be positive number.
      eventConfig.extendCookieValidity = true # Should the Queue-it session cookie validity time be extended each time the validation runs?
      # eventConfig.culture = "da-DK" # Optional - Culture of the queue layout in the format specified here: https:#msdn.microsoft.com/en-us/library/ee825488(v=cs.20).aspx. If unspecified then settings from Event will be used.
      # eventConfig.layoutName = "NameOfYourCustomLayout" # Optional - Name of the queue layout. If unspecified then settings from Event will be used.
      
      requestUrl = request.original_url
      queueitToken = request.query_parameters[QueueIt::KnownUser::QUEUEIT_TOKEN_KEY.to_sym]
      
      # Verify if the user has been through the queue
      validationResult = QueueIt::KnownUser.resolveQueueRequestByLocalConfig(
      	                   requestUrl,
			   queueitToken,
			   eventConfig,
			   customerId,
			   secretKey,
			   request)
      
      if(validationResult.doRedirect)	
        #Adding no cache headers to prevent browsers to cache requests
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate, max-age=0"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
        #end
      	 if(!validationResult.isAjaxResult)
            # Send the user to the queue - either becuase hash was missing or becuase is was invalid
            redirect_to validationResult.redirectUrl
        else
            head :ok
            response.headers[validationResult.getAjaxQueueRedirectHeaderKey()] = validationResult.getAjaxRedirectUrl()
        end
      else
      	# Request can continue - we remove queueittoken form querystring parameter to avoid sharing of user specific token				
      	pattern = Regexp.new("([\\?&])(" + QueueIt::KnownUser::QUEUEIT_TOKEN_KEY + "=[^&]*)", Regexp::IGNORECASE)
      	requestUrlWithoutToken = requestUrl.gsub(pattern, '')
      	
      	if(requestUrl != requestUrlWithoutToken && validationResult.actionType == "Queue")
      	    redirect_to requestUrlWithoutToken
      	end
      end
    rescue StandardError => stdErr
      # There was an error validating the request
      # Use your own logging framework to log the error
      # This was a configuration error, so we let the user continue
      puts stdErr.message
    end
  end
end
```
