require 'cgi'

module QueueIt
	class Utils
		def self.isNilOrEmpty(value)
			return !value || value.to_s == ''
		end
		def self.toString(value)
			if(value == nil)
				return ''
			end
			return value.to_s
		end
		def self.urlEncode(value)
			return CGI.escape(value).gsub("+", "%20").gsub("%7E", "~")
		end
		def self.urlDecode(value)
			return CGI.unescape(value)
		end
		def self.getParameterByName(url, parameterName)
			name = Regexp.escape(parameterName)
			regex = /[?&]#{name}(=([^&#]*)|&|#|$)/
			match = url.match(regex)

			return nil unless match
			return '' if match[2].nil?

			response = CGI.unescape(match[2])

			return response
		end
	end

	class QueueEventConfig
		attr_accessor :eventId	
		attr_accessor :layoutName
		attr_accessor :culture
		attr_accessor :queueDomain
		attr_accessor :extendCookieValidity
		attr_accessor :cookieValidityMinute
		attr_accessor :cookieDomain
		attr_accessor :isCookieHttpOnly
		attr_accessor :isCookieSecure
		attr_accessor :version
		attr_accessor :actionName

		def initialize
			@eventId = nil
			@layoutName = nil
			@culture = nil
			@queueDomain = nil
			@extendCookieValidity = nil
			@cookieValidityMinute = nil
			@cookieDomain = nil
			@isCookieHttpOnly = false
			@isCookieSecure = false
			@version = nil
			@actionName = "unspecified"
		end

		def toString
			return "EventId:" + Utils.toString(eventId) + 
				   "&Version:" + Utils.toString(version) +
				   "&QueueDomain:" + Utils.toString(queueDomain) + 
				   "&CookieDomain:" + Utils.toString(cookieDomain) + 
				   "&IsCookieHttpOnly:" + Utils.toString(isCookieHttpOnly) + 
				   "&IsCookieSecure:" + Utils.toString(isCookieSecure) + 
				   "&ExtendCookieValidity:" + Utils.toString(extendCookieValidity) +
				   "&CookieValidityMinute:" + Utils.toString(cookieValidityMinute) + 
				   "&LayoutName:" + Utils.toString(layoutName) + 
				   "&Culture:" + Utils.toString(culture) +
				   "&ActionName:" + Utils.toString(actionName)
		end
	end

	class CancelEventConfig
		attr_accessor :eventId
		attr_accessor :queueDomain
		attr_accessor :cookieDomain
		attr_accessor :isCookieHttpOnly
		attr_accessor :isCookieSecure
		attr_accessor :version
		attr_accessor :actionName

		def initialize
			@eventId = nil
			@queueDomain = nil
			@cookieDomain = nil
			@isCookieHttpOnly = false
			@isCookieSecure = false
			@version = nil
			@actionName = "unspecified"
		end

		def toString
			return "EventId:" + Utils.toString(eventId) + 
				   "&Version:" + Utils.toString(version) +
				   "&QueueDomain:" + Utils.toString(queueDomain) + 
				   "&CookieDomain:" + Utils.toString(cookieDomain) +
				   "&IsCookieHttpOnly:" + Utils.toString(isCookieHttpOnly) + 
				   "&IsCookieSecure:" + Utils.toString(isCookieSecure) + 
				   "&ActionName:" + Utils.toString(actionName)
		end
	end

	class RequestValidationResult
		attr_reader :actionType
		attr_reader :eventId
		attr_reader :queueId
		attr_reader :redirectUrl
		attr_reader :redirectType
		attr_accessor :actionName
		attr_accessor :isAjaxResult

		def initialize(actionType, eventId, queueId, redirectUrl, redirectType, actionName)
			@actionType = actionType
			@eventId = eventId
			@queueId = queueId
			@redirectUrl = redirectUrl
			@redirectType = redirectType
			@actionName = actionName
		end

		def doRedirect
			return !Utils.isNilOrEmpty(@redirectUrl)
		end

		def getAjaxQueueRedirectHeaderKey
			return "x-queueit-redirect"
		end

		def getAjaxRedirectUrl
			if !Utils.isNilOrEmpty(@redirectUrl)				
				return Utils.urlEncode(@redirectUrl)				
			end
			return ""		
		end
	end

	class KnownUserError < StandardError
		def initialize(message)
			super(message)
		end
	end

	class ActionTypes
		CANCEL = "Cancel"
		QUEUE = "Queue"
		IGNORE = "Ignore"
	end
end