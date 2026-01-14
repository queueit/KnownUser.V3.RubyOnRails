require 'open-uri'
require 'cgi'

module QueueIt
	class UserInQueueService
		SDK_VERSION_NO = "3.7.2"
		SDK_VERSION = "v3-ruby-" + SDK_VERSION_NO
    
		def initialize(userInQueueStateRepository)
			@userInQueueStateRepository = userInQueueStateRepository
		end
     
		def validateQueueRequest(targetUrl, queueitToken, config, customerId, secretKey)
			state = @userInQueueStateRepository.getState(config.eventId, config.cookieValidityMinute, secretKey, true)
			if (state.isValid)
				if (state.isStateExtendable && config.extendCookieValidity)
					@userInQueueStateRepository.store(
						config.eventId,
						state.queueId,
						nil,
						!Utils::isNilOrEmpty(config.cookieDomain) ? config.cookieDomain : '',
						config.isCookieHttpOnly,
						config.isCookieSecure,
						state.redirectType,
						secretKey)
				end
				return RequestValidationResult.new(ActionTypes::QUEUE, config.eventId, state.queueId, nil, state.redirectType, config.actionName)            			
			end

			queueParams = QueueUrlParams::extractQueueParams(queueitToken)

			requestValidationResult = nil
			isTokenValid = false

			if (queueParams.nil?)
				requestValidationResult = getQueueResult(targetUrl, config, customerId)
			else
				tokenValidationResult = validateToken(config, queueParams, secretKey)
				if (tokenValidationResult.nil?)
					requestValidationResult = getQueueResult(targetUrl, config, customerId)
				elsif (tokenValidationResult.isValid)
					requestValidationResult = getValidTokenResult(config, queueParams, secretKey)
				else
					requestValidationResult = getErrorResult(customerId, targetUrl, config, queueParams, tokenValidationResult.errorCode)
				end
			end
            
			if (state.isFound && !isTokenValid)
				@userInQueueStateRepository.cancelQueueCookie(config.eventId, config.cookieDomain, config.isCookieHttpOnly, config.isCookieSecure);
			end
            
			return requestValidationResult;
		end

		def validateCancelRequest(targetUrl, cancelConfig, customerId, secretKey)
			state = @userInQueueStateRepository.getState(cancelConfig.eventId, -1, secretKey, false)
			if (state.isValid)
				@userInQueueStateRepository.cancelQueueCookie(cancelConfig.eventId, cancelConfig.cookieDomain, cancelConfig.isCookieHttpOnly, cancelConfig.isCookieSecure)

				query = getQueryString(customerId, cancelConfig.eventId, cancelConfig.version, cancelConfig.actionName, nil, nil) + 
							(!Utils::isNilOrEmpty(targetUrl) ? ("&r=" +  Utils.urlEncode(targetUrl)) : "" )

				uriPath = "cancel/" + customerId + "/" + cancelConfig.eventId

				if(!Utils::isNilOrEmpty(state.queueId))
					uriPath = uriPath + "/" + state.queueId
				end

				redirectUrl = generateRedirectUrl(cancelConfig.queueDomain, uriPath, query)
				
				return RequestValidationResult.new(ActionTypes::CANCEL, cancelConfig.eventId, state.queueId, redirectUrl, state.redirectType, cancelConfig.actionName)			
			else
				return RequestValidationResult.new(ActionTypes::CANCEL, cancelConfig.eventId, nil, nil, nil, cancelConfig.actionName)			
			end
		end 

		def getValidTokenResult(config, queueParams, secretKey) 
			@userInQueueStateRepository.store(
				config.eventId,
				queueParams.queueId,
				queueParams.cookieValidityMinutes,				
				!Utils::isNilOrEmpty(config.cookieDomain) ? config.cookieDomain : '',
				config.isCookieHttpOnly,
				config.isCookieSecure,
				queueParams.redirectType,
				secretKey)

			return RequestValidationResult.new(ActionTypes::QUEUE, config.eventId, queueParams.queueId, nil, queueParams.redirectType, config.actionName)
		end

		def getErrorResult(customerId, targetUrl, config, qParams, errorCode) 
			query = getQueryString(customerId, config.eventId, config.version, config.actionName, config.culture, config.layoutName) +
				"&queueittoken=" + qParams.queueITToken +
				"&ts=" + Time.now.getutc.tv_sec.to_s +
				(!Utils::isNilOrEmpty(targetUrl) ? ("&t=" +  Utils.urlEncode(targetUrl)) : "")
			
			redirectUrl = generateRedirectUrl(config.queueDomain, "error/" + errorCode + "/", query)

			return RequestValidationResult.new(ActionTypes::QUEUE, config.eventId, nil, redirectUrl, nil, config.actionName)        
		end

		def getQueueResult(targetUrl, config, customerId) 
			query = getQueryString(customerId, config.eventId, config.version, config.actionName, config.culture, config.layoutName) + 
							(!Utils::isNilOrEmpty(targetUrl) ? "&t=" + Utils.urlEncode( targetUrl) : "")		

			redirectUrl = generateRedirectUrl(config.queueDomain, "", query)

			return RequestValidationResult.new(ActionTypes::QUEUE, config.eventId, nil, redirectUrl, nil, config.actionName)        
		end

		def getQueryString(customerId, eventId, configVersion, actionName, culture, layoutName) 
			queryStringList = Array.new 
			queryStringList.push("c=" + Utils.urlEncode(customerId))
			queryStringList.push("e=" + Utils.urlEncode(eventId))
			queryStringList.push("ver=" + SDK_VERSION) 
			queryStringList.push("cver=" + (!configVersion.nil? ? configVersion.to_s : '-1'))
			queryStringList.push("man=" + Utils.urlEncode(actionName))

			if (!Utils::isNilOrEmpty(culture)) 
				queryStringList.push("cid=" + Utils.urlEncode(culture))
			end
			if (!Utils::isNilOrEmpty(layoutName)) 
				queryStringList.push("l=" + Utils.urlEncode(layoutName))
			end
			return queryStringList.join("&")
		end

		def generateRedirectUrl(queueDomain, uriPath, query)
			if (!queueDomain.end_with?("/") )
				queueDomain = queueDomain + "/"
			end		
			return "https://" + queueDomain + uriPath + "?" + query
		end

		def extendQueueCookie(eventId, cookieValidityMinutes, cookieDomain, isCookieHttpOnly, isCookieSecure, secretKey) 
			@userInQueueStateRepository.reissueQueueCookie(eventId, cookieValidityMinutes, cookieDomain, isCookieHttpOnly, isCookieSecure, secretKey)
		end

		def getIgnoreActionResult(actionName)
			return RequestValidationResult.new(ActionTypes::IGNORE, nil, nil, nil, nil, actionName)
		end

		def validateToken(config, queueParams, secretKey)
			begin
				calculatedHash = OpenSSL::HMAC.hexdigest('sha256', secretKey, queueParams.queueITTokenWithoutHash) 
				if (calculatedHash.upcase() != queueParams.hashCode.upcase())
					return TokenValidationResult.new(false, "hash")
				end
				if (queueParams.eventId.upcase() != config.eventId.upcase())
					return TokenValidationResult.new(false, "eventid")
				end
				if (queueParams.timeStamp < Time.now.getutc.tv_sec)
					return TokenValidationResult.new(false, "timestamp")
				end

				return TokenValidationResult.new(true, nil)
			rescue
				return nil
			end
		end

		class TokenValidationResult
			attr_reader :isValid
			attr_reader :errorCode

			def initialize(isValid, errorCode)
				@isValid = isValid
				@errorCode = errorCode
			end
		end
	end
end
