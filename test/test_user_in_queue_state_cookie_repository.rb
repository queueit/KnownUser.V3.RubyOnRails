require "test/unit"
require_relative '../lib/queue_it'

module QueueIt
	class CookieManagerMockClass 
		attr_reader :cookieList
		attr_reader :setCookieCalls
		attr_reader :getCookieCalls

		def initialize()
			@cookieList = Hash.new
			@setCookieCalls = Hash.new
			@getCookieCalls = Hash.new
		end

		def setCookie(cookieName, value, expire, domain) 
			@cookieList[cookieName] = {
				"name" => cookieName,
				"value" => value,
				"expiration" => expire,
				"cookieDomain" => domain
			};
			@setCookieCalls[@setCookieCalls.length] = {
				"name" => cookieName,
				"value" => value,
				"expiration" => expire,
				"cookieDomain" => domain
				};
		end

		def getCookie(cookieName) 
			@getCookieCalls[@getCookieCalls.length] = cookieName
			if(!@cookieList.key?(cookieName))
				return nil
			end
			return @cookieList[cookieName]["value"]
		end
	end

	class TestUserInQueueStateCookieRepository < Test::Unit::TestCase
		def test_store_getState_ExtendableCookie_CookieIsSaved() 
			eventId = "event1";
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db";
			cookieDomain = ".test.com";
			queueId = "queueId";
			cookieValidity = 10;
			cookieKey = UserInQueueStateCookieRepository::getCookieKey(eventId);
			cookieManager = CookieManagerMockClass.new();
			testObject = UserInQueueStateCookieRepository.new(cookieManager);
			testObject.store(eventId, queueId, true, cookieValidity, cookieDomain, secretKey);
			state = testObject.getState(eventId, secretKey);
			assert(state.isValid);
			assert(state.queueId == queueId);
			assert(state.isStateExtendable);
			assert((Time.now.getutc.to_i+ 10 * 60 - state.expires).abs < 100);
			assert(((cookieManager.cookieList[cookieKey]["expiration"]).to_i - Time.now.getutc.to_i - 24 * 60 * 60).abs < 100);
			assert(cookieManager.cookieList[cookieKey]["cookieDomain"] == cookieDomain);
		end

		def test_store_getState_TamperedCookie_StateIsNotValid() 
			eventId = "event1";
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db";
			cookieDomain = ".test.com";
			queueId = "queueId";
			cookieValidity = 10;
			cookieKey = UserInQueueStateCookieRepository::getCookieKey(eventId);
			cookieManager = CookieManagerMockClass.new();
			testObject = UserInQueueStateCookieRepository.new(cookieManager);
			testObject.store(eventId, queueId, false, cookieValidity, cookieDomain, secretKey);
			state = testObject.getState(eventId, secretKey);
			assert(state.isValid);
			oldCookieValue = cookieManager.cookieList[cookieKey]["value"];
			cookieManager.cookieList[cookieKey]["value"] = oldCookieValue.sub("IsCookieExtendable=false", "IsCookieExtendable=true");
			state2 = testObject.getState(eventId, secretKey);
			assert(!state2.isValid);
		end

		def test_store_getState_ExpiredCookie_StateIsNotValid() 
			eventId = "event1";
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db";
			cookieDomain = ".test.com";
			queueId = "queueId";
			cookieManager = CookieManagerMockClass.new();
			testObject = UserInQueueStateCookieRepository.new(cookieManager);
			testObject.store(eventId, queueId, true, -1, cookieDomain, secretKey);
			state = testObject.getState(eventId, secretKey);
			assert(!state.isValid);
		end

		def test_store_getState_DifferentEventId_StateIsNotValid() 
			eventId = "event1";
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db";
			cookieDomain = ".test.com";
			queueId = "queueId";
			cookieManager = CookieManagerMockClass.new();
			testObject = UserInQueueStateCookieRepository.new(cookieManager);
			testObject.store(eventId, queueId, true, 10, cookieDomain, secretKey);
			state = testObject.getState(eventId, secretKey);
			assert(state.isValid);
			state2 = testObject.getState("event2", secretKey);
			assert(!state2.isValid);
		end

		def test_store_getState_InvalidCookie_StateIsNotValid()
			eventId = "event1";
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db";
			cookieDomain = ".test.com";
			queueId = "queueId";
			cookieKey = UserInQueueStateCookieRepository::getCookieKey(eventId);
			cookieManager =  CookieManagerMockClass.new();
			testObject = UserInQueueStateCookieRepository.new(cookieManager);
			testObject.store(eventId, queueId, true, 20, cookieDomain, secretKey);
			state = testObject.getState(eventId, secretKey);
			assert(state.isValid);
			cookieManager.cookieList[cookieKey]["value"] = "IsCookieExtendable=ooOOO&Expires=|||&QueueId=000&Hash=23232";
			state2 = testObject.getState(eventId, secretKey);
			assert(!state2.isValid);
		end

		def test_cancelQueueCookie_Test()
			eventId = "event1";
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db";
			cookieDomain = ".test.com";
			queueId = "queueId";
			cookieManager = CookieManagerMockClass.new();
			testObject = UserInQueueStateCookieRepository.new(cookieManager);
			testObject.store(eventId, queueId, true, 20, cookieDomain, secretKey);
			state = testObject.getState(eventId, secretKey);
			assert(state.isValid);
			testObject.cancelQueueCookie(eventId, cookieDomain);
			state2 = testObject.getState(eventId, secretKey);
			assert(!state2.isValid);
			assert((cookieManager.setCookieCalls[1]["expiration"]).to_i == -1);
			assert(cookieManager.setCookieCalls[1]["cookieDomain"] == cookieDomain);
			assert(cookieManager.setCookieCalls[1]["value"].nil?);
		end

		def test_extendQueueCookie_CookieDoesNotExist_Test() 
			eventId = "event1";
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db";
			cookieDomain = ".test.com";
			queueId = "queueId";
			cookieManager = CookieManagerMockClass.new();
			testObject = UserInQueueStateCookieRepository.new(cookieManager);
			testObject.store("event2", queueId, true, 20, cookieDomain, secretKey);
			testObject.extendQueueCookie(eventId, 20, cookieDomain, secretKey);
			assert(cookieManager.setCookieCalls.length == 1);
		end

		def test_extendQueueCookie_CookietExist_Test() 
			eventId = "event1";
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db";
			cookieDomain = ".test.com";
			queueId = "queueId";
			cookieKey = UserInQueueStateCookieRepository::getCookieKey(eventId);
			cookieManager = CookieManagerMockClass.new();
			testObject = UserInQueueStateCookieRepository.new(cookieManager);
			testObject.store(eventId, queueId, true, 20, cookieDomain, secretKey);
			testObject.extendQueueCookie(eventId, 12, cookieDomain, secretKey);
			state = testObject.getState(eventId, secretKey);
			assert(state.isValid);
			assert(state.queueId == queueId);
			assert(state.isStateExtendable);
			assert((Time.now.getutc.to_i + 12 * 60 - state.expires).abs < 100);
			assert(((cookieManager.cookieList[cookieKey]["expiration"]).to_i - Time.now.getutc.to_i - 24 * 60 * 60).abs < 100);
			assert(cookieManager.cookieList[cookieKey]["cookieDomain"] == cookieDomain);
		end
	end
end