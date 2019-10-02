>You can find the latest released version [here](https://github.com/queueit/KnownUser.V3.RubyOnRails/releases/latest).

# KnownUser.V3.RubyOnRails
The Queue-it Security Framework is used to ensure that end users cannot bypass the queue by adding a server-side integration to your server. It supports ruby > 1.9.3 and rails > 3.2 .

## Introduction
When a user is redirected back from the queue to your website, the queue engine can attache a query string parameter (`queueittoken`) containing some information about the user. 
The most important fields of the `queueittoken` are:

 - q - the users unique queue identifier
 - ts - a timestamp of how long this redirect is valid
 - h - a hash of the token


The high level logic is as follows:

![The KnownUser validation flow](https://github.com/queueit/KnownUser.V3.RubyOnRails/blob/master/Documentation/KnownUserFlow.png)

 1. User requests a page on your server
 2. The validation method sees that the has no Queue-it session cookie and no `queueittoken` and sends him to the correct queue based on the configuration
 3. User waits in the queue
 4. User is redirected back to your website, now with a `queueittoken`
 5. The validation method validates the `queueittoken` and creates a Queue-it session cookie
 6. The user browses to a new page and the Queue-it session cookie will let him go there without queuing again

## How to validate a user
To validate that the current user is allowed to enter your website (has been through the queue) these steps are needed:

 1. Providing the queue configuration to the KnownUser validation
 2. Validate the `queueittoken` and store a session cookie


### 1. Providing the queue configuration
The recommended way is to use the Go Queue-it self-service portal to setup the configuration. 
The configuration specifies a set of Triggers and Actions. A Trigger is an expression matching one, more or all URLs on your website. 
When a user enter your website and the URL matches a Trigger-expression the corresponding Action will be triggered. 
The Action specifies which queue the users should be send to. 
In this way you can specify which queue(s) should protect which page(s) on the fly without changing the server-side integration.

This configuration can then be downloaded to your application server. 
Read more about how *[here](https://github.com/queueit/KnownUser.V3.RubyOnRails/tree/master/Documentation)*.

### 2. Validate the `queueittoken` and store a session cookie
To validate that the user has been through the queue, use the `QueueIT::KnownUser.validateRequestByIntegrationConfig` method. 
This call will validate the timestamp and hash and if valid create a "QueueITAccepted-SDFrts345E-V3_[EventId]" cookie with a TTL as specified in the configuration.
If the timestamp or hash is invalid, the user is send back to the queue.


## Implementation
The KnownUser validation must be done on *all requests except requests for static resources like images, css files and ...*. 
So, if you add the KnownUser validation logic to a central place, then be sure that the Triggers only fire on page requests (including ajax requests) and not on e.g. image.

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
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
        #end
        
        # Send the user to the queue - either because hash was missing or because is was invalid
	redirect_to validationResult.redirectUrl
      else
        # Request can continue, we remove queueittoken from url to avoid sharing of user specific token	
	if(requestUrl != requestUrlWithoutToken)
            redirect_to requestUrlWithoutToken
	end
      end
    
    rescue StandardError => stdErr
      # There was an error validationg the request
      # Use your own logging framework to log the Exception
      # This was a configuration exception, so we let the user continue
      puts stdErr.message
    end
  end
end
```

## Installation
Queue-it KnownUser V3 is distributed as a gem, which is how it should be used in your app.

Include the gem in your Gemfile:

```ruby
gem "queueit_knownuserv3"
```

## Alternative Implementation

### Queue configuration

If your application server (maybe due to security reasons) is not allowed to do external GET requests, then you have three options:

1. Manually download the configuration file from Queue-it Go self-service portal, save it on your application server and load it from local disk
2. Use an internal gateway server to download the configuration file and save to application server
3. Specify the configuration in code without using the Trigger/Action paradigm. In this case it is important *only to queue-up page requests* and not requests for resources or AJAX calls. 
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
      eventConfig.queueDomain = "xxx.queue-it.net" # Domain name of the queue - usually in the format [CustomerId].queue-it.net
      # eventConfig.cookieDomain = ".my-shop.com" # Optional - Domain name where the Queue-it session cookie should be saved
      eventConfig.cookieValidityMinute = 15 # Optional - Validity of the Queue-it session cookie. Default is 10 minutes
      eventConfig.extendCookieValidity = true # Optional - Should the Queue-it session cookie validity time be extended each time the validation runs? Default is true.
      # eventConfig.culture = "da-DK" # Optional - Culture of the queue ticket layout in the format specified here: https:#msdn.microsoft.com/en-us/library/ee825488(v=cs.20).aspx Default is to use what is specified on Event
      # eventConfig.layoutName = "NameOfYourCustomLayout" # Optional - Name of the queue ticket layout - e.g. "Default layout by Queue-it". Default is to take what is specified on the Event
      
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
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
        response.headers["Pragma"] = "no-cache"
        response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
        #end
      	
        # Send the user to the queue - either becuase hash was missing or becuase is was invalid
      	redirect_to validationResult.redirectUrl
      else
      	# Request can continue - we remove queueittoken form querystring parameter to avoid sharing of user specific token				
      	pattern = Regexp.new("([\\?&])(" + QueueIt::KnownUser::QUEUEIT_TOKEN_KEY + "=[^&]*)", Regexp::IGNORECASE)
      	requestUrlWithoutToken = requestUrl.gsub(pattern, '')
      	
      	if(requestUrl != requestUrlWithoutToken)
      	    redirect_to requestUrlWithoutToken
      	end
      end
    rescue StandardError => stdErr
      # There was an error validationg the request
      # Use your own logging framework to log the Exception
      # This was a configuration exception, so we let the user continue
      puts stdErr.message
    end
  end
end
```
### Protecting ajax calls on static pages
If you have some static html pages (might be behind cache servers) and you have some ajax calls from those pages needed to be protected by KnownUser library you need to follow these steps:
1) You are using v.3.5.1 (or later) of the KnownUser library.
2) Make sure KnownUser code will not run on static pages (by ignoring those URLs in your integration configuration).
3) Add below JavaScript tags to static pages :
```
<script type="text/javascript" src="//static.queue-it.net/script/queueclient.min.js"></script>
<script
 data-queueit-intercept-domain="{YOUR_CURRENT_DOMAIN}"
   data-queueit-intercept="true"
  data-queueit-c="{YOUR_CUSTOMER_ID}"
  type="text/javascript"
  src="//static.queue-it.net/script/queueconfigloader.min.js">
</script>
```
4) Use the following method to protect all dynamic calls (including dynamic pages and ajax calls).
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
        response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
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
	if(requestUrl != requestUrlWithoutToken && !validationResult.actionType.nil? && !validationResult.actionType.empty?)
          redirect_to requestUrlWithoutToken
	end
      end
    
    rescue StandardError => stdErr
      # There was an error validationg the request
      # Use your own logging framework to log the Exception
      # This was a configuration exception, so we let the user continue
      puts stdErr.message
    end
  end
end
```
