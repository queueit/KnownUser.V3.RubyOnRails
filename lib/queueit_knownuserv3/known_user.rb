require 'cgi'
require 'json'

module QueueIt

	class KnownUser
		QUEUEIT_TOKEN_KEY = "queueittoken"
		QUEUEIT_DEBUG_KEY = "queueitdebug"
		QUEUEIT_AJAX_HEADER_KEY = "x-queueit-ajaxpageurl"

		@@userInQueueService = nil
		def self.getUserInQueueService()
			if (@@userInQueueService == nil)
				return UserInQueueService.new(UserInQueueStateCookieRepository.new(HttpContextProvider.httpContext.cookieManager))
			end

			return @@userInQueueService
		end
		private_class_method :getUserInQueueService

		def self.isQueueAjaxCall
			headers = HttpContextProvider.httpContext.headers
			return headers[QUEUEIT_AJAX_HEADER_KEY] != nil
		end
		private_class_method :isQueueAjaxCall

		def self.generateTargetUrl(originalTargetUrl)
			unless isQueueAjaxCall()
				return originalTargetUrl
			end
			headers = HttpContextProvider.httpContext.headers
			return CGI::unescape(headers[QUEUEIT_AJAX_HEADER_KEY])
		end
		private_class_method :generateTargetUrl

		def self.convertToInt(value)
			begin
				converted = Integer(value)
			rescue
				converted = 0
			end
			return converted
		end
		private_class_method :convertToInt

		def self.logMoreRequestDetails(debugEntries)
			httpContext = HttpContextProvider.httpContext
			headers = httpContext.headers

			debugEntries["ServerUtcTime"] = Time.now.utc.iso8601
			debugEntries["RequestIP"] = httpContext.userHostAddress
			debugEntries["RequestHttpHeader_Via"] = headers["via"]
			debugEntries["RequestHttpHeader_Forwarded"] = headers["forwarded"]
			debugEntries["RequestHttpHeader_XForwardedFor"] = headers["x-forwarded-for"]
			debugEntries["RequestHttpHeader_XForwardedHost"] = headers["x-forwarded-host"]
			debugEntries["RequestHttpHeader_XForwardedProto"] = headers["x-forwarded-proto"]
		end
		private_class_method :logMoreRequestDetails

		def self.setDebugCookie(debugEntries)
			if(debugEntries == nil || debugEntries.length == 0)
				return
			end

			cookieManager = HttpContextProvider.httpContext.cookieManager
			cookieValue = ''
			debugEntries.each do |entry|
				cookieValue << (entry[0].to_s + '=' + entry[1].to_s + '|')
			end
			cookieValue = cookieValue.chop # remove trailing char
			cookieManager.setCookie(QUEUEIT_DEBUG_KEY, cookieValue, nil, nil, false, false)
		end
		private_class_method :setDebugCookie

		def self._resolveQueueRequestByLocalConfig(targetUrl, queueitToken, queueConfig, customerId, secretKey, debugEntries, isDebug)

			if(isDebug)
				debugEntries["SdkVersion"] = UserInQueueService::SDK_VERSION
				debugEntries["Runtime"] = getRuntime()
				debugEntries["TargetUrl"] = targetUrl
				debugEntries["QueueitToken"] = queueitToken
				debugEntries["OriginalUrl"] = getRealOriginalUrl()
				if(queueConfig == nil)
					debugEntries["QueueConfig"] = "NULL"
				else
					debugEntries["QueueConfig"] = queueConfig.toString()
				end
				logMoreRequestDetails(debugEntries)
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

			userInQueueService = getUserInQueueService()
			result = userInQueueService.validateQueueRequest(targetUrl, queueitToken, queueConfig, customerId, secretKey)
			result.isAjaxResult = isQueueAjaxCall()

			return result
		end
		private_class_method :_resolveQueueRequestByLocalConfig

		def self._cancelRequestByLocalConfig(targetUrl, queueitToken, cancelConfig, customerId, secretKey, debugEntries, isDebug)
			targetUrl = generateTargetUrl(targetUrl)

			if(isDebug)
				debugEntries["SdkVersion"] = UserInQueueService::SDK_VERSION
				debugEntries["Runtime"] = getRuntime()
				debugEntries["TargetUrl"] = targetUrl
				debugEntries["QueueitToken"] = queueitToken
				debugEntries["OriginalUrl"] = getRealOriginalUrl()
				if(cancelConfig == nil)
					debugEntries["CancelConfig"] = "NULL"
				else
					debugEntries["CancelConfig"] = cancelConfig.toString()
				end
				logMoreRequestDetails(debugEntries)
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

			userInQueueService = getUserInQueueService()
			result = userInQueueService.validateCancelRequest(targetUrl, cancelConfig, customerId, secretKey)
			result.isAjaxResult = isQueueAjaxCall()

			return result
		end
		private_class_method :_cancelRequestByLocalConfig

		def self.extendQueueCookie(eventId, cookieValidityMinute, cookieDomain, isCookieHttpOnly, isCookieSecure, secretKey)
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

			userInQueueService = getUserInQueueService()
			userInQueueService.extendQueueCookie(eventId, cookieValidityMinute, cookieDomain, isCookieHttpOnly, isCookieSecure, secretKey)
		end

		def self.resolveQueueRequestByLocalConfig(targetUrl, queueitToken, queueConfig, customerId, secretKey)
			debugEntries = Hash.new
			connectorDiagnostics = ConnectorDiagnostics.verify(customerId, secretKey, queueitToken)

			if(connectorDiagnostics.hasError)
				return connectorDiagnostics.validationResult
			end
			begin
				targetUrl = generateTargetUrl(targetUrl)
				return _resolveQueueRequestByLocalConfig(targetUrl, queueitToken, queueConfig, customerId, secretKey, debugEntries, connectorDiagnostics.isEnabled)
			rescue Exception => e
				if(connectorDiagnostics.isEnabled)
					debugEntries["Exception"] = e.message
				end
				raise e
			ensure
				setDebugCookie(debugEntries)
			end
		end

		def self.validateRequestByIntegrationConfig(currentUrlWithoutQueueITToken, queueitToken, integrationConfigJson, customerId, secretKey)
			debugEntries = Hash.new
			customerIntegration = Hash.new
			connectorDiagnostics = ConnectorDiagnostics.verify(customerId, secretKey, queueitToken)

			if(connectorDiagnostics.hasError)
				return connectorDiagnostics.validationResult
			end
			begin
				if(connectorDiagnostics.isEnabled)
					debugEntries["SdkVersion"] = UserInQueueService::SDK_VERSION
					debugEntries["Runtime"] = getRuntime()
					debugEntries["PureUrl"] = currentUrlWithoutQueueITToken
					debugEntries["QueueitToken"] = queueitToken
					debugEntries["OriginalUrl"] = getRealOriginalUrl()
					logMoreRequestDetails(debugEntries)
				end

				customerIntegration = JSON.parse(integrationConfigJson)

				if(connectorDiagnostics.isEnabled)
					if(customerIntegration.length != 0 and customerIntegration["Version"] != nil)
						debugEntries["ConfigVersion"] = customerIntegration["Version"]
					else
						debugEntries["ConfigVersion"] = "NULL"
					end
				end

				if(Utils.isNilOrEmpty(currentUrlWithoutQueueITToken))
					raise KnownUserError, "currentUrlWithoutQueueITToken can not be nil or empty."
				end

				if(customerIntegration.length == 0 || customerIntegration["Version"] == nil)
					raise KnownUserError, "integrationConfigJson is not valid json."
				end

				integrationEvaluator = IntegrationEvaluator.new
				matchedConfig = integrationEvaluator.getMatchedIntegrationConfig(customerIntegration, currentUrlWithoutQueueITToken, HttpContextProvider.httpContext)

				if(connectorDiagnostics.isEnabled)
					if(matchedConfig == nil)
						debugEntries["MatchedConfig"] = "NULL"
					else
						debugEntries["MatchedConfig"] = matchedConfig["Name"]
					end
				end

				if(matchedConfig == nil)
					return RequestValidationResult.new(nil, nil, nil, nil, nil, nil)
				end

				# unspecified or 'Queue' specified
				if(!matchedConfig.key?("ActionType") || Utils.isNilOrEmpty(matchedConfig["ActionType"]) || matchedConfig["ActionType"].eql?(ActionTypes::QUEUE))
					return handleQueueAction(currentUrlWithoutQueueITToken, queueitToken, customerIntegration,
								customerId, secretKey, matchedConfig, debugEntries, connectorDiagnostics.isEnabled)

				elsif(matchedConfig["ActionType"].eql?(ActionTypes::CANCEL))
					return handleCancelAction(currentUrlWithoutQueueITToken, queueitToken, customerIntegration,
								customerId, secretKey, matchedConfig, debugEntries, connectorDiagnostics.isEnabled)

				# for all unknown types default to 'Ignore'
				else
					userInQueueService = getUserInQueueService()
					result = userInQueueService.getIgnoreActionResult(matchedConfig["Name"])
					result.isAjaxResult = isQueueAjaxCall()

					return result
				end
			rescue Exception => e
				if(connectorDiagnostics.isEnabled)
					debugEntries["Exception"] = e.message
				end
				raise e
			ensure
				setDebugCookie(debugEntries)
			end
		end

		def self.handleQueueAction(currentUrlWithoutQueueITToken, queueitToken, customerIntegration, customerId, secretKey, matchedConfig, debugEntries, isDebug)
			queueConfig = QueueEventConfig.new
			queueConfig.eventId = matchedConfig["EventId"]
			queueConfig.layoutName = matchedConfig["LayoutName"]
			queueConfig.culture = matchedConfig["Culture"]
			queueConfig.queueDomain = matchedConfig["QueueDomain"]
			queueConfig.extendCookieValidity = matchedConfig["ExtendCookieValidity"]
			queueConfig.cookieValidityMinute = matchedConfig["CookieValidityMinute"]
			queueConfig.cookieDomain = matchedConfig["CookieDomain"]
			queueConfig.isCookieHttpOnly = matchedConfig["IsCookieHttpOnly"] || false
			queueConfig.isCookieSecure = matchedConfig["IsCookieSecure"] || false
			queueConfig.version = customerIntegration["Version"]
			queueConfig.actionName = matchedConfig["Name"]

			case matchedConfig["RedirectLogic"]
				when "ForcedTargetUrl"
					targetUrl = matchedConfig["ForcedTargetUrl"]
				when "EventTargetUrl"
					targetUrl = ''
				else
					targetUrl = generateTargetUrl(currentUrlWithoutQueueITToken)
			end

			return _resolveQueueRequestByLocalConfig(targetUrl, queueitToken, queueConfig, customerId, secretKey, debugEntries, isDebug)
		end

		def self.handleCancelAction(currentUrlWithoutQueueITToken, queueitToken, customerIntegration, customerId, secretKey, matchedConfig, debugEntries, isDebug)
			cancelConfig = CancelEventConfig.new
			cancelConfig.eventId = matchedConfig["EventId"]
			cancelConfig.queueDomain = matchedConfig["QueueDomain"]
			cancelConfig.cookieDomain = matchedConfig["CookieDomain"]
			cancelConfig.isCookieHttpOnly = matchedConfig["IsCookieHttpOnly"] || false
			cancelConfig.isCookieSecure = matchedConfig["IsCookieSecure"] || false
			cancelConfig.version = customerIntegration["Version"]
			cancelConfig.actionName = matchedConfig["Name"]

			return _cancelRequestByLocalConfig(currentUrlWithoutQueueITToken, queueitToken, cancelConfig, customerId, secretKey, debugEntries, isDebug)
		end

		def self.cancelRequestByLocalConfig(targetUrl, queueitToken, cancelConfig, customerId, secretKey)
			debugEntries = Hash.new
			connectorDiagnostics = ConnectorDiagnostics.verify(customerId, secretKey, queueitToken)

			if(connectorDiagnostics.hasError)
				return connectorDiagnostics.validationResult
			end
			begin
				return _cancelRequestByLocalConfig(targetUrl, queueitToken, cancelConfig, customerId, secretKey, debugEntries, connectorDiagnostics.isEnabled)
			rescue Exception => e
				if(connectorDiagnostics.isEnabled)
					debugEntries["Exception"] = e.message
				end
				raise e
			ensure
				setDebugCookie(debugEntries)
			end
		end

		def self.getRealOriginalUrl()
			return HttpContextProvider.httpContext.url
			# RoR could modify request.original_url if request contains x-forwarded-host/proto http headers.
			# Therefore we need this method to be able to access the 'real' original url.
			#return request.env["rack.url_scheme"] + "://" + request.env["HTTP_HOST"] + request.original_fullpath
		end

		def self.getRuntime()
			return RUBY_VERSION.to_s
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

		def setCookie(name, value, expire, domain, isHttpOnly, isSecure)
			key = name.to_sym
			noDomain = Utils.isNilOrEmpty(domain)
			deleteCookie = Utils.isNilOrEmpty(value)
			noExpire = Utils.isNilOrEmpty(expire)

			if(noDomain)
				if(deleteCookie)
					@cookies.delete(key)
				else
					if(noExpire)
						@cookies[key] = { :value => value, :httponly => isHttpOnly, :secure => isSecure }
					else
						@cookies[key] = { :value => value, :expires => expire, :httponly => isHttpOnly, :secure => isSecure }
					end
				end
			else
				if(deleteCookie)
					@cookies.delete(key, :domain => domain)
				else
					if(noExpire)
						@cookies[key] = { :value => value, :domain => domain, :httponly => isHttpOnly, :secure => isSecure }
					else
						@cookies[key] = { :value => value, :expires => expire, :domain => domain, :httponly => isHttpOnly, :secure => isSecure }
					end
				end
			end
		end
	end
end



