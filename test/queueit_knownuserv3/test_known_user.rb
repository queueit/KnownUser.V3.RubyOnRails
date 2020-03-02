require 'test/unit'
require 'json'
require_relative '../../lib/queueit_knownuserv3'

module QueueIt
	class HttpRequestMock
		attr_accessor :user_agent
		attr_accessor :env
		attr_accessor :original_fullpath
		attr_accessor :cookie_jar
		attr_accessor :remote_ip
		attr_accessor :headers

		def initialize
			@headers = {}
		end

		def setRealOriginalUrl(proto, host, path)
			@env = {"rack.url_scheme" => proto, "HTTP_HOST" => host}
			@original_fullpath = path
		end
	end

	class UserInQueueServiceMock
		attr_reader :extendQueueCookieCalls
		attr_reader :validateQueueRequestCalls
		attr_reader :validateCancelRequestCalls
		attr_reader :getIgnoreActionResultCalls		
		
		attr_accessor :validateQueueRequestResult
		attr_accessor :validateCancelRequestResult
		attr_accessor :getIgnoreActionResult
		attr_accessor :validateCancelRequestRaiseException
		attr_accessor :validateQueueRequestRaiseException

		def initialize
			@extendQueueCookieCalls = {}
			@validateQueueRequestCalls = {}
			@validateCancelRequestCalls = {}
			@getIgnoreActionResultCalls = {}
			@validateCancelRequestRaiseException = false
			@validateQueueRequestRaiseException = false
			@validateQueueRequestResult = RequestValidationResult.new(ActionTypes::QUEUE, nil, nil, nil, nil, nil)
			@validateCancelRequestResult = RequestValidationResult.new(ActionTypes::CANCEL, nil, nil, nil, nil, nil)
			@getIgnoreActionResult = RequestValidationResult.new(ActionTypes::IGNORE, nil, nil, nil, nil, nil)
		end
	
		def extendQueueCookie(eventId, cookieValidityMinute, cookieDomain, secretKey)		
			@extendQueueCookieCalls[@extendQueueCookieCalls.length] = {
				"eventId" => eventId,
				"cookieValidityMinute" => cookieValidityMinute,
				"cookieDomain" => cookieDomain,
				"secretKey" => secretKey
			}
		end

		def validateQueueRequest(targetUrl, queueitToken, config, customerId, secretKey)
			@validateQueueRequestCalls[@validateQueueRequestCalls.length] = {
				"targetUrl" => targetUrl,
				"queueitToken" => queueitToken,
				"config" => config,
				"customerId" => customerId,
				"secretKey" => secretKey
			}

			if(@validateQueueRequestRaiseException)
				raise Exception.new, "Exception"
			end

			return @validateQueueRequestResult
		end

		def validateCancelRequest(targetUrl, config, customerId, secretKey)
			@validateCancelRequestCalls[@validateQueueRequestCalls.length] = {
				"targetUrl" => targetUrl,
				"config" => config,
				"customerId" => customerId,
				"secretKey" => secretKey
			}

			if(@validateCancelRequestRaiseException)
				raise Exception.new, "Exception"
			end
			return @validateCancelRequestResult
		end

		def getIgnoreActionResult(actionName)
			@getIgnoreActionResultCalls[@getIgnoreActionResultCalls.length] = {"actionName" => actionName}
			return @getIgnoreActionResult
		end
	end

	class QueueITTokenGenerator
		def self.generateDebugToken(eventId, secretKey, expired)
			ts = (Time.now.getutc.tv_sec + 1000).to_s
			if(expired)
				ts = (Time.now.getutc.tv_sec - 1000).to_s
			end
			tokenWithoutHash = QueueUrlParams::EVENT_ID_KEY + QueueUrlParams::KEY_VALUE_SEPARATOR_CHAR + eventId + 
				QueueUrlParams::KEY_VALUE_SEPARATOR_GROUP_CHAR + 
				QueueUrlParams::REDIRECT_TYPE_KEY + QueueUrlParams::KEY_VALUE_SEPARATOR_CHAR + "debug" +
				QueueUrlParams::KEY_VALUE_SEPARATOR_GROUP_CHAR + 
				QueueUrlParams::TIMESTAMP_KEY + QueueUrlParams::KEY_VALUE_SEPARATOR_CHAR + ts
			
			hash = OpenSSL::HMAC.hexdigest('sha256', secretKey, tokenWithoutHash)
			token = tokenWithoutHash + QueueUrlParams::KEY_VALUE_SEPARATOR_GROUP_CHAR + QueueUrlParams::HASH_KEY + QueueUrlParams::KEY_VALUE_SEPARATOR_CHAR + hash
			return token
		end
	end

	class TestKnownUser < Test::Unit::TestCase
		def test_cancelRequestByLocalConfig	
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)
		
			cancelConfig = CancelEventConfig.new
			cancelConfig.eventId = "eventId"
			cancelConfig.queueDomain = "queueDomain"
			cancelConfig.version = 1
			cancelConfig.cookieDomain = "cookieDomain"
			cancelConfig.actionName = "CancelAction"

			result = KnownUser.cancelRequestByLocalConfig("targetUrl", "token", cancelConfig, "customerId", "secretKey", HttpRequestMock.new)

			assert( userInQueueService.validateCancelRequestCalls[0]["targetUrl"] == "targetUrl" )
			assert( userInQueueService.validateCancelRequestCalls[0]["config"] == cancelConfig )
			assert( userInQueueService.validateCancelRequestCalls[0]["customerId"] == "customerId" )
			assert( userInQueueService.validateCancelRequestCalls[0]["secretKey"] == "secretKey" )
			assert( !result.isAjaxResult )
		end

		def test_cancelRequestByLocalConfig_AjaxCall
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)
		
			cancelConfig = CancelEventConfig.new
			cancelConfig.eventId = "eventId"
			cancelConfig.queueDomain = "queueDomain"
			cancelConfig.version = 1
			cancelConfig.cookieDomain = "cookieDomain"
			cancelConfig.actionName = "CancelAction"

			requestMock = HttpRequestMock.new
			requestMock.headers = { "x-queueit-ajaxpageurl" => "http%3a%2f%2furl" }
			userInQueueService.validateCancelRequestResult = RequestValidationResult.new(ActionTypes::CANCEL, "eventId", nil, "http://q.qeuue-it.com", nil, cancelConfig.actionName)

			result = KnownUser.cancelRequestByLocalConfig("targetUrl", "token", cancelConfig, "customerId", "secretKey", requestMock)

			assert( userInQueueService.validateCancelRequestCalls[0]["targetUrl"] == "http://url" )
			assert( userInQueueService.validateCancelRequestCalls[0]["config"] == cancelConfig )
			assert( userInQueueService.validateCancelRequestCalls[0]["customerId"] == "customerId" )
			assert( userInQueueService.validateCancelRequestCalls[0]["secretKey"] == "secretKey" )
			assert( result.isAjaxResult )
			assert( result.getAjaxRedirectUrl.downcase == "http%3a%2f%2fq.qeuue-it.com" )
			assert( result.actionName == cancelConfig.actionName )
		end

		def test_cancelRequestByLocalConfig_nil_QueueDomain
			errorThrown = false
        
			cancelConfig = CancelEventConfig.new
			cancelConfig.eventId = "eventId"
		
			begin
				KnownUser.cancelRequestByLocalConfig("targetUrl", "token", cancelConfig, "customerId", "secretKey", HttpRequestMock.new)
			rescue KnownUserError => err
				errorThrown = err.message.eql? "cancelConfig.queueDomain can not be nil or empty."
			end
		
			assert( errorThrown )
		end
	
		def test_cancelRequestByLocalConfig_nil_EventId
			errorThrown = false
        
			cancelConfig = CancelEventConfig.new
			cancelConfig.queueDomain = "queueDomain"

			begin
				KnownUser.cancelRequestByLocalConfig("targetUrl", "token", cancelConfig, "customerId", "secretKey", HttpRequestMock.new)
			rescue KnownUserError => err
				errorThrown = err.message.eql? "cancelConfig.eventId can not be nil or empty."
			end
		
			assert( errorThrown )
		end

		def test_cancelRequestByLocalConfig_nil_CancelConfig
			errorThrown = false
        
			begin
				KnownUser.cancelRequestByLocalConfig("targetUrl", "token", nil, "customerId", "secretKey", HttpRequestMock.new)
			rescue KnownUserError => err
				errorThrown = err.message.eql? "cancelConfig can not be nil."
			end
		
			assert( errorThrown )
		end

		def test_cancelRequestByLocalConfig_nil_CustomerId
			errorThrown = false
        
			begin
				KnownUser.cancelRequestByLocalConfig("targetUrl", "token", CancelEventConfig.new, nil, "secretKey", HttpRequestMock.new)
			rescue KnownUserError => err
				errorThrown = err.message.eql? "customerId can not be nil or empty."
			end
		
			assert( errorThrown )
		end

		def test_cancelRequestByLocalConfig_nil_SeceretKey
			errorThrown = false
        
			begin
				KnownUser.cancelRequestByLocalConfig("targetUrl", "token", CancelEventConfig.new, "customerId", nil, HttpRequestMock.new)
			rescue KnownUserError => err
				errorThrown = err.message.eql? "secretKey can not be nil or empty."
			end
		
			assert( errorThrown )
		end

		def test_cancelRequestByLocalConfig_nil_TargetUrl
			errorThrown = false
        
			begin
				KnownUser.cancelRequestByLocalConfig(nil, "token", CancelEventConfig.new, "customerId", nil, HttpRequestMock.new)
			rescue KnownUserError => err
				errorThrown = err.message.eql? "targetUrl can not be nil or empty."
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
		
			KnownUser.extendQueueCookie("evtId", 10, "domain", "key", HttpRequestMock.new)
		
			assert( userInQueueService.extendQueueCookieCalls[0]["eventId"] == "evtId" )
			assert( userInQueueService.extendQueueCookieCalls[0]["cookieValidityMinute"] == 10 )
			assert( userInQueueService.extendQueueCookieCalls[0]["cookieDomain"] == "domain" )
			assert( userInQueueService.extendQueueCookieCalls[0]["secretKey"] == "key" )		
		end

		def test_resolveQueueRequestByLocalConfig_empty_eventId
			queueConfig = QueueEventConfig.new
			queueConfig.cookieDomain = "cookieDomain"
			queueConfig.layoutName = "layoutName"
			queueConfig.culture = "culture"
			#queueConfig.eventId = "eventId"
			queueConfig.queueDomain = "queueDomain"
			queueConfig.extendCookieValidity = true
			queueConfig.cookieValidityMinute = 10
			queueConfig.version = 12

			errorThrown = false
        
			begin
				KnownUser.resolveQueueRequestByLocalConfig("targeturl", "queueIttoken", queueConfig, "customerid", "secretkey", HttpRequestMock.new)
			rescue KnownUserError => err
				errorThrown = err.message.eql? "queueConfig.eventId can not be nil or empty."
			end
		
			assert( errorThrown )
		end

		def test_resolveQueueRequestByLocalConfig_empty_secretKey
			queueConfig = QueueEventConfig.new
			queueConfig.cookieDomain = "cookieDomain"
			queueConfig.layoutName = "layoutName"
			queueConfig.culture = "culture"
			queueConfig.eventId = "eventId"
			queueConfig.queueDomain = "queueDomain"
			queueConfig.extendCookieValidity = true
			queueConfig.cookieValidityMinute = 10
			queueConfig.version = 12

			errorThrown = false
        
			begin
				KnownUser.resolveQueueRequestByLocalConfig("targeturl", "queueIttoken", queueConfig, "customerid", nil, HttpRequestMock.new)
			rescue KnownUserError => err
				errorThrown = err.message.eql? "secretKey can not be nil or empty."
			end
		
			assert( errorThrown )
		end

		def test_resolveQueueRequestByLocalConfig_empty_queueDomain
			queueConfig = QueueEventConfig.new
			queueConfig.cookieDomain = "cookieDomain"
			queueConfig.layoutName = "layoutName"
			queueConfig.culture = "culture"
			queueConfig.eventId = "eventId"
			#queueConfig.queueDomain = "queueDomain"
			queueConfig.extendCookieValidity = true
			queueConfig.cookieValidityMinute = 10
			queueConfig.version = 12

			errorThrown = false
        
			begin
				KnownUser.resolveQueueRequestByLocalConfig("targeturl", "queueIttoken", queueConfig, "customerid", "secretkey", HttpRequestMock.new)
			rescue KnownUserError => err
				errorThrown = err.message.eql? "queueConfig.queueDomain can not be nil or empty."
			end
		
			assert( errorThrown )
		end

		def test_resolveQueueRequestByLocalConfig_empty_customerId
			queueConfig = QueueEventConfig.new
			queueConfig.cookieDomain = "cookieDomain"
			queueConfig.layoutName = "layoutName"
			queueConfig.culture = "culture"
			queueConfig.eventId = "eventId"
			queueConfig.queueDomain = "queueDomain"
			queueConfig.extendCookieValidity = true
			queueConfig.cookieValidityMinute = 10
			queueConfig.version = 12

			errorThrown = false
        
			begin
				KnownUser.resolveQueueRequestByLocalConfig("targeturl", "queueIttoken", queueConfig, nil, "secretKey", HttpRequestMock.new)
			rescue KnownUserError => err
				errorThrown = err.message.eql? "customerId can not be nil or empty."
			end
		
			assert( errorThrown )
		end

		def test_resolveQueueRequestByLocalConfig_Invalid_extendCookieValidity
			queueConfig = QueueEventConfig.new
			queueConfig.cookieDomain = "cookieDomain"
			queueConfig.layoutName = "layoutName"
			queueConfig.culture = "culture"
			queueConfig.eventId = "eventId"
			queueConfig.queueDomain = "queueDomain"
			queueConfig.extendCookieValidity = "not-a-boolean"
			queueConfig.cookieValidityMinute = 10
			queueConfig.version = 12

			errorThrown = false
        
			begin
				KnownUser.resolveQueueRequestByLocalConfig("targeturl", "queueIttoken", queueConfig, "customerId", "secretKey", HttpRequestMock.new)
			rescue KnownUserError => err
				errorThrown = err.message.eql? "queueConfig.extendCookieValidity should be valid boolean."
			end
		
			assert( errorThrown )
		end

		def test_resolveQueueRequestByLocalConfig_Invalid_cookieValidityMinute
			queueConfig = QueueEventConfig.new
			queueConfig.cookieDomain = "cookieDomain"
			queueConfig.layoutName = "layoutName"
			queueConfig.culture = "culture"
			queueConfig.eventId = "eventId"
			queueConfig.queueDomain = "queueDomain"
			queueConfig.extendCookieValidity = true
			queueConfig.cookieValidityMinute = "test"
			queueConfig.version = 12

			errorThrown = false
        
			begin
				KnownUser.resolveQueueRequestByLocalConfig("targeturl", "queueIttoken", queueConfig, "customerId", "secretKey", HttpRequestMock.new)
			rescue KnownUserError => err
				errorThrown = err.message.start_with? "queueConfig.cookieValidityMinute should be integer greater than 0"
			end
		
			assert( errorThrown )
		end

		def test_resolveQueueRequestByLocalConfig_zero_cookieValidityMinute
			queueConfig = QueueEventConfig.new
			queueConfig.cookieDomain = "cookieDomain"
			queueConfig.layoutName = "layoutName"
			queueConfig.culture = "culture"
			queueConfig.eventId = "eventId"
			queueConfig.queueDomain = "queueDomain"
			queueConfig.extendCookieValidity = true
			queueConfig.cookieValidityMinute = 0
			queueConfig.version = 12

			errorThrown = false
        
			begin
				KnownUser.resolveQueueRequestByLocalConfig("targeturl", "queueIttoken", queueConfig, "customerId", "secretKey", HttpRequestMock.new)
			rescue KnownUserError => err
				errorThrown = err.message.start_with? "queueConfig.cookieValidityMinute should be integer greater than 0"
			end
		
			assert( errorThrown )
		end

		def test_resolveQueueRequestByLocalConfig
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)

			queueConfig = QueueEventConfig.new
			queueConfig.cookieDomain = "cookieDomain"
			queueConfig.layoutName = "layoutName"
			queueConfig.culture = "culture"
			queueConfig.eventId = "eventId"
			queueConfig.queueDomain = "queueDomain"
			queueConfig.extendCookieValidity = true
			queueConfig.cookieValidityMinute = 10
			queueConfig.version = 12
			queueConfig.actionName = "QueueAction"

			result = KnownUser.resolveQueueRequestByLocalConfig("target", "token", queueConfig, "id", "key", HttpRequestMock.new)

			assert( userInQueueService.validateQueueRequestCalls[0]["targetUrl"] == "target" )
			assert( userInQueueService.validateQueueRequestCalls[0]["queueitToken"] == "token" )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"] == queueConfig )
			assert( userInQueueService.validateQueueRequestCalls[0]["customerId"] == "id" )
			assert( userInQueueService.validateQueueRequestCalls[0]["secretKey"] == "key" )
			assert( !result.isAjaxResult )
		end

		def test_resolveQueueRequestByLocalConfig_AjaxCall
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)

			queueConfig = QueueEventConfig.new
			queueConfig.cookieDomain = "cookieDomain"
			queueConfig.layoutName = "layoutName"
			queueConfig.culture = "culture"
			queueConfig.eventId = "eventId"
			queueConfig.queueDomain = "queueDomain"
			queueConfig.extendCookieValidity = true
			queueConfig.cookieValidityMinute = 10
			queueConfig.version = 12
			queueConfig.actionName = "QueueAction"

			requestMock = HttpRequestMock.new
			requestMock.headers = { "x-queueit-ajaxpageurl" => "http%3a%2f%2furl" }
			userInQueueService.validateQueueRequestResult = RequestValidationResult.new(ActionTypes::QUEUE, "eventId", nil, "http://q.qeuue-it.com", nil, queueConfig.actionName)

			result = KnownUser.resolveQueueRequestByLocalConfig("targetUrl", "token", queueConfig, "customerId", "secretKey", requestMock)

			assert( userInQueueService.validateQueueRequestCalls[0]["targetUrl"] == "http://url" )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"] == queueConfig )
			assert( userInQueueService.validateQueueRequestCalls[0]["customerId"] == "customerId" )
			assert( userInQueueService.validateQueueRequestCalls[0]["secretKey"] == "secretKey" )
			assert( result.isAjaxResult )
			assert( result.getAjaxRedirectUrl.downcase == "http%3a%2f%2fq.qeuue-it.com" )
			assert( result.actionName == queueConfig.actionName )
		end

		def test_validateRequestByIntegrationConfig_empty_currentUrlWithoutQueueITToken
			errorThrown = false
        
			begin
				KnownUser.validateRequestByIntegrationConfig("", "queueIttoken", "{}", "customerId", "secretKey", HttpRequestMock.new)
			rescue KnownUserError => err
				errorThrown = err.message.start_with? "currentUrlWithoutQueueITToken can not be nil or empty"
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
					#:ActionType => "Queue", #omitting will default to "Queue"
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
			mockRequest.cookie_jar = Hash.new
			integrationConfigJson = JSON.generate(integrationConfig)
			result = KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "token", integrationConfigJson, "id", "key", mockRequest)

			assert( userInQueueService.validateQueueRequestCalls[0]["targetUrl"] == "http://test.com?event1=true" )
			assert( userInQueueService.validateQueueRequestCalls[0]["queueitToken"] == "token" )
			assert( userInQueueService.validateQueueRequestCalls[0]["customerId"] == "id" )
			assert( userInQueueService.validateQueueRequestCalls[0]["secretKey"] == "key" )

			assert( userInQueueService.validateQueueRequestCalls[0]["config"].queueDomain == "knownusertest.queue-it.net" )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"].eventId == "event1" )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"].culture == "" )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"].layoutName == "Christmas Layout by Queue-it" )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"].extendCookieValidity )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"].cookieValidityMinute == 20 )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"].cookieDomain == ".test.com" )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"].version == 3 )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"].actionName == integrationConfig[:Integrations][0][:Name] )
			assert( !result.isAjaxResult )
		end

		def test_validateRequestByIntegrationConfig_AjaxCall
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)

			integrationConfig = 
			{
				:Description => "test",
				:Integrations => 
				[
				{
					:Name => "event1action",
					#:ActionType => "Queue", #omitting will default to "Queue"
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
			mockRequest.headers = { "x-queueit-ajaxpageurl" => "http%3a%2f%2furl" }
			mockRequest.cookie_jar = Hash.new
			integrationConfigJson = JSON.generate(integrationConfig)

			userInQueueService.validateQueueRequestResult = RequestValidationResult.new(ActionTypes::QUEUE, "eventId", nil, "http://q.qeuue-it.com", nil, integrationConfig[:Integrations][0][:Name])

			result = KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "token", integrationConfigJson, "id", "key", mockRequest)

			assert( userInQueueService.validateQueueRequestCalls[0]["targetUrl"] == "http://url" )
			assert( userInQueueService.validateQueueRequestCalls[0]["queueitToken"] == "token" )
			assert( userInQueueService.validateQueueRequestCalls[0]["customerId"] == "id" )
			assert( userInQueueService.validateQueueRequestCalls[0]["secretKey"] == "key" )

			assert( userInQueueService.validateQueueRequestCalls[0]["config"].queueDomain == "knownusertest.queue-it.net" )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"].eventId == "event1" )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"].culture == "" )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"].layoutName == "Christmas Layout by Queue-it" )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"].extendCookieValidity )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"].cookieValidityMinute == 20 )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"].cookieDomain == ".test.com" )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"].version == 3 )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"].actionName == integrationConfig[:Integrations][0][:Name] )
			assert( result.isAjaxResult )
			assert( result.getAjaxRedirectUrl.downcase == "http%3a%2f%2fq.qeuue-it.com" )
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
			result = KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", HttpRequestMock.new)
        
			assert( userInQueueService.validateQueueRequestCalls.length == 0 )
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
			result = KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", HttpRequestMock.new)
		
			assert( userInQueueService.validateQueueRequestCalls[0]['targetUrl'] == "http://test.com" )
			assert( !result.isAjaxResult )
		end

		def test_validateRequestByIntegrationConfig_ForcedTargetUrl_AjaxCall
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
			
			requestMock = HttpRequestMock.new
			requestMock.headers = { "x-queueit-ajaxpageurl" => "http%3a%2f%2furl" }
			userInQueueService.validateQueueRequestResult = RequestValidationResult.new(ActionTypes::QUEUE, "eventId", nil, "http://q.qeuue-it.com", nil, integrationConfig[:Integrations][0][:Name])

			integrationConfigJson = JSON.generate(integrationConfig)
			result = KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", requestMock)
		
			assert( userInQueueService.validateQueueRequestCalls[0]['targetUrl'] == "http://test.com" )
			assert( result.isAjaxResult )
			assert( result.getAjaxRedirectUrl.downcase == "http%3a%2f%2fq.qeuue-it.com" )
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
			result = KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", HttpRequestMock.new)
		
			assert( userInQueueService.validateQueueRequestCalls[0]['targetUrl'] == "" )
			assert( !result.isAjaxResult )
		end

		def test_validateRequestByIntegrationConfig_EventTargetUrl_AjaxCall
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

			requestMock = HttpRequestMock.new
			requestMock.headers = { "x-queueit-ajaxpageurl" => "http%3a%2f%2furl" }
			userInQueueService.validateQueueRequestResult = RequestValidationResult.new(ActionTypes::QUEUE, "eventId", nil, "http://q.qeuue-it.com", nil, integrationConfig[:Integrations][0][:Name])

			integrationConfigJson = JSON.generate(integrationConfig)
			result = KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", requestMock)
		
			assert( userInQueueService.validateQueueRequestCalls[0]['targetUrl'] == "" )
			assert( result.isAjaxResult )
			assert( result.getAjaxRedirectUrl.downcase == "http%3a%2f%2fq.qeuue-it.com" )
		end

		def test_validateRequestByIntegrationConfig_CancelAction
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)		
		
			integrationConfig = 
			{
				:Description => "test",
				:Integrations => 
				[
				{
					:Name => "event1action",
					:ActionType => "Cancel",
					:EventId => "event1",
					:CookieDomain => ".test.com",
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
				}
				],
				:CustomerId => "knownusertest",
				:AccountId => "knownusertest",
				:Version => 3,
				:PublishDate => "2017-05-15T21:39:12.0076806Z",
				:ConfigDataVersion => "1.0.0.1"
			}

			integrationConfigJson = JSON.generate(integrationConfig)
			result = KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", HttpRequestMock.new)
		
			assert( userInQueueService.validateCancelRequestCalls[0]["targetUrl"] == "http://test.com?event1=true" )
			assert( userInQueueService.validateCancelRequestCalls[0]["customerId"] == "customerid" )
			assert( userInQueueService.validateCancelRequestCalls[0]["secretKey"] == "secretkey" )

			assert( userInQueueService.validateCancelRequestCalls[0]["config"].queueDomain == "knownusertest.queue-it.net" )
			assert( userInQueueService.validateCancelRequestCalls[0]["config"].eventId == "event1" )
			assert( userInQueueService.validateCancelRequestCalls[0]["config"].cookieDomain == ".test.com" )
			assert( userInQueueService.validateCancelRequestCalls[0]["config"].version == 3 )
			assert( userInQueueService.validateCancelRequestCalls[0]["config"].actionName == integrationConfig[:Integrations][0][:Name] )
			assert( !result.isAjaxResult )
		end

		def test_validateRequestByIntegrationConfig_CancelAction_AjaxCall
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)		
		
			integrationConfig = 
			{
				:Description => "test",
				:Integrations => 
				[
				{
					:Name => "event1action",
					:ActionType => "Cancel",
					:EventId => "event1",
					:CookieDomain => ".test.com",
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
				}
				],
				:CustomerId => "knownusertest",
				:AccountId => "knownusertest",
				:Version => 3,
				:PublishDate => "2017-05-15T21:39:12.0076806Z",
				:ConfigDataVersion => "1.0.0.1"
			}

			requestMock = HttpRequestMock.new
			requestMock.headers = { "x-queueit-ajaxpageurl" => "http%3a%2f%2furl" }
			userInQueueService.validateCancelRequestResult = RequestValidationResult.new(ActionTypes::CANCEL, "eventId", nil, "http://q.qeuue-it.com", nil, integrationConfig[:Integrations][0][:Name])

			integrationConfigJson = JSON.generate(integrationConfig)
 			result = KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", requestMock)
		
			assert( userInQueueService.validateCancelRequestCalls[0]["targetUrl"] == "http://url" )
			assert( userInQueueService.validateCancelRequestCalls[0]["customerId"] == "customerid" )
			assert( userInQueueService.validateCancelRequestCalls[0]["secretKey"] == "secretkey" )

			assert( userInQueueService.validateCancelRequestCalls[0]["config"].queueDomain == "knownusertest.queue-it.net" )
			assert( userInQueueService.validateCancelRequestCalls[0]["config"].eventId == "event1" )
			assert( userInQueueService.validateCancelRequestCalls[0]["config"].cookieDomain == ".test.com" )
			assert( userInQueueService.validateCancelRequestCalls[0]["config"].version == 3 )
			assert( userInQueueService.validateCancelRequestCalls[0]["config"].actionName == integrationConfig[:Integrations][0][:Name] )
			assert( result.isAjaxResult )
			assert( result.getAjaxRedirectUrl.downcase == "http%3a%2f%2fq.qeuue-it.com" )
		end

		def test_validateRequestByIntegrationConfig_ignoreAction
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)		
		
			integrationConfig = 
			{
				:Description => "test",
				:Integrations => 
				[
				{
					:Name => "event1action",
					:ActionType => "Ignore",
					:EventId => "event1",
					:CookieDomain => ".test.com",
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
				}
				],
				:CustomerId => "knownusertest",
				:AccountId => "knownusertest",
				:Version => 3,
				:PublishDate => "2017-05-15T21:39:12.0076806Z",
				:ConfigDataVersion => "1.0.0.1"
			}

			integrationConfigJson = JSON.generate(integrationConfig)
			result = KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", HttpRequestMock.new)
		
			assert( userInQueueService.getIgnoreActionResultCalls.length.eql? 1 )
			assert( userInQueueService.getIgnoreActionResultCalls[0]["actionName"] == integrationConfig[:Integrations][0][:Name] )
			assert( !result.isAjaxResult )
		end

		def test_validateRequestByIntegrationConfig_ignoreAction_AjaxCall
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)		
		
			integrationConfig = 
			{
				:Description => "test",
				:Integrations => 
				[
				{
					:Name => "event1action",
					:ActionType => "Ignore",
					:EventId => "event1",
					:CookieDomain => ".test.com",
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
				}
				],
				:CustomerId => "knownusertest",
				:AccountId => "knownusertest",
				:Version => 3,
				:PublishDate => "2017-05-15T21:39:12.0076806Z",
				:ConfigDataVersion => "1.0.0.1"
			}

			requestMock = HttpRequestMock.new
			requestMock.headers = { "x-queueit-ajaxpageurl" => "http%3a%2f%2furl" }
			
			integrationConfigJson = JSON.generate(integrationConfig)
			result = KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", requestMock)
		
			assert( userInQueueService.getIgnoreActionResultCalls.length.eql? 1 )
			assert( userInQueueService.getIgnoreActionResultCalls[0]["actionName"] == integrationConfig[:Integrations][0][:Name] )
			assert( result.isAjaxResult )
		end

		def test_validateRequestByIntegrationConfig_defaultsTo_ignoreAction
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)		
		
			integrationConfig = 
			{
				:Description => "test",
				:Integrations => 
				[
				{
					:Name => "event1action",
					:ActionType => "some-future-action-type",
					:EventId => "event1",
					:CookieDomain => ".test.com",
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
				}
				],
				:CustomerId => "knownusertest",
				:AccountId => "knownusertest",
				:Version => 3,
				:PublishDate => "2017-05-15T21:39:12.0076806Z",
				:ConfigDataVersion => "1.0.0.1"
			}

			integrationConfigJson = JSON.generate(integrationConfig)
			KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", HttpRequestMock.new)
		
			assert( userInQueueService.getIgnoreActionResultCalls.length.eql? 1 )
			assert( userInQueueService.getIgnoreActionResultCalls[0]["actionName"] == integrationConfig[:Integrations][0][:Name] )
		end

		def test_ValidateRequestByIntegrationConfig_Debug
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)

			integrationConfig = 
			{
				:Description => "test",
				:Integrations => 
				[
				{
					:Name => "event1action",
					#:ActionType => "Queue", #omitting will default to "Queue"
					:EventId => "event1",
					:CookieDomain => ".test.com",
					:LayoutName => "Christmas Layout by Queue-it",
					:Culture => "da-DK",
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
		
			requestMock = HttpRequestMock.new
			requestMock.user_agent = "googlebot"
			requestMock.setRealOriginalUrl("http", "localhost", "/original_url")
			requestMock.cookie_jar = {}
			requestMock.remote_ip = "userIP"
			requestMock.headers = {
				"via" => "v", 
				"forwarded" => "f", 
				"x-forwarded-for" => "xff",
				"x-forwarded-host" => "xfh", 
				"x-forwarded-proto" => "xfp" }
			integrationConfigJson = JSON.generate(integrationConfig)
		
			secretKey = "secretKey"
			queueitToken = QueueITTokenGenerator::generateDebugToken("eventId", secretKey, false)
		
			expectedServerTime = Time.now.utc.iso8601
			KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", queueitToken, integrationConfigJson, "customerId", secretKey, requestMock)

			expectedCookieValue = 
				"SdkVersion=" + UserInQueueService::SDK_VERSION +
				"|Runtime=" + RUBY_VERSION.to_s +
				"|PureUrl=http://test.com?event1=true|QueueitToken=" + queueitToken + 
				"|OriginalUrl=http://localhost/original_url" +
				"|ServerUtcTime=" + expectedServerTime + 
				"|RequestIP=userIP" + 
				"|RequestHttpHeader_Via=v" + 
				"|RequestHttpHeader_Forwarded=f" + 
				"|RequestHttpHeader_XForwardedFor=xff" + 
				"|RequestHttpHeader_XForwardedHost=xfh" + 
				"|RequestHttpHeader_XForwardedProto=xfp" +
				"|ConfigVersion=3|MatchedConfig=event1action" + 
				"|TargetUrl=http://test.com?event1=true|QueueConfig=EventId:event1&Version:3&QueueDomain:knownusertest.queue-it.net&CookieDomain:.test.com&ExtendCookieValidity:true&CookieValidityMinute:20&LayoutName:Christmas Layout by Queue-it&Culture:da-DK&ActionName:" + integrationConfig[:Integrations][0][:Name]

			assert( requestMock.cookie_jar.length == 1 )
			assert( requestMock.cookie_jar.key?(KnownUser::QUEUEIT_DEBUG_KEY.to_sym) )

			actualCookieValue = requestMock.cookie_jar[KnownUser::QUEUEIT_DEBUG_KEY.to_sym]["value".to_sym]
			assert( expectedCookieValue.eql?(actualCookieValue) )
		end

		def test_ValidateRequestByIntegrationConfig_Debug_WithoutMatch
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)

			requestMock = HttpRequestMock.new
			requestMock.setRealOriginalUrl("http", "localhost", "/original_url")
			requestMock.cookie_jar = {}
			requestMock.remote_ip = "userIP"
			requestMock.headers = {
				"via" => "v", 
				"forwarded" => "f", 
				"x-forwarded-for" => "xff",
				"x-forwarded-host" => "xfh", 
				"x-forwarded-proto" => "xfp" }
		
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

			secretKey = "secretKey"
			queueitToken = QueueITTokenGenerator::generateDebugToken("eventId", secretKey, false)		

			integrationConfigJson = JSON.generate(integrationConfig)
			expectedServerTime = Time.now.utc.iso8601
			KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", queueitToken, integrationConfigJson, "customerId", secretKey, requestMock)

			expectedCookieValue = 
				"SdkVersion=" + UserInQueueService::SDK_VERSION +
				"|Runtime=" + RUBY_VERSION.to_s +
				"|PureUrl=http://test.com?event1=true|QueueitToken=" + queueitToken + 
				"|OriginalUrl=http://localhost/original_url" + 
				"|ServerUtcTime=" + expectedServerTime + 
				"|RequestIP=userIP" + 
				"|RequestHttpHeader_Via=v" + 
				"|RequestHttpHeader_Forwarded=f" + 
				"|RequestHttpHeader_XForwardedFor=xff" + 
				"|RequestHttpHeader_XForwardedHost=xfh" + 
				"|RequestHttpHeader_XForwardedProto=xfp" +
				"|ConfigVersion=3|MatchedConfig=NULL"

			assert( requestMock.cookie_jar.length == 1 )
			assert( requestMock.cookie_jar.key?(KnownUser::QUEUEIT_DEBUG_KEY.to_sym) )
			actualCookieValue = requestMock.cookie_jar[KnownUser::QUEUEIT_DEBUG_KEY.to_sym]["value".to_sym]
			assert( expectedCookieValue.eql?(actualCookieValue) )
		end

		def test_validateRequestByIntegrationConfig_debug_invalid_config_json
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)

			requestMock = HttpRequestMock.new
			requestMock.setRealOriginalUrl("http", "localhost", "/original_url")
			requestMock.cookie_jar = {}
			requestMock.remote_ip = "userIP"
			requestMock.headers = {
				"via" => "v", 
				"forwarded" => "f", 
				"x-forwarded-for" => "xff",
				"x-forwarded-host" => "xfh", 
				"x-forwarded-proto" => "xfp" }

			integrationConfigJson = "{}"
			queueitToken = QueueITTokenGenerator::generateDebugToken("eventId", "secretKey", false)
		
			expectedServerTime = Time.now.utc.iso8601
			
			errorThrown = false
			begin
				KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", queueitToken, 
					integrationConfigJson, "customerId", "secretKey", requestMock)
			rescue KnownUserError => err
				errorThrown = err.message.start_with? "integrationConfigJson is not valid json."
			end
		
			assert( errorThrown )

			expectedCookieValue = 
				"SdkVersion=" + UserInQueueService::SDK_VERSION +
				"|Runtime=" + RUBY_VERSION.to_s +				 
				"|PureUrl=http://test.com?event1=true" + 
				"|QueueitToken=" + queueitToken + 
				"|OriginalUrl=http://localhost/original_url" + 
				"|ServerUtcTime=" + expectedServerTime + 
				"|RequestIP=userIP" + 
				"|RequestHttpHeader_Via=v" + 
				"|RequestHttpHeader_Forwarded=f" + 
				"|RequestHttpHeader_XForwardedFor=xff" + 
				"|RequestHttpHeader_XForwardedHost=xfh" + 
				"|RequestHttpHeader_XForwardedProto=xfp" +
				"|ConfigVersion=NULL" +
				"|Exception=integrationConfigJson is not valid json."

			assert( requestMock.cookie_jar.length == 1 )
			assert( requestMock.cookie_jar.key?(KnownUser::QUEUEIT_DEBUG_KEY.to_sym) )
			actualCookieValue = requestMock.cookie_jar[KnownUser::QUEUEIT_DEBUG_KEY.to_sym]["value".to_sym]
			assert( expectedCookieValue.eql?(actualCookieValue) )
		end

		def test_ValidateRequestByIntegrationConfig_Debug_Missing_CustomerId
			requestMock = HttpRequestMock.new
			requestMock.cookie_jar = {}
			
			expiredDebugToken = QueueITTokenGenerator::generateDebugToken("eventId", "secretKey", true)

			result = KnownUser.validateRequestByIntegrationConfig(
				"http://test.com?event1=true", expiredDebugToken, "{}", nil, "secretKey",
				requestMock)

			assert( "https://api2.queue-it.net/diagnostics/connector/error/?code=setup" == result.redirectUrl )
			assert( requestMock.cookie_jar.length == 0 )
		end

		def test_ValidateRequestByIntegrationConfig_Debug_Missing_Secretkey
			requestMock = HttpRequestMock.new
			requestMock.cookie_jar = {}
			
			expiredDebugToken = QueueITTokenGenerator::generateDebugToken("eventId", "secretKey", true)

			result = KnownUser.validateRequestByIntegrationConfig(
				"http://test.com?event1=true", expiredDebugToken, "{}", "customerId", nil,
				requestMock)

			assert( "https://api2.queue-it.net/diagnostics/connector/error/?code=setup" == result.redirectUrl )
			assert( requestMock.cookie_jar.length == 0 )
		end

		def test_ValidateRequestByIntegrationConfig_Debug_ExpiredToken
			requestMock = HttpRequestMock.new
			requestMock.cookie_jar = {}
			
			expiredDebugToken = QueueITTokenGenerator::generateDebugToken("eventId", "secretKey", true)

			result = KnownUser.validateRequestByIntegrationConfig(
				"http://test.com?event1=true", expiredDebugToken, "{}", "customerId", "secretKey",
				requestMock)

			assert( "https://customerId.api2.queue-it.net/customerId/diagnostics/connector/error/?code=timestamp" == result.redirectUrl )
			assert( requestMock.cookie_jar.length == 0 )
		end

		def test_ValidateRequestByIntegrationConfig_Debug_ModifiedToken
			requestMock = HttpRequestMock.new
			requestMock.cookie_jar = {}
			
			invalidDebugToken = QueueITTokenGenerator::generateDebugToken("eventId", "secretKey", false) + "invalid-hash"

			result = KnownUser.validateRequestByIntegrationConfig(
				"http://test.com?event1=true", invalidDebugToken, "{}", "customerId", "secretKey",
				requestMock)

			assert( "https://customerId.api2.queue-it.net/customerId/diagnostics/connector/error/?code=hash" == result.redirectUrl )
			assert( requestMock.cookie_jar.length == 0 )
		end

		def test_ResolveQueueRequestByLocalConfig_Debug
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)

			queueConfig = QueueEventConfig.new
			queueConfig.cookieDomain = "cookieDomain"
			queueConfig.layoutName = "layoutName"
			queueConfig.culture = "culture"
			queueConfig.eventId = "eventId"
			queueConfig.queueDomain = "queueDomain"
			queueConfig.extendCookieValidity = true
			queueConfig.cookieValidityMinute = 10
			queueConfig.version = 12
			queueConfig.actionName = "QueueAction"

			requestMock = HttpRequestMock.new
			requestMock.setRealOriginalUrl("http", "localhost", "/original_url")
			requestMock.cookie_jar = {}
			requestMock.remote_ip = "userIP"
			requestMock.headers = {
				"via" => "v", 
				"forwarded" => "f", 
				"x-forwarded-for" => "xff",
				"x-forwarded-host" => "xfh", 
				"x-forwarded-proto" => "xfp" }

			secretKey = "secretKey"
			queueitToken = QueueITTokenGenerator::generateDebugToken("eventId", secretKey, false)
		
			expectedServerTime = Time.now.utc.iso8601
			KnownUser.resolveQueueRequestByLocalConfig("url", queueitToken, queueConfig, "customerId", secretKey, requestMock)
		
			expectedCookieValue = 
				"SdkVersion=" + UserInQueueService::SDK_VERSION +
				"|Runtime=" + RUBY_VERSION.to_s +
				"|TargetUrl=url|QueueitToken=" + queueitToken + 
				"|OriginalUrl=http://localhost/original_url" + 
				"|QueueConfig=EventId:eventId&Version:12&QueueDomain:queueDomain&CookieDomain:cookieDomain&ExtendCookieValidity:true&CookieValidityMinute:10&LayoutName:layoutName&Culture:culture&ActionName:QueueAction" +
				"|ServerUtcTime=" + expectedServerTime + 
				"|RequestIP=userIP" + 
				"|RequestHttpHeader_Via=v" + 
				"|RequestHttpHeader_Forwarded=f" + 
				"|RequestHttpHeader_XForwardedFor=xff" + 
				"|RequestHttpHeader_XForwardedHost=xfh" + 
				"|RequestHttpHeader_XForwardedProto=xfp"

			assert( requestMock.cookie_jar.length == 1 )
			assert( requestMock.cookie_jar.key?(KnownUser::QUEUEIT_DEBUG_KEY.to_sym) )
			actualCookieValue = requestMock.cookie_jar[KnownUser::QUEUEIT_DEBUG_KEY.to_sym]["value".to_sym]
			assert( expectedCookieValue.eql?(actualCookieValue) )
		end

		def test_ResolveQueueRequestByLocalConfig_Debug_NullConfig
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)

			requestMock = HttpRequestMock.new
			requestMock.setRealOriginalUrl("http", "localhost", "/original_url")
			requestMock.cookie_jar = {}
			requestMock.remote_ip = "userIP"
			requestMock.headers = {
				"via" => "v", 
				"forwarded" => "f", 
				"x-forwarded-for" => "xff",
				"x-forwarded-host" => "xfh", 
				"x-forwarded-proto" => "xfp" }

			queueitToken = QueueITTokenGenerator::generateDebugToken("eventId", "secretKey", false)		
			expectedServerTime = Time.now.utc.iso8601
			
			errorThrown = false
			begin
				KnownUser.resolveQueueRequestByLocalConfig("http://test.com?event1=true", queueitToken, 
					nil, "customerId", "secretKey", requestMock)
			rescue KnownUserError => err
				errmsg = err.message
				errorThrown = err.message.start_with? "queueConfig can not be nil."
			end
		
			assert( errorThrown )

			expectedCookieValue = 
				"SdkVersion=" + UserInQueueService::SDK_VERSION +
				"|Runtime=" + RUBY_VERSION.to_s +
				"|TargetUrl=http://test.com?event1=true" + 
				"|QueueitToken=" + queueitToken + 
				"|OriginalUrl=http://localhost/original_url" + 
				"|QueueConfig=NULL" + 
				"|ServerUtcTime=" + expectedServerTime + 
				"|RequestIP=userIP" + 
				"|RequestHttpHeader_Via=v" + 
				"|RequestHttpHeader_Forwarded=f" + 
				"|RequestHttpHeader_XForwardedFor=xff" + 
				"|RequestHttpHeader_XForwardedHost=xfh" + 
				"|RequestHttpHeader_XForwardedProto=xfp" +
				"|Exception=queueConfig can not be nil."

			assert( requestMock.cookie_jar.length == 1 )
			assert( requestMock.cookie_jar.key?(KnownUser::QUEUEIT_DEBUG_KEY.to_sym) )
			actualCookieValue = requestMock.cookie_jar[KnownUser::QUEUEIT_DEBUG_KEY.to_sym]["value".to_sym]
			assert( expectedCookieValue.eql?(actualCookieValue) )		
		end

		def test_ResolveQueueRequestByLocalConfig_Debug_Missing_CustomerId
			requestMock = HttpRequestMock.new
			requestMock.cookie_jar = {}
			
			queueConfig = QueueEventConfig.new
			expiredDebugToken = QueueITTokenGenerator::generateDebugToken("eventId", "secretKey", true)

			result = KnownUser.resolveQueueRequestByLocalConfig(
				"http://test.com?event1=true", expiredDebugToken, queueConfig, nil, "secretKey",
				requestMock)

			assert( "https://api2.queue-it.net/diagnostics/connector/error/?code=setup" == result.redirectUrl )
			assert( requestMock.cookie_jar.length == 0 )
		end

		def test_ResolveQueueRequestByLocalConfig_Debug_Missing_SecretKey
			requestMock = HttpRequestMock.new
			requestMock.cookie_jar = {}
			
			queueConfig = QueueEventConfig.new
			expiredDebugToken = QueueITTokenGenerator::generateDebugToken("eventId", "secretKey", true)

			result = KnownUser.resolveQueueRequestByLocalConfig(
				"http://test.com?event1=true", expiredDebugToken, queueConfig, "customerId", nil,
				requestMock)

			assert( "https://api2.queue-it.net/diagnostics/connector/error/?code=setup" == result.redirectUrl )
			assert( requestMock.cookie_jar.length == 0 )
		end

		def test_ResolveQueueRequestByLocalConfig_Debug_ExpiredToken
			requestMock = HttpRequestMock.new
			requestMock.cookie_jar = {}
			
			queueConfig = QueueEventConfig.new
			expiredDebugToken = QueueITTokenGenerator::generateDebugToken("eventId", "secretKey", true)

			result = KnownUser.resolveQueueRequestByLocalConfig(
				"http://test.com?event1=true", expiredDebugToken, queueConfig, "customerId", "secretKey",
				requestMock)

			assert( "https://customerId.api2.queue-it.net/customerId/diagnostics/connector/error/?code=timestamp" == result.redirectUrl )
			assert( requestMock.cookie_jar.length == 0 )
		end

		def test_ResolveQueueRequestByLocalConfig_Debug_ModifiedToken
			requestMock = HttpRequestMock.new
			requestMock.cookie_jar = {}
			
			queueConfig = QueueEventConfig.new
			invalidDebugToken = QueueITTokenGenerator::generateDebugToken("eventId", "secretKey", false) + "invalid-hash"

			result = KnownUser.resolveQueueRequestByLocalConfig(
				"http://test.com?event1=true", invalidDebugToken, queueConfig, "customerId", "secretKey",
				requestMock)

			assert( "https://customerId.api2.queue-it.net/customerId/diagnostics/connector/error/?code=hash" == result.redirectUrl )
			assert( requestMock.cookie_jar.length == 0 )
		end

		def test_CancelRequestByLocalConfig_Debug
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)
		
			cancelConfig = CancelEventConfig.new
			cancelConfig.eventId = "eventId"
			cancelConfig.queueDomain = "queueDomain"
			cancelConfig.version = 1
			cancelConfig.cookieDomain = "cookieDomain"
			cancelConfig.actionName = "CancelAction"

			requestMock = HttpRequestMock.new
			requestMock.setRealOriginalUrl("http", "localhost", "/original_url")
			requestMock.cookie_jar = {}
			requestMock.remote_ip = "userIP"
			requestMock.headers = {
				"via" => "v", 
				"forwarded" => "f", 
				"x-forwarded-for" => "xff",
				"x-forwarded-host" => "xfh", 
				"x-forwarded-proto" => "xfp" }

			secretKey = "secretKey"
			queueitToken = QueueITTokenGenerator::generateDebugToken("eventId", secretKey, false)
		
			expectedServerTime = Time.now.utc.iso8601
			KnownUser.cancelRequestByLocalConfig("url", queueitToken, cancelConfig, "customerId", secretKey, requestMock)

			expectedCookieValue = 
				"SdkVersion=" + UserInQueueService::SDK_VERSION +
				"|Runtime=" + RUBY_VERSION.to_s +
				"|TargetUrl=url|QueueitToken=" + queueitToken + 
				"|OriginalUrl=http://localhost/original_url" + 
				"|CancelConfig=EventId:eventId&Version:1&QueueDomain:queueDomain&CookieDomain:cookieDomain&ActionName:" + cancelConfig.actionName + 
				"|ServerUtcTime=" + expectedServerTime + 
				"|RequestIP=userIP" + 
				"|RequestHttpHeader_Via=v" + 
				"|RequestHttpHeader_Forwarded=f" + 
				"|RequestHttpHeader_XForwardedFor=xff" + 
				"|RequestHttpHeader_XForwardedHost=xfh" + 
				"|RequestHttpHeader_XForwardedProto=xfp" 

			assert( requestMock.cookie_jar.length == 1 )
			assert( requestMock.cookie_jar.key?(KnownUser::QUEUEIT_DEBUG_KEY.to_sym) )
			
			actualCookieValue = requestMock.cookie_jar[KnownUser::QUEUEIT_DEBUG_KEY.to_sym]["value".to_sym]
			assert( expectedCookieValue.eql?(actualCookieValue) )
		end

		def test_CancelRequestByLocalConfig_Debug_NullConfig
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)

			requestMock = HttpRequestMock.new
			requestMock.setRealOriginalUrl("http", "localhost", "/original_url")
			requestMock.cookie_jar = {}
			requestMock.remote_ip = "userIP"
			requestMock.headers = {
				"via" => "v", 
				"forwarded" => "f", 
				"x-forwarded-for" => "xff",
				"x-forwarded-host" => "xfh", 
				"x-forwarded-proto" => "xfp" }

			queueitToken = QueueITTokenGenerator::generateDebugToken("eventId", "secretKey", false)		
			expectedServerTime = Time.now.utc.iso8601
			
			errorThrown = false
			begin
				KnownUser.cancelRequestByLocalConfig("http://test.com?event1=true", queueitToken, 
					nil, "customerId", "secretKey", requestMock)
			rescue KnownUserError => err
				errmsg = err.message
				errorThrown = err.message.start_with? "cancelConfig can not be nil."
			end
		
			assert( errorThrown )

			expectedCookieValue = 
				"SdkVersion=" + UserInQueueService::SDK_VERSION +
				"|Runtime=" + RUBY_VERSION.to_s +
				"|TargetUrl=http://test.com?event1=true" + 
				"|QueueitToken=" + queueitToken + 
				"|OriginalUrl=http://localhost/original_url" + 
				"|CancelConfig=NULL" + 
				"|ServerUtcTime=" + expectedServerTime + 
				"|RequestIP=userIP" + 
				"|RequestHttpHeader_Via=v" + 
				"|RequestHttpHeader_Forwarded=f" + 
				"|RequestHttpHeader_XForwardedFor=xff" + 
				"|RequestHttpHeader_XForwardedHost=xfh" + 
				"|RequestHttpHeader_XForwardedProto=xfp" +
				"|Exception=cancelConfig can not be nil."

			assert( requestMock.cookie_jar.length == 1 )
			assert( requestMock.cookie_jar.key?(KnownUser::QUEUEIT_DEBUG_KEY.to_sym) )
			actualCookieValue = requestMock.cookie_jar[KnownUser::QUEUEIT_DEBUG_KEY.to_sym]["value".to_sym]
			assert( expectedCookieValue.eql?(actualCookieValue) )
		end

		def test_CancelRequestByLocalConfig_Debug_Missing_CustomerId
			requestMock = HttpRequestMock.new
			requestMock.cookie_jar = {}
			
			cancelConfig = CancelEventConfig.new
			expiredDebugToken = QueueITTokenGenerator::generateDebugToken("eventId", "secretKey", true)

			result = KnownUser.cancelRequestByLocalConfig(
				"http://test.com?event1=true", expiredDebugToken, cancelConfig, nil, "secretKey",
				requestMock)

			assert( "https://api2.queue-it.net/diagnostics/connector/error/?code=setup" == result.redirectUrl )
			assert( requestMock.cookie_jar.length == 0 )		
		end

		def test_CancelRequestByLocalConfig_Debug_Missing_SecretKey
			requestMock = HttpRequestMock.new
			requestMock.cookie_jar = {}
			
			cancelConfig = CancelEventConfig.new
			expiredDebugToken = QueueITTokenGenerator::generateDebugToken("eventId", "secretKey", true)

			result = KnownUser.cancelRequestByLocalConfig(
				"http://test.com?event1=true", expiredDebugToken, cancelConfig, "customerId", nil,
				requestMock)

			assert( "https://api2.queue-it.net/diagnostics/connector/error/?code=setup" == result.redirectUrl )
			assert( requestMock.cookie_jar.length == 0 )
		end

		def test_CancelRequestByLocalConfig_Debug_ExpiredToken
			requestMock = HttpRequestMock.new
			requestMock.cookie_jar = {}
			
			cancelConfig = CancelEventConfig.new
			expiredDebugToken = QueueITTokenGenerator::generateDebugToken("eventId", "secretKey", true)

			result = KnownUser.cancelRequestByLocalConfig(
				"http://test.com?event1=true", expiredDebugToken, cancelConfig, "customerId", "secretKey",
				requestMock)

			assert( "https://customerId.api2.queue-it.net/customerId/diagnostics/connector/error/?code=timestamp" == result.redirectUrl )
			assert( requestMock.cookie_jar.length == 0 )
		end

		def test_CancelRequestByLocalConfig_Debug_ModifiedToken
			requestMock = HttpRequestMock.new
			requestMock.cookie_jar = {}
			
			cancelConfig = CancelEventConfig.new
			invalidDebugToken = QueueITTokenGenerator::generateDebugToken("eventId", "secretKey", false) + "invalid-hash"

			result = KnownUser.cancelRequestByLocalConfig(
				"http://test.com?event1=true", invalidDebugToken, cancelConfig, "customerId", "secretKey",
				requestMock)

			assert( "https://customerId.api2.queue-it.net/customerId/diagnostics/connector/error/?code=hash" == result.redirectUrl )
			assert( requestMock.cookie_jar.length == 0 )
		end

		def test_CancelRequestByLocalConfig_Exception_NoDebugToken_NoDebugCookie	
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)
		
			cancelConfig = CancelEventConfig.new
			cancelConfig.eventId = "eventId"
			cancelConfig.queueDomain = "queueDomain"
			cancelConfig.version = 1
			cancelConfig.cookieDomain = "cookieDomain"
			cancelConfig.actionName = "CancelAction"

			requestMock = HttpRequestMock.new
			requestMock.setRealOriginalUrl("http", "localhost", "/original_url")
			requestMock.cookie_jar = {}
			requestMock.remote_ip = "userIP"
			requestMock.headers = {
				"via" => "v", 
				"forwarded" => "f", 
				"x-forwarded-for" => "xff",
				"x-forwarded-host" => "xfh", 
				"x-forwarded-proto" => "xfp" }
				userInQueueService.validateCancelRequestRaiseException = true
			begin
				result = KnownUser.cancelRequestByLocalConfig("targetUrl", "token", cancelConfig, "customerId", "secretKey", HttpRequestMock.new)
			rescue Exception => e
				assert(e.message == "Exception")
			end	
			assert( requestMock.cookie_jar.length == 0 )
			assert( userInQueueService.validateCancelRequestCalls.length > 0 )
		end

		def test_ValidateRequestByIntegrationConfig_Exception_NoDebugToken_NoDebugCookie	
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)
			integrationConfig = 
			{
				:Description => "test",
				:Integrations => 
				[
				{
					:Name => "event1action",
					:ActionType => "Cancel",
					:EventId => "event1",
					:CookieDomain => ".test.com",
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
				}
				],
				:CustomerId => "knownusertest",
				:AccountId => "knownusertest",
				:Version => 3,
				:PublishDate => "2017-05-15T21:39:12.0076806Z",
				:ConfigDataVersion => "1.0.0.1"
			}

			integrationConfigJson = JSON.generate(integrationConfig)			

			requestMock = HttpRequestMock.new
			requestMock.setRealOriginalUrl("http", "localhost", "/original_url")
			requestMock.cookie_jar = {}
			requestMock.remote_ip = "userIP"
			requestMock.headers = {
				"via" => "v", 
				"forwarded" => "f", 
				"x-forwarded-for" => "xff",
				"x-forwarded-host" => "xfh", 
				"x-forwarded-proto" => "xfp" }
				userInQueueService.validateCancelRequestRaiseException = true
			begin
				result = KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", requestMock)
			rescue Exception => e
				assert(e.message == "Exception")
			end	
			assert( requestMock.cookie_jar.length == 0 )
			assert( userInQueueService.validateCancelRequestCalls.length > 0 )
		end

		def test_ResolveQueueRequestByLocalConfig_Exception_NoDebugToken_NoDebugCookie	
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)
		
			queueConfig = QueueEventConfig.new
			queueConfig.cookieDomain = "cookieDomain"
			queueConfig.layoutName = "layoutName"
			queueConfig.culture = "culture"
			queueConfig.eventId = "eventId"
			queueConfig.queueDomain = "queueDomain"
			queueConfig.extendCookieValidity = true
			queueConfig.cookieValidityMinute = 10
			queueConfig.version = 12
			queueConfig.actionName = "QueueAction"			

			requestMock = HttpRequestMock.new
			requestMock.setRealOriginalUrl("http", "localhost", "/original_url")
			requestMock.cookie_jar = {}
			requestMock.remote_ip = "userIP"
			requestMock.headers = {
				"via" => "v", 
				"forwarded" => "f", 
				"x-forwarded-for" => "xff",
				"x-forwarded-host" => "xfh", 
				"x-forwarded-proto" => "xfp" }
				userInQueueService.validateQueueRequestRaiseException = true
			begin
				result = KnownUser.resolveQueueRequestByLocalConfig("target", "token", queueConfig, "id", "key", requestMock)
			rescue Exception => e
				assert(e.message == "Exception")
			end	
			assert( requestMock.cookie_jar.length == 0 )
			assert( userInQueueService.validateQueueRequestCalls.length > 0 )
		end
	end
end
