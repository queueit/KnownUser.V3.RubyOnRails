require 'openssl' 
require 'base64'
require 'date'

module QueueIt
	class UserInQueueStateCookieRepository 
		QUEUEIT_DATA_KEY = "QueueITAccepted-SDFrts345E-V3"
    
		def initialize(cookieManager)
			@cookieManager = cookieManager
		end

		def cancelQueueCookie(eventId, cookieDomain) 
			cookieKey = self.class.getCookieKey(eventId)
			@cookieManager.setCookie(cookieKey, nil, -1, cookieDomain)
		end

		def store(eventId, queueId, fixedCookieValidityMinutes, cookieDomain, redirectType, secretKey, tokenIdentifier)
			cookieKey = self.class.getCookieKey(eventId)
			cookieValue = createCookieValue(eventId, queueId, Utils.toString(fixedCookieValidityMinutes), redirectType, secretKey, tokenIdentifier)
			@cookieManager.setCookie(cookieKey, cookieValue, Time.now + (24*60*60), cookieDomain)
		end

		def self.getCookieKey(eventId)
			 return QUEUEIT_DATA_KEY + '_' + eventId
		end

		def createCookieValue(eventId, queueId, fixedCookieValidityMinutes, redirectType, secretKey, tokenIdentifier) 
			issueTime = Time.now.getutc.tv_sec.to_s
			hashValue = generateHash(eventId, queueId, fixedCookieValidityMinutes, redirectType, issueTime, secretKey)
			
			fixedCookieValidityMinutesPart = ""
			if(!Utils.isNilOrEmpty(fixedCookieValidityMinutes))
				fixedCookieValidityMinutesPart = "&FixedValidityMins=" + fixedCookieValidityMinutes
			end
		
			cookieValue = "EventId=" + eventId + "&QueueId=" + queueId + fixedCookieValidityMinutesPart + "&RedirectType=" + redirectType + "&IssueTime=" + issueTime + "&Hash=" + hashValue + '&TokenIdentifier=' + tokenIdentifier
			return cookieValue
		end
    
		def getCookieNameValueMap(cookieValue) 
			result = Hash.new 
			cookieNameValues = cookieValue.split("&")
			cookieNameValues.each do |item|
				arr = item.split("=")
				if(arr.length == 2)
					result[arr[0]] = arr[1]
				end
			end
			return result
		end

		def generateHash(eventId, queueId, fixedCookieValidityMinutes, redirectType, issueTime, secretKey)
			OpenSSL::HMAC.hexdigest('sha256', secretKey, eventId + queueId + fixedCookieValidityMinutes + redirectType + issueTime)
		end

		def isCookieValid(secretKey, cookieNameValueMap, eventId, cookieValidityMinutes, validateTime) 
			begin
				if (!cookieNameValueMap.key?("EventId")) 
					return false
				end
				
				if (!cookieNameValueMap.key?("QueueId")) 
					return false
				end
				
				if (!cookieNameValueMap.key?("RedirectType")) 
					return false
				end
				
				if (!cookieNameValueMap.key?("IssueTime")) 
					return false
				end
				
				if (!cookieNameValueMap.key?("Hash")) 
					return false
				end

				fixedCookieValidityMinutes = ""
				if (cookieNameValueMap.key?("FixedValidityMins")) 
					fixedCookieValidityMinutes = cookieNameValueMap["FixedValidityMins"]
				end
				
				hashValue = generateHash(
					cookieNameValueMap["EventId"], 
					cookieNameValueMap["QueueId"],
					fixedCookieValidityMinutes,
					cookieNameValueMap["RedirectType"],
					cookieNameValueMap["IssueTime"],
					secretKey)
				
				if (hashValue != cookieNameValueMap["Hash"]) 
					return false
				end						
				
				if (eventId.upcase != cookieNameValueMap["EventId"].upcase) 
					return false
				end
				
				if(validateTime)
					validity = cookieValidityMinutes
					if(!Utils.isNilOrEmpty(fixedCookieValidityMinutes))
						validity = fixedCookieValidityMinutes.to_i
					end
					
					expirationTime = cookieNameValueMap["IssueTime"].to_i + (validity*60)
					if(expirationTime < Time.now.getutc.tv_sec)
						return false
					end
				end        		
				
				return true			
			rescue
				return false
			end
		end

		def reissueQueueCookie(eventId, cookieValidityMinutes, cookieDomain, secretKey)       
			cookieKey = self.class.getCookieKey(eventId)
			cookieValue = @cookieManager.getCookie(cookieKey)
			if (cookieValue.nil?) 
				return
			end
       
			cookieNameValueMap = getCookieNameValueMap(cookieValue)
			if (!isCookieValid(secretKey, cookieNameValueMap, eventId, cookieValidityMinutes, true)) 
				return 
			end

			fixedCookieValidityMinutes = ""
			if (cookieNameValueMap.key?("FixedValidityMins")) 
				fixedCookieValidityMinutes = cookieNameValueMap["FixedValidityMins"]
			end

			cookieValue = createCookieValue(
				eventId, 
				cookieNameValueMap["QueueId"], 
				fixedCookieValidityMinutes, 
				cookieNameValueMap["RedirectType"], 
				secretKey,
				cookieNameValueMap["TokenIdentifier"])
			
			@cookieManager.setCookie(cookieKey, cookieValue, Time.now + (24*60*60), cookieDomain)
		end

		def getState(eventId, cookieValidityMinutes, secretKey, validateTime) 
			cookieKey = self.class.getCookieKey(eventId)
			if (@cookieManager.getCookie(cookieKey).nil?) 
				return StateInfo.new(false, nil, nil, nil)
			end
			cookieNameValueMap = getCookieNameValueMap(@cookieManager.getCookie(cookieKey))
			if (!isCookieValid(secretKey, cookieNameValueMap, eventId, cookieValidityMinutes, validateTime))
				return StateInfo.new(false, nil, nil, nil)
			end

			fixedCookieValidityMinutes = nil
			if (cookieNameValueMap.key?("FixedValidityMins")) 
				fixedCookieValidityMinutes = cookieNameValueMap["FixedValidityMins"].to_i
			end

			return StateInfo.new(
				true, 
				cookieNameValueMap["QueueId"], 
				fixedCookieValidityMinutes,
				cookieNameValueMap["RedirectType"],
			    cookieNameValueMap['TokenIdentifier'])
		end
	end

	class StateInfo 
		attr_reader :isValid
		attr_reader :queueId
		attr_reader :fixedCookieValidityMinutes
		attr_reader :redirectType
		attr_reader :tokenIdentifier

		def initialize(isValid, queueId, fixedCookieValidityMinutes, redirectType, tokenIdentifier = nil) 
			@isValid = isValid
			@queueId = queueId
			@fixedCookieValidityMinutes = fixedCookieValidityMinutes
			@redirectType = redirectType
			@tokenIdentifier = tokenIdentifier
		end

		def isStateExtendable
			return @isValid && @fixedCookieValidityMinutes.nil?
		end
	end
end
