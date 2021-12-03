require 'test/unit'
require_relative '../../lib/queueit_knownuserv3'

module QueueIt

	class TestIntegrationEvaluator < Test::Unit::TestCase
		def test_getMatchedIntegrationConfig_oneTrigger_and_notMatched
			integrationConfig =
			{
				"Integrations" =>
				[
					{
						"Triggers" =>
						[
							{
								"LogicalOperator" => "And",
								"TriggerParts" =>
								[
									{
										"CookieName" => "c1",
										"Operator" => "Equals",
										"ValueToCompare" => "value1",
										"ValidatorType" => "CookieValidator",
										"IsIgnoreCase" => false,
										"IsNegative" => false
									},
									{
										"UrlPart" => "PageUrl",
										"ValidatorType" => "UrlValidator",
										"ValueToCompare" => "test",
										"Operator" => "Contains",
										"IsIgnoreCase" => false,
										"IsNegative" => false
									}
								]
							}
						]
					}
				]
			}

			url = "http://test.testdomain.com:8080/test?q=2";
			testObject = IntegrationEvaluator.new;
			matchedConfig = testObject.getMatchedIntegrationConfig(integrationConfig, url, HttpContextMock.new)
			assert(matchedConfig == nil);
		end

		def test_getMatchedIntegrationConfig_oneTrigger_and_matched
			integrationConfig =
			{
				"Integrations" =>
				[
					{
						"Name" => "integration1",
						"Triggers" =>
						[
							{
								"LogicalOperator" => "And",
								"TriggerParts" =>
								[
									{
										"CookieName" => "c1",
										"Operator" => "Equals",
										"ValueToCompare" => "value1",
										"ValidatorType" => "CookieValidator",
										"IsIgnoreCase" => true,
										"IsNegative" => false
									},
									{
										"UrlPart" => "PageUrl",
										"ValidatorType" => "UrlValidator",
										"ValueToCompare" => "test",
										"Operator" => "Contains",
										"IsIgnoreCase" => false,
										"IsNegative" => false
									}
								]
							}
						]
					}
				]
			}

			url = "http://test.testdomain.com:8080/test?q=2";
			contextMock = HttpContextMock.new

			cookieManager = CookieManagerMock.new
			cookieManager.cookieList[:c1] = { "value" => "Value1" }
			cookieManager.cookieList[:c2] = { "value" => "ddd" }
			contextMock.cookieManager = cookieManager

			testObject = IntegrationEvaluator.new;
			matchedConfig = testObject.getMatchedIntegrationConfig(integrationConfig, url, contextMock)
			assert( matchedConfig["Name"].eql? "integration1" );
		end

		def test_getMatchedIntegrationConfig_oneTrigger_and_notmatched_UserAgent
			integrationConfig =
			{
				"Integrations" =>
				[
					{
						"Name" => "integration1",
						"Triggers" =>
						[
							{
								"LogicalOperator" => "And",
								"TriggerParts" =>
								[
									{
										"CookieName" => "c1",
										"Operator" => "Equals",
										"ValueToCompare" => "value1",
										"ValidatorType" => "CookieValidator",
										"IsIgnoreCase" => true,
										"IsNegative" => false
									},
									{
										"UrlPart" => "PageUrl",
										"ValidatorType" => "UrlValidator",
										"ValueToCompare" => "test",
										"Operator" => "Contains",
										"IsIgnoreCase" => false,
										"IsNegative" => false
									},
									{
										"ValidatorType" => "userAgentValidator",
										"ValueToCompare" => "Googlebot",
										"Operator" => "Contains",
										"IsIgnoreCase" => true,
										"IsNegative" => true
									}
								]
							}
						]
					}
				]
			}

			url = "http://test.testdomain.com:8080/test?q=2";
			contextMock = HttpContextMock.new
			contextMock.userAgent = "bot.html google.com googlebot test"

			cookieManager = CookieManagerMock.new
			cookieManager.cookieList[:c1] = { "value" => "Value1" }
			cookieManager.cookieList[:c2] = { "value" => "ddd" }
			contextMock.cookieManager = cookieManager

			testObject = IntegrationEvaluator.new;
			matchedConfig = testObject.getMatchedIntegrationConfig(integrationConfig, url, contextMock)
			assert( matchedConfig == nil);
		end

		def test_getMatchedIntegrationConfig_oneTrigger_or_notMatched
			integrationConfig =
			{
				"Integrations" =>
				[
					{
						"Name" => "integration1",
						"Triggers" =>
						[
							{
								"LogicalOperator" => "Or",
								"TriggerParts" =>
								[
									{
										"CookieName" => "c1",
										"Operator" => "Equals",
										"ValueToCompare" => "value1",
										"ValidatorType" => "CookieValidator",
										"IsIgnoreCase" => true,
										"IsNegative" => true
									},
									{
										"UrlPart" => "PageUrl",
										"ValidatorType" => "UrlValidator",
										"ValueToCompare" => "test",
										"Operator" => "Equals",
										"IsIgnoreCase" => false,
										"IsNegative" => false
									}
								]
							}
						]
					}
				]
			}

			url = "http://test.testdomain.com:8080/test?q=2";
			contextMock = HttpContextMock.new

			cookieManager = CookieManagerMock.new
			cookieManager.cookieList[:c1] = { "value" => "Value1" }
			cookieManager.cookieList[:c2] = { "value" => "ddd" }
			contextMock.cookieManager = cookieManager

			testObject = IntegrationEvaluator.new;
			matchedConfig = testObject.getMatchedIntegrationConfig(integrationConfig, url, contextMock)
			assert( matchedConfig == nil );
		end

		def test_getMatchedIntegrationConfig_oneTrigger_or_matched
			integrationConfig =
			{
				"Integrations" =>
				[
					{
						"Name" => "integration1",
						"Triggers" =>
						[
							{
								"LogicalOperator" => "Or",
								"TriggerParts" =>
								[
									{
										"CookieName" => "c1",
										"Operator" => "Equals",
										"ValueToCompare" => "value1",
										"ValidatorType" => "CookieValidator",
										"IsIgnoreCase" => true,
										"IsNegative" => true
									},
									{
										"UrlPart" => "PageUrl",
										"ValidatorType" => "UrlValidator",
										"ValueToCompare" => "test",
										"Operator" => "Equals",
										"IsIgnoreCase" => false,
										"IsNegative" => true
									}
								]
							}
						]
					}
				]
			}

			url = "http://test.testdomain.com:8080/test?q=2";
			contextMock = HttpContextMock.new

			cookieManager = CookieManagerMock.new
			cookieManager.cookieList[:c1] = { "value" => "Value1" }
			cookieManager.cookieList[:c2] = { "value" => "ddd" }
			contextMock.cookieManager = cookieManager

			testObject = IntegrationEvaluator.new;
			matchedConfig = testObject.getMatchedIntegrationConfig(integrationConfig, url, contextMock)
			assert( matchedConfig["Name"].eql? "integration1" );
		end

		def test_getMatchedIntegrationConfig_twoTriggers_matched
			integrationConfig =
			{
				"Integrations" =>
				[
					{
						"Name" => "integration1",
						"Triggers" =>
						[
							{
								"LogicalOperator" => "And",
								"TriggerParts" =>
								[
									{
										"CookieName" => "c1",
										"Operator" => "Equals",
										"ValueToCompare" => "value1",
										"ValidatorType" => "CookieValidator",
										"IsIgnoreCase" => true,
										"IsNegative" => true
									}
								]
							},
							{
								"LogicalOperator" => "And",
								"TriggerParts" =>
								[
									{
										"CookieName" => "c1",
										"Operator" => "Equals",
										"ValueToCompare" => "Value1",
										"ValidatorType" => "CookieValidator",
										"IsIgnoreCase" => false,
										"IsNegative" => false
									},
									{
										"UrlPart" => "PageUrl",
										"ValidatorType" => "UrlValidator",
										"ValueToCompare" => "test",
										"Operator" => "Contains",
										"IsIgnoreCase" => false,
										"IsNegative" => false
									}
								]
							}
						]
					}
				]
			}

			url = "http://test.testdomain.com:8080/test?q=2";
			contextMock = HttpContextMock.new

			cookieManager = CookieManagerMock.new
			cookieManager.cookieList[:c1] = { "value" => "Value1" }
			cookieManager.cookieList[:c2] = { "value" => "ddd" }
			contextMock.cookieManager = cookieManager

			testObject = IntegrationEvaluator.new;
			matchedConfig = testObject.getMatchedIntegrationConfig(integrationConfig, url, contextMock)
			assert( matchedConfig["Name"].eql? "integration1" );
		end

		def test_getMatchedIntegrationConfig_threeIntegrationsInOrder_secondMatched
			integrationConfig =
			{
				"Integrations" =>
				[
					{
						"Name" => "integration0",
						"Triggers" =>
						[
							{
								"LogicalOperator" => "And",
								"TriggerParts" =>
								[
									{
										"UrlPart" => "PageUrl",
										"ValidatorType" => "UrlValidator",
										"ValueToCompare" => "Test",
										"Operator" => "Contains",
										"IsIgnoreCase" => false,
										"IsNegative" => false
									}
								]
							}
						]
					},
					{
						"Name" => "integration1",
						"Triggers" =>
						[
							{
								"LogicalOperator" => "And",
								"TriggerParts" =>
								[
									{
										"UrlPart" => "PageUrl",
										"ValidatorType" => "UrlValidator",
										"ValueToCompare" => "test",
										"Operator" => "Contains",
										"IsIgnoreCase" => false,
										"IsNegative" => false
									}
								]
							}
						]
					},
					{
						"Name" => "integration2",
						"Triggers" =>
						[
							{
								"LogicalOperator" => "And",
								"TriggerParts" =>
								[
									{
										"CookieName" => "c1",
										"ValidatorType" => "CookieValidator",
										"ValueToCompare" => "c1",
										"Operator" => "Equals",
										"IsIgnoreCase" => true,
										"IsNegative" => false
									}
								]
							}
						]
					}
				]
			}

			url = "http://test.testdomain.com:8080/test?q=2";
			contextMock = HttpContextMock.new

			cookieManager = CookieManagerMock.new
			cookieManager.cookieList[:c1] = { "value" => "Value1" }
			cookieManager.cookieList[:c2] = { "value" => "ddd" }
			contextMock.cookieManager = cookieManager

			testObject = IntegrationEvaluator.new;
			matchedConfig = testObject.getMatchedIntegrationConfig(integrationConfig, url, contextMock)
			assert( matchedConfig["Name"].eql? "integration1" );
		end
	end

	class TestUrlValidatorHelper < Test::Unit::TestCase
		def test_evaluate
			assert( !UrlValidatorHelper.evaluate(nil, "notimportant") )
			assert( !UrlValidatorHelper.evaluate({}, "notimportant") )

			triggerPart =
			{
				"UrlPart" => "PageUrl",
				"Operator" => "Contains",
				"IsIgnoreCase" => true,
				"IsNegative" => false,
				"ValueToCompare" => "http://test.testdomain.com:8080/test?q=1"
			}
			assert( !UrlValidatorHelper.evaluate(triggerPart, "http://test.testdomain.com:8080/test?q=2") )

			triggerPart =
			{
				"UrlPart" => "PagePath",
				"Operator" => "Equals",
				"IsIgnoreCase"=> true,
				"IsNegative"=> false,
				"ValueToCompare"=> "/Test/t1"
			}
			assert( UrlValidatorHelper.evaluate(triggerPart, "http://test.testdomain.com:8080/test/t1?q=2&y02") )

			triggerPart =
			{
				"UrlPart" => "HostName",
				"Operator" => "Contains",
				"IsIgnoreCase" => true,
				"IsNegative" => false,
				"ValueToCompare" => "test.testdomain.com"
			}
			assert( UrlValidatorHelper.evaluate(triggerPart, "http://m.test.testdomain.com:8080/test?q=2") )

			triggerPart =
			{
				"UrlPart" => "HostName",
				"Operator" => "Contains",
				"IsIgnoreCase" => true,
				"IsNegative" => true,
				"ValueToCompare" => "test.testdomain.com"
			}
			assert( !UrlValidatorHelper.evaluate(triggerPart,"http://m.test.testdomain.com:8080/test?q=2") )
		end
	end

	class TestUserAgentValidatorHelper < Test::Unit::TestCase
		def test_evaluate
			assert( !UserAgentValidatorHelper.evaluate(nil, "notimportant") )
			assert( !UserAgentValidatorHelper.evaluate({}, "notimportant") )

			triggerPart =
			{
				"Operator" => "Contains",
				"IsIgnoreCase" => false,
				"IsNegative" => false,
				"ValueToCompare" => "googlebot"
			}
			assert( !UserAgentValidatorHelper.evaluate(triggerPart, "Googlebot sample useraagent") )

			triggerPart =
			{
				"Operator" => "Equals",
				"IsIgnoreCase"=> true,
				"IsNegative"=> true,
				"ValueToCompare"=> "googlebot"
			}
			assert( UserAgentValidatorHelper.evaluate(triggerPart, "oglebot sample useraagent") )

			triggerPart =
			{

				"Operator" => "Contains",
				"IsIgnoreCase" => false,
				"IsNegative" => true,
				"ValueToCompare" => "googlebot"
			}
			assert(!UserAgentValidatorHelper.evaluate(triggerPart, "googlebot") )

			triggerPart =
			{

				"Operator" => "Contains",
				"IsIgnoreCase" => true,
				"IsNegative" => false,
				"ValueToCompare" => "googlebot"
			}
			assert( UserAgentValidatorHelper.evaluate(triggerPart, "Googlebot") )
		end
	end

	class TestCookieValidatorHelper < Test::Unit::TestCase
		def test_evaluate
			cookieManagerMock = CookieManagerMock.new

			cookieManagerMock.cookieList[:c1] = { "value" => "notimportant" }
			assert(!CookieValidatorHelper.evaluate(nil, cookieManagerMock))
			assert(!CookieValidatorHelper.evaluate({}, cookieManagerMock))

			triggerPart =
			{
				"CookieName" => "c1",
				"Operator" => "Contains",
				"IsIgnoreCase" => true,
				"IsNegative" => false,
				"ValueToCompare" => "1"
			}
			cookieManagerMock.cookieList = {:c1 => { "value" => "hhh" }}
			assert(!CookieValidatorHelper.evaluate(triggerPart, cookieManagerMock))

			triggerPart =
			{
				"CookieName" => "c1",
				"Operator" => "Contains",
				"ValueToCompare" => "1"
			}
			cookieManagerMock.cookieList = {:c2 => { "value" => "ddd" }, :c1 => { "value" => "3" }}
			assert(!CookieValidatorHelper.evaluate(triggerPart, cookieManagerMock))

			triggerPart =
			{
				"CookieName" => "c1",
				"Operator" => "Contains",
				"IsIgnoreCase" => true,
				"IsNegative" => false,
				"ValueToCompare" => "1"
			}
			cookieManagerMock.cookieList = {:c2 => { "value" => "ddd" }, :c1 => { "value" => "1" }}
			assert(CookieValidatorHelper.evaluate(triggerPart, cookieManagerMock))

			triggerPart =
			{
				"CookieName" => "c1",
				"Operator" => "Contains",
				"IsIgnoreCase" => true,
				"IsNegative" => true,
				"ValueToCompare" => "1"
			}
			cookieManagerMock.cookieList = {:c2 => { "value" => "ddd" }, :c1 => { "value" => "1" }}
			assert(!CookieValidatorHelper.evaluate(triggerPart, cookieManagerMock))
		end
	end

	class TestHttpHeaderValidatorHelper < Test::Unit::TestCase
		def test_evaluate
			assert( !HttpHeaderValidatorHelper.evaluate(nil, {'a-header' => "notimportant" }) )
			assert( !HttpHeaderValidatorHelper.evaluate({}, {'a-header' => "notimportant" }) )

			triggerPart =
			{
				"HttpHeaderName" => "a-header",
				"Operator" => "Contains",
				"IsIgnoreCase" => true,
				"IsNegative" => false,
				"ValueToCompare" => "value"
			}
			assert( HttpHeaderValidatorHelper.evaluate(triggerPart, {'a-header' => "VaLuE"}) )

			triggerPart =
			{
				"HttpHeaderName" => "a-header",
				"Operator" => "Contains",
				"ValueToCompare" => "value"
			}
			assert( !HttpHeaderValidatorHelper.evaluate(triggerPart, {'a-header' => "not" }) )

			triggerPart =
			{
				"HttpHeaderName" => "a-header",
				"Operator" => "Contains",
				"ValueToCompare" => "value",
				"IsNegative" => true,
			}
			assert( HttpHeaderValidatorHelper.evaluate(triggerPart, {'a-header' => "not" }) )
		end
	end

	class TestRequestBodyValidatorHelperHelper < Test::Unit::TestCase
		def test_evaluate
			assert(!RequestBodyValidatorHelper.evaluate(nil, "notimportant"))
			assert(!RequestBodyValidatorHelper.evaluate({}, "notimportant"))

			triggerPart =
			{
				"Operator" => "Contains",
				"IsIgnoreCase" => false,
				"IsNegative" => false,
				"ValueToCompare" => "test body"
			}
			assert(RequestBodyValidatorHelper.evaluate(triggerPart, "test body"))

			triggerPart["ValueToCompare"] = "ZZZ";
			assert(!RequestBodyValidatorHelper.evaluate(triggerPart, "test body"))

			triggerPart["ValueToCompare"] = "Test";
			triggerPart["IsIgnoreCase"] = true;
			assert(RequestBodyValidatorHelper.evaluate(triggerPart, "test body"))

			triggerPart["ValueToCompare"] = "Test";
			triggerPart["IsIgnoreCase"] = true;
			triggerPart["IsNegative"] = true;
			assert(!RequestBodyValidatorHelper.evaluate(triggerPart, "test body"))

		end
	end

	class TestComparisonOperatorHelper < Test::Unit::TestCase
		def test_evaluate_equals_operator
			assert( ComparisonOperatorHelper.evaluate("Equals", false, false, nil, nil, nil) )
			assert( ComparisonOperatorHelper.evaluate("Equals", false, false, "test1", "test1", nil) )
			assert( !ComparisonOperatorHelper.evaluate("Equals", false, false, "test1", "Test1", nil) )
			assert( ComparisonOperatorHelper.evaluate("Equals", false, true, "test1", "Test1", nil) )
			assert( ComparisonOperatorHelper.evaluate("Equals", true, false, "test1", "Test1", nil) )
			assert( !ComparisonOperatorHelper.evaluate("Equals", true, false, "test1", "test1", nil) )
			assert( !ComparisonOperatorHelper.evaluate("Equals", true, true, "test1", "Test1", nil) )
		end

		def test_evaluate_contains_operator
			assert( ComparisonOperatorHelper.evaluate("Contains", false, false, nil, nil, nil) )
			assert( ComparisonOperatorHelper.evaluate("Contains", false, false, "test_test1_test", "test1", nil) )
			assert( !ComparisonOperatorHelper.evaluate("Contains", false, false, "test_test1_test", "Test1", nil) )
			assert( ComparisonOperatorHelper.evaluate("Contains", false, true, "test_test1_test", "Test1", nil) )
			assert( ComparisonOperatorHelper.evaluate("Contains", true, false, "test_test1_test", "Test1", nil) )
			assert( !ComparisonOperatorHelper.evaluate("Contains", true, true, "test_test1", "Test1", nil) )
			assert( !ComparisonOperatorHelper.evaluate("Contains", true, false, "test_test1", "test1", nil) )
			assert( ComparisonOperatorHelper.evaluate("Contains", false, false, "test_dsdsdsdtest1", "*", nil) )
		end

		def test_evaluate_equalsAny_operator
			assert( ComparisonOperatorHelper.evaluate("EqualsAny", false, false, "test1", nil, ["test1"]) )
			assert( !ComparisonOperatorHelper.evaluate("EqualsAny", false, false, "test1", nil, ["Test1"]) )
			assert( ComparisonOperatorHelper.evaluate("EqualsAny", false, true, "test1", nil, ["Test1"]) )
			assert( ComparisonOperatorHelper.evaluate("EqualsAny", true, false, "test1", nil, ["Test1"]) )
			assert( !ComparisonOperatorHelper.evaluate("EqualsAny", true, false, "test1", nil, ["test1"]) )
			assert( !ComparisonOperatorHelper.evaluate("EqualsAny", true, true, "test1", nil, ["Test1"]) )
		end

		def test_evaluate_containsAny_operator
			assert( ComparisonOperatorHelper.evaluate("ContainsAny", false, false, "test_test1_test", nil, ["test1"]) )
			assert( !ComparisonOperatorHelper.evaluate("ContainsAny", false, false, "test_test1_test", nil, ["Test1"]) )
			assert( ComparisonOperatorHelper.evaluate("ContainsAny", false, true, "test_test1_test", nil, ["Test1"]) )
			assert( ComparisonOperatorHelper.evaluate("ContainsAny", true, false, "test_test1_test", nil, ["Test1"]) )
			assert( !ComparisonOperatorHelper.evaluate("ContainsAny", true, true, "test_test1", nil, ["Test1"]) )
			assert( !ComparisonOperatorHelper.evaluate("ContainsAny", true, false, "test_test1", nil, ["test1"]) )
			assert( ComparisonOperatorHelper.evaluate("ContainsAny", false, false, "test_dsdsdsdtest1", nil, ["*"]) )
		end

		def test_evaluate_unsupported_operator
			assert( !ComparisonOperatorHelper.evaluate("-not-supported-", false, false, nil, nil, nil) )
		end
	end
end
