require 'test/unit'
require_relative '../IntegrationConfigHelpers'

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
		matchedConfig = testObject.getMatchedIntegrationConfig(integrationConfig, url, {})
        assert( matchedConfig == nil);
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
        testObject = IntegrationEvaluator.new;
		matchedConfig = testObject.getMatchedIntegrationConfig(integrationConfig, url, { :c2 => "ddd", :c1 => "Value1" })		
		assert( matchedConfig["Name"].eql? "integration1" );
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
        testObject = IntegrationEvaluator.new;
		matchedConfig = testObject.getMatchedIntegrationConfig(integrationConfig, url, { :c2 => "ddd", :c1 => "Value1" })		
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
        testObject = IntegrationEvaluator.new;
		matchedConfig = testObject.getMatchedIntegrationConfig(integrationConfig, url, { :c2 => "ddd", :c1 => "Value1" })		
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
        testObject = IntegrationEvaluator.new;
		matchedConfig = testObject.getMatchedIntegrationConfig(integrationConfig, url, { :c2 => "ddd", :c1 => "Value1" })		
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
        testObject = IntegrationEvaluator.new;
		matchedConfig = testObject.getMatchedIntegrationConfig(integrationConfig, url, { :c2 => "ddd", :c1 => "Value1" })		
		assert( matchedConfig["Name"].eql? "integration1" );			
	end
end

class TestUrlValidatorHelper < Test::Unit::TestCase
	def test_evaluate 
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

class TestCookieValidatorHelper < Test::Unit::TestCase
	def test_evaluate
		triggerPart = 
		{
			"CookieName" => "c1",
			"Operator" => "Contains",
			"IsIgnoreCase" => true,
			"IsNegative" => false,
			"ValueToCompare" => "1"
		}
        assert( !CookieValidatorHelper.evaluate(triggerPart, {:c1 => "hhh"}) )        

		triggerPart = {}
        triggerPart = 
		{
			"CookieName" => "c1",
			"Operator" => "Contains",
			"ValueToCompare" => "1"
		}
		assert( !CookieValidatorHelper.evaluate(triggerPart, {:c2 => "ddd", :c1 => "1"}) )
        
		triggerPart = 
		{
			"CookieName" => "c1",
			"Operator" => "Contains",
			"IsIgnoreCase" => true,
			"IsNegative" => false,
			"ValueToCompare" => "1"
		}
		assert( CookieValidatorHelper.evaluate(triggerPart, {:c2 => "ddd", :c1 => "1"}) )
        
		triggerPart = 
		{
			"CookieName" => "c1",
			"Operator" => "Contains",
			"IsIgnoreCase" => true,
			"IsNegative" => true,
			"ValueToCompare" => "1"
		}
		assert( !CookieValidatorHelper.evaluate(triggerPart, {:c2 => "ddd", :c1 => "1"}) )	
	end
end

class TestComparisonOperatorHelper < Test::Unit::TestCase
	def test_evaluate_equals_operator
	    assert( ComparisonOperatorHelper.evaluate("Equals", false, false, nil, nil) )
		assert( ComparisonOperatorHelper.evaluate("Equals", false, false, "test1", "test1") )
		assert( !ComparisonOperatorHelper.evaluate("Equals", false, false, "test1", "Test1") )
        assert( ComparisonOperatorHelper.evaluate("Equals", false, true, "test1", "Test1") )
        assert( ComparisonOperatorHelper.evaluate("Equals", true, false, "test1", "Test1") )
        assert( !ComparisonOperatorHelper.evaluate("Equals", true, false, "test1", "test1") )
		assert( !ComparisonOperatorHelper.evaluate("Equals", true, true, "test1", "Test1") )
	end

	def test_evaluate_contains_operator
		assert( ComparisonOperatorHelper.evaluate("Contains", false, false, nil, nil) )
		assert( ComparisonOperatorHelper.evaluate("Contains", false, false, "test_test1_test", "test1") )
        assert( !ComparisonOperatorHelper.evaluate("Contains", false, false, "test_test1_test", "Test1") )
        assert( ComparisonOperatorHelper.evaluate("Contains", false, true, "test_test1_test", "Test1") )
        assert( ComparisonOperatorHelper.evaluate("Contains", true, false, "test_test1_test", "Test1") )
        assert( !ComparisonOperatorHelper.evaluate("Contains", true, true, "test_test1", "Test1") )
        assert( !ComparisonOperatorHelper.evaluate("Contains", true, false, "test_test1", "test1") )
        assert( ComparisonOperatorHelper.evaluate("Contains", false, false, "test_dsdsdsdtest1", "*") )
	end

	def test_evaluate_startsWith_operator
		assert( ComparisonOperatorHelper.evaluate("StartsWith", false, false, nil, nil) )
		assert( ComparisonOperatorHelper.evaluate("StartsWith", false, false, "test1_test1_test", "test1") )
        assert( !ComparisonOperatorHelper.evaluate("StartsWith", false, false, "test1_test1_test", "Test1") )
        assert( ComparisonOperatorHelper.evaluate("StartsWith", false, true, "test1_test1_test", "Test1") )
        assert( !ComparisonOperatorHelper.evaluate("StartsWith", true, true, "test1_test1_test", "Test1") )    
	end

	def test_evaluate_endsWith_operator
		assert( ComparisonOperatorHelper.evaluate("EndsWith", false, false, nil, nil) )
		assert( ComparisonOperatorHelper.evaluate("EndsWith", false, false, "test1_test1_testshop", "shop") )
        assert( !ComparisonOperatorHelper.evaluate("EndsWith", false, false, "test1_test1_testshop2", "shop") )
        assert( ComparisonOperatorHelper.evaluate("EndsWith", false, true, "test1_test1_testshop", "Shop") )
        assert( !ComparisonOperatorHelper.evaluate("EndsWith", true, true, "test1_test1_testshop", "Shop") )
	end

	def test_evaluate_matchesWith_operator
		assert( ComparisonOperatorHelper.evaluate("MatchesWith", false, false, nil, nil) )
		assert( ComparisonOperatorHelper.evaluate("MatchesWith", false, false, "test1_test1_testshop", ".*shop.*") )
        assert( !ComparisonOperatorHelper.evaluate("MatchesWith", false, false, "test1_test1_testshop2", ".*Shop.*") )
        assert( ComparisonOperatorHelper.evaluate("MatchesWith", false, true, "test1_test1_testshop", ".*Shop.*") )
        assert( !ComparisonOperatorHelper.evaluate("MatchesWith", true, true, "test1_test1_testshop", ".*Shop.*") )
	end

	def test_evaluate_unsupported_operator
		assert( !ComparisonOperatorHelper.evaluate("-not-supported-", false, false, nil, nil) )
	end	
end
