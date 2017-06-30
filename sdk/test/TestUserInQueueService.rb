require 'cgi'
require 'test/unit'
require_relative '../UserInQueueService'
require_relative '../Models'

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

    def store(eventId, queueId,isStateExtendable, cookieValidityMinute, cookieDomain, customerSecretKey) 
        arrayFunctionCallsArgs['store'].push([eventId,
            queueId,
            isStateExtendable,
            cookieValidityMinute,
            cookieDomain,
            customerSecretKey])
    end

    def getState(eventId, customerSecretKey) 
        arrayFunctionCallsArgs['getState'].push([eventId,
            customerSecretKey])
        return arrayReturns['getState'][arrayFunctionCallsArgs['getState'].length - 1]
    end

    def cancelQueueCookie(eventId, cookieDomain) 
        arrayFunctionCallsArgs['cancelQueueCookie'].push([eventId, cookieDomain])
    end

    def extendQueueCookie(eventId, cookieValidityMinute, cookieDomain, customerSecretKey) 
        arrayFunctionCallsArgs['store'].push([
            eventId,
            cookieValidityMinute,
            cookieDomain,
            customerSecretKey])
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

class TestUserInQueueService < Test::Unit::TestCase 
    def test_ValidateRequest_ValidState_ExtendableCookie_NoCookieExtensionFromConfig_DoNotRedirectDoNotStoreCookieWithExtension
        eventConfig =  EventConfig.new()
        eventConfig.eventId = "e1"
        eventConfig.queueDomain = "testDomain"
        eventConfig.cookieDomain = "testDomain"
        eventConfig.cookieValidityMinute = 10
        eventConfig.extendCookieValidity = false
        cookieProviderMock =  UserInQueueStateRepositoryMockClass.new()
        cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(true, "queueId", true  ,   Time.now.getutc.to_i+ 10 * 60))
        testObject = UserInQueueService.new(cookieProviderMock)
        result = testObject.validateRequest("url", "token", eventConfig, "customerid", "key")
        
        assert(!result.doRedirect())
        assert(result.queueId == "queueId")
        assert(!cookieProviderMock.expectCallAny('store'))
        assert(cookieProviderMock.expectCall('getState', 1,["e1", 'key']))
    end

    def test_ValidateRequest_ValidState_ExtendableCookie_CookieExtensionFromConfig_DoNotRedirectDoStoreCookieWithExtension
        eventConfig = EventConfig.new()
        eventConfig.eventId = "e1"
        eventConfig.queueDomain = "testDomain.com"
        eventConfig.cookieDomain = "testDomain"
        eventConfig.cookieValidityMinute=10
        eventConfig.extendCookieValidity=true
         
        cookieProviderMock =  UserInQueueStateRepositoryMockClass.new()
        cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(true, "queueId", true  ,   Time.now.getutc.to_i+ 10 * 60))
        testObject = UserInQueueService.new(cookieProviderMock)
        result = testObject.validateRequest("url", "token", eventConfig, "customerid", "key")
        assert(!result.doRedirect())
        assert(result.eventId == 'e1')
        assert(result.queueId == "queueId")
     
        assert(cookieProviderMock.expectCall('store', 1, ["e1", 'queueId',true, 10, 'testDomain', "key"]))
    end

    def test_ValidateRequest_ValidState_NoExtendableCookie_DoNotRedirectDoNotStoreCookieWithExtension
        eventConfig = EventConfig.new()
        eventConfig.eventId = "e1"
        eventConfig.queueDomain = "testDomain"
        eventConfig.cookieValidityMinute = 10
        eventConfig.extendCookieValidity = true
        cookieProviderMock = UserInQueueStateRepositoryMockClass.new()
        cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(true, "queueId", false  ,   Time.now.getutc.to_i+ 10 * 60))
        testObject = UserInQueueService.new(cookieProviderMock)
        result = testObject.validateRequest("url", "token", eventConfig, "customerid", "key")
        assert(!result.doRedirect())
        assert(result.eventId == 'e1')
        assert(result.queueId == "queueId")
        assert(!cookieProviderMock.expectCallAny('store'))
    end

    def test_ValidateRequest_NoCookie_TampredToken_RedirectToErrorPageWithHashError_DoNotStoreCookie
        key = "4e1db821-a825-49da-acd0-5d376f2068db"
        eventConfig = EventConfig.new()
        eventConfig.eventId = "e1"
        eventConfig.queueDomain = "testDomain.com"
        eventConfig.cookieValidityMinute = 10
        eventConfig.extendCookieValidity = true
        eventConfig.version = 11
        url = "http://test.test.com?b=h"
         
        cookieProviderMock = UserInQueueStateRepositoryMockClass.new()
        cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false, nil, false  ,   -1))
            
        token = generateHash('e1','queueId', (Time.now.getutc.to_i + (3 * 60)).to_s, 'False', nil, key)
        token = token.sub("False", 'True')

        expectedErrorUrl = "https://testDomain.com/error/hash?c=testCustomer&e=e1" + 
                "&ver=v3-ruby-1.0.0.0" +
                 "&cver=11" +
                 "&queueittoken=" + token +
                 "&t=" +  CGI.escape(url)
        testObject = UserInQueueService.new(cookieProviderMock)
        result = testObject.validateRequest(url, token, eventConfig, "testCustomer", key)
        assert(!cookieProviderMock.expectCallAny('store'))
        assert(result.doRedirect())
        assert(result.eventId == 'e1')
      
         matches = /&ts=[^&]*/.match(result.redirectUrl)
      
        timestamp = matches[0].sub("&ts=", "")
        timestamp = timestamp.sub("&", "")
        assert(Time.now.getutc.to_i - timestamp.to_i < 100)
        urlWithoutTimeStamp = result.redirectUrl.gsub(/&ts=[^&]*/, "")
        assert(urlWithoutTimeStamp.upcase() == expectedErrorUrl.upcase())
    end

    def test_ValidateRequest_NoCookie_ExpiredTimeStampInToken_RedirectToErrorPageWithTimeStampError_DoNotStoreCookie
        key = "4e1db821-a825-49da-acd0-5d376f2068db"
        eventConfig = EventConfig.new()
        eventConfig.eventId = "e1"
        eventConfig.queueDomain = "testDomain.com"
        eventConfig.cookieValidityMinute = 10
        eventConfig.extendCookieValidity = true
        eventConfig.version = 11
        url = "http://test.test.com?b=h"
        cookieProviderMock = UserInQueueStateRepositoryMockClass.new
        cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false,nil, false,   -1))
        token = generateHash('e1','queueId', (Time.now.getutc.to_i - (3 * 60)).to_s, 'False', nil, key)
        expectedErrorUrl = "https://testDomain.com/error/timestamp?c=testCustomer&e=e1" + 
                  "&ver=v3-ruby-1.0.0.0" +
                    "&cver=11" +
                 "&queueittoken=" + token +
                 "&t=" + CGI.escape(url)

        testObject = UserInQueueService.new(cookieProviderMock)
        result = testObject.validateRequest(url, token, eventConfig, "testCustomer", key)
        assert(!cookieProviderMock.expectCallAny('store'))
        assert(result.doRedirect())
        assert(result.eventId == 'e1')
        matches = /&ts=[^&]*/.match(result.redirectUrl)
        timestamp = matches[0].sub("&ts=", "")
        timestamp =timestamp.sub("&", "")
        assert(Time.now.getutc.to_i - timestamp.to_i < 100)
        urlWithoutTimeStamp = result.redirectUrl.gsub(/&ts=[^&]*/, "")
        assert(urlWithoutTimeStamp.upcase == expectedErrorUrl.upcase)
    end
    
    def test_ValidateRequest_NoCookie_EventIdMismatch_RedirectToErrorPageWithEventIdMissMatchError_DoNotStoreCookie
        key = "4e1db821-a825-49da-acd0-5d376f2068db"
        eventConfig = EventConfig.new()
        eventConfig.eventId = "e2"
        eventConfig.queueDomain = "testDomain.com"
        eventConfig.cookieValidityMinute = 10
        eventConfig.extendCookieValidity = true
        eventConfig.version = 11
        url = "http://test.test.com?b=h"
        cookieProviderMock = UserInQueueStateRepositoryMockClass.new
        cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false,nil, false,   -1))
        token = generateHash('e1', 'queueId',(Time.now.getutc.to_i - (3 * 60)).to_s, 'False', nil, key)
        expectedErrorUrl = "https://testDomain.com/error/eventid?c=testCustomer&e=e2" + 
                "&ver=v3-ruby-1.0.0.0"+ "&cver=11" +
                "&queueittoken=" + token +
                "&t=" + CGI.escape(url)
        testObject = UserInQueueService.new(cookieProviderMock)
        result = testObject.validateRequest(url, token, eventConfig, "testCustomer", key)
        assert(!cookieProviderMock.expectCallAny('store'))
        assert(result.doRedirect())
        assert(result.eventId == 'e2')
        matches = /&ts=[^&]*/.match(result.redirectUrl)
        timestamp = matches[0].sub("&ts=", "")
        timestamp = timestamp.sub("&", "")
        assert(Time.now.getutc.to_i - timestamp.to_i < 100)
        urlWithoutTimeStamp = result.redirectUrl.gsub(/&ts=[^&]*/, "")
        assert(urlWithoutTimeStamp.upcase == expectedErrorUrl.upcase)
    end

    def test_ValidateRequest_NoCookie_ValidToken_ExtendableCookie_DoNotRedirect_StoreEextendableCookie
        key = "4e1db821-a825-49da-acd0-5d376f2068db"
        eventConfig = EventConfig.new()
        eventConfig.eventId = "e1"
        eventConfig.queueDomain = "testDomain.com"
        eventConfig.cookieValidityMinute = 10
        eventConfig.cookieDomain = "testDomain"
        eventConfig.extendCookieValidity = true
        eventConfig.version = 11
        url = "http://test.test.com?b=h"
        cookieProviderMock = UserInQueueStateRepositoryMockClass.new
        cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false, nil, false,   -1))
        
        token = generateHash('e1', 'queueId',(Time.now.getutc.to_i + (3 * 60)).to_s, 'true', nil, key)
        testObject = UserInQueueService.new(cookieProviderMock)
        result = testObject.validateRequest(url, token, eventConfig, "testCustomer", key)
        assert(!result.doRedirect())
        assert(result.eventId == 'e1')
        assert(result.queueId == 'queueId')
        assert(cookieProviderMock.expectCall('store', 1, ["e1",'queueId', true, 10, 'testDomain', key]))
    end

    def test_ValidateRequest_NoCookie_ValidToken_CookieValidityMinuteFromToken_DoNotRedirect_StoreNonEextendableCookie
        key = "4e1db821-a825-49da-acd0-5d376f2068db"
        eventConfig = EventConfig.new()
        eventConfig.eventId = "e1"
        eventConfig.queueDomain = "testDomain.com"
        eventConfig.cookieValidityMinute = 30
        eventConfig.cookieDomain = "testDomain"
        eventConfig.extendCookieValidity = true
        eventConfig.version = 11
        url = "http://test.test.com?b=h"
        cookieProviderMock =  UserInQueueStateRepositoryMockClass.new()
        cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false, nil, false,   -1))
        token = generateHash('e1', 'queueId',(Time.now.getutc.to_i + (3 * 60)).to_s, 'false', 3, key)
        testObject = UserInQueueService.new(cookieProviderMock)
        result = testObject.validateRequest(url, token, eventConfig, "testCustomer", key)
        assert(!result.doRedirect())
        assert(result.eventId == 'e1')
         assert(result.queueId == 'queueId')
        assert(cookieProviderMock.expectCall('store', 1, ["e1",'queueId', false, 3, 'testDomain', key]))
    end

    def test_NoCookie_NoValidToken_WithoutToken_RedirectToQueue() 
        key = "4e1db821-a825-49da-acd0-5d376f2068db"
        eventConfig = EventConfig.new()
        eventConfig.eventId = "e1"
        eventConfig.queueDomain = "testDomain.com"
        eventConfig.cookieValidityMinute = 10
        eventConfig.extendCookieValidity = true
        eventConfig.version = 11
        eventConfig.culture = 'en-US'
        eventConfig.layoutName = 'testlayout'
        url = "http://test.test.com?b=h"
        cookieProviderMock = UserInQueueStateRepositoryMockClass.new()
        cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false, nil, false,   -1))
        token = ""
        expectedErrorUrl = "https://testDomain.com?c=testCustomer&e=e1" +
                "&ver=v3-ruby-1.0.0.0" + "&cver=11"  + "&cid=en-US" +
                "&l=testlayout"+"&t=" + CGI.escape(url)
        testObject = UserInQueueService.new(cookieProviderMock)
        result = testObject.validateRequest(url, token, eventConfig, "testCustomer", key)
        assert(!cookieProviderMock.expectCallAny('store'))
        assert(result.doRedirect())
        assert(result.eventId == 'e1')
         assert(result.queueId == nil)
        assert(result.redirectUrl.upcase() == expectedErrorUrl.upcase())
    end
    
    def test_NoCookie_NoValidToken_WithoutToken_RedirectToQueue_NoTargetUrl
        key = "4e1db821-a825-49da-acd0-5d376f2068db"
        eventConfig = EventConfig.new()
        eventConfig.eventId = "e1"
        eventConfig.queueDomain = "testDomain.com"
        eventConfig.cookieValidityMinute = 10
        eventConfig.extendCookieValidity = true
        eventConfig.version = 11
        eventConfig.culture = 'en-US'
        eventConfig.layoutName = 'testlayout'
        cookieProviderMock = UserInQueueStateRepositoryMockClass.new()
        cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false, nil, false, -1))
        token = ""
        expectedErrorUrl = "https://testDomain.com?c=testCustomer&e=e1" +
                "&ver=v3-ruby-1.0.0.0" + "&cver=11"  + "&cid=en-US" +
                "&l=testlayout"
        testObject = UserInQueueService.new(cookieProviderMock)
        result = testObject.validateRequest(nil, token, eventConfig, "testCustomer", key)
        assert(!cookieProviderMock.expectCallAny('store'))
        assert(result.doRedirect())
        assert(result.eventId == 'e1')
         assert(result.queueId == nil)
        assert(result.redirectUrl.upcase() == expectedErrorUrl.upcase())
    end

    def test_ValidateRequest_NoCookie_InValidToken
        key = "4e1db821-a825-49da-acd0-5d376f2068db"
        eventConfig = EventConfig.new()
        eventConfig.eventId = "e1"
        eventConfig.queueDomain = "testDomain.com"
        eventConfig.cookieValidityMinute = 10
        eventConfig.extendCookieValidity = true
        eventConfig.version = 11
        eventConfig.culture = 'en-US'
        eventConfig.layoutName = 'testlayout'
        url = "http://test.test.com?b=h"
        cookieProviderMock =  UserInQueueStateRepositoryMockClass.new
        cookieProviderMock.arrayReturns['getState'].push(StateInfo.new(false, nil, false, -1))
        testObject = UserInQueueService.new(cookieProviderMock)
        result = testObject.validateRequest(url, "ts_sasa~cv_adsasa~ce_falwwwse~q_944c1f44-60dd-4e37-aabc-f3e4bb1c8895", eventConfig, "testCustomer", key)
        assert(!cookieProviderMock.expectCallAny('store'))
        assert(result.doRedirect())
        assert(result.eventId == 'e1')
           assert(result.queueId == nil)
        assert(result.redirectUrl.start_with?("https://testDomain.com/error/hash?c=testCustomer&e=e1"))
    end

    def generateHash(eventId,queueId ,timestamp, extendableCookie, cookieValidityMinute, secretKey) 
        token = 'e_' + eventId + '~ts_' + timestamp + '~ce_' + extendableCookie + '~q_' +  queueId
        if (!cookieValidityMinute.nil?)
            token = token + '~cv_' + cookieValidityMinute.to_s
        end 
        return token + '~h_' + OpenSSL::HMAC.hexdigest('sha256', secretKey, token)       
    end
end