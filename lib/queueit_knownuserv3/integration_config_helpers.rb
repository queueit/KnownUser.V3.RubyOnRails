require 'uri'

module QueueIt
	class IntegrationEvaluator
		def getMatchedIntegrationConfig(customerIntegration, currentPageUrl, request)
			if (!customerIntegration.kind_of?(Hash) || !customerIntegration.key?("Integrations") ||
				!customerIntegration["Integrations"].kind_of?(Array))
				return nil;
			end
			customerIntegration["Integrations"].each do |integrationConfig|
				next if !integrationConfig.kind_of?(Hash) || !integrationConfig.key?("Triggers") || !integrationConfig["Triggers"].kind_of?(Array)
			
				integrationConfig["Triggers"].each do |trigger|
					if(!trigger.kind_of?(Hash))
						return false
					end
					if(evaluateTrigger(trigger, currentPageUrl, request))
						return integrationConfig
					end
				end
			end

			return nil
		end

		def evaluateTrigger(trigger, currentPageUrl, request)
			if (!trigger.key?("LogicalOperator") ||
				!trigger.key?("TriggerParts") ||
				!trigger["TriggerParts"].kind_of?(Array))
				return false;
			end
		
			if(trigger["LogicalOperator"].eql? "Or")
				trigger["TriggerParts"].each do |triggerPart|
					if(!triggerPart.kind_of?(Hash))
						return false
					end
					if(evaluateTriggerPart(triggerPart, currentPageUrl, request))
						return true
					end
				end
				return false
			else
				trigger["TriggerParts"].each do |triggerPart|
					if(!triggerPart.kind_of?(Hash))
						return false
					end
					if(!evaluateTriggerPart(triggerPart, currentPageUrl, request))
						return false
					end
				end
				return true
			end
		end

		def evaluateTriggerPart(triggerPart, currentPageUrl, request)
			if (!triggerPart.key?("ValidatorType"))
				return false
			end

			case triggerPart["ValidatorType"]
				when "UrlValidator"
					return UrlValidatorHelper.evaluate(triggerPart, currentPageUrl)
				when "CookieValidator"
					return CookieValidatorHelper.evaluate(triggerPart, request.cookie_jar)
				when "UserAgentValidator"
					return UserAgentValidatorHelper.evaluate(triggerPart, request.user_agent)
				when "HttpHeaderValidator"
					return HttpHeaderValidatorHelper.evaluate(triggerPart, request.headers)
				else
					return false
			end
		end
	end

	class UrlValidatorHelper
		def self.evaluate(triggerPart, url)
			if (triggerPart.nil? || 
				!triggerPart.key?("Operator") ||
				!triggerPart.key?("IsNegative") ||
				!triggerPart.key?("IsIgnoreCase") ||
				!triggerPart.key?("UrlPart"))
				return false
			end
			
			urlPart = UrlValidatorHelper.getUrlPart(triggerPart["UrlPart"], url)

			return ComparisonOperatorHelper.evaluate(
				triggerPart["Operator"], 
				triggerPart["IsNegative"], 
				triggerPart["IsIgnoreCase"], 
				urlPart, 
				triggerPart["ValueToCompare"],
				triggerPart["ValuesToCompare"])
		end

		def self.getUrlPart(urlPart, url)
			begin
				urlParts = URI.parse(url)		
				case urlPart
					when "PagePath"
						return urlParts.path
					when "PageUrl"
						return url
					when "HostName"
						return urlParts.host
					else
						return ''
				end
			rescue
				return ''
			end
		end
	end

	class CookieValidatorHelper
		def self.evaluate(triggerPart, cookieJar)
			begin
				if (triggerPart.nil? ||
					!triggerPart.key?("Operator") ||
					!triggerPart.key?("IsNegative") ||
					!triggerPart.key?("IsIgnoreCase") ||
					!triggerPart.key?("CookieName"))
					return false
				end

				if(cookieJar.nil?)
					return false
				end

				cookieName = triggerPart["CookieName"]
				cookieValue = ''
				if(!cookieName.nil? && !cookieJar[cookieName.to_sym].nil?)
					cookieValue = cookieJar[cookieName.to_sym]
				end
				return ComparisonOperatorHelper.evaluate(
					triggerPart["Operator"], 
					triggerPart["IsNegative"], 
					triggerPart["IsIgnoreCase"], 
					cookieValue, 
					triggerPart["ValueToCompare"],
					triggerPart["ValuesToCompare"])
			rescue
				return false
			end
		end
	end

	class UserAgentValidatorHelper
		def self.evaluate(triggerPart, userAgent)
			begin
				if (triggerPart.nil? ||
					!triggerPart.key?("Operator") ||
					!triggerPart.key?("IsNegative") ||
					!triggerPart.key?("IsIgnoreCase"))
					return false
				end
			
				return ComparisonOperatorHelper.evaluate(
					triggerPart["Operator"], 
					triggerPart["IsNegative"], 
					triggerPart["IsIgnoreCase"], 
					userAgent, 
					triggerPart["ValueToCompare"],
					triggerPart["ValuesToCompare"])
			end
		end
	end

	class HttpHeaderValidatorHelper
		def self.evaluate(triggerPart, headers)
			begin
				if (triggerPart.nil? || 
					!triggerPart.key?("Operator") ||
					!triggerPart.key?("IsNegative") ||
					!triggerPart.key?("IsIgnoreCase")
					!triggerPart.key?("HttpHeaderName"))
					return false
				end

				headerValue = headers[triggerPart['HttpHeaderName']]
				return ComparisonOperatorHelper.evaluate(
					triggerPart["Operator"], 
					triggerPart["IsNegative"], 
					triggerPart["IsIgnoreCase"], 
					headerValue, 
					triggerPart["ValueToCompare"],
					triggerPart["ValuesToCompare"])
			rescue
				return false
			end
		end
	end

	class ComparisonOperatorHelper
		def self.evaluate(opt, isNegative, ignoreCase, value, valueToCompare, valuesToCompare)
			if (value.nil?)
				value = ''
			end
			
			if (valueToCompare.nil?) 
				valueToCompare = ''
			end
			
			if (valuesToCompare.nil?)
				valuesToCompare = []
			end

			case opt		
				when "Equals"
					return ComparisonOperatorHelper.equals(value, valueToCompare, isNegative, ignoreCase)
				when "Contains" 
					return ComparisonOperatorHelper.contains(value, valueToCompare, isNegative, ignoreCase)
				when "StartsWith"
					return ComparisonOperatorHelper.startsWith(value, valueToCompare, isNegative, ignoreCase)
				when "EndsWith"
					return ComparisonOperatorHelper.endsWith(value, valueToCompare, isNegative, ignoreCase)
				when "MatchesWith"
					return ComparisonOperatorHelper.matchesWith(value, valueToCompare, isNegative, ignoreCase)
				when "EqualsAny"
					return ComparisonOperatorHelper.equalsAny(value, valuesToCompare, isNegative, ignoreCase)
				when "ContainsAny"
					return ComparisonOperatorHelper.containsAny(value, valuesToCompare, isNegative, ignoreCase)
				else
					return false
			end
		end

		def self.equals(value, valueToCompare, isNegative, ignoreCase)
			if(ignoreCase)
				evaluation = value.upcase.eql? valueToCompare.upcase
			else
				evaluation = value.eql? valueToCompare
			end

			if(isNegative)
				return !evaluation
			else
				return evaluation
			end
		end

		def self.contains(value, valueToCompare, isNegative, ignoreCase)
			if(valueToCompare.eql? "*")
				return true
			end

			if(ignoreCase)
				value = value.upcase
				valueToCompare = valueToCompare.upcase
			end

			evaluation = value.include? valueToCompare
			if(isNegative)
				return !evaluation
			else
				return evaluation
			end
		end

		def self.startsWith(value, valueToCompare, isNegative, ignoreCase)
			if(ignoreCase)
				evaluation = value.upcase.start_with? valueToCompare.upcase
			else
				evaluation = value.start_with? valueToCompare
			end

			if(isNegative)
				return !evaluation
			else
				return evaluation
			end
		end

		def self.endsWith(value, valueToCompare, isNegative, ignoreCase)
			if(ignoreCase)
				evaluation = value.upcase.end_with? valueToCompare.upcase
			else
				evaluation = value.end_with? valueToCompare
			end

			if(isNegative)
				return !evaluation
			else
				return evaluation
			end
		end

		def self.matchesWith(value, valueToCompare, isNegative, ignoreCase)
			if(ignoreCase)
				pattern = Regexp.new(valueToCompare, Regexp::IGNORECASE) 
			else
				pattern = Regexp.new(valueToCompare)
			end
		
			evaluation = pattern.match(value) != nil
			if(isNegative)
				return !evaluation
			else
				return evaluation
			end
		end

		def self.equalsAny(value, valuesToCompare, isNegative, ignoreCase)
			valuesToCompare.each do |valueToCompare|
				if (ComparisonOperatorHelper.equals(value, valueToCompare, false, ignoreCase))
					return !isNegative
				end
			end
			return isNegative
		end

		def self.containsAny(value, valuesToCompare, isNegative, ignoreCase)
			valuesToCompare.each do |valueToCompare|
				if (ComparisonOperatorHelper.contains(value, valueToCompare, false, ignoreCase))
					return !isNegative
				end
			end
			return isNegative
		end
	end
end