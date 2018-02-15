require "test/unit"
require_relative '../../lib/queueit_knownuserv3'

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
			}
			@setCookieCalls[@setCookieCalls.length] = {
				"name" => cookieName,
				"value" => value,
				"expiration" => expire,
				"cookieDomain" => domain
			}
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
		def generateHash(eventId, queueId, fixedCookieValidityMinutes, redirectType, issueTime, secretKey)
			OpenSSL::HMAC.hexdigest('sha256', secretKey, eventId + queueId + Utils.toString(fixedCookieValidityMinutes) + redirectType + issueTime)
		end

		def test_store_hasValidState_ExtendableCookie_CookieIsSaved()
			eventId = "event1"
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db"
			cookieDomain = ".test.com"
			queueId = "queueId"
			cookieValidity = 10
			cookieKey = UserInQueueStateCookieRepository::getCookieKey(eventId)
			cookieManager = CookieManagerMockClass.new()
			testObject = UserInQueueStateCookieRepository.new(cookieManager)
			testObject.store(eventId, queueId, nil, cookieDomain, "Queue", secretKey)
			state = testObject.getState(eventId, cookieValidity, secretKey, true)
			assert(state.isValid)
			assert(state.queueId == queueId)
			assert(state.isStateExtendable)
			assert(state.redirectType == 'Queue')
			assert(((cookieManager.cookieList[cookieKey]["expiration"]).to_i - Time.now.getutc.to_i - 24 * 60 * 60).abs < 100)
			assert(cookieManager.cookieList[cookieKey]["cookieDomain"] == cookieDomain)
		end
	    
		def test_store_hasValidState_nonExtendableCookie_CookieIsSaved()
			eventId = "event1"
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db"
			cookieDomain = ".test.com"
			queueId = "queueId"
			cookieValidity = 3
			cookieKey = UserInQueueStateCookieRepository::getCookieKey(eventId)
			cookieManager = CookieManagerMockClass.new()
			testObject = UserInQueueStateCookieRepository.new(cookieManager)
			testObject.store(eventId, queueId, cookieValidity, cookieDomain, "Idle", secretKey)
			state = testObject.getState(eventId, cookieValidity, secretKey, true)
			assert(state.isValid)
			assert(state.queueId == queueId)
			assert(!state.isStateExtendable)
			assert(state.redirectType == 'Idle')
			assert(state.fixedCookieValidityMinutes == 3)
			oldCookieValue = cookieManager.cookieList[cookieKey]["value"]
			assert(((cookieManager.cookieList[cookieKey]["expiration"]).to_i - Time.now.getutc.to_i - 24 * 60 * 60).abs < 100)
			assert(cookieManager.cookieList[cookieKey]["cookieDomain"] == cookieDomain)			
		end
		
		def test_store_hasValidState_tamperedCookie_stateIsNotValid_isCookieExtendable()
			eventId = "event1"
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db"
			cookieDomain = ".test.com"
			queueId = "queueId"
			cookieValidity = 10
			cookieKey = UserInQueueStateCookieRepository::getCookieKey(eventId)
			cookieManager = CookieManagerMockClass.new()
			testObject = UserInQueueStateCookieRepository.new(cookieManager)
			testObject.store(eventId, queueId, 3, cookieDomain, "Idle", secretKey)
			state = testObject.getState(eventId, cookieValidity, secretKey, true)
			assert(state.isValid)
			oldCookieValue = cookieManager.cookieList[cookieKey]["value"]
			cookieManager.cookieList[cookieKey]["value"] = oldCookieValue.sub("FixedValidityMins=3", "FixedValidityMins=10")
			state2 = testObject.getState(eventId, cookieValidity, secretKey, true)
			assert(!state2.isValid)
			assert(!state2.isStateExtendable)
		end
		
		def test_store_hasValidState_tamperedCookie_stateIsNotValid_eventId()
			eventId = "event1"
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db"
			cookieDomain = ".test.com"
			queueId = "queueId"
			cookieValidity = 10
			cookieKey = UserInQueueStateCookieRepository::getCookieKey(eventId)
			cookieManager = CookieManagerMockClass.new()
			testObject = UserInQueueStateCookieRepository.new(cookieManager)
			
			testObject.store(eventId, queueId, 3, cookieDomain, "Idle", secretKey)
			state = testObject.getState(eventId, cookieValidity, secretKey, true)
			assert(state.isValid)

			oldCookieValue = cookieManager.cookieList[cookieKey]["value"]
			cookieManager.cookieList[cookieKey]["value"] = oldCookieValue.sub("EventId=event1", "EventId=event2")
			state2 = testObject.getState(eventId, cookieValidity, secretKey, true)
			assert(!state2.isValid)
			assert(!state2.isStateExtendable)
		end
		
		def	test_store_hasValidState_expiredCookie_stateIsNotValid()
			eventId = "event1"
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db"
			cookieDomain = ".test.com"
			queueId = "queueId"
			cookieValidity = -1
			cookieManager = CookieManagerMockClass.new()
			testObject = UserInQueueStateCookieRepository.new(cookieManager)
			testObject.store(eventId, queueId, nil, cookieDomain, "Idle", secretKey)
			state = testObject.getState(eventId, cookieValidity, secretKey, true)
			assert(!state.isValid)
		end
		
		def test_store_hasValidState_differentEventId_stateIsNotValid()
			eventId = "event1"
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db"
			cookieDomain = ".test.com"
			queueId = "queueId"
			cookieValidity = 10
			cookieManager = CookieManagerMockClass.new()
			testObject = UserInQueueStateCookieRepository.new(cookieManager)
			testObject.store(eventId, queueId, nil, cookieDomain, "Queue", secretKey)
			state = testObject.getState(eventId, cookieValidity, secretKey, true)
			assert(state.isValid)
			state2 = testObject.getState("event2", cookieValidity, secretKey, true)
			assert(!state2.isValid)
		end
		
		def test_hasValidState_noCookie_stateIsNotValid()
			eventId = "event1"
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db"
			cookieDomain = ".test.com"
			queueId = "queueId"
			cookieValidity = 10
			cookieManager = CookieManagerMockClass.new()
			testObject = UserInQueueStateCookieRepository.new(cookieManager)
			state = testObject.getState(eventId, cookieValidity, secretKey, true)
			assert(!state.isValid)			
		end
		
		def test_hasValidState_invalidCookie_stateIsNotValid()
			eventId = "event1"
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db"
			cookieDomain = ".test.com"
			queueId = "queueId"
			cookieKey = UserInQueueStateCookieRepository::getCookieKey(eventId)
			cookieValidity = 10
			cookieManager =  CookieManagerMockClass.new()
			testObject = UserInQueueStateCookieRepository.new(cookieManager)
			testObject.store(eventId, queueId, 20, cookieDomain, "Queue", secretKey)
			state = testObject.getState(eventId, cookieValidity, secretKey, true)
			assert(state.isValid)
			cookieManager.cookieList[cookieKey]["value"] = "IsCookieExtendable=ooOOO&Expires=|||&QueueId=000&Hash=23232"
			state2 = testObject.getState(eventId, cookieValidity, secretKey, true)
			assert(!state2.isValid)
		end
		
		def test_cancelQueueCookie()
			eventId = "event1"
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db"
			cookieDomain = ".test.com"
			queueId = "queueId"
			cookieValidity = 20
			cookieManager = CookieManagerMockClass.new()
			testObject = UserInQueueStateCookieRepository.new(cookieManager)
			testObject.store(eventId, queueId, 20, cookieDomain, "Queue", secretKey)
			state = testObject.getState(eventId, cookieValidity, secretKey, true)
			assert(state.isValid)
			testObject.cancelQueueCookie(eventId, cookieDomain)
			state2 = testObject.getState(eventId, cookieValidity, secretKey, true)
			assert(!state2.isValid)
			assert((cookieManager.setCookieCalls[1]["expiration"]).to_i == -1)
			assert(cookieManager.setCookieCalls[1]["cookieDomain"] == cookieDomain)
			assert(cookieManager.setCookieCalls[1]["value"].nil?)
		end
		
		def test_extendQueueCookie_cookieExist()
			eventId = "event1"
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db"
			cookieDomain = ".test.com"
			queueId = "queueId"
			cookieKey = UserInQueueStateCookieRepository::getCookieKey(eventId)
			cookieManager = CookieManagerMockClass.new()
			testObject = UserInQueueStateCookieRepository.new(cookieManager)
			testObject.store(eventId, queueId, nil, cookieDomain, "Queue", secretKey)
            testObject.reissueQueueCookie(eventId, 12, cookieDomain, secretKey)
	        state = testObject.getState(eventId, 5, secretKey, true)
			assert(state.isValid)
			assert(state.queueId == queueId)
			assert(state.isStateExtendable)
			assert(((cookieManager.cookieList[cookieKey]["expiration"]).to_i - Time.now.getutc.to_i - 24 * 60 * 60).abs < 100)
			assert(cookieManager.cookieList[cookieKey]["cookieDomain"] == cookieDomain)
		end
		
		def test_extendQueueCookie_cookieDoesNotExist()
			eventId = "event1"
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db"
			cookieDomain = ".test.com"
			queueId = "queueId"
			cookieManager = CookieManagerMockClass.new()
			testObject = UserInQueueStateCookieRepository.new(cookieManager)
			testObject.store("event2", queueId, 20, cookieDomain, "Queue", secretKey)
			testObject.reissueQueueCookie(eventId, 12, cookieDomain, secretKey)
			assert(cookieManager.setCookieCalls.length == 1)
		end
		
		def test_getState_validCookieFormat_extendable()
			eventId = "event1"
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db"
			cookieDomain = ".test.com"
			queueId = "queueId"
			cookieKey = UserInQueueStateCookieRepository::getCookieKey(eventId)
			issueTime = Time.now.getutc.tv_sec.to_s
			hash = generateHash(eventId, queueId, nil, "queue", issueTime, secretKey)

			cookieManager = CookieManagerMockClass.new()
			testObject = UserInQueueStateCookieRepository.new(cookieManager)

			cookieManager.setCookie(cookieKey, "EventId="+eventId+"&QueueId="+queueId+"&RedirectType=queue&IssueTime="+issueTime+"&Hash="+hash, Time.now + (24*60*60), cookieDomain)
			state = testObject.getState(eventId, 10, secretKey, true)

			assert(state.isStateExtendable)
			assert(state.isValid)
			assert(state.queueId == queueId)
			assert(state.redirectType == "queue")
		end
		
		def test_getState_oldCookie_invalid_expiredCookie_extendable()
			eventId = "event1"
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db"
			cookieDomain = ".test.com"
			queueId = "queueId"
			cookieKey = UserInQueueStateCookieRepository::getCookieKey(eventId)
			issueTime = (Time.now.getutc.tv_sec - (11*60)).to_s 
			hash = generateHash(eventId, queueId, nil, "queue", issueTime, secretKey)

			cookieManager = CookieManagerMockClass.new()
			testObject = UserInQueueStateCookieRepository.new(cookieManager)

			cookieManager.setCookie(cookieKey, "EventId="+eventId+"&QueueId="+queueId+"&RedirectType=queue&IssueTime="+issueTime+"&Hash="+hash, Time.now + (24*60*60), cookieDomain)
			state = testObject.getState(eventId, 10, secretKey, true)

			assert(!state.isValid)
		end
		
		def test_getState_oldCookie_invalid_expiredCookie_nonExtendable()
			eventId = "event1"
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db"
			cookieDomain = ".test.com"
			queueId = "queueId"
			cookieKey = UserInQueueStateCookieRepository::getCookieKey(eventId)
			issueTime = (Time.now.getutc.tv_sec - (4*60)).to_s 
			hash = generateHash(eventId, queueId, 3, "idle", issueTime, secretKey)

			cookieManager = CookieManagerMockClass.new()
			testObject = UserInQueueStateCookieRepository.new(cookieManager)

			cookieManager.setCookie(cookieKey, "EventId="+eventId+"&QueueId="+queueId+"&FixedValidityMins=3&RedirectType=idle&IssueTime="+issueTime+"&Hash="+hash, Time.now + (24*60*60), cookieDomain)
			state = testObject.getState(eventId, 10, secretKey, true)

			assert(!state.isValid)
		end
		
		def test_getState_validCookieFormat_nonExtendable()
			eventId = "event1"
			secretKey = "4e1deweb821-a82ew5-49da-acdqq0-5d3476f2068db"
			cookieDomain = ".test.com"
			queueId = "queueId"
			cookieKey = UserInQueueStateCookieRepository::getCookieKey(eventId)
			issueTime = Time.now.getutc.tv_sec.to_s 
			hash = generateHash(eventId, queueId, 3, "idle", issueTime, secretKey)

			cookieManager = CookieManagerMockClass.new()
			testObject = UserInQueueStateCookieRepository.new(cookieManager)

			cookieManager.setCookie(cookieKey, "EventId="+eventId+"&QueueId="+queueId+"&FixedValidityMins=3&RedirectType=idle&IssueTime="+issueTime+"&Hash="+hash, Time.now + (24*60*60), cookieDomain)
			state = testObject.getState(eventId, 10, secretKey, true)

			assert(!state.isStateExtendable)
			assert(state.isValid)
			assert(state.queueId == queueId)
			assert(state.redirectType == "idle")
		end
	end
end