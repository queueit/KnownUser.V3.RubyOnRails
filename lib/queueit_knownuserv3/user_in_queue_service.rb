require 'open-uri'
require 'cgi'

module QueueIt
	class UserInQueueService
		SDK_VERSION = "3.3.0"
    
		def initialize(userInQueueStateRepository)
			@userInQueueStateRepository = userInQueueStateRepository
		end
     
		def validateQueueRequest(targetUrl, queueitToken, config, customerId, secretKey)
			state = @userInQueueStateRepository.getState(config.eventId, secretKey)
			if (state.isValid)
				if (state.isStateExtendable && config.extendCookieValidity) 
					@userInQueueStateRepository.store(
						config.eventId,
						state.queueId,
						true,
						config.cookieValidityMinute,
						!Utils::isNilOrEmpty(config.cookieDomain) ? config.cookieDomain : '',
						secretKey)
				end
				return RequestValidationResult.new(ActionTypes::QUEUE, config.eventId, state.queueId, nil)            			
			end
        
			queueParams = QueueUrlParams::extractQueueParams(queueitToken)
			if(!queueParams.nil?) 
				return getQueueITTokenValidationResult(targetUrl, config.eventId, config, queueParams, customerId, secretKey)
			else 
				return getInQueueRedirectResult(targetUrl, config, customerId)
			end
		end

		def validateCancelRequest(targetUrl, config, customerId, secretKey)
			state = @userInQueueStateRepository.getState(config.eventId, secretKey)
			if (state.isValid)
				@userInQueueStateRepository.cancelQueueCookie(config.eventId, config.cookieDomain)

				query = getQueryString(customerId, config.eventId, config.version, nil, nil) + ( !Utils::isNilOrEmpty(targetUrl) ? ("&r=" +  CGI.escape(targetUrl)) : "" )
			
				domainAlias = config.queueDomain
				if (!domainAlias.end_with?("/") )
					domainAlias = domainAlias + "/"
				end
			
				redirectUrl = "https://" + domainAlias + "cancel/" + customerId + "/" + config.eventId + "/?" + query;
				return RequestValidationResult.new(ActionTypes::CANCEL, config.eventId, state.queueId, redirectUrl)			
			else
				return RequestValidationResult.new(ActionTypes::CANCEL, config.eventId, nil, nil)			
			end
		end 

		def getQueueITTokenValidationResult(targetUrl, eventId, config, queueParams,customerId, secretKey) 
			calculatedHash = OpenSSL::HMAC.hexdigest('sha256', secretKey, queueParams.queueITTokenWithoutHash) 
			if (calculatedHash.upcase() != queueParams.hashCode.upcase()) 
				return getVaidationErrorResult(customerId, targetUrl, config, queueParams, "hash")
			end
			if (queueParams.eventId.upcase() != eventId.upcase()) 
				return getVaidationErrorResult(customerId, targetUrl, config, queueParams, "eventid")
			end
			if (queueParams.timeStamp < Time.now.getutc.tv_sec) 
				return getVaidationErrorResult(customerId, targetUrl, config, queueParams, "timestamp")
			end

			@userInQueueStateRepository.store(
				config.eventId,
				queueParams.queueId,
				queueParams.extendableCookie,
				!(queueParams.cookieValidityMinute.nil?) ? queueParams.cookieValidityMinute : config.cookieValidityMinute,
				!Utils::isNilOrEmpty(config.cookieDomain) ? config.cookieDomain : '',
				secretKey)
			return RequestValidationResult.new(ActionTypes::QUEUE, config.eventId, queueParams.queueId, nil)        		
		end

		def getVaidationErrorResult(customerId, targetUrl, config, qParams, errorCode) 
			query = getQueryString(customerId, config.eventId, config.version, config.culture, config.layoutName) +
				"&queueittoken=" + qParams.queueITToken +
				"&ts=" + Time.now.getutc.tv_sec.to_s +
				(!Utils::isNilOrEmpty(targetUrl) ? ("&t=" +  CGI.escape(targetUrl)) : "")
			domainAlias = config.queueDomain
			if (!domainAlias.end_with?("/") )
				domainAlias = domainAlias + "/"
			end
			redirectUrl = "https://" + domainAlias + "error/" + errorCode + "/?"  + query
			return RequestValidationResult.new(ActionTypes::QUEUE, config.eventId, nil, redirectUrl)        
		end

		def getInQueueRedirectResult(targetUrl, config, customerId) 
			redirectUrl = "https://" + config.queueDomain + 
				"?" + getQueryString(customerId, config.eventId, config.version, config.culture, config.layoutName) + 
				(!Utils::isNilOrEmpty(targetUrl) ? "&t=" +  
				CGI.escape( targetUrl) : "")
			return RequestValidationResult.new(ActionTypes::QUEUE, config.eventId, nil, redirectUrl)        
		end

		def getQueryString(customerId, eventId, configVersion, culture, layoutName) 
			queryStringList = Array.new 
			queryStringList.push("c=" + CGI.escape(customerId))
			queryStringList.push("e=" + CGI.escape(eventId))
			queryStringList.push("ver=v3-ruby-" + SDK_VERSION) 
			queryStringList.push("cver=" + (!configVersion.nil? ? configVersion.to_s : '-1'))
			if (!Utils::isNilOrEmpty(culture)) 
				queryStringList.push("cid=" + CGI.escape(culture))
			end
			if (!Utils::isNilOrEmpty(layoutName)) 
				queryStringList.push("l=" + CGI.escape(layoutName))
			end
			return queryStringList.join("&")
		end

		def extendQueueCookie(eventId, cookieValidityMinute, cookieDomain, secretKey) 
			@userInQueueStateRepository.extendQueueCookie(eventId, cookieValidityMinute, cookieDomain, secretKey)
		end
	end
end
