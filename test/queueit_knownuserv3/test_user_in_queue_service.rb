require 'cgi'
require 'test/unit'
require_relative '../../lib/queueit_knownuserv3'

module QueueIt
	class UserInQueueStateRepositoryMockClass
		attr_reader :arrayFunctionCallsArgs
		attr_reader :arrayReturns

		def initialize()
			@arrayFunctionCallsArgs = {
				'store' => Array.new,
				'getState' => Array.new,
				'cancelQueueCookie' => Array.new,
				'extendQueueCookie' => Array.new
			}
			@arrayReturns = {
				'store' => Array.new,
				'getState' => Array.new,
				'cancelQueueCookie' => Array.new,
				'extendQueueCookie' => Array.new
			}
		end

		def store(eventId, queueId, fixedCookieValidityMinutes, cookieDomain, isCookieHttpOnly, isCookieSecure, redirectType, secretKey) 
			arrayFunctionCallsArgs['store'].push([
				eventId,
				queueId,
				fixedCookieValidityMinutes,
				cookieDomain,
				isCookieHttpOnly,
				isCookieSecure,
				redirectType,
				secretKey
			])
		end

		def getState(eventId, cookieValidityMinutes, secretKey, validateTime) 
			arrayFunctionCallsArgs['getState'].push([
				eventId,
				cookieValidityMinutes,
				secretKey,
				validateTime
			])
			return arrayReturns['getState'][arrayFunctionCallsArgs['getState'].length - 1]
		end

		def cancelQueueCookie(eventId, cookieDomain, isCookieHttpOnly, isCookieSecure) 
			arrayFunctionCallsArgs['cancelQueueCookie'].push([eventId, cookieDomain, isCookieHttpOnly, isCookieSecure])
		end

		def reissueQueueCookie(eventId, cookieValidityMinutes, cookieDomain, secretKey)
			arrayFunctionCallsArgs['store'].push([
				eventId,
				cookieValidityMinutes,
				cookieDomain,
				secretKey
			])
		end

		def expectCall(functionName, secquenceNo, argument) 
			if (arrayFunctionCallsArgs[functionName].length >= secquenceNo) 
				argArr = arrayFunctionCallsArgs[functionName][secquenceNo - 1]
				if (argument.length != argArr.length) 
					return false
				end
				(0..argArr.length - 1).each  do |i| 
				  if (argArr[i] != argument[i]) 
						return false
				  end
				end
				return true
			end
			return false
		end

		def expectCallAny(functionName) 
			if (arrayFunctionCallsArgs[functionName].length >= 1) 
				return true
			end
			return false
		end
	end

	class UserInQueueServiceTestable < UserInQueueService
		def validateToken(config, queueParams, secretKey)
			return nil
		end
	end

	class TestUserInQueueService < Test::Unit::TestCase 
		def test_ValidateQueueRequest_ValidState_ExtendableCookie_NoCookieExtensionFromConfig_DoNotRedirectDoNotStoreCookieWithExtension
			queueConfig =  QueueEventConfig.new
			queueConfig.eventId = "e1"
			queueConfig.queueDomain = "testDomain"
			queueConfig.cookieDomain = "testDomain"
			queueConfig.cookieValidityMinute = 10
			queueConfig.extendCookieValidity = false
			queueConfig.actionName = "QueueAction"
			cookieProviderMock =  UserInQueueStateRepositoryMockClass.new()
			cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(true, true, "queueId", nil, "idle"))
			testObject = UserInQueueService.new(cookieProviderMock)
			result = testObject.validateQueueRequest("url", "token", queueConfig, "customerid", "key")
        
			assert(!result.doRedirect())
			assert(result.queueId == "queueId")
			assert(result.actionName == queueConfig.actionName)
			assert(!cookieProviderMock.expectCallAny('store'))
			assert(cookieProviderMock.expectCall('getState', 1,["e1", 10, 'key', true]))
			assert(!cookieProviderMock.expectCallAny('cancelQueueCookie'))
		end

		def test_ValidateQueueRequest_ValidState_ExtendableCookie_CookieExtensionFromConfig_DoNotRedirectDoStoreCookieWithExtension
			queueConfig = QueueEventConfig.new
			queueConfig.eventId = "e1"
			queueConfig.queueDomain = "testDomain.com"
			queueConfig.cookieDomain = "testDomain"
			queueConfig.isCookieHttpOnly = false
			queueConfig.isCookieSecure = false
			queueConfig.cookieValidityMinute=10
			queueConfig.extendCookieValidity=true
			queueConfig.actionName = "QueueAction"

			cookieProviderMock =  UserInQueueStateRepositoryMockClass.new()
			cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(true, true, "queueId", nil, "disabled"))
			testObject = UserInQueueService.new(cookieProviderMock)
			result = testObject.validateQueueRequest("url", "token", queueConfig, "customerid", "key")
			assert(!result.doRedirect())
			assert(result.eventId == 'e1')
			assert(result.queueId == "queueId")
			assert(result.actionName == queueConfig.actionName)
			assert(cookieProviderMock.expectCall('store', 1, ["e1", 'queueId', nil, 'testDomain', false, false, "disabled", "key"]))
			assert(!cookieProviderMock.expectCallAny('cancelQueueCookie'))
		end

		def test_ValidateQueueRequest_ValidState_NoExtendableCookie_DoNotRedirectDoNotStoreCookieWithExtension
			queueConfig = QueueEventConfig.new
			queueConfig.eventId = "e1"
			queueConfig.queueDomain = "testDomain"
			queueConfig.cookieValidityMinute = 10
			queueConfig.extendCookieValidity = true
			queueConfig.actionName = "QueueAction"

			cookieProviderMock = UserInQueueStateRepositoryMockClass.new()
			cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(true, true, "queueId", 3, "idle"))
			testObject = UserInQueueService.new(cookieProviderMock)
			result = testObject.validateQueueRequest("url", "token", queueConfig, "customerid", "key")
			assert(!result.doRedirect())
			assert(result.eventId == 'e1')
			assert(result.queueId == "queueId")
			assert(result.actionName == queueConfig.actionName)
			assert(!cookieProviderMock.expectCallAny('store'))
			assert(!cookieProviderMock.expectCallAny('cancelQueueCookie'))
		end

		def test_ValidateQueueRequest_NoCookie_TampredToken_RedirectToErrorPageWithHashError_DoNotStoreCookie
			key = "4e1db821-a825-49da-acd0-5d376f2068db"
			queueConfig = QueueEventConfig.new
			queueConfig.eventId = "e1"
			queueConfig.queueDomain = "testDomain.com"
			queueConfig.cookieValidityMinute = 10
			queueConfig.extendCookieValidity = true
			queueConfig.version = 11
			queueConfig.actionName = "QueueAction"
			url = "http://test.test.com?b=h"
         
			cookieProviderMock = UserInQueueStateRepositoryMockClass.new()
			cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false, false, nil, nil, nil))
            
			token = generateHash('e1', 'queueId', (Time.now.getutc.to_i + (3 * 60)).to_s, 'False', nil, 'idle', key)
			token = token.sub("False", 'True')
   	    
			expectedErrorUrl = "https://testDomain.com/error/hash/?c=testCustomer&e=e1" + 
					"&ver=" + UserInQueueService::SDK_VERSION +
					 "&cver=11" +
					 "&man=" + queueConfig.actionName +
					 "&queueittoken=" + token +
					 "&t=" +  Utils.urlEncode(url)
			testObject = UserInQueueService.new(cookieProviderMock)
			result = testObject.validateQueueRequest(url, token, queueConfig, "testCustomer", key)
			assert(!cookieProviderMock.expectCallAny('store'))
			assert(result.doRedirect())
			assert(result.eventId == 'e1')
			assert(result.actionName == queueConfig.actionName)
			matches = /&ts=[^&]*/.match(result.redirectUrl)
        
			timestamp = matches[0].sub("&ts=", "")
			timestamp = timestamp.sub("&", "")
			assert(Time.now.getutc.to_i - timestamp.to_i < 100)
			urlWithoutTimeStamp = result.redirectUrl.gsub(/&ts=[^&]*/, "")        
			assert(urlWithoutTimeStamp.upcase() == expectedErrorUrl.upcase())	
			assert(!cookieProviderMock.expectCallAny('cancelQueueCookie'))    
		end

		def test_ValidateQueueRequest_NoCookie_ExpiredTimeStampInToken_RedirectToErrorPageWithTimeStampError_DoNotStoreCookie
			key = "4e1db821-a825-49da-acd0-5d376f2068db"
			queueConfig = QueueEventConfig.new
			queueConfig.eventId = "e1"
			queueConfig.queueDomain = "testDomain.com"
			queueConfig.cookieValidityMinute = 10
			queueConfig.extendCookieValidity = true
			queueConfig.version = 11
			queueConfig.actionName = "QueueAction"
			url = "http://test.test.com?b=h"
			cookieProviderMock = UserInQueueStateRepositoryMockClass.new
			cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false, false, nil, nil, nil))
			token = generateHash('e1','queueId', (Time.now.getutc.to_i - (3 * 60)).to_s, 'False', nil, 'queue', key)
			expectedErrorUrl = "https://testDomain.com/error/timestamp/?c=testCustomer&e=e1" + 
					  "&ver=" + UserInQueueService::SDK_VERSION +
					  "&cver=11" +
					  "&man=" + queueConfig.actionName +
					 "&queueittoken=" + token +
					 "&t=" + Utils.urlEncode(url)

			testObject = UserInQueueService.new(cookieProviderMock)
			result = testObject.validateQueueRequest(url, token, queueConfig, "testCustomer", key)
			assert(!cookieProviderMock.expectCallAny('store'))
			assert(result.doRedirect())
			assert(result.eventId == 'e1')
			assert(result.actionName == queueConfig.actionName)
			matches = /&ts=[^&]*/.match(result.redirectUrl)
			timestamp = matches[0].sub("&ts=", "")
			timestamp =timestamp.sub("&", "")
			assert(Time.now.getutc.to_i - timestamp.to_i < 100)
			urlWithoutTimeStamp = result.redirectUrl.gsub(/&ts=[^&]*/, "")
			assert(urlWithoutTimeStamp.upcase == expectedErrorUrl.upcase)
			assert(!cookieProviderMock.expectCallAny('cancelQueueCookie'))
		end
    
		def test_ValidateQueueRequest_NoCookie_EventIdMismatch_RedirectToErrorPageWithEventIdMissMatchError_DoNotStoreCookie
			key = "4e1db821-a825-49da-acd0-5d376f2068db"
			queueConfig = QueueEventConfig.new
			queueConfig.eventId = "e2"
			queueConfig.queueDomain = "testDomain.com"
			queueConfig.cookieValidityMinute = 10
			queueConfig.extendCookieValidity = true
			queueConfig.version = 11
			queueConfig.actionName = "QueueAction"
			url = "http://test.test.com?b=h"
			cookieProviderMock = UserInQueueStateRepositoryMockClass.new
			cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false, false, nil, nil, nil))
			token = generateHash('e1', 'queueId',(Time.now.getutc.to_i - (3 * 60)).to_s, 'False', nil, 'queue', key)
			expectedErrorUrl = "https://testDomain.com/error/eventid/?c=testCustomer&e=e2" + 
					"&ver=" + UserInQueueService::SDK_VERSION + "&cver=11" +
					"&man=" + queueConfig.actionName +
					"&queueittoken=" + token +
					"&t=" + Utils.urlEncode(url)
			testObject = UserInQueueService.new(cookieProviderMock)
			result = testObject.validateQueueRequest(url, token, queueConfig, "testCustomer", key)
			assert(!cookieProviderMock.expectCallAny('store'))
			assert(result.doRedirect())
			assert(result.eventId == 'e2')
			assert(result.actionName == queueConfig.actionName)
			matches = /&ts=[^&]*/.match(result.redirectUrl)
			timestamp = matches[0].sub("&ts=", "")
			timestamp = timestamp.sub("&", "")
			assert(Time.now.getutc.to_i - timestamp.to_i < 100)
			urlWithoutTimeStamp = result.redirectUrl.gsub(/&ts=[^&]*/, "")
			assert(urlWithoutTimeStamp.upcase == expectedErrorUrl.upcase)
			assert(!cookieProviderMock.expectCallAny('cancelQueueCookie'))
		end

		def test_ValidateQueueRequest_NoCookie_ValidToken_ExtendableCookie_DoNotRedirect_StoreExtendableCookie
			key = "4e1db821-a825-49da-acd0-5d376f2068db"
			queueConfig = QueueEventConfig.new
			queueConfig.eventId = "e1"
			queueConfig.queueDomain = "testDomain.com"
			queueConfig.cookieValidityMinute = 10
			queueConfig.cookieDomain = "testDomain"
			queueConfig.isCookieHttpOnly = false
			queueConfig.isCookieSecure = false
			queueConfig.extendCookieValidity = true
			queueConfig.version = 11
			queueConfig.actionName = "QueueAction"
			url = "http://test.test.com?b=h"
			cookieProviderMock = UserInQueueStateRepositoryMockClass.new
			cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false, false, nil, nil, nil))
        
			token = generateHash('e1', 'queueId',(Time.now.getutc.to_i + (3 * 60)).to_s, 'true', nil, 'queue', key)
			testObject = UserInQueueService.new(cookieProviderMock)
			result = testObject.validateQueueRequest(url, token, queueConfig, "testCustomer", key)
			assert(!result.doRedirect())
			assert(result.eventId == 'e1')
			assert(result.queueId == 'queueId')
			assert(result.redirectType == 'queue')
			assert(result.actionName == queueConfig.actionName)
			assert(cookieProviderMock.expectCall('store', 1, ["e1", 'queueId', nil, 'testDomain', false, false, 'queue', key]))
			assert(!cookieProviderMock.expectCallAny('cancelQueueCookie'))
		end

		def test_ValidateQueueRequest_NoCookie_ValidToken_CookieValidityMinuteFromToken_DoNotRedirect_StoreNonExtendableCookie
			key = "4e1db821-a825-49da-acd0-5d376f2068db"
			queueConfig = QueueEventConfig.new
			queueConfig.eventId = "e1"
			queueConfig.queueDomain = "testDomain.com"
			queueConfig.cookieValidityMinute = 30
			queueConfig.cookieDomain = "testDomain"
			queueConfig.isCookieHttpOnly = false
			queueConfig.isCookieSecure = false
			queueConfig.extendCookieValidity = true
			queueConfig.version = 11
			queueConfig.actionName = "QueueAction"
			url = "http://test.test.com?b=h"
			cookieProviderMock =  UserInQueueStateRepositoryMockClass.new()
			cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false, false, nil, nil, nil))
			token = generateHash('e1', 'queueId',(Time.now.getutc.to_i + (3 * 60)).to_s, 'false', 3, 'DirectLink', key)
			testObject = UserInQueueService.new(cookieProviderMock)
			result = testObject.validateQueueRequest(url, token, queueConfig, "testCustomer", key)
			assert(!result.doRedirect())
			assert(result.eventId == 'e1')
			assert(result.queueId == 'queueId')
			assert(result.redirectType == 'DirectLink')
			assert(result.actionName == queueConfig.actionName)
			assert(cookieProviderMock.expectCall('store', 1, ["e1",'queueId', 3, 'testDomain', false, false, 'DirectLink', key]))
			assert(!cookieProviderMock.expectCallAny('cancelQueueCookie'))
		end

		def test_ValidateQueueRequest_InvalidToken_validateTokenReturnsNull_DoRedirect
			key = "4e1db821-a825-49da-acd0-5d376f2068db"
			queueConfig = QueueEventConfig.new
			queueConfig.eventId = "e1"
			queueConfig.queueDomain = "testDomain.com"
			queueConfig.cookieValidityMinute = 30
			queueConfig.cookieDomain = "testDomain"
			queueConfig.isCookieHttpOnly = false
			queueConfig.isCookieSecure = false
			queueConfig.extendCookieValidity = true
			queueConfig.version = 11
			queueConfig.actionName = "QueueAction"
			url = "http://test.test.com?b=h"
			cookieProviderMock =  UserInQueueStateRepositoryMockClass.new()
			cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false, false, nil, nil, nil))
			token = generateHash('e1', 'queueId',(Time.now.getutc.to_i + (3 * 60)).to_s, 'false', 3, 'DirectLink', key)
			testObject = UserInQueueServiceTestable.new(cookieProviderMock)
			result = testObject.validateQueueRequest(url, token, queueConfig, "testCustomer", key)
			assert(result.doRedirect())
			assert(result.eventId == 'e1')
			assert(result.queueId == nil)
		end

		def test_ValidateQueueRequest_NoCookie_WithoutToken_RedirectToQueue() 
			key = "4e1db821-a825-49da-acd0-5d376f2068db"
			queueConfig = QueueEventConfig.new
			queueConfig.eventId = "e1"
			queueConfig.queueDomain = "testDomain.com"
			queueConfig.cookieValidityMinute = 10
			queueConfig.extendCookieValidity = true
			queueConfig.version = 11
			queueConfig.culture = 'en-US'
			queueConfig.layoutName = 'testlayout'
			queueConfig.actionName = "QueueAction"
			url = "http://test.test.com?b=h"
			cookieProviderMock = UserInQueueStateRepositoryMockClass.new()
			cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false, false, nil, nil, nil))
			token = ""
			expectedRedirectUrl = "https://testDomain.com/?c=testCustomer&e=e1" +
					"&ver=" + UserInQueueService::SDK_VERSION + "&cver=11"  + 
					"&man=" + queueConfig.actionName +
					"&cid=en-US" +
					"&l=testlayout"+"&t=" + Utils.urlEncode(url)
			testObject = UserInQueueService.new(cookieProviderMock)
			result = testObject.validateQueueRequest(url, token, queueConfig, "testCustomer", key)
			assert(!cookieProviderMock.expectCallAny('store'))
			assert(result.doRedirect())
			assert(result.eventId == 'e1')
			assert(result.queueId == nil)
			assert(result.redirectUrl.upcase() == expectedRedirectUrl.upcase())
			assert(result.actionName == queueConfig.actionName)
			assert(!cookieProviderMock.expectCallAny('cancelQueueCookie'))
		end
    		
		def test_ValidateRequest_NoCookie_WithoutToken_RedirectToQueue_NotargetUrl
			key = "4e1db821-a825-49da-acd0-5d376f2068db"
			queueConfig = QueueEventConfig.new
			queueConfig.eventId = "e1"
			queueConfig.queueDomain = "testDomain.com"
			queueConfig.cookieValidityMinute = 10
			queueConfig.extendCookieValidity = true
			queueConfig.version = 11
			queueConfig.culture = 'en-US'
			queueConfig.layoutName = 'testlayout'
			queueConfig.actionName = "QueueAction"
			cookieProviderMock = UserInQueueStateRepositoryMockClass.new()
			cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false, false, nil, nil, nil))
			token = ""
			expectedRedirectUrl = "https://testDomain.com/?c=testCustomer&e=e1" +
					"&ver=" + UserInQueueService::SDK_VERSION + "&cver=11" +
					"&man=" + queueConfig.actionName +
					"&cid=en-US" +
					"&l=testlayout"
			testObject = UserInQueueService.new(cookieProviderMock)
			result = testObject.validateQueueRequest(nil, token, queueConfig, "testCustomer", key)
			assert(!cookieProviderMock.expectCallAny('store'))
			assert(result.doRedirect())
			assert(result.eventId == 'e1')
			assert(result.queueId == nil)
			assert(result.redirectUrl.upcase() == expectedRedirectUrl.upcase())
			assert(result.actionName == queueConfig.actionName)
			assert(!cookieProviderMock.expectCallAny('cancelQueueCookie'))
		end
		
		def test_ValidateRequest_InvalidCookie_WithoutToken_RedirectToQueue_CancelCookie
			key = "4e1db821-a825-49da-acd0-5d376f2068db"
			queueConfig = QueueEventConfig.new
			queueConfig.eventId = "e1"
			queueConfig.queueDomain = "testDomain.com"
			queueConfig.cookieValidityMinute = 10
			queueConfig.extendCookieValidity = true
			queueConfig.version = 11
			queueConfig.culture = 'en-US'
			queueConfig.layoutName = 'testlayout'
			queueConfig.actionName = "QueueAction"
			cookieProviderMock = UserInQueueStateRepositoryMockClass.new()
			cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(true, false, nil, nil, nil))
			token = ""
			expectedRedirectUrl = "https://testDomain.com/?c=testCustomer&e=e1" +
					"&ver=" + UserInQueueService::SDK_VERSION + "&cver=11" +
					"&man=" + queueConfig.actionName +
					"&cid=en-US" +
					"&l=testlayout"
			testObject = UserInQueueService.new(cookieProviderMock)
			result = testObject.validateQueueRequest(nil, token, queueConfig, "testCustomer", key)
			assert(!cookieProviderMock.expectCallAny('store'))
			assert(result.doRedirect())
			assert(result.eventId == 'e1')
			assert(result.queueId == nil)
			assert(result.redirectUrl.upcase() == expectedRedirectUrl.upcase())
			assert(result.actionName == queueConfig.actionName)
			assert(cookieProviderMock.expectCallAny('cancelQueueCookie'))
		end

		def test_ValidateQueueRequest_NoCookie_InValidToken
			key = "4e1db821-a825-49da-acd0-5d376f2068db"
			queueConfig = QueueEventConfig.new
			queueConfig.eventId = "e1"
			queueConfig.queueDomain = "testDomain.com"
			queueConfig.cookieValidityMinute = 10
			queueConfig.extendCookieValidity = true
			queueConfig.version = 11
			queueConfig.culture = 'en-US'
			queueConfig.layoutName = 'testlayout'
			queueConfig.actionName = "QueueAction"
			url = "http://test.test.com?b=h"
			
			expectedRedirectUrl = "https://testDomain.com/error/hash/?c=testCustomer&e=e1" +
					"&ver=" + UserInQueueService::SDK_VERSION + "&cver=11" +
					"&man=" + queueConfig.actionName +
					"&cid=en-US" +
					"&l=testlayout" +
					"&queueittoken=ts_sasa~cv_adsasa~ce_falwwwse~q_944c1f44-60dd-4e37-aabc-f3e4bb1c8895"

			cookieProviderMock =  UserInQueueStateRepositoryMockClass.new
			cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false, false, nil, nil, nil))
			testObject = UserInQueueService.new(cookieProviderMock)
			result = testObject.validateQueueRequest(url, "ts_sasa~cv_adsasa~ce_falwwwse~q_944c1f44-60dd-4e37-aabc-f3e4bb1c8895", queueConfig, "testCustomer", key)
			assert(!cookieProviderMock.expectCallAny('store'))
			assert(result.doRedirect())
			assert(result.eventId == 'e1')
			assert(result.queueId == nil)
			assert(result.redirectUrl.start_with?(expectedRedirectUrl))
			assert(result.actionName == queueConfig.actionName)
			assert(!cookieProviderMock.expectCallAny('cancelQueueCookie'))			
		end

		def test_ValidateRequest_InvalidCookie_InvalidToken_CancelCookie
			key = "4e1db821-a825-49da-acd0-5d376f2068db"
			queueConfig = QueueEventConfig.new
			queueConfig.eventId = "e1"
			queueConfig.queueDomain = "testDomain.com"
			queueConfig.cookieValidityMinute = 10
			queueConfig.extendCookieValidity = true
			queueConfig.version = 11
			queueConfig.culture = 'en-US'
			queueConfig.layoutName = 'testlayout'
			queueConfig.actionName = "QueueAction"
			url = "http://test.test.com?b=h"
			
			expectedRedirectUrl = "https://testDomain.com/error/hash/?c=testCustomer&e=e1" +
					"&ver=" + UserInQueueService::SDK_VERSION + "&cver=11" +
					"&man=" + queueConfig.actionName +
					"&cid=en-US" +
					"&l=testlayout" +
					"&queueittoken=ts_sasa~cv_adsasa~ce_falwwwse~q_944c1f44-60dd-4e37-aabc-f3e4bb1c8895"

			cookieProviderMock =  UserInQueueStateRepositoryMockClass.new
			cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(true, false, nil, nil, nil))
			testObject = UserInQueueService.new(cookieProviderMock)
			result = testObject.validateQueueRequest(url, "ts_sasa~cv_adsasa~ce_falwwwse~q_944c1f44-60dd-4e37-aabc-f3e4bb1c8895", queueConfig, "testCustomer", key)
			assert(!cookieProviderMock.expectCallAny('store'))
			assert(result.doRedirect())
			assert(result.eventId == 'e1')
			assert(result.queueId == nil)
			assert(result.redirectUrl.start_with?(expectedRedirectUrl))
			assert(result.actionName == queueConfig.actionName)
			assert(cookieProviderMock.expectCallAny('cancelQueueCookie'))			
		end	

		def test_validateCancelRequest
			cancelConfig = CancelEventConfig.new
			cancelConfig.eventId = "e1"
			cancelConfig.queueDomain = "testDomain.com"
			cancelConfig.cookieDomain = "my-cookie-domain";
			cancelConfig.isCookieHttpOnly = false
			cancelConfig.isCookieSecure = false
			cancelConfig.version = 10
			cancelConfig.actionName = "Cancel Action (._~-&) !*|'\""
			url = "http://test.test.com?b=h"
			cookieProviderMock = UserInQueueStateRepositoryMockClass.new()
			cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(true, true, "queueId", 3, "idle"))
			expectedUrl = "https://testDomain.com/cancel/testCustomer/e1/queueId?" +
								"c=testCustomer" + 
								"&e=e1" + 
								"&ver=" + UserInQueueService::SDK_VERSION + 
								"&cver=10" + 
								"&man=" + "Cancel%20Action%20%28._~-%26%29%20%21%2A%7C%27%22" + 
								"&r=" + Utils.urlEncode(url);
			testObject = UserInQueueService.new(cookieProviderMock)
			result = testObject.validateCancelRequest(url, cancelConfig, "testCustomer", "key")
		
			assert(cookieProviderMock.expectCall('cancelQueueCookie', 1,["e1", 'my-cookie-domain', false, false]))
			assert(result.doRedirect())
			assert(result.queueId == "queueId")
			assert(result.eventId == 'e1')
			assert(expectedUrl == result.redirectUrl)
			assert(result.actionName == cancelConfig.actionName)
		end

		def test_getIgnoreActionResult
			actionName = "IgnorAction"
			testObject = UserInQueueService.new(UserInQueueStateRepositoryMockClass.new())
			result = testObject.getIgnoreActionResult(actionName)

			assert( !result.doRedirect() )
			assert( result.eventId.nil? )
			assert( result.queueId.nil? )
			assert( result.redirectUrl.nil? )
			assert( result.actionType.eql? 'Ignore' )
			assert(result.actionName == actionName)
		end

		def generateHash(eventId, queueId, timestamp, extendableCookie, cookieValidityMinutes, redirectType, secretKey) 
			token = 'e_' + eventId + '~ts_' + timestamp + '~ce_' + extendableCookie + '~q_' +  queueId
			if (!cookieValidityMinutes.nil?)
				token = token + '~cv_' + cookieValidityMinutes.to_s
			end
			if (!redirectType.nil?)
				token = token + '~rt_' + redirectType
			end
			return token + '~h_' + OpenSSL::HMAC.hexdigest('sha256', secretKey, token)       
		end
	end
end