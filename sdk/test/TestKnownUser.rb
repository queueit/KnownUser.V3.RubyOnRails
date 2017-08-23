require 'test/unit'
require 'json'
require_relative '../KnownUser'

class HttpRequestMock
	attr_accessor :user_agent
end

class UserInQueueServiceMock
	attr_reader :cancelQueueCookieCalls
	attr_reader :extendQueueCookieCalls
	attr_reader :validateRequestCalls

	def initialize
		@cancelQueueCookieCalls = {}
		@extendQueueCookieCalls = {}
		@validateRequestCalls = {}
	end
	
	def cancelQueueCookie(eventId, cookieDomain)	
		@cancelQueueCookieCalls[@cancelQueueCookieCalls.length] = {
            "eventId" => eventId,
            "cookieDomain" => cookieDomain
        }
	end

	def extendQueueCookie(eventId, cookieValidityMinute, cookieDomain, secretKey)		
		@extendQueueCookieCalls[@extendQueueCookieCalls.length] = {
            "eventId" => eventId,
			"cookieValidityMinute" => cookieValidityMinute,
            "cookieDomain" => cookieDomain,
			"secretKey" => secretKey
        }
	end

	def validateRequest(targetUrl, queueitToken, config, customerId, secretKey)
		@validateRequestCalls[@validateRequestCalls.length] = {
            "targetUrl" => targetUrl,
			"queueitToken" => queueitToken,
            "config" => config,
			"customerId" => customerId,
            "secretKey" => secretKey
        }
	end
end

