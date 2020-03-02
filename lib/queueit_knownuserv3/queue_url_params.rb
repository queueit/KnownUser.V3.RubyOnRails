module QueueIt
	class QueueUrlParams
		KEY_VALUE_SEPARATOR_GROUP_CHAR = '~'
		KEY_VALUE_SEPARATOR_CHAR = '_'
		TIMESTAMP_KEY = "ts"
		COOKIE_VALIDITY_MINUTES_KEY = "cv"
		EVENT_ID_KEY = "e"
		EXTENDABLE_COOKIE_KEY = "ce"
		HASH_KEY = "h"
		QUEUE_ID_KEY = "q"
		REDIRECT_TYPE_KEY = "rt"

		attr_accessor :timeStamp
		attr_accessor :eventId
		attr_accessor :hashCode
		attr_accessor :extendableCookie
		attr_accessor :cookieValidityMinutes
		attr_accessor :queueITToken
		attr_accessor :queueITTokenWithoutHash
		attr_accessor :queueId
		attr_accessor :redirectType

		def initialize
			@timeStamp = 0
			@eventId = ""
			@hashCode = ""
			@extendableCookie = false
			@cookieValidityMinutes = nil
			@queueITToken = ""
			@queueITTokenWithoutHash = ""
			@queueId = ""
			@redirectType = nil
		end

		def self.extractQueueParams(queueitToken)
			if(Utils.isNilOrEmpty(queueitToken))
				return nil
			end
			result = QueueUrlParams.new
			result.queueITToken = queueitToken
			paramsNameValueList = result.queueITToken.split(KEY_VALUE_SEPARATOR_GROUP_CHAR)

			paramsNameValueList.each do |pNameValue|
				paramNameValueArr = pNameValue.split(KEY_VALUE_SEPARATOR_CHAR)
				
				if(!paramNameValueArr.length().eql? 2)
					next
				end

				case paramNameValueArr[0]
					when HASH_KEY
						result.hashCode = paramNameValueArr[1]
					when TIMESTAMP_KEY
						if paramNameValueArr[1] !~ /\D/
							result.timeStamp = paramNameValueArr[1].to_i
						else
							result.timeStamp = 0
						end
					when COOKIE_VALIDITY_MINUTES_KEY
						if paramNameValueArr[1] !~ /\D/
							result.cookieValidityMinutes = paramNameValueArr[1].to_i
						else
							result.cookieValidityMinutes = nil
						end
					when EVENT_ID_KEY
						result.eventId = paramNameValueArr[1]
					when EXTENDABLE_COOKIE_KEY
						if paramNameValueArr[1].upcase.eql? 'TRUE'
							result.extendableCookie = true
						end					
					when QUEUE_ID_KEY
						result.queueId = paramNameValueArr[1]
					when REDIRECT_TYPE_KEY
						result.redirectType = paramNameValueArr[1] 
				end		
			end
			result.queueITTokenWithoutHash = result.queueITToken.gsub((KEY_VALUE_SEPARATOR_GROUP_CHAR + HASH_KEY + KEY_VALUE_SEPARATOR_CHAR + result.hashCode), "")		
			return result
		end
	end
end