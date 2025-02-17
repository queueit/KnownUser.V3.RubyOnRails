require 'cgi'
require 'json'

module QueueIt
	class KnownUser
		QUEUEIT_TOKEN_KEY = "queueittoken"
		QUEUEIT_DEBUG_KEY = "queueitdebug"
		QUEUEIT_AJAX_HEADER_KEY = "x-queueit-ajaxpageurl"

		def initialize(httpContext)
			@httpContext = httpContext
		end

		def extendQueueCookie(eventId, cookieValidityMinute, cookieDomain, isCookieHttpOnly, isCookieSecure, secretKey)
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

		def resolveQueueRequestByLocalConfig(targetUrl, queueitToken, queueConfig, customerId, secretKey)
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

		def validateRequestByIntegrationConfig(currentUrlWithoutQueueITToken, queueitToken, integrationConfigJson, customerId, secretKey)
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
				matchedConfig = integrationEvaluator.getMatchedIntegrationConfig(customerIntegration, currentUrlWithoutQueueITToken, @httpContext)

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

		def handleQueueAction(currentUrlWithoutQueueITToken, queueitToken, customerIntegration, customerId, secretKey, matchedConfig, debugEntries, isDebug)
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

		def handleCancelAction(currentUrlWithoutQueueITToken, queueitToken, customerIntegration, customerId, secretKey, matchedConfig, debugEntries, isDebug)
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

		def cancelRequestByLocalConfig(targetUrl, queueitToken, cancelConfig, customerId, secretKey)
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

		def getRealOriginalUrl
			return @httpContext.url
			# RoR could modify request.original_url if request contains x-forwarded-host/proto http headers.
			# Therefore we need this method to be able to access the 'real' original url.
			#return request.env["rack.url_scheme"] + "://" + request.env["HTTP_HOST"] + request.original_fullpath
		end

		def getRuntime
			RUBY_VERSION.to_s
		end

		private

		def getUserInQueueService
			@userInQueueService ||= UserInQueueService.new(UserInQueueStateCookieRepository.new(@httpContext.cookieManager))
		end

		def isQueueAjaxCall
			headers = @httpContext.headers

			headers[QUEUEIT_AJAX_HEADER_KEY] != nil
		end

		def generateTargetUrl(originalTargetUrl)
			return originalTargetUrl unless isQueueAjaxCall

			headers = @httpContext.headers

			CGI.unescape(headers[QUEUEIT_AJAX_HEADER_KEY])
		end

		def convertToInt(value)
			Integer(value) rescue 0
		end

		def logMoreRequestDetails(debugEntries)
			headers = @httpContext.headers

			debugEntries["ServerUtcTime"] = Time.now.utc.iso8601
			debugEntries["RequestIP"] = @httpContext.userHostAddress
			debugEntries["RequestHttpHeader_Via"] = headers["via"]
			debugEntries["RequestHttpHeader_Forwarded"] = headers["forwarded"]
			debugEntries["RequestHttpHeader_XForwardedFor"] = headers["x-forwarded-for"]
			debugEntries["RequestHttpHeader_XForwardedHost"] = headers["x-forwarded-host"]
			debugEntries["RequestHttpHeader_XForwardedProto"] = headers["x-forwarded-proto"]
		end

		def setDebugCookie(debugEntries)
			return if debugEntries == nil || debugEntries.length == 0

			cookieManager = @httpContext.cookieManager
			cookieValue = +''
			debugEntries.each do |entry|
				cookieValue << (entry[0].to_s + '=' + entry[1].to_s + '|')
			end
			cookieValue = cookieValue.chop # remove trailing char
			cookieManager.setCookie(QUEUEIT_DEBUG_KEY, cookieValue, nil, nil, false, false)
		end

		def _resolveQueueRequestByLocalConfig(targetUrl, queueitToken, queueConfig, customerId, secretKey, debugEntries, isDebug)
			if(isDebug)
				debugEntries["SdkVersion"] = UserInQueueService::SDK_VERSION
				debugEntries["Runtime"] = getRuntime
				debugEntries["TargetUrl"] = targetUrl
				debugEntries["QueueitToken"] = queueitToken
				debugEntries["OriginalUrl"] = getRealOriginalUrl
				if queueConfig == nil
					debugEntries["QueueConfig"] = "NULL"
				else
					debugEntries["QueueConfig"] = queueConfig.toString
				end
				logMoreRequestDetails(debugEntries)
			end

			raise KnownUserError, "customerId can not be nil or empty." if Utils.isNilOrEmpty(customerId)
			raise KnownUserError, "secretKey can not be nil or empty." if Utils.isNilOrEmpty(secretKey)
			raise KnownUserError, "queueConfig can not be nil." if queueConfig == nil
			raise KnownUserError, "queueConfig.eventId can not be nil or empty." if Utils.isNilOrEmpty(queueConfig.eventId)
			raise KnownUserError, "queueConfig.queueDomain can not be nil or empty." if Utils.isNilOrEmpty(queueConfig.queueDomain)

			minutes = convertToInt(queueConfig.cookieValidityMinute)
			if(minutes <= 0)
				raise KnownUserError, "queueConfig.cookieValidityMinute should be integer greater than 0."
			end

			if(![true, false].include? queueConfig.extendCookieValidity)
				raise KnownUserError, "queueConfig.extendCookieValidity should be valid boolean."
			end

			userInQueueService = getUserInQueueService
			result = userInQueueService.validateQueueRequest(targetUrl, queueitToken, queueConfig, customerId, secretKey)
			result.isAjaxResult = isQueueAjaxCall

			return result
		end

		def _cancelRequestByLocalConfig(targetUrl, queueitToken, cancelConfig, customerId, secretKey, debugEntries, isDebug)
			targetUrl = generateTargetUrl(targetUrl)

			if isDebug
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

			raise KnownUserError, "targetUrl can not be nil or empty." if Utils.isNilOrEmpty(targetUrl)
			raise KnownUserError, "customerId can not be nil or empty." if Utils.isNilOrEmpty(customerId)
			raise KnownUserError, "secretKey can not be nil or empty." if Utils.isNilOrEmpty(secretKey)
			raise KnownUserError, "cancelConfig can not be nil." if cancelConfig == nil
			raise KnownUserError, "cancelConfig.eventId can not be nil or empty." if Utils.isNilOrEmpty(cancelConfig.eventId)
			raise KnownUserError, "cancelConfig.queueDomain can not be nil or empty." if Utils.isNilOrEmpty(cancelConfig.queueDomain)

			userInQueueService = getUserInQueueService
			result = userInQueueService.validateCancelRequest(targetUrl, cancelConfig, customerId, secretKey)
			result.isAjaxResult = isQueueAjaxCall

			result
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

			if noDomain
				if deleteCookie
					@cookies.delete(key)
				elsif noExpire
					@cookies[key] = { value: value, httponly: isHttpOnly, secure: isSecure }
				else
					@cookies[key] = { value: value, expires: expire, httponly: isHttpOnly, secure: isSecure }
				end
			else
				if deleteCookie
					@cookies.delete(key, domain: domain)
				elsif noExpire
					@cookies[key] = { value: value, domain: domain, httponly: isHttpOnly, secure: isSecure }
				else
					@cookies[key] = { value: value, expires: expire, domain: domain, httponly: isHttpOnly, secure: isSecure }
				end
			end
		end
	end
end