class TestKnownUser < Test::Unit::TestCase
	def test_cancelQueueCookie
		userInQueueService = UserInQueueServiceMock.new 
		KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)		
		
		KnownUser.cancelQueueCookie("evtId", "domain", {})
		
		assert( userInQueueService.cancelQueueCookieCalls[0]["eventId"] == "evtId" )
		assert( userInQueueService.cancelQueueCookieCalls[0]["cookieDomain"] == "domain" )
	end

	def test_cancelQueueCookie_nil_EventId
		errorThrown = false
        
		begin
            KnownUser.cancelQueueCookie(nil, "cookieDomain", {})
		rescue KnownUserError => err
			errorThrown = err.message.eql? "eventId can not be nil or empty."
		end
		
		assert( errorThrown )
	end

	def test_extendQueueCookie_nil_EventId
		errorThrown = false
        
		begin
            KnownUser.extendQueueCookie(nil, 10, "cookieDomain", "secretkey", {})
		rescue KnownUserError => err
			errorThrown = err.message.eql? "eventId can not be nil or empty."
		end
		
		assert( errorThrown )
	end

	def test_extendQueueCookie_nil_SecretKey
		errorThrown = false
        
		begin
            KnownUser.extendQueueCookie("eventId", 10, "cookieDomain", nil, {})
		rescue KnownUserError => err
			errorThrown = err.message.eql? "secretKey can not be nil or empty."
		end
		
		assert( errorThrown )
	end

	def test_extendQueueCookie_Invalid_CookieValidityMinute
		errorThrown = false
        
		begin
            KnownUser.extendQueueCookie("eventId", "invalidInt", "cookieDomain", "secrettKey", {})
		rescue KnownUserError => err
			errorThrown = err.message.eql? "cookieValidityMinute should be integer greater than 0."
		end
		
		assert( errorThrown )
	end

	def test_extendQueueCookie_Negative_CookieValidityMinute
		errorThrown = false
        
		begin
            KnownUser.extendQueueCookie("eventId", -1, "cookieDomain", "secrettKey", {})
		rescue KnownUserError => err
			errorThrown = err.message.eql? "cookieValidityMinute should be integer greater than 0."
		end
		
		assert( errorThrown )
	end

	def test_extendQueueCookie
		userInQueueService = UserInQueueServiceMock.new 
		KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)		
		
		KnownUser.extendQueueCookie("evtId", 10, "domain", "key", {})
		
		assert( userInQueueService.extendQueueCookieCalls[0]["eventId"] == "evtId" )
		assert( userInQueueService.extendQueueCookieCalls[0]["cookieValidityMinute"] == 10 )
		assert( userInQueueService.extendQueueCookieCalls[0]["cookieDomain"] == "domain" )
		assert( userInQueueService.extendQueueCookieCalls[0]["secretKey"] == "key" )		
	end

	def test_validateRequestByLocalEventConfig_empty_eventId
		eventconfig = EventConfig.new
		eventconfig.cookieDomain = "cookieDomain"
        eventconfig.layoutName = "layoutName"
        eventconfig.culture = "culture"
        #eventconfig.eventId = "eventId"
        eventconfig.queueDomain = "queueDomain"
        eventconfig.extendCookieValidity = true
        eventconfig.cookieValidityMinute = 10
        eventconfig.version = 12

		errorThrown = false
        
		begin
            KnownUser.validateRequestByLocalEventConfig("targeturl", "queueIttoken", eventconfig, "customerid", "secretkey", {})
		rescue KnownUserError => err
			errorThrown = err.message.eql? "eventConfig.eventId can not be nil or empty."
		end
		
		assert( errorThrown )
	end

	def test_validateRequestByLocalEventConfig_empty_secretKey
		eventconfig = EventConfig.new
		eventconfig.cookieDomain = "cookieDomain"
        eventconfig.layoutName = "layoutName"
        eventconfig.culture = "culture"
        eventconfig.eventId = "eventId"
        eventconfig.queueDomain = "queueDomain"
        eventconfig.extendCookieValidity = true
        eventconfig.cookieValidityMinute = 10
        eventconfig.version = 12

		errorThrown = false
        
		begin
            KnownUser.validateRequestByLocalEventConfig("targeturl", "queueIttoken", eventconfig, "customerid", nil, {})
		rescue KnownUserError => err
			errorThrown = err.message.eql? "secretKey can not be nil or empty."
		end
		
		assert( errorThrown )
	end

	def test_validateRequestByLocalEventConfig_empty_queueDomain
		eventconfig = EventConfig.new
		eventconfig.cookieDomain = "cookieDomain"
        eventconfig.layoutName = "layoutName"
        eventconfig.culture = "culture"
        eventconfig.eventId = "eventId"
        #eventconfig.queueDomain = "queueDomain"
        eventconfig.extendCookieValidity = true
        eventconfig.cookieValidityMinute = 10
        eventconfig.version = 12

		errorThrown = false
        
		begin
            KnownUser.validateRequestByLocalEventConfig("targeturl", "queueIttoken", eventconfig, "customerid", "secretkey", {})
		rescue KnownUserError => err
			errorThrown = err.message.eql? "eventConfig.queueDomain can not be nil or empty."
		end
		
		assert( errorThrown )
	end

	def test_validateRequestByLocalEventConfig_empty_customerId
		eventconfig = EventConfig.new
		eventconfig.cookieDomain = "cookieDomain"
        eventconfig.layoutName = "layoutName"
        eventconfig.culture = "culture"
        eventconfig.eventId = "eventId"
        eventconfig.queueDomain = "queueDomain"
        eventconfig.extendCookieValidity = true
        eventconfig.cookieValidityMinute = 10
        eventconfig.version = 12

		errorThrown = false
        
		begin
            KnownUser.validateRequestByLocalEventConfig("targeturl", "queueIttoken", eventconfig, nil, "secretKey", {})
		rescue KnownUserError => err
			errorThrown = err.message.eql? "customerId can not be nil or empty."
		end
		
		assert( errorThrown )
	end

	def test_validateRequestByLocalEventConfig_Invalid_extendCookieValidity
		eventconfig = EventConfig.new
		eventconfig.cookieDomain = "cookieDomain"
        eventconfig.layoutName = "layoutName"
        eventconfig.culture = "culture"
        eventconfig.eventId = "eventId"
        eventconfig.queueDomain = "queueDomain"
        eventconfig.extendCookieValidity = "not-a-boolean"
        eventconfig.cookieValidityMinute = 10
        eventconfig.version = 12

		errorThrown = false
        
		begin
            KnownUser.validateRequestByLocalEventConfig("targeturl", "queueIttoken", eventconfig, "customerId", "secretKey", {})
		rescue KnownUserError => err
			errorThrown = err.message.eql? "eventConfig.extendCookieValidity should be valid boolean."
		end
		
		assert( errorThrown )
	end

	def test_validateRequestByLocalEventConfig_Invalid_cookieValidityMinute
		eventconfig = EventConfig.new
        eventconfig.cookieDomain = "cookieDomain"
        eventconfig.layoutName = "layoutName"
        eventconfig.culture = "culture"
        eventconfig.eventId = "eventId"
        eventconfig.queueDomain = "queueDomain"
        eventconfig.extendCookieValidity = true
        eventconfig.cookieValidityMinute = "test"
        eventconfig.version = 12

		errorThrown = false
        
		begin
            KnownUser.validateRequestByLocalEventConfig("targeturl", "queueIttoken", eventconfig, "customerId", "secretKey", {})
		rescue KnownUserError => err
			errorThrown = err.message.start_with? "eventConfig.cookieValidityMinute should be integer greater than 0"
		end
		
		assert( errorThrown )
	end

	def test_validateRequestByLocalEventConfig_zero_cookieValidityMinute
		eventconfig = EventConfig.new
        eventconfig.cookieDomain = "cookieDomain"
        eventconfig.layoutName = "layoutName"
        eventconfig.culture = "culture"
        eventconfig.eventId = "eventId"
        eventconfig.queueDomain = "queueDomain"
        eventconfig.extendCookieValidity = true
        eventconfig.cookieValidityMinute = 0
        eventconfig.version = 12

		errorThrown = false
        
		begin
            KnownUser.validateRequestByLocalEventConfig("targeturl", "queueIttoken", eventconfig, "customerId", "secretKey", {})
		rescue KnownUserError => err
			errorThrown = err.message.start_with? "eventConfig.cookieValidityMinute should be integer greater than 0"
		end
		
		assert( errorThrown )
	end

	def test_validateRequestByLocalEventConfig
		userInQueueService = UserInQueueServiceMock.new 
		KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)

		eventconfig = EventConfig.new
        eventconfig.cookieDomain = "cookieDomain"
        eventconfig.layoutName = "layoutName"
        eventconfig.culture = "culture"
        eventconfig.eventId = "eventId"
        eventconfig.queueDomain = "queueDomain"
        eventconfig.extendCookieValidity = true
        eventconfig.cookieValidityMinute = 10
        eventconfig.version = 12

		KnownUser.validateRequestByLocalEventConfig("target", "token", eventconfig, "id", "key", {})

		assert( userInQueueService.validateRequestCalls[0]["targetUrl"] == "target" )
		assert( userInQueueService.validateRequestCalls[0]["queueitToken"] == "token" )
		assert( userInQueueService.validateRequestCalls[0]["config"] == eventconfig )
		assert( userInQueueService.validateRequestCalls[0]["customerId"] == "id" )
		assert( userInQueueService.validateRequestCalls[0]["secretKey"] == "key" )
	end

	def test_validateRequestByIntegrationConfig_empty_currentUrl
		errorThrown = false
        
		begin
            KnownUser.validateRequestByIntegrationConfig("", "queueIttoken", nil, "customerId", "secretKey", {}, HttpRequestMock.new)
		rescue KnownUserError => err
			errorThrown = err.message.start_with? "currentUrl can not be nil or empty"
		end
		
		assert( errorThrown )
	end

	def test_validateRequestByIntegrationConfig_empty_integrationsConfigString
		errorThrown = false
        
		begin
            KnownUser.validateRequestByIntegrationConfig("currentUrl", "queueIttoken", nil, "customerId", "secretKey", {}, HttpRequestMock.new)
		rescue KnownUserError => err
			errorThrown = err.message.start_with? "integrationsConfigString can not be nil or empty"
		end
		
		assert( errorThrown )
	end

	def test_validateRequestByIntegrationConfig_invalid_integrationsConfigString
		errorThrown = false
        
		begin
            KnownUser.validateRequestByIntegrationConfig("currentUrl", "queueIttoken", "not-valid-json", "customerId", "secretKey", {}, HttpRequestMock.new)
		rescue KnownUserError => err
			errorThrown = err.message.start_with? "integrationConfiguration text was not valid"
		end
		
		assert( errorThrown )
	end

	def test_validateRequestByIntegrationConfig
		userInQueueService = UserInQueueServiceMock.new 
		KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)

		integrationConfig = 
        {
            :Description => "test",
            :Integrations => 
			[
			{
                :Name => "event1action",
                :ActionType => "Queue",
                :EventId => "event1",
                :CookieDomain => ".test.com",
                :LayoutName => "Christmas Layout by Queue-it",
                :Culture => "",
                :ExtendCookieValidity => true,
                :CookieValidityMinute => 20,
                :Triggers => 
				[
                {
                    :TriggerParts => 
					[
                    {
                        :Operator => "Contains",
                        :ValueToCompare => "event1",
                        :UrlPart => "PageUrl",
                        :ValidatorType => "UrlValidator",
                        :IsNegative => false,
                        :IsIgnoreCase => true
					},					
					{
                        :Operator => "Contains",
                        :ValueToCompare => "googlebot",
                        :ValidatorType => "UserAgentValidator",
                        :IsNegative => false,
                        :IsIgnoreCase => false
                    }
                    ],
                    :LogicalOperator => "And"
                }
				],
                :QueueDomain => "knownusertest.queue-it.net",
                :RedirectLogic => "AllowTParameter"
            }
            ],
            :CustomerId => "knownusertest",
            :AccountId => "knownusertest",
            :Version => 3,
            :PublishDate => "2017-05-15T21:39:12.0076806Z",
            :ConfigDataVersion => "1.0.0.1"
        }
		mockRequest = HttpRequestMock.new
		mockRequest.user_agent = 'googlebot'
		integrationConfigJson = JSON.generate(integrationConfig)
		KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "token", integrationConfigJson, "id", "key", Hash.new, mockRequest)

		assert( userInQueueService.validateRequestCalls[0]["targetUrl"] == "http://test.com?event1=true" )
		assert( userInQueueService.validateRequestCalls[0]["queueitToken"] == "token" )
		assert( userInQueueService.validateRequestCalls[0]["customerId"] == "id" )
		assert( userInQueueService.validateRequestCalls[0]["secretKey"] == "key" )

		assert( userInQueueService.validateRequestCalls[0]["config"].queueDomain == "knownusertest.queue-it.net" )
		assert( userInQueueService.validateRequestCalls[0]["config"].eventId == "event1" )
		assert( userInQueueService.validateRequestCalls[0]["config"].culture == "" )
		assert( userInQueueService.validateRequestCalls[0]["config"].layoutName == "Christmas Layout by Queue-it" )
		assert( userInQueueService.validateRequestCalls[0]["config"].extendCookieValidity )
		assert( userInQueueService.validateRequestCalls[0]["config"].cookieValidityMinute == 20 )
		assert( userInQueueService.validateRequestCalls[0]["config"].cookieDomain == ".test.com" )
		assert( userInQueueService.validateRequestCalls[0]["config"].version == 3 )
	end

	def test_validateRequestByIntegrationConfig_NotMatch
		userInQueueService = UserInQueueServiceMock.new 
		KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)

        integrationConfig = 
        {
          :Description => "test",
          :Integrations => [
          ],
          :CustomerId => "knownusertest",
          :AccountId => "knownusertest",
          :Version => 3,
          :PublishDate => "2017-05-15T21:39:12.0076806Z",
          :ConfigDataVersion => "1.0.0.1"
        }

		integrationConfigJson = JSON.generate(integrationConfig)
        result = KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", Hash.new, HttpRequestMock.new)
        
		assert( userInQueueService.validateRequestCalls.length == 0 )
		assert( !result.doRedirect )
	end

	def test_validateRequestByIntegrationConfig_ForcedTargetUrl
		userInQueueService = UserInQueueServiceMock.new 
		KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)
		
		integrationConfig = 
        {
            :Description => "test",
            :Integrations => 
			[
			{
                :Name => "event1action",
                :ActionType => "Queue",
                :EventId => "event1",
                :CookieDomain => ".test.com",
                :LayoutName => "Christmas Layout by Queue-it",
                :Culture => "",
                :ExtendCookieValidity => true,
                :CookieValidityMinute => 20,
                :Triggers => 
				[
                {
                    :TriggerParts => 
					[
                    {
                        :Operator => "Contains",
                        :ValueToCompare => "event1",
                        :UrlPart => "PageUrl",
                        :ValidatorType => "UrlValidator",
                        :IsNegative => false,
                        :IsIgnoreCase => true
                    }
                    ],
                    :LogicalOperator => "And"
                }
				],
                :QueueDomain => "knownusertest.queue-it.net",
                :RedirectLogic => "ForcedTargetUrl",
				:ForcedTargetUrl => "http://test.com"
            }
            ],
            :CustomerId => "knownusertest",
            :AccountId => "knownusertest",
            :Version => 3,
            :PublishDate => "2017-05-15T21:39:12.0076806Z",
            :ConfigDataVersion => "1.0.0.1"
        }
			
		integrationConfigJson = JSON.generate(integrationConfig)
		KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", Hash.new, HttpRequestMock.new)
		
		assert( userInQueueService.validateRequestCalls[0]['targetUrl'] == "http://test.com" )
	end

	def test_validateRequestByIntegrationConfig_EventTargetUrl
		userInQueueService = UserInQueueServiceMock.new 
		KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)		
		
		integrationConfig = 
        {
            :Description => "test",
            :Integrations => 
			[
			{
                :Name => "event1action",
                :ActionType => "Queue",
                :EventId => "event1",
                :CookieDomain => ".test.com",
                :LayoutName => "Christmas Layout by Queue-it",
                :Culture => "",
                :ExtendCookieValidity => true,
                :CookieValidityMinute => 20,
                :Triggers => 
				[
                {
                    :TriggerParts => 
					[
                    {
                        :Operator => "Contains",
                        :ValueToCompare => "event1",
                        :UrlPart => "PageUrl",
                        :ValidatorType => "UrlValidator",
                        :IsNegative => false,
                        :IsIgnoreCase => true
					}
                    ],
                    :LogicalOperator => "And"
                }
				],
                :QueueDomain => "knownusertest.queue-it.net",
                :RedirectLogic => "EventTargetUrl"
            }
            ],
            :CustomerId => "knownusertest",
            :AccountId => "knownusertest",
            :Version => 3,
            :PublishDate => "2017-05-15T21:39:12.0076806Z",
            :ConfigDataVersion => "1.0.0.1"
		}

		integrationConfigJson = JSON.generate(integrationConfig)
		KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", Hash.new, HttpRequestMock.new)
		
		assert( userInQueueService.validateRequestCalls[0]['targetUrl'] == "" )
	end
end
