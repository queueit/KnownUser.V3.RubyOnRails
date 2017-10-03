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
			if (!triggerPart.key?("Operator") ||
				!triggerPart.key?("IsNegative") ||
				!triggerPart.key?("IsIgnoreCase") ||
				!triggerPart.key?("ValueToCompare") ||
				!triggerPart.key?("UrlPart"))
				return false;
			end

			urlPart = UrlValidatorHelper.getUrlPart(triggerPart["UrlPart"], url)

			return ComparisonOperatorHelper.evaluate(
				triggerPart["Operator"], 
				triggerPart["IsNegative"], 
				triggerPart["IsIgnoreCase"], 
				urlPart, 
				triggerPart["ValueToCompare"])
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
				if (!triggerPart.key?("Operator") ||
					!triggerPart.key?("IsNegative") ||
					!triggerPart.key?("IsIgnoreCase") ||
					!triggerPart.key?("ValueToCompare") ||
					!triggerPart.key?("CookieName"))
					return false;
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
					triggerPart["ValueToCompare"])
			rescue
				return false
			end
		end
	end

	class UserAgentValidatorHelper
		def self.evaluate(triggerPart, userAgent)
			begin
				if (!triggerPart.key?("Operator") ||
					!triggerPart.key?("IsNegative") ||
					!triggerPart.key?("IsIgnoreCase") ||
					!triggerPart.key?("ValueToCompare"))
					return false;
				end

				return ComparisonOperatorHelper.evaluate(
					triggerPart["Operator"], 
					triggerPart["IsNegative"], 
					triggerPart["IsIgnoreCase"], 
					userAgent, 
					triggerPart["ValueToCompare"])
			end
		end
	end

	class HttpHeaderValidatorHelper
		def self.evaluate(triggerPart, headers)
			begin				
				headerValue = headers[triggerPart['HttpHeaderName']]
				return ComparisonOperatorHelper.evaluate(
					triggerPart["Operator"], 
					triggerPart["IsNegative"], 
					triggerPart["IsIgnoreCase"], 
					headerValue, 
					triggerPart["ValueToCompare"])				
			rescue
				return false
			end
		end
	end

	class ComparisonOperatorHelper
		def self.evaluate(opt, isNegative, ignoreCase, left, right)
			if(left.nil?)
				left = ''
			end
			if(right.nil?) 
				right = ''
			end

			case opt		
				when "Equals"
					return ComparisonOperatorHelper.equals(left, right, isNegative, ignoreCase)
				when "Contains" 
					return ComparisonOperatorHelper.contains(left, right, isNegative, ignoreCase)
				when "StartsWith"
					return ComparisonOperatorHelper.startsWith(left, right, isNegative, ignoreCase)
				when "EndsWith"
					return ComparisonOperatorHelper.endsWith(left, right, isNegative, ignoreCase)
				when "MatchesWith"
					return ComparisonOperatorHelper.matchesWith(left, right, isNegative, ignoreCase)
				else
					return false
			end
		end

		def self.equals(left, right, isNegative, ignoreCase)
			if(ignoreCase)
				evaluation = left.upcase.eql? right.upcase
			else
				evaluation = left.eql? right
			end

			if(isNegative)
				return !evaluation
			else
				return evaluation
			end
		end

		def self.contains(left, right, isNegative, ignoreCase)
			if(right.eql? "*")
				return true
			end

			if(ignoreCase)
				left = left.upcase
				right = right.upcase
			end

			evaluation = left.include? right
			if(isNegative)
				return !evaluation
			else
				return evaluation
			end
		end

		def self.startsWith(left, right, isNegative, ignoreCase)
			if(ignoreCase)
				evaluation = left.upcase.start_with? right.upcase
			else
				evaluation = left.start_with? right
			end

			if(isNegative)
				return !evaluation
			else
				return evaluation
			end
		end

		def self.endsWith(left, right, isNegative, ignoreCase)
			if(ignoreCase)
				evaluation = left.upcase.end_with? right.upcase
			else
				evaluation = left.end_with? right
			end

			if(isNegative)
				return !evaluation
			else
				return evaluation
			end
		end

		def self.matchesWith(left, right, isNegative, ignoreCase)
			if(ignoreCase)
				pattern = Regexp.new(right, Regexp::IGNORECASE) 
			else
				pattern = Regexp.new(right)
			end
		
			evaluation = pattern.match(left) != nil
			if(isNegative)
				return !evaluation
			else
				return evaluation
			end
		end
	end
end