public class WaystarVerificationProvider implements IInsuranceVerificationProvider {

    public ProviderResult verify(String memberId, String firstName, String lastName, String dob, String payerId, String payerName) {
        ProviderResult result = new ProviderResult();

        WaystarDataWrapper data = new WaystarDataWrapper();
        data.inquiringProviderName = 'Sunshine Behavorial Health';
        data.subscriberMemberId = memberId;
        data.patientFirstName = firstName;
        data.patientLastName = lastName;
        data.patientDOB = dob;
        data.payerId = payerId;

        WaystarResult insuranceInfo = fetch(data);

        if (insuranceInfo.ParsedOutput.FailCode != null) {
            result.success = false;
            result.errorMessage = resolveFailCode(insuranceInfo.ParsedOutput.FailCode, insuranceInfo.ParsedOutput.FailReason);
            return result;
        }

        if (insuranceInfo.ParsedOutput.Benefits?.x30 == null
            && insuranceInfo.ParsedOutput.Benefits?.MH == null
            && insuranceInfo.ParsedOutput.Benefits?.AI == null) {
            result.success = true;
            result.policyActive = false;
            result.errorMessage = 'Benefits could not be found.';
            return result;
        }

        if (insuranceInfo.ParsedOutput.FileStatus != 1 || insuranceInfo.ParsedOutput.Plans.isEmpty()) {
            result.success = true;
            result.policyActive = false;
            result.errorMessage = 'No active insurance found.';
            return result;
        }

        // Prefer service type "30" (behavioral health) when multiple plans exist
        WaystarResult.Plans activePlan = insuranceInfo.ParsedOutput.Plans[0];
        for (WaystarResult.Plans plan : insuranceInfo.ParsedOutput.Plans) {
            if (plan.FileStatus == 1 && plan.InsurancePlan == '30') {
                activePlan = plan;
                break;
            }
        }

        result.success = true;
        result.policyActive = activePlan.FileStatus == 1;
        result.planName = activePlan.InsurancePlanName;
        result.employer = insuranceInfo.ParsedOutput.Employer;
        result.planStatus = result.policyActive ? 'Active' : 'Inactive';

        if (activePlan.ActiveDate != null) {
            if (activePlan.ActiveDate > Date.today()) {
                result.policyActive = false;
            }
            result.activeDate = activePlan.ActiveDate.month() + '/' + activePlan.ActiveDate.day() + '/' + activePlan.ActiveDate.year();
        }

        Boolean oon = false;
        if (insuranceInfo.ParsedOutput.Benefits?.MH?.IND != null) {
            oon = insuranceInfo.ParsedOutput.Benefits.MH.IND.BonCovgPerc != null
                  || insuranceInfo.ParsedOutput.Benefits.MH.IND.BonDed != null
                  || insuranceInfo.ParsedOutput.Benefits.MH.IND.BonOop != null;
        }
        result.outOfNetwork = oon;
        result.outOfNetworkBenefits = oon ? 'Yes' : 'No';

        if (String.isNotBlank(insuranceInfo.ParsedOutput.Subscriber?.Address1)) {
            result.subscriberAddress = insuranceInfo.ParsedOutput.Subscriber.Address1;
            result.subscriberCity = insuranceInfo.ParsedOutput.Subscriber.City;
            result.subscriberState = insuranceInfo.ParsedOutput.Subscriber.State;
            result.subscriberZip = insuranceInfo.ParsedOutput.Subscriber.Zip;
        }

        result.patientDob = insuranceInfo.ParsedOutput.Patient?.Dob;
        result.patientAddress1 = insuranceInfo.ParsedOutput.Patient?.Address1;
        result.patientAddress2 = insuranceInfo.ParsedOutput.Patient?.Address2;
        result.patientCity = insuranceInfo.ParsedOutput.Patient?.City;
        result.patientState = insuranceInfo.ParsedOutput.Patient?.State;
        result.patientZip = insuranceInfo.ParsedOutput.Patient?.Zip;

        result.insurancePolicy = memberId;
        result.effectiveDate = activePlan.ActiveDate;

        return result;
    }

    private WaystarResult fetch(WaystarDataWrapper data) {
        AWS_Credentials__c auth = AWS_Credentials__c.getInstance();
        String queryString =
            'UserID=' + auth.Waystar_UserId__c +
            '&Password=' + auth.Waystar_Password__c +
            '&DataFormat=SF1' +
            '&ResponseType=FullJSON' +
            '&Data=' + EncodingUtil.urlEncode(data.toPipeDelimitedString(), 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setEndpoint('callout:Waystar?' + queryString);
        req.setTimeout(30000);

        HttpResponse res;
        try {
            res = new Http().send(req);
        } catch (System.CalloutException ex) {
            if (ex.getMessage() == 'Read timed out') {
                throw new InsuranceVerification.VerificationTimeoutException('Read timed out');
            }
            throw ex;
        }

        if (res.getStatusCode() != 200) {
            throw new CalloutException('Failed integration callout');
        }

        return WaystarResult.parse(res.getBody());
    }

    private String resolveFailCode(String failCode, String failReason) {
        ErrorLogger.ErrorInfo errorReq = new ErrorLogger.ErrorInfo();
        errorReq.context = 'Waystar';
        errorReq.errorMessage = ('Fail Code: ' + failCode + ' ' + failReason).left(256);
        new ErrorLogger().logError(errorReq);

        if (failCode == '42' || failCode == '77' || failCode == '99') {
            return Label.IV_No_Response.replaceAll('\\{errorid\\}', errorReq.id());
        } else if (failCode == '73' || failCode == '98') {
            return Label.IV_Incorrect_Name.replaceAll('\\{errorid\\}', errorReq.id());
        } else if (failCode == '54' || failCode == '58' || failCode == '71') {
            return Label.IV_DOB_Incorrect.replaceAll('\\{errorid\\}', errorReq.id());
        } else if (failCode == '44' || failCode == '45' || failCode == '46' || failCode == '60' ||
                   failCode == '70' || failCode == '72' || failCode == '74' || failCode == '76' ||
                   failCode == '75' || failCode == '79') {
            return Label.IV_No_Match.replaceAll('\\{errorid\\}', errorReq.id());
        } else if (failCode == '41' || failCode == '43' || failCode == '51' ||
                   failCode == '53' || failCode == '55' || failCode == '78' || failCode == '97') {
            return Label.Fatal_Error.replaceAll('\\{errorid\\}', errorReq.id());
        } else {
            return failReason + ' Error Id: ' + errorReq.id();
        }
    }

    public System.Queueable buildFollowUpJob(Id recordId, ProviderResult pr) {
        return null;
    }
}