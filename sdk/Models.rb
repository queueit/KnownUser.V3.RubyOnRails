class Utils
	def self.isNilOrEmpty(value)
		return !value || value.empty?
	end
end

class EventConfig
	attr_accessor :eventId	
	attr_accessor :layoutName
	attr_accessor :culture
	attr_accessor :queueDomain
	attr_accessor :extendCookieValidity
	attr_accessor :cookieValidityMinute
	attr_accessor :cookieDomain
	attr_accessor :version

	def initialize
		@eventId = nil
		@layoutName = nil
		@culture = nil
		@queueDomain = nil
		@extendCookieValidity = nil
		@cookieValidityMinute = nil
		@cookieDomain = nil
		@version = nil
	end
end

class RequestValidationResult
	attr_reader :eventId
	attr_reader :queueId
	attr_reader :redirectUrl

	def initialize(eventId, queueId, redirectUrl)
		@eventId = eventId
		@queueId = queueId
		@redirectUrl = redirectUrl
	end

	def doRedirect
		return !Utils.isNilOrEmpty(@redirectUrl)
	end
end

class KnownUserError < StandardError
	def initialize(message)
		super(message)
	end
end