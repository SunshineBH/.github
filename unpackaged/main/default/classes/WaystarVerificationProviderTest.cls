@isTest
public class WaystarVerificationProviderTest {

    private class SuccessMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"ParsedOutput":{"FileStatus":1,"FileStatusDescription":"ACTIVE","MemberId":"123456","Employer":"TechCorp","GroupNumber":"GRP123",' +
                '"Subscriber":{"First":"John","Last":"Doe","Dob":"01/01/1980","Address1":"456 Elm St","City":"Springfield","State":"IL","Zip":"62704"},' +
                '"Patient":{"First":"John","Last":"Doe","Dob":"01/01/1980","Address1":"456 Elm St","Address2":"Unit 2","City":"Springfield","State":"IL","Zip":"62704"},' +
                '"Plans":[{"InsurancePlan":"30","InsurancePlanName":"30","FileStatus":1,"FileStatusDescription":"ACTIVE","ActiveDate":"01/01/2024","IsActive":true}],' +
                '"Benefits":{"30":{"IND":{"BinDed":"1000","BonDed":"1200","BonCovgPerc":"60%"}},"MH":{"IND":{"BonCovgPerc":"60%"}}}}}'
            );
            return res;
        }
    }

    private class FailCodeMock implements HttpCalloutMock {
        public String failCode;
        public FailCodeMock(String code) { this.failCode = code; }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"ParsedOutput":{"FileStatus":3,"failCode":"' + failCode + '","failReason":"Test fail reason"}}');
            return res;
        }
    }

    private class InactiveMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"ParsedOutput":{"FileStatus":1,"MemberId":"123456","Employer":"Anon Inc",' +
                '"Subscriber":{"First":"John","Last":"Doe","Dob":"01/01/1970"},' +
                '"Patient":{"First":"John","Last":"Doe","Dob":"01/01/1970"},' +
                '"Plans":[{"InsurancePlan":"30","InsurancePlanName":"BLUE CHOICE PREFERRED","FileStatus":2,"FileStatusDescription":"INACTIVE","IsActive":false}],' +
                '"Benefits":{"30":{"IND":{"CoverageStatus":"Inactive"}},"MH":{"IND":{"CoverageStatus":"Active"}}}}}'
            );
            return res;
        }
    }

    private class NoBenefitsMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"ParsedOutput":{"FileStatus":1,"Plans":[],"Benefits":{}}}');
            return res;
        }
    }

    @isTest
    static void testVerify_Success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        WaystarVerificationProvider provider = new WaystarVerificationProvider();

        Test.startTest();
        ProviderResult result = provider.verify('123456', 'John', 'Doe', '1/1/1980', 'PAYID1', 'Test Payer');
        Test.stopTest();

        Assert.areEqual(true, result.success);
        Assert.areEqual(true, result.policyActive);
        Assert.areEqual('30', result.planName);
        Assert.areEqual('TechCorp', result.employer);
        Assert.areEqual('456 Elm St', result.subscriberAddress);
        Assert.areEqual(true, result.outOfNetwork, 'BonCovgPerc present should indicate OON');
    }

    @isTest
    static void testVerify_InactivePlan() {
        Test.setMock(HttpCalloutMock.class, new InactiveMock());

        WaystarVerificationProvider provider = new WaystarVerificationProvider();

        Test.startTest();
        ProviderResult result = provider.verify('123456', 'John', 'Doe', '1/1/1980', 'PAYID1', 'Test Payer');
        Test.stopTest();

        Assert.areEqual(true, result.success);
        Assert.areEqual(false, result.policyActive);
    }

    @isTest
    static void testVerify_NoBenefits() {
        Test.setMock(HttpCalloutMock.class, new NoBenefitsMock());

        WaystarVerificationProvider provider = new WaystarVerificationProvider();

        Test.startTest();
        ProviderResult result = provider.verify('123456', 'John', 'Doe', '1/1/1980', 'PAYID1', 'Test Payer');
        Test.stopTest();

        Assert.areEqual(true, result.success);
        Assert.areEqual(false, result.policyActive);
        Assert.isTrue(result.errorMessage.contains('Benefits could not be found') || result.errorMessage.contains('No active insurance'));
    }

    @isTest
    static void testVerify_FailCode97() {
        Test.setMock(HttpCalloutMock.class, new FailCodeMock('97'));

        WaystarVerificationProvider provider = new WaystarVerificationProvider();

        Test.startTest();
        ProviderResult result = provider.verify('123456', 'John', 'Doe', '1/1/1980', 'PAYID1', 'Test Payer');
        Test.stopTest();

        Assert.areEqual(false, result.success);
        Assert.isNotNull(result.errorMessage);
    }

    @isTest
    static void testVerify_FailCode73_IncorrectName() {
        Test.setMock(HttpCalloutMock.class, new FailCodeMock('73'));

        WaystarVerificationProvider provider = new WaystarVerificationProvider();

        Test.startTest();
        ProviderResult result = provider.verify('123456', 'John', 'Doe', '1/1/1980', 'PAYID1', 'Test Payer');
        Test.stopTest();

        Assert.areEqual(false, result.success);
        Assert.isNotNull(result.errorMessage);
    }

    @isTest
    static void testVerify_FailCode42_NoResponse() {
        Test.setMock(HttpCalloutMock.class, new FailCodeMock('42'));

        WaystarVerificationProvider provider = new WaystarVerificationProvider();

        Test.startTest();
        ProviderResult result = provider.verify('123456', 'John', 'Doe', '1/1/1980', 'PAYID1', 'Test Payer');
        Test.stopTest();

        Assert.areEqual(false, result.success);
        Assert.isNotNull(result.errorMessage);
    }

    @isTest
    static void testVerify_FailCode54_DobIncorrect() {
        Test.setMock(HttpCalloutMock.class, new FailCodeMock('54'));

        WaystarVerificationProvider provider = new WaystarVerificationProvider();

        Test.startTest();
        ProviderResult result = provider.verify('123456', 'John', 'Doe', '1/1/1980', 'PAYID1', 'Test Payer');
        Test.stopTest();

        Assert.areEqual(false, result.success);
        Assert.isNotNull(result.errorMessage);
    }

    @isTest
    static void testVerify_FailCode44_NoMatch() {
        Test.setMock(HttpCalloutMock.class, new FailCodeMock('44'));

        WaystarVerificationProvider provider = new WaystarVerificationProvider();

        Test.startTest();
        ProviderResult result = provider.verify('123456', 'John', 'Doe', '1/1/1980', 'PAYID1', 'Test Payer');
        Test.stopTest();

        Assert.areEqual(false, result.success);
        Assert.isNotNull(result.errorMessage);
    }

    @isTest
    static void testVerify_FailCodeUnknown() {
        Test.setMock(HttpCalloutMock.class, new FailCodeMock('00'));

        WaystarVerificationProvider provider = new WaystarVerificationProvider();

        Test.startTest();
        ProviderResult result = provider.verify('123456', 'John', 'Doe', '1/1/1980', 'PAYID1', 'Test Payer');
        Test.stopTest();

        Assert.areEqual(false, result.success);
        Assert.isNotNull(result.errorMessage);
    }

    @isTest
    static void testVerify_FutureActiveDate() {
        Test.setMock(HttpCalloutMock.class, new FutureActiveDateMock());

        WaystarVerificationProvider provider = new WaystarVerificationProvider();

        Test.startTest();
        ProviderResult result = provider.verify('123456', 'John', 'Doe', '1/1/1980', 'PAYID1', 'Test Payer');
        Test.stopTest();

        Assert.areEqual(true, result.success);
        Assert.isFalse(result.policyActive);
    }

    @isTest
    static void testVerify_HttpError() {
        Test.setMock(HttpCalloutMock.class, new HttpErrorMock());

        WaystarVerificationProvider provider = new WaystarVerificationProvider();

        Test.startTest();
        Exception caught;
        try {
            provider.verify('123456', 'John', 'Doe', '1/1/1980', 'PAYID1', 'Test Payer');
        } catch (Exception ex) {
            caught = ex;
        }
        Test.stopTest();

        Assert.isNotNull(caught);
    }

    @isTest
    static void testBuildFollowUpJob_ReturnsNull() {
        WaystarVerificationProvider provider = new WaystarVerificationProvider();
        ProviderResult pr = new ProviderResult();
        Assert.isNull(provider.buildFollowUpJob(null, pr));
    }

    private class HttpErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    private class FutureActiveDateMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            Date future = Date.today().addYears(1);
            String futureStr = future.month() + '/' + future.day() + '/' + future.year();
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(
                '{"ParsedOutput":{"FileStatus":1,"MemberId":"123456","Employer":"FutureCorp",' +
                '"Subscriber":{},"Patient":{},' +
                '"Plans":[{"InsurancePlan":"30","InsurancePlanName":"Future Plan","FileStatus":1,"ActiveDate":"' + futureStr + '","IsActive":true}],' +
                '"Benefits":{"30":{"IND":{}},"MH":{"IND":{}}}}}'
            );
            return res;
        }
    }
}