require 'json'

require_relative 'Models'
require_relative 'UserInQueueService'
require_relative 'UserInQueueStateCookieRepository'
require_relative 'IntegrationConfigHelpers'

class KnownUser
	QUEUEIT_TOKEN_KEY = "queueittoken"
	
	@@userInQueueService = nil
	
	def self.createUserInQueueService(cookieJar)
		if (@@userInQueueService == nil)
			return UserInQueueService.new(UserInQueueStateCookieRepository.new(CookieManager.new(cookieJar)))
		end
		
		return @@userInQueueService
	end

	def self.convertToInt(value)
		begin
			converted = Integer(value)
		rescue
			converted = 0
		end
		return converted
	end

	def self.cancelQueueCookie(eventId, cookieDomain, cookieJar)
		if(Utils.isNilOrEmpty(eventId))
			raise KnownUserError, "eventId can not be nil or empty."
		end
		
		userInQueueService = KnownUser.createUserInQueueService(cookieJar)
		userInQueueService.cancelQueueCookie(eventId, cookieDomain)
	end

	def self.extendQueueCookie(eventId, cookieValidityMinute, cookieDomain, secretKey, cookieJar)
		if(Utils.isNilOrEmpty(eventId))
			raise KnownUserError, "eventId can not be nil or empty."
		end
		
		if(Utils.isNilOrEmpty(secretKey))
			raise KnownUserError, "secretKey can not be nil or empty."
		end

		minutes = KnownUser.convertToInt(cookieValidityMinute)
		if(minutes <= 0)
			raise KnownUserError, "cookieValidityMinute should be integer greater than 0."	
		end

		userInQueueService = KnownUser.createUserInQueueService(cookieJar)
		userInQueueService.extendQueueCookie(eventId, cookieValidityMinute, cookieDomain, secretKey)
	end

	def self.validateRequestByLocalEventConfig(targetUrl, queueitToken, eventConfig, customerId, secretKey, cookieJar)
		if(Utils.isNilOrEmpty(customerId))
			raise KnownUserError, "customerId can not be nil or empty."
		end
		
		if(Utils.isNilOrEmpty(secretKey))
			raise KnownUserError, "secretKey can not be nil or empty."
		end
		
		if(eventConfig == nil)
			raise KnownUserError, "eventConfig can not be nil."
		end
		
		if(Utils.isNilOrEmpty(eventConfig.eventId))
			raise KnownUserError, "eventConfig.eventId can not be nil or empty."
		end
		
		if(Utils.isNilOrEmpty(eventConfig.queueDomain))
			raise KnownUserError, "eventConfig.queueDomain can not be nil or empty."
		end
		
		minutes = KnownUser.convertToInt(eventConfig.cookieValidityMinute)
		if(minutes <= 0)
			raise KnownUserError, "eventConfig.cookieValidityMinute should be integer greater than 0."	
		end
		
		if(![true, false].include? eventConfig.extendCookieValidity)
			raise KnownUserError, "eventConfig.extendCookieValidity should be valid boolean."
		end

		userInQueueService = KnownUser.createUserInQueueService(cookieJar)
		userInQueueService.validateRequest(targetUrl, queueitToken, eventConfig, customerId, secretKey)
	end

	def self.validateRequestByIntegrationConfig(currentUrl, queueitToken, integrationsConfigString, customerId, secretKey, cookieJar)
		if(Utils.isNilOrEmpty(currentUrl))
			raise KnownUserError, "currentUrl can not be nil or empty."
		end

		if(Utils.isNilOrEmpty(integrationsConfigString))
			raise KnownUserError, "integrationsConfigString can not be nil or empty."
		end

		eventConfig = EventConfig.new
		targetUrl = ''

		begin
			customerIntegration = JSON.parse(integrationsConfigString)
			integrationEvaluator = IntegrationEvaluator.new
			integrationConfig = integrationEvaluator.getMatchedIntegrationConfig(customerIntegration, currentUrl, cookieJar)

			if(integrationConfig == nil)
				return RequestValidationResult.new(nil, nil, nil)
			end
			
			eventConfig.eventId = integrationConfig["EventId"]
			eventConfig.queueDomain = integrationConfig["QueueDomain"]
			eventConfig.layoutName = integrationConfig["LayoutName"]
			eventConfig.culture = integrationConfig["Culture"]
			eventConfig.cookieDomain = integrationConfig["CookieDomain"]
			eventConfig.extendCookieValidity = integrationConfig["ExtendCookieValidity"]
			eventConfig.cookieValidityMinute = integrationConfig["CookieValidityMinute"]
			eventConfig.version = customerIntegration["Version"]
			
			case integrationConfig["RedirectLogic"]
				when "ForcedTargetUrl"
					targetUrl = integrationConfig["ForcedTargetUrl"]					
				when "EventTargetUrl"
					targetUrl = ''
				else
					targetUrl = currentUrl
			end
		rescue StandardError => stdErr
			raise KnownUserError, "integrationConfiguration text was not valid: " + stdErr.message
		end

		return validateRequestByLocalEventConfig(targetUrl, queueitToken, eventConfig, customerId, secretKey, cookieJar)
	end
end

class CookieManager
	@cookies = {}

	def initialize(cookieJar)
		@cookies = cookieJar
	end
	
	def getCookie(name)
		key = name.to_sym
		if(!Utils.isNilOrEmpty(@cookies[key]))
			return @cookies[key]
		end
		return nil
	end

	def setCookie(name, value, expire, domain)
		key = name.to_sym
		noDomain = Utils.isNilOrEmpty(domain) 
		deleteCookie = Utils.isNilOrEmpty(value)

		if(noDomain)	
			if(deleteCookie)
				@cookies.delete(key)
			else
				@cookies[key] = { :value => value, :expires => expire }
			end		
		else
			if(deleteCookie)
				@cookies.delete(key, :domain => domain)				
			else
				@cookies[key] = { :value => value, :expires => expire, :domain => domain }		
			end		
		end		
	end
end