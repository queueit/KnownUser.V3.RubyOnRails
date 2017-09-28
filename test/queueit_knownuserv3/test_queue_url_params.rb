require 'test/unit'
require_relative '../../lib/queueit_knownuserv3'

module QueueIt
	class TestQueueUrlParams < Test::Unit::TestCase
		def test_extractQueueParams
			queueITToken = "e_testevent1~q_6cf23f10-aca7-4fa2-840e-e10f56aecb44~ts_1486645251~ce_True~cv_3~rt_Queue~h_cb7b7b53fa20e708cb59a5a2696f248cba3b2905d92e12ee5523c298adbef298";
			result = QueueUrlParams.extractQueueParams(queueITToken);
			assert( result.eventId.eql? "testevent1" )
			assert( result.timeStamp == 1486645251 )
			assert( result.extendableCookie.eql? true )
			assert( result.queueITToken.eql? queueITToken )
			assert( result.cookieValidityMinute == 3 )
			assert( result.queueId.eql? "6cf23f10-aca7-4fa2-840e-e10f56aecb44" )
			assert( result.hashCode.eql? "cb7b7b53fa20e708cb59a5a2696f248cba3b2905d92e12ee5523c298adbef298" )
			assert( result.queueITTokenWithoutHash.eql? "e_testevent1~q_6cf23f10-aca7-4fa2-840e-e10f56aecb44~ts_1486645251~ce_True~cv_3~rt_Queue" )	
		end

		def test_extractQueueParams_notValidToken
			queueITToken = "ts_sasa~cv_adsasa~ce_falwwwse~q_944c1f44-60dd-4e37-aabc-f3e4bb1c8895";
			result = QueueUrlParams.extractQueueParams(queueITToken);
			assert( result.eventId.empty? )
			assert( result.timeStamp == 0 )
			assert( result.extendableCookie.eql? false )
			assert( result.queueITToken.eql? queueITToken )
			assert( result.cookieValidityMinute.nil? )
			assert( result.queueId.eql? "944c1f44-60dd-4e37-aabc-f3e4bb1c8895" )
			assert( result.hashCode.empty? )
			assert( result.queueITTokenWithoutHash.eql? "ts_sasa~cv_adsasa~ce_falwwwse~q_944c1f44-60dd-4e37-aabc-f3e4bb1c8895" )	
		end
	end
end