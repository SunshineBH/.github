@IsTest
private class VerifyTXPdfQueueableTest {
    private class MockSuccess implements HttpCalloutMock {
        private Integer callCount = 0;

        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (req.getEndpoint().contains('reports/export')) {
                res.setBody('{"status":200,"message":"Report created successfully","download_link":"https://example.s3.amazonaws.com/test.pdf"}');
            } else {
                res.setBodyAsBlob(Blob.valueOf('%PDF-test'));
            }
            return res;
        }
    }

    private class MockExportFailure implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"internal server error"}');
            return res;
        }
    }

    @IsTest
    static void testSuccess() {
        Opportunity opp = new Opportunity(Name = 'Test', StageName = 'Prospecting', CloseDate = Date.today());
        insert opp;

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        System.enqueueJob(new VerifyTXPdfQueueable('test-vob-id', opp.Id));
        Test.stopTest();

        List<ContentDocumentLink> links = [SELECT Id, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :opp.Id];
        Assert.areEqual(1, links.size(), 'Expected one file attached to Opportunity');

        List<ContentVersion> versions = [SELECT Title FROM ContentVersion WHERE ContentDocumentId = :links[0].ContentDocumentId];
        Assert.areEqual('Test - VerifyTX', versions[0].Title);
    }

    @IsTest
    static void testExportFailureSkipsAttachment() {
        Opportunity opp = new Opportunity(Name = 'Test', StageName = 'Prospecting', CloseDate = Date.today());
        insert opp;

        Test.setMock(HttpCalloutMock.class, new MockExportFailure());
        Test.startTest();
        System.enqueueJob(new VerifyTXPdfQueueable('test-vob-id', opp.Id));
        Test.stopTest();

        List<ContentDocumentLink> links = [SELECT Id, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :opp.Id];
        Assert.areEqual(0, links.size(), 'Expected no files attached when export fails');
    }
}