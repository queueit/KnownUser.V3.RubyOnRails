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

		def setRealOriginalUrl(proto, host, path)
			@env = {"rack.url_scheme" => proto, "HTTP_HOST" => host}
			@original_fullpath = path
		end
	end

	class UserInQueueServiceMock
		attr_reader :extendQueueCookieCalls
		attr_reader :validateQueueRequestCalls
		attr_reader :validateCancelRequestCalls

		def initialize
			@extendQueueCookieCalls = {}
			@validateQueueRequestCalls = {}
			@validateCancelRequestCalls = {}
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
		end

		def validateCancelRequest(targetUrl, config, customerId, secretKey)
			@validateCancelRequestCalls[@validateQueueRequestCalls.length] = {
				"targetUrl" => targetUrl,
				"config" => config,
				"customerId" => customerId,
				"secretKey" => secretKey
			}
		end
	end

	class QueueITTokenGenerator
		def self.generateDebugToken(eventId, secretKey)
			tokenWithoutHash = (QueueUrlParams::EVENT_ID_KEY + QueueUrlParams::KEY_VALUE_SEPARATOR_CHAR + eventId) + QueueUrlParams::KEY_VALUE_SEPARATOR_GROUP_CHAR + (QueueUrlParams::REDIRECT_TYPE_KEY + QueueUrlParams::KEY_VALUE_SEPARATOR_CHAR + "debug")
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

			KnownUser.cancelRequestByLocalConfig("targetUrl", "token", cancelConfig, "customerId", "secretKey", HttpRequestMock.new)

			assert( userInQueueService.validateCancelRequestCalls[0]["targetUrl"] == "targetUrl" )
			assert( userInQueueService.validateCancelRequestCalls[0]["config"] == cancelConfig )
			assert( userInQueueService.validateCancelRequestCalls[0]["customerId"] == "customerId" )
			assert( userInQueueService.validateCancelRequestCalls[0]["secretKey"] == "secretKey" )
		end

		def test_cancelRequestByLocalConfig_setDebugCookie
			userInQueueService = UserInQueueServiceMock.new 
			KnownUser.class_variable_set(:@@userInQueueService, userInQueueService)
		
			cancelConfig = CancelEventConfig.new
			cancelConfig.eventId = "eventId"
			cancelConfig.queueDomain = "queueDomain"
			cancelConfig.version = 1
			cancelConfig.cookieDomain = "cookieDomain"

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
			queueitToken = QueueITTokenGenerator::generateDebugToken("eventId", secretKey)
		
			expectedServerTime = Time.now.utc.iso8601
			KnownUser.cancelRequestByLocalConfig("url", queueitToken, cancelConfig, "customerId", secretKey, requestMock)

			expectedCookieValue = "TargetUrl=url|QueueitToken=" + queueitToken + 
				"|OriginalUrl=http://localhost/original_url" + 
				"|CancelConfig=EventId:eventId&Version:1&QueueDomain:queueDomain&CookieDomain:cookieDomain" + 
				"|ServerUtcTime=" + expectedServerTime + 
				"|RequestIP=userIP" + 
				"|RequestHttpHeader_Via=v" + 
				"|RequestHttpHeader_Forwarded=f" + 
				"|RequestHttpHeader_XForwardedFor=xff" + 
				"|RequestHttpHeader_XForwardedHost=xfh" + 
				"|RequestHttpHeader_XForwardedProto=xfp" 

			assert( requestMock.cookie_jar.length == 1 );
			assert( requestMock.cookie_jar.key?(KnownUser::QUEUEIT_DEBUG_KEY.to_sym) )
			
			actualCookieValue = requestMock.cookie_jar[KnownUser::QUEUEIT_DEBUG_KEY.to_sym]["value".to_sym]
			assert( expectedCookieValue.eql?(actualCookieValue) )
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

		def test_resolveQueueRequestByLocalConfig_setDebugCookie
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
			queueitToken = QueueITTokenGenerator::generateDebugToken("eventId", secretKey)
		
			expectedServerTime = Time.now.utc.iso8601
			KnownUser.resolveQueueRequestByLocalConfig("url", queueitToken, queueConfig, "customerId", secretKey, requestMock)
		
			expectedCookieValue = "TargetUrl=url|QueueitToken=" + queueitToken + 
				"|OriginalUrl=http://localhost/original_url" + 
				"|QueueConfig=EventId:eventId&Version:12&QueueDomain:queueDomain&CookieDomain:cookieDomain&ExtendCookieValidity:true&CookieValidityMinute:10&LayoutName:layoutName&Culture:culture" +
				"|ServerUtcTime=" + expectedServerTime + 
				"|RequestIP=userIP" + 
				"|RequestHttpHeader_Via=v" + 
				"|RequestHttpHeader_Forwarded=f" + 
				"|RequestHttpHeader_XForwardedFor=xff" + 
				"|RequestHttpHeader_XForwardedHost=xfh" + 
				"|RequestHttpHeader_XForwardedProto=xfp"

			assert( requestMock.cookie_jar.length == 1 );
			assert( requestMock.cookie_jar.key?(KnownUser::QUEUEIT_DEBUG_KEY.to_sym) )
			actualCookieValue = requestMock.cookie_jar[KnownUser::QUEUEIT_DEBUG_KEY.to_sym]["value".to_sym]
			assert( expectedCookieValue.eql?(actualCookieValue) )
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

			KnownUser.resolveQueueRequestByLocalConfig("target", "token", queueConfig, "id", "key", HttpRequestMock.new)

			assert( userInQueueService.validateQueueRequestCalls[0]["targetUrl"] == "target" )
			assert( userInQueueService.validateQueueRequestCalls[0]["queueitToken"] == "token" )
			assert( userInQueueService.validateQueueRequestCalls[0]["config"] == queueConfig )
			assert( userInQueueService.validateQueueRequestCalls[0]["customerId"] == "id" )
			assert( userInQueueService.validateQueueRequestCalls[0]["secretKey"] == "key" )
		end

		def test_validateRequestByIntegrationConfig_empty_currentUrlWithoutQueueITToken
			errorThrown = false
        
			begin
				KnownUser.validateRequestByIntegrationConfig("", "queueIttoken", nil, "customerId", "secretKey", HttpRequestMock.new)
			rescue KnownUserError => err
				errorThrown = err.message.start_with? "currentUrlWithoutQueueITToken can not be nil or empty"
			end
		
			assert( errorThrown )
		end

		def test_validateRequestByIntegrationConfig_empty_integrationsConfigString
			errorThrown = false
        
			begin
				KnownUser.validateRequestByIntegrationConfig("currentUrlWithoutQueueITToken", "queueIttoken", nil, "customerId", "secretKey", HttpRequestMock.new)
			rescue KnownUserError => err
				errorThrown = err.message.start_with? "integrationsConfigString can not be nil or empty"
			end
		
			assert( errorThrown )
		end

		def test_validateRequestByIntegrationConfig_invalid_integrationsConfigString
			errorThrown = false
        
			begin
				KnownUser.validateRequestByIntegrationConfig("currentUrlWithoutQueueITToken", "queueIttoken", "not-valid-json", "customerId", "secretKey", HttpRequestMock.new)
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
			KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "token", integrationConfigJson, "id", "key", mockRequest)

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
		end

		def test_validateRequestByIntegrationConfig_setDebugCookie
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
			queueitToken = QueueITTokenGenerator::generateDebugToken("eventId", secretKey)
		
			expectedServerTime = Time.now.utc.iso8601
			KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", queueitToken, integrationConfigJson, "customerId", secretKey, requestMock)

			expectedCookieValue = "ConfigVersion=3|PureUrl=http://test.com?event1=true|QueueitToken=" + queueitToken + 
				"|OriginalUrl=http://localhost/original_url" +
				"|ServerUtcTime=" + expectedServerTime + 
				"|RequestIP=userIP" + 
				"|RequestHttpHeader_Via=v" + 
				"|RequestHttpHeader_Forwarded=f" + 
				"|RequestHttpHeader_XForwardedFor=xff" + 
				"|RequestHttpHeader_XForwardedHost=xfh" + 
				"|RequestHttpHeader_XForwardedProto=xfp" +
				"|MatchedConfig=event1action|TargetUrl=http://test.com?event1=true|QueueConfig=EventId:event1&Version:3&QueueDomain:knownusertest.queue-it.net&CookieDomain:.test.com&ExtendCookieValidity:true&CookieValidityMinute:20&LayoutName:Christmas Layout by Queue-it&Culture:da-DK"

			assert( requestMock.cookie_jar.length == 1 );
			assert( requestMock.cookie_jar.key?(KnownUser::QUEUEIT_DEBUG_KEY.to_sym) )

			actualCookieValue = requestMock.cookie_jar[KnownUser::QUEUEIT_DEBUG_KEY.to_sym]["value".to_sym]
			assert( expectedCookieValue.eql?(actualCookieValue) )
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

		def test_validateRequestByIntegrationConfig_setDebugCookie_NotMatch
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
			queueitToken = QueueITTokenGenerator::generateDebugToken("eventId", secretKey)		

			integrationConfigJson = JSON.generate(integrationConfig)
			expectedServerTime = Time.now.utc.iso8601
			KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", queueitToken, integrationConfigJson, "customerId", secretKey, requestMock)

			expectedCookieValue = "ConfigVersion=3|PureUrl=http://test.com?event1=true|QueueitToken=" + queueitToken + 
				"|OriginalUrl=http://localhost/original_url" + 
				"|ServerUtcTime=" + expectedServerTime + 
				"|RequestIP=userIP" + 
				"|RequestHttpHeader_Via=v" + 
				"|RequestHttpHeader_Forwarded=f" + 
				"|RequestHttpHeader_XForwardedFor=xff" + 
				"|RequestHttpHeader_XForwardedHost=xfh" + 
				"|RequestHttpHeader_XForwardedProto=xfp" +
				"|MatchedConfig=NULL"

			assert( requestMock.cookie_jar.length == 1 );
			assert( requestMock.cookie_jar.key?(KnownUser::QUEUEIT_DEBUG_KEY.to_sym) )
			actualCookieValue = requestMock.cookie_jar[KnownUser::QUEUEIT_DEBUG_KEY.to_sym]["value".to_sym]
			assert( expectedCookieValue.eql?(actualCookieValue) )
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
			KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", HttpRequestMock.new)
		
			assert( userInQueueService.validateQueueRequestCalls[0]['targetUrl'] == "http://test.com" )
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
			KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", HttpRequestMock.new)
		
			assert( userInQueueService.validateQueueRequestCalls[0]['targetUrl'] == "" )
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
			KnownUser.validateRequestByIntegrationConfig("http://test.com?event1=true", "queueIttoken", integrationConfigJson, "customerid", "secretkey", HttpRequestMock.new)
		
			assert( userInQueueService.validateCancelRequestCalls[0]["targetUrl"] == "http://test.com?event1=true" )
			assert( userInQueueService.validateCancelRequestCalls[0]["customerId"] == "customerid" )
			assert( userInQueueService.validateCancelRequestCalls[0]["secretKey"] == "secretkey" )

			assert( userInQueueService.validateCancelRequestCalls[0]["config"].queueDomain == "knownusertest.queue-it.net" )
			assert( userInQueueService.validateCancelRequestCalls[0]["config"].eventId == "event1" )
			assert( userInQueueService.validateCancelRequestCalls[0]["config"].cookieDomain == ".test.com" )
			assert( userInQueueService.validateCancelRequestCalls[0]["config"].version == 3 )
		end
	end
end