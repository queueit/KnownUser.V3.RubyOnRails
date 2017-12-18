require 'json'

module QueueIt
	class KnownUser
		QUEUEIT_TOKEN_KEY = "queueittoken"
		QUEUEIT_DEBUG_KEY = "queueitdebug"
	
		@@userInQueueService = nil	
		def self.getUserInQueueService(cookieJar)
			if (@@userInQueueService == nil)
				return UserInQueueService.new(UserInQueueStateCookieRepository.new(CookieManager.new(cookieJar)))
			end
		
			return @@userInQueueService
		end
		private_class_method :getUserInQueueService

		def self.convertToInt(value)
			begin
				converted = Integer(value)
			rescue
				converted = 0
			end
			return converted
		end
		private_class_method :convertToInt
	
		def self.logMoreRequestDetails(debugEntries, request)
			debugEntries["ServerUtcTime"] = Time.now.utc.iso8601
			debugEntries["RequestIP"] = request.remote_ip
			debugEntries["RequestHttpHeader_Via"] = request.headers["via"]
			debugEntries["RequestHttpHeader_Forwarded"] = request.headers["forwarded"]
			debugEntries["RequestHttpHeader_XForwardedFor"] = request.headers["x-forwarded-for"]
			debugEntries["RequestHttpHeader_XForwardedHost"] = request.headers["x-forwarded-host"]
			debugEntries["RequestHttpHeader_XForwardedProto"] = request.headers["x-forwarded-proto"]
		end
		private_class_method :logMoreRequestDetails

		def self.getIsDebug(queueitToken, secretKey)
			qParams = QueueUrlParams.extractQueueParams(queueitToken)
			if(qParams == nil)
				return false
			end

			redirectType = qParams.redirectType
			if(redirectType == nil)
				return false
			end
		
			if (redirectType.upcase.eql?("DEBUG"))
				calculatedHash = OpenSSL::HMAC.hexdigest('sha256', secretKey, qParams.queueITTokenWithoutHash)
				valid = qParams.hashCode.eql?(calculatedHash) 
				return valid
			end
			return false
		end
		private_class_method :getIsDebug

		def self.setDebugCookie(debugEntries, cookieJar)
			if(debugEntries == nil || debugEntries.length == 0)
				return
			end
		
			cookieManager = CookieManager.new(cookieJar)
			cookieValue = ''
			debugEntries.each do |entry|
				cookieValue << (entry[0].to_s + '=' + entry[1].to_s + '|')
			end
			cookieValue = cookieValue.chop # remove trailing char		
			cookieManager.setCookie(QUEUEIT_DEBUG_KEY, cookieValue, nil, nil)
		end
		private_class_method :setDebugCookie

		def self._resolveQueueRequestByLocalConfig(targetUrl, queueitToken, queueConfig, customerId, secretKey, request, debugEntries)
			isDebug = getIsDebug(queueitToken, secretKey)
			if(isDebug)
				debugEntries["TargetUrl"] = targetUrl
				debugEntries["QueueitToken"] = queueitToken
				debugEntries["OriginalUrl"] = getRealOriginalUrl(request)
				if(queueConfig == nil)
					debugEntries["QueueConfig"] = "NULL"
				else
					debugEntries["QueueConfig"] = queueConfig.toString()
				end
				logMoreRequestDetails(debugEntries, request)
			end
		
			if(Utils.isNilOrEmpty(customerId))
				raise KnownUserError, "customerId can not be nil or empty."
			end
		
			if(Utils.isNilOrEmpty(secretKey))
				raise KnownUserError, "secretKey can not be nil or empty."
			end
		
			if(queueConfig == nil)
				raise KnownUserError, "queueConfig can not be nil."
			end
		
			if(Utils.isNilOrEmpty(queueConfig.eventId))
				raise KnownUserError, "queueConfig.eventId can not be nil or empty."
			end
		
			if(Utils.isNilOrEmpty(queueConfig.queueDomain))
				raise KnownUserError, "queueConfig.queueDomain can not be nil or empty."
			end
		
			minutes = convertToInt(queueConfig.cookieValidityMinute)
			if(minutes <= 0)
				raise KnownUserError, "queueConfig.cookieValidityMinute should be integer greater than 0."	
			end
		
			if(![true, false].include? queueConfig.extendCookieValidity)
				raise KnownUserError, "queueConfig.extendCookieValidity should be valid boolean."
			end

			userInQueueService = getUserInQueueService(request.cookie_jar)
			userInQueueService.validateQueueRequest(targetUrl, queueitToken, queueConfig, customerId, secretKey)
		end
		private_class_method :_resolveQueueRequestByLocalConfig
	
		def self._cancelRequestByLocalConfig(targetUrl, queueitToken, cancelConfig, customerId, secretKey, request, debugEntries)
			isDebug = getIsDebug(queueitToken, secretKey)
			if(isDebug)
				debugEntries["TargetUrl"] = targetUrl
				debugEntries["QueueitToken"] = queueitToken
				debugEntries["OriginalUrl"] = getRealOriginalUrl(request)
				if(cancelConfig == nil)
					debugEntries["CancelConfig"] = "NULL"
				else
					debugEntries["CancelConfig"] = cancelConfig.toString()
				end
				logMoreRequestDetails(debugEntries, request)
			end
		
			if(Utils.isNilOrEmpty(targetUrl))
				raise KnownUserError, "targetUrl can not be nil or empty."
			end

			if(Utils.isNilOrEmpty(customerId))
				raise KnownUserError, "customerId can not be nil or empty."
			end
		
			if(Utils.isNilOrEmpty(secretKey))
				raise KnownUserError, "secretKey can not be nil or empty."
			end
		
			if(cancelConfig == nil)
				raise KnownUserError, "cancelConfig can not be nil."
			end
		
			if(Utils.isNilOrEmpty(cancelConfig.eventId))
				raise KnownUserError, "cancelConfig.eventId can not be nil or empty."
			end
		
			if(Utils.isNilOrEmpty(cancelConfig.queueDomain))
				raise KnownUserError, "cancelConfig.queueDomain can not be nil or empty."
			end

			userInQueueService = getUserInQueueService(request.cookie_jar)
			userInQueueService.validateCancelRequest(targetUrl, cancelConfig, customerId, secretKey)
		end
		private_class_method :_cancelRequestByLocalConfig

		def self.extendQueueCookie(eventId, cookieValidityMinute, cookieDomain, secretKey, request)
			if(Utils.isNilOrEmpty(eventId))
				raise KnownUserError, "eventId can not be nil or empty."
			end
		
			if(Utils.isNilOrEmpty(secretKey))
				raise KnownUserError, "secretKey can not be nil or empty."
			end

			minutes = convertToInt(cookieValidityMinute)
			if(minutes <= 0)
				raise KnownUserError, "cookieValidityMinute should be integer greater than 0."	
			end

			userInQueueService = getUserInQueueService(request.cookie_jar)
			userInQueueService.extendQueueCookie(eventId, cookieValidityMinute, cookieDomain, secretKey)
		end

		def self.resolveQueueRequestByLocalConfig(targetUrl, queueitToken, queueConfig, customerId, secretKey, request)
			debugEntries = Hash.new
			begin
				return _resolveQueueRequestByLocalConfig(targetUrl, queueitToken, queueConfig, customerId, secretKey, request, debugEntries)
			ensure
				setDebugCookie(debugEntries, request.cookie_jar)
			end
		end

		def self.validateRequestByIntegrationConfig(currentUrlWithoutQueueITToken, queueitToken, integrationsConfigString, customerId, secretKey, request)
			if(Utils.isNilOrEmpty(currentUrlWithoutQueueITToken))
				raise KnownUserError, "currentUrlWithoutQueueITToken can not be nil or empty."
			end

			if(Utils.isNilOrEmpty(integrationsConfigString))
				raise KnownUserError, "integrationsConfigString can not be nil or empty."
			end

			begin
				customerIntegration = JSON.parse(integrationsConfigString)
			
				debugEntries = Hash.new		
				isDebug = getIsDebug(queueitToken, secretKey)
				if(isDebug)
					debugEntries["ConfigVersion"] = customerIntegration["Version"]
					debugEntries["PureUrl"] = currentUrlWithoutQueueITToken
					debugEntries["QueueitToken"] = queueitToken
					debugEntries["OriginalUrl"] = getRealOriginalUrl(request)
					logMoreRequestDetails(debugEntries, request)
				end
			
				integrationEvaluator = IntegrationEvaluator.new
				matchedConfig = integrationEvaluator.getMatchedIntegrationConfig(customerIntegration, currentUrlWithoutQueueITToken, request)

				if(isDebug)
					if(matchedConfig == nil)
						debugEntries["MatchedConfig"] = "NULL"
					else
						debugEntries["MatchedConfig"] = matchedConfig["Name"]
					end
				end

				if(matchedConfig == nil)
					return RequestValidationResult.new(nil, nil, nil, nil)
				end
			
				# unspecified or 'Queue' specified
				if(!matchedConfig.key?("ActionType") || Utils.isNilOrEmpty(matchedConfig["ActionType"]) || matchedConfig["ActionType"].eql?(ActionTypes::QUEUE))
					handleQueueAction(currentUrlWithoutQueueITToken, queueitToken, customerIntegration, customerId, secretKey, matchedConfig, request, debugEntries)
				
				elsif(matchedConfig["ActionType"].eql?(ActionTypes::CANCEL))
					handleCancelAction(currentUrlWithoutQueueITToken, queueitToken, customerIntegration, customerId, secretKey, matchedConfig, request, debugEntries)
					
				# for all unknown types default to 'Ignore'
				else
					userInQueueService = getUserInQueueService(request.cookie_jar)
					userInQueueService.getIgnoreActionResult()
				end

			rescue StandardError => stdErr
				raise KnownUserError, "integrationConfiguration text was not valid: " + stdErr.message
			ensure
				setDebugCookie(debugEntries, request.cookie_jar)
			end
		end

		def self.handleQueueAction(currentUrlWithoutQueueITToken, queueitToken, customerIntegration, customerId, secretKey, matchedConfig, request, debugEntries)
			queueConfig = QueueEventConfig.new
			queueConfig.eventId = matchedConfig["EventId"]
			queueConfig.queueDomain = matchedConfig["QueueDomain"]
			queueConfig.layoutName = matchedConfig["LayoutName"]
			queueConfig.culture = matchedConfig["Culture"]
			queueConfig.cookieDomain = matchedConfig["CookieDomain"]
			queueConfig.extendCookieValidity = matchedConfig["ExtendCookieValidity"]
			queueConfig.cookieValidityMinute = matchedConfig["CookieValidityMinute"]
			queueConfig.version = customerIntegration["Version"]
			
			case matchedConfig["RedirectLogic"]
				when "ForcedTargetUrl"
					targetUrl = matchedConfig["ForcedTargetUrl"]					
				when "EventTargetUrl"
					targetUrl = ''
				else
					targetUrl = currentUrlWithoutQueueITToken
			end

			return _resolveQueueRequestByLocalConfig(targetUrl, queueitToken, queueConfig, customerId, secretKey, request, debugEntries)		
		end

		def self.handleCancelAction(currentUrlWithoutQueueITToken, queueitToken, customerIntegration, customerId, secretKey, matchedConfig, request, debugEntries)
			cancelConfig = CancelEventConfig.new;
			cancelConfig.eventId = matchedConfig["EventId"]
			cancelConfig.queueDomain = matchedConfig["QueueDomain"]
			cancelConfig.cookieDomain = matchedConfig["CookieDomain"]
			cancelConfig.version = customerIntegration["Version"]
            
			return _cancelRequestByLocalConfig(currentUrlWithoutQueueITToken, queueitToken, cancelConfig, customerId, secretKey, request, debugEntries);
		end

		def self.cancelRequestByLocalConfig(targetUrl, queueitToken, cancelConfig, customerId, secretKey, request)
			debugEntries = Hash.new
			begin
				return _cancelRequestByLocalConfig(targetUrl, queueitToken, cancelConfig, customerId, secretKey, request, debugEntries)
			ensure
				setDebugCookie(debugEntries, request.cookie_jar)
			end
		end

		def self.getRealOriginalUrl(request)
			# RoR could modify request.original_url if request contains x-forwarded-host/proto http headers.  
			# Therefore we need this method to be able to access the 'real' original url.
			return request.env["rack.url_scheme"] + "://" + request.env["HTTP_HOST"] + request.original_fullpath
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
			noExpire = Utils.isNilOrEmpty(expire)

			if(noDomain)
				if(deleteCookie)
					@cookies.delete(key)
				else
					if(noExpire)
						@cookies[key] = { :value => value }
					else
						@cookies[key] = { :value => value, :expires => expire }
					end
				end		
			else
				if(deleteCookie)
					@cookies.delete(key, :domain => domain)				
				else
					if(noExpire)
						@cookies[key] = { :value => value, :domain => domain }		
					else
						@cookies[key] = { :value => value, :expires => expire, :domain => domain }		
					end
				end		
			end		
		end
	end
end



