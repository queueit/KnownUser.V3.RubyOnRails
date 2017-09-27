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

		def store(eventId, queueId, isStateExtendable, cookieValidityMinute, cookieDomain, secretKey)
			cookieKey = self.class.getCookieKey(eventId)
			expirationTime = (Time.now.getutc.tv_sec + (cookieValidityMinute * 60)).to_s
			isStateExtendableString = (isStateExtendable) ? 'true' : 'false'
			cookieValue = createCookieValue(queueId, isStateExtendableString, expirationTime, secretKey)
			@cookieManager.setCookie(cookieKey, cookieValue, Time.now + (24*60*60), cookieDomain)
		end

		def self.getCookieKey(eventId)
			 return QUEUEIT_DATA_KEY + '_' + eventId
		end

		def createCookieValue(queueId, isStateExtendable, expirationTime, secretKey) 
			hashValue = OpenSSL::HMAC.hexdigest('sha256', secretKey, queueId + isStateExtendable + expirationTime) 
			cookieValue = "QueueId=" + queueId + "&IsCookieExtendable=" + isStateExtendable + "&Expires=" + expirationTime + "&Hash=" + hashValue        
			return cookieValue
		end
    
		def getCookieNameValueMap(cookieValue) 
			result = Hash.new 
			cookieNameValues = cookieValue.split("&")
			if (cookieNameValues.length != 4) 
				return result
			end

			cookieNameValues.each do |item|
				arr = item.split("=")
				if(arr.length == 2)
					result[arr[0]] = arr[1]
				end
			end
			return result
		end

		def isCookieValid(cookieNameValueMap, secretKey) 
			begin
				if (!cookieNameValueMap.key?("IsCookieExtendable")) 
					return false
				end
				if (!cookieNameValueMap.key?("Expires")) 
					return false
				end
				if (!cookieNameValueMap.key?("Hash")) 
					return false
				end
				if (!cookieNameValueMap.key?("QueueId")) 
					return false
				end
				hashValue = OpenSSL::HMAC.hexdigest('sha256', secretKey, cookieNameValueMap["QueueId"] + cookieNameValueMap["IsCookieExtendable"] + cookieNameValueMap["Expires"]) 
				if (hashValue != cookieNameValueMap["Hash"]) 
					return false
				end		
				if(Integer(cookieNameValueMap["Expires"]) < Time.now.getutc.tv_sec) 
					return false
				end
				return true
			rescue
				return false
			end
		end

		def extendQueueCookie(eventId, cookieValidityMinute, cookieDomain, secretKey)       
			cookieKey = self.class.getCookieKey(eventId)
			cookieValue = @cookieManager.getCookie(cookieKey)
			if (cookieValue.nil?) 
				return
			end
       
			cookieNameValueMap = getCookieNameValueMap(cookieValue)
			if (!isCookieValid(cookieNameValueMap, secretKey)) 
				return 
			end
			expirationTime = (Time.now.getutc.tv_sec + (cookieValidityMinute * 60)).to_s
			cookieValue = createCookieValue(cookieNameValueMap["QueueId"], cookieNameValueMap["IsCookieExtendable"], expirationTime, secretKey)
			@cookieManager.setCookie(cookieKey, cookieValue, Time.now + (24*60*60), cookieDomain)
		end

		def getState(eventId, secretKey) 
			cookieKey = cookieKey = self.class.getCookieKey(eventId)
			if (@cookieManager.getCookie(cookieKey).nil?) 
				return StateInfo.new(false, nil, false, 0)
			end
			cookieNameValueMap = getCookieNameValueMap(@cookieManager.getCookie(cookieKey))
			if (!isCookieValid(cookieNameValueMap, secretKey))
				return StateInfo.new(false, nil, false,0)
			end
			return StateInfo.new(
				true, 
				cookieNameValueMap["QueueId"], 
				cookieNameValueMap["IsCookieExtendable"] == 'true',
				Integer(cookieNameValueMap["Expires"]))
		end
	end

	class StateInfo 
		attr_reader :isValid
		attr_reader :queueId
		attr_reader :isStateExtendable    
		attr_reader :expires # used just for unit tests

		def initialize(isValid, queueId, isStateExtendable, expires) 
			@isValid = isValid
			@queueId = queueId
			@isStateExtendable = isStateExtendable
			@expires = expires
		end
	end
end