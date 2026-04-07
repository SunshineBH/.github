public class VerifyTXPdfQueueable implements Queueable, Database.AllowsCallouts {
    private String vobId;
    private Id recordId;

    public VerifyTXPdfQueueable(String vobId, Id recordId) {
        this.vobId = vobId;
        this.recordId = recordId;
    }

    public void execute(QueueableContext ctx) {
        try {
            String downloadLink = requestPdfExport();
            if (downloadLink == null) return;
            Blob pdfBlob = downloadPdf(downloadLink);
            attachToRecord(pdfBlob);
        } catch (Exception ex) {
            ErrorLogger.ErrorInfo err = new ErrorLogger.ErrorInfo();
            err.context = 'VerifyTXPdfQueueable';
            err.errorMessage = ex.getMessage().left(256);
            new ErrorLogger().logError(err);
        }
    }

    private String requestPdfExport() {
        Map<String, Object> body = new Map<String, Object>{
            'format' => 'pdf',
            'vob_id' => vobId,
            'request_type' => 'custom',
            'out_of_network' => new List<String>{ 'AI', '30', 'MH' },
            'in_network' => new List<String>{ 'AI', '30', 'MH' },
            'on_demand' => true
        };

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setEndpoint('callout:VerifyTX/reports/export');
        req.setBody(JSON.serialize(body));
        req.setTimeout(30000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) return null;

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        return (String) parsed.get('download_link');
    }

    private Blob downloadPdf(String url) {
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(url);
        req.setTimeout(30000);
        HttpResponse res = new Http().send(req);
        return res.getBodyAsBlob();
    }

    private void attachToRecord(Blob pdfBlob) {
        String recordName = [SELECT Name FROM Opportunity WHERE Id = :recordId].Name;
        ContentVersion cv = new ContentVersion();
        cv.Title = recordName + ' - VerifyTX';
        cv.PathOnClient = recordName + ' - VerifyTX.pdf';
        cv.VersionData = pdfBlob;
        cv.IsMajorVersion = true;
        insert cv;

        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentDocumentId;
        cdl.LinkedEntityId = recordId;
        cdl.ShareType = 'V';
        insert cdl;
    }
}