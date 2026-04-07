@isTest
public class VerifyTXVerificationProviderTest {

    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"response_status_code":"4","response_status":"Complete",' +
                '"cache":{' +
                '"insurance_details":{' +
                '"coverage":"Active Coverage",' +
                '"plan_name":"Standard Silver VALUE",' +
                '"plan_sponsor":"Ambetter",' +
                '"plan_dates":{"start":"2026-01-01T00:00:00.000Z","end":"2026-12-31T00:00:00.000Z"}},' +
                '"subscriber_details":{' +
                '"address":{"address":"123 Test Road","city":"Test","state":"TX","zip":"77449"}},' +
                '"client_details":{' +
                '"date_of_birth":"1990-10-01",' +
                '"address":{"address":"123 Test Road","city":"Test","state":"TX","zip":"77449"}},' +
                '"benefits":{}}}'
                );
            return res;
        }
    }

    private class SuccessWithOONMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"response_status_code":"4","response_status":"Complete",' +
                '"cache":{' +
                '"insurance_details":{' +
                '"coverage":"Active Coverage",' +
                '"plan_name":"PPO Gold",' +
                '"plan_sponsor":"Cigna",' +
                '"coverage_dates":{"start":"2025-07-01T00:00:00.000Z"}},' +
                '"subscriber_details":{},' +
                '"client_details":{},' +
                '"benefits":{"out_of_network":[{"name":"Mental Health","status":"Active"}]}}}'
                );
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"response_status_code":"42",' +
                '"response_status":"The insurance company did not respond to your request.",' +
                '"error_status":"Error Payer Unresponsive"}'
                );
            return res;
        }
    }

    private class HttpErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    private class NoCacheMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"response_status_code":"4","response_status":"Complete"}');
            return res;
        }
    }

    @isTest
    static void testVerify_Success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        VerifyTXVerificationProvider provider = new VerifyTXVerificationProvider();

        Test.startTest();
        ProviderResult result = provider.verify('U12345', 'Testy', 'Testerson', '10/1/1990', 'AMB001', 'Ambetter');
        Test.stopTest();

        Assert.areEqual(true, result.success);
        Assert.areEqual(true, result.policyActive);
        Assert.areEqual('Active', result.planStatus);
        Assert.areEqual('Standard Silver VALUE', result.planName);
        Assert.areEqual('Ambetter', result.employer);
        Assert.areEqual('123 Test Road', result.subscriberAddress);
        Assert.areEqual('Test', result.subscriberCity);
        Assert.areEqual('TX', result.subscriberState);
        Assert.areEqual('77449', result.subscriberZip);
        Assert.areEqual('1990-10-01', result.patientDob);
        Assert.areEqual(false, result.outOfNetwork);
        Assert.areEqual('No', result.outOfNetworkBenefits);
        Assert.areEqual('U12345', result.insurancePolicy);
        Assert.areEqual(Date.newInstance(2026, 1, 1), result.effectiveDate);
        Assert.areEqual('1/1/2026', result.activeDate);
    }

    @isTest
    static void testVerify_NoOutOfNetwork() {
        Test.setMock(HttpCalloutMock.class, new SuccessWithOONMock());

        VerifyTXVerificationProvider provider = new VerifyTXVerificationProvider();

        Test.startTest();
        ProviderResult result = provider.verify('M99999', 'Jane', 'Doe', '7/4/1985', 'CGN001', 'Cigna');
        Test.stopTest();

        Assert.areEqual(true, result.success);
        Assert.areEqual(true, result.policyActive);
        Assert.areEqual(false, result.outOfNetwork);
        Assert.areEqual('No', result.outOfNetworkBenefits);
        Assert.areEqual(Date.newInstance(2025, 7, 1), result.effectiveDate);
        Assert.areEqual('7/1/2025', result.activeDate);
    }

    @isTest
    static void testVerify_Error() {
        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        VerifyTXVerificationProvider provider = new VerifyTXVerificationProvider();

        Test.startTest();
        ProviderResult result = provider.verify('12345', 'Tester', 'Testlon', '1/1/1977', 'AMB001', 'Ambetter');
        Test.stopTest();

        Assert.areEqual(false, result.success);
        Assert.isNotNull(result.errorMessage);
        Assert.isTrue(result.errorMessage.contains('The insurance company did not respond'));
    }

    @isTest
    static void testVerify_NoCache() {
        Test.setMock(HttpCalloutMock.class, new NoCacheMock());

        VerifyTXVerificationProvider provider = new VerifyTXVerificationProvider();

        Test.startTest();
        ProviderResult result = provider.verify('12345', 'Tester', 'Testlon', '1/1/1977', 'AMB001', 'Ambetter');
        Test.stopTest();

        Assert.areEqual(true, result.success);
        Assert.areEqual(false, result.policyActive);
        Assert.areEqual('No active insurance found.', result.errorMessage);
    }

    @isTest
    static void testVerify_HttpError() {
        Test.setMock(HttpCalloutMock.class, new HttpErrorMock());

        VerifyTXVerificationProvider provider = new VerifyTXVerificationProvider();

        Test.startTest();
        Exception caught;
        try {
            provider.verify('12345', 'Tester', 'Testlon', '1/1/1977', 'AMB001', 'Ambetter');
        } catch (Exception ex) {
            caught = ex;
        }
        Test.stopTest();

        Assert.isNotNull(caught);
    }

    private class SuccessWithBenefitsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"response_status_code":"4","response_status":"Complete",' +
                '"cache":{' +
                '"insurance_details":{' +
                '"coverage":"Active Coverage",' +
                '"plan_name":"PPO Gold",' +
                '"plan_sponsor":"Cigna",' +
                '"plan_dates":{"start":"2026-01-01T00:00:00.000Z"}},' +
                '"subscriber_details":{},' +
                '"client_details":{},' +
                '"benefits":{' +
                '"in_network":[{"type":"MH","name":"Mental Health","status":"Active Coverage",' +
                '"deductibles":[{"levelCode":"IND","level":"Individual","units":"USD","total":"3400","amount":"1200.00"}],' +
                '"outOfPocket":[{"levelCode":"IND","level":"Individual","units":"USD","total":"4500","amount":"2000.00"}],' +
                '"coPayment":[{"levelCode":"IND","level":"Individual","units":"USD","amount":"50"}],' +
                '"coInsurance":[],"reserve":[],"coverageBasis":[],"coverageBasisList":[],"limitations":[],"nonCovered":[],"contacts":[],"notes":[],"description":[]}],' +
                '"out_of_network":[{"type":"MH","name":"Mental Health","status":"Active Coverage",' +
                '"deductibles":[{"levelCode":"IND","level":"Individual","units":"USD","total":"6800","amount":"2400.00"}],' +
                '"outOfPocket":[{"levelCode":"IND","level":"Individual","units":"USD","total":"9000","amount":"4000.00"}],' +
                '"coPayment":[{"levelCode":"IND","level":"Individual","units":"USD","amount":"100"}],' +
                '"coInsurance":[],"reserve":[],"coverageBasis":[],"coverageBasisList":[],"limitations":[],"nonCovered":[],"contacts":[],"notes":[],"description":[]}]}}}'
                );
            return res;
        }
    }

    @isTest
    static void testVerify_BenefitExtraction() {
        Test.setMock(HttpCalloutMock.class, new SuccessWithBenefitsMock());

        VerifyTXVerificationProvider provider = new VerifyTXVerificationProvider();

        Test.startTest();
        ProviderResult result = provider.verify('M99999', 'Jane', 'Doe', '7/4/1985', 'CGN001', 'Cigna');
        Test.stopTest();

        Assert.areEqual(true, result.success);
        Assert.areEqual(true, result.policyActive);
        Assert.areEqual(3400, result.dedInn);
        Assert.areEqual(1200, result.dedMetInn);
        Assert.areEqual(4500, result.oopInn);
        Assert.areEqual(2000, result.oopMetInn);
        Assert.areEqual(50, result.copayInn);
        Assert.areEqual('Individual', result.indOrFamInn);
        Assert.areEqual(6800, result.dedOon);
        Assert.areEqual(2400, result.dedMetOon);
        Assert.areEqual(9000, result.oopOon);
        Assert.areEqual(4000, result.oopMetOon);
        Assert.areEqual(100, result.copayOon);
        Assert.areEqual('Individual', result.indOrFamOon);
    }

    @isTest
    static void testBuildFollowUpJob_WithVobId() {
        Opportunity opp = new Opportunity(Name = 'Test', StageName = 'Prospecting', CloseDate = Date.today());
        insert opp;

        ProviderResult pr = new ProviderResult();
        pr.vobId = 'vob-123';

        VerifyTXVerificationProvider provider = new VerifyTXVerificationProvider();
        System.Queueable job = provider.buildFollowUpJob(opp.Id, pr);

        Assert.isNotNull(job);
        Assert.isInstanceOfType(job, VerifyTXPdfQueueable.class);
    }

    @isTest
    static void testBuildFollowUpJob_NoVobId() {
        Opportunity opp = new Opportunity(Name = 'Test', StageName = 'Prospecting', CloseDate = Date.today());
        insert opp;

        ProviderResult pr = new ProviderResult();
        pr.vobId = null;

        VerifyTXVerificationProvider provider = new VerifyTXVerificationProvider();
        System.Queueable job = provider.buildFollowUpJob(opp.Id, pr);

        Assert.isNull(job);
    }
}