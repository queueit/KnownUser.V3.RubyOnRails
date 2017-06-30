require 'open-uri'
require 'cgi'

require_relative 'Models'
require_relative 'UserInQueueStateCookieRepository'
require_relative 'QueueUrlParams'

class UserInQueueService
	SDK_VERSION = "1.0.0.0"
    
	def initialize(userInQueueStateRepository) 
        @userInQueueStateRepository = userInQueueStateRepository
	end
     
    def validateRequest(targetUrl, queueitToken, config, customerId, secretKey)
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
            result = RequestValidationResult.new(config.eventId, state.queueId, nil)            
			return result
        end
        
        queueParams = QueueUrlParams::extractQueueParams(queueitToken)
        if(!queueParams.nil?) 
            return getQueueITTokenValidationResult(targetUrl, config.eventId, config, queueParams, customerId, secretKey)
        else 
            return getInQueueRedirectResult(targetUrl, config, customerId)
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
        result = RequestValidationResult.new(config.eventId, queueParams.queueId, nil)        
		return result
    end

    def getVaidationErrorResult(customerId, targetUrl, config, qParams, errorCode) 
        query = getQueryString(customerId, config) +
			"&queueittoken=" + qParams.queueITToken +
			"&ts=" + Time.now.getutc.tv_sec.to_s +
			(!Utils::isNilOrEmpty(targetUrl) ? ("&t=" +  CGI.escape(targetUrl)) : "")
        domainAlias = config.queueDomain
        if (!domainAlias.end_with?("/") )
            domainAlias = domainAlias + "/"
        end
        redirectUrl = "https://" + domainAlias + "error/" + errorCode + "?"  + query
        result = RequestValidationResult.new(config.eventId, nil, redirectUrl)
        return result
    end

    def getInQueueRedirectResult(targetUrl, config, customerId) 
		redirectUrl = "https://" + config.queueDomain + 
			"?" + getQueryString(customerId, config) + 
			(!Utils::isNilOrEmpty(targetUrl) ? "&t=" +  
			CGI.escape( targetUrl) : "")
        result = RequestValidationResult.new(config.eventId, nil, redirectUrl)
        return result
    end

    def getQueryString(customerId, config) 
        queryStringList = Array.new 
        queryStringList.push("c=" + CGI.escape(customerId))
        queryStringList.push("e=" + CGI.escape(config.eventId))
        queryStringList.push("ver=v3-ruby-" + SDK_VERSION) 
        queryStringList.push("cver=" + (!config.version.nil? ? config.version.to_s : '-1'))
        if (!Utils::isNilOrEmpty(config.culture)) 
            queryStringList.push("cid=" + CGI.escape(config.culture))
        end
        if (!Utils::isNilOrEmpty(config.layoutName)) 
            queryStringList.push("l=" + CGI.escape(config.layoutName))
        end
        return queryStringList.join("&")
    end

    def cancelQueueCookie(eventId, cookieDomain) 
        @userInQueueStateRepository.cancelQueueCookie(eventId, cookieDomain)
    end

    def extendQueueCookie(eventId, cookieValidityMinute, cookieDomain, secretKey) 
        @userInQueueStateRepository.extendQueueCookie(eventId, cookieValidityMinute, cookieDomain, secretKey)
    end
end