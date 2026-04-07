public class VerifyTXVerificationProvider implements IInsuranceVerificationProvider {
    public ProviderResult verify(String memberId, String firstName, String lastName, String dob, String payerId, String payerName) {
        ProviderResult result = new ProviderResult();

        String responseBody = fetch(memberId, firstName, lastName, dob, payerId);
        // _id can't map to an Apex field name — extract it before typed deserialization
        result.vobId = (String) ((Map<String, Object>) JSON.deserializeUntyped(responseBody)).get('_id');
        VtxResponse response = (VtxResponse) JSON.deserialize(responseBody, VtxResponse.class);

        if (response.response_status_code != '4') {
            ErrorLogger.ErrorInfo errorReq = new ErrorLogger.ErrorInfo();
            errorReq.context = 'VerifyTX';
            errorReq.errorMessage = ('Status Code: ' + response.response_status_code + ' ' + response.response_status).left(256);
            new ErrorLogger().logError(errorReq);
            result.success = false;
            result.errorMessage = response.response_status;
            return result;
        }

        VtxCache cache = response.cache;
        if (cache == null) {
            result.success = true;
            result.policyActive = false;
            result.errorMessage = 'No active insurance found.';
            return result;
        }

        VtxInsuranceDetails ins = cache.insurance_details;
        result.success = true;
        result.policyActive = ins != null && ins.coverage == 'Active Coverage';
        result.planStatus = result.policyActive ? 'Active' : 'Inactive';

        if (ins != null) {
            result.planName = ins.plan_name != null ? ins.plan_name : ins.plan_sponsor;
            result.employer = ins.plan_sponsor;
            VtxCoverageDates dates = ins.effectiveDates();
            if (dates != null && dates.start != null) {
                Date startDate = parseIsoDate(dates.start);
                if (startDate != null) {
                    result.effectiveDate = startDate;
                    result.activeDate = startDate.month() + '/' + startDate.day() + '/' + startDate.year();
                }
            }
        }

        VtxBenefits benefits = cache.benefits;
        if (benefits != null) {
            Boolean outOfNetworkBenefits = false;

            if (benefits.out_of_network != null) {
                for (VtxBenefitItem outOfNetworkBenefitItem : benefits.out_of_network) {
                    if (
                        (outOfNetworkBenefitItem.coInsurance != null && !outOfNetworkBenefitItem.coInsurance.isEmpty()) ||
                        (outOfNetworkBenefitItem.coPayment != null &&  !outOfNetworkBenefitItem.coPayment.isEmpty()) ||
                        (outOfNetworkBenefitItem.deductibles != null && !outOfNetworkBenefitItem.deductibles.isEmpty()) ||
                        (outOfNetworkBenefitItem.coInsurance != null && !outOfNetworkBenefitItem.coInsurance.isEmpty())
                    ) {
                        outOfNetworkBenefits = true;
                        break;
                    }
                }
            }

            result.outOfNetwork = outOfNetworkBenefits;

            if (result.policyActive == true) {
                result = extractBenefits(result, benefits);
            }
        }
        result.outOfNetworkBenefits = result.outOfNetwork == true ? 'Yes' : 'No';

        if (cache.subscriber_details != null && cache.subscriber_details.address != null) {
            VtxAddress addr = cache.subscriber_details.address;
            result.subscriberAddress = addr.address;
            result.subscriberCity = addr.city;
            result.subscriberState = addr.state;
            result.subscriberZip = addr.zip;
        }

        if (cache.client_details != null) {
            result.patientDob = cache.client_details.date_of_birth;
            if (cache.client_details.address != null) {
                VtxAddress addr = cache.client_details.address;
                result.patientAddress1 = addr.address;
                result.patientCity = addr.city;
                result.patientState = addr.state;
                result.patientZip = addr.zip;
            }
        }

        result.insurancePolicy = memberId;
        return result;
    }

    public System.Queueable buildFollowUpJob(Id recordId, ProviderResult pr) {
        if (pr.vobId == null) return null;
        return new VerifyTXPdfQueueable(pr.vobId, recordId);
    }

    private String fetch(String memberId, String firstName, String lastName, String dob, String payerId) {
        Map<String, String> requestBody = new Map<String, String>();
        requestBody.put('client_type', 'prospect');
        requestBody.put('facility', '6556369913c7c0658e948366');
        requestBody.put('member_id', memberId);
        requestBody.put('first_name', firstName);
        requestBody.put('last_name', lastName);
        requestBody.put('date_of_birth', dob);
        requestBody.put('payer_id', payerId);

        HttpRequest req = new HttpRequest();
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setEndpoint('callout:VerifyTX/vobs/verify');
        req.setBody(JSON.serialize(requestBody));
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

        if (res.getStatusCode() == 200) {
            return res.getBody();
        }

        System.debug('VerifyTX integration failed: ' + res.getStatusCode() + ' - ' + res.getBody());
        throw new CalloutException('Failed VerifyTX integration callout');
    }

    private ProviderResult extractBenefits(ProviderResult result, VtxBenefits benefits) {
        List<String> typePriority = new List<String> {'AI', 'MH', '30'};

        List<VtxBenefitItem> innItems = findBenefitItem(benefits.in_network, typePriority);
        if (!innItems.isEmpty()) {
            Coverage cover = populateCoverage(innItems);

            if (cover.ded != null) {
                result.dedInn = parseDecimal(cover.ded.total);
                result.dedMetInn = parseDecimal(cover.ded.amount);
                result.indOrFamInn = cover.ded.level;
            }

            if (cover.oop != null) {
                result.oopInn = parseDecimal(cover.oop.total);
                result.oopMetInn = parseDecimal(cover.oop.amount);
            }

            System.debug('coIns: ' + cover.coIns);
            if (cover.coIns != null) {
                Decimal pct = parseDecimal(cover.coIns.amount);
                if (pct != null) {
                    result.covgPercInn = 100 - (pct * 100);
                }
                System.debug('pct: ' + pct);
            }

            result.copayInn = cover.copay;
        }

        List<VtxBenefitItem> oonItems = findBenefitItem(benefits.out_of_network, typePriority);

        if (!oonItems.isEmpty()) {
            Coverage cover = populateCoverage(oonItems);
            if (cover.ded != null) {
                result.dedOon = parseDecimal(cover.ded.total);
                result.dedMetOon = parseDecimal(cover.ded.amount);
                result.indOrFamOon = cover.ded.level;
            }

            if (cover.oop != null) {
                result.oopOon = parseDecimal(cover.oop.total);
                result.oopMetOon = parseDecimal(cover.oop.amount);
            }

            result.copayOon =  cover.copay;

            if (cover.coIns != null) {
                Decimal pct = parseDecimal(cover.coIns.amount);
                if (pct != null) {
                    result.covgPercOon = 100 - (pct * 100);
                }
            }
        }

        if (result.oopInn != null) {
            result.hasInnOopMax = 'Yes';
        }

        if (result.oopOon != null) {
            result.hasOonOopMax = 'Yes';
        }

        return result;
    }

    private Coverage populateCoverage(List<VtxBenefitItem> innItems) {
        Coverage cover = new Coverage();
        if (innItems.isEmpty()) {
            return cover;
        }

        System.debug('innItems: ' + innItems);

        for (VtxBenefitItem innItem : innItems) {
            System.debug('innItem: ' + innItem);

            if (cover.ded == null) {
                cover.ded = findLevelEntry(innItem.deductibles);
            }
            if (cover.oop == null) {
                cover.oop = findLevelEntry(innItem.outOfPocket);
            }
            if (cover.coIns == null) {
                cover.coIns = findLevelEntry(innItem.coInsurance);
            }
            if (cover.copay == null && innItem.coPayment != null && !innItem.coPayment.isEmpty()) {
                cover.copay = parseDecimal(innItem.coPayment[0].amount);
            }

            if (cover.ded != null && cover.oop != null && cover.coIns != null && cover.copay != null) {
                break;
            }
        }
        return cover;
    }

    private class Coverage {
        VtxLevelEntry ded;
        VtxLevelEntry oop;
        VtxLevelEntry coIns;
        Decimal copay;
    }

    private List<VtxBenefitItem> findBenefitItem(List<VtxBenefitItem> items, List<String> typePriority) {
        System.debug('typePriority: ' + typePriority);
        List<VtxBenefitItem> benefits = new List<VtxBenefitItem>();

        if (items == null || items.isEmpty()) {
            return benefits;
        }

        Map<String, VtxBenefitItem> byType = new Map<String, VtxBenefitItem>();
        for (VtxBenefitItem item : items) {
            System.debug('item: ' + item);
            if (item.type == null || byType.containsKey(item.type)) {
                continue;
            }

            if (
                (item.deductibles != null && !item.deductibles.isEmpty()) ||
                (item.outOfPocket != null && !item.outOfPocket.isEmpty()) ||
                (item.coInsurance != null && !item.coInsurance.isEmpty())
            ) {
                byType.put(item.type, item);
            }
        }
        System.debug('byType: ' + byType.keySet());

        for (String t : typePriority) {
            if (byType.containsKey(t)) {
                System.debug('t: ' + t);
                benefits.add(byType.get(t));
            }
        }
        return benefits;
    }

    private VtxLevelEntry findLevelEntry(List<VtxLevelEntry> entries) {
        if (entries == null || entries.isEmpty()) {
            return null;
        }

        for (VtxLevelEntry entry : entries) {
            if ('IND'.equals(entry.levelCode)) {
                return entry;
            }
        }
        return entries[0];
    }

    private Decimal parseDecimal(String val) {
        if (String.isBlank(val)) return null;
        try {
            return Decimal.valueOf(val);
        } catch (Exception ex) {
            return null;
        }
    }

// ISO date format from VerifyTX is YYYY-MM-DDTHH:mm:ss.sssZ
    private Date parseIsoDate(String isoDate) {
        try {
            String datePart = isoDate.split('T')[0];
            List<String> parts = datePart.split('-');
            return Date.newInstance(Integer.valueOf(parts[0]), Integer.valueOf(parts[1]), Integer.valueOf(parts[2]));
        } catch (Exception ex) {
            return null;
        }
    }

    private class VtxAddress {
        String address;
        String city;
        String state;
        String zip;
    }

    private class VtxCoverageDates {
        String start;
    }

    private class VtxInsuranceDetails {
        String coverage;
        String plan_name;
        String plan_sponsor;
        VtxCoverageDates coverage_dates;
        VtxCoverageDates plan_dates;

        VtxCoverageDates effectiveDates() {
            return coverage_dates != null ? coverage_dates : plan_dates;
        }
    }

    private class VtxLevelEntry {
        String levelCode;
        String level;
        String total;
        String amount;
    }

    private class VtxBenefitItem {
        String type;
        List<VtxLevelEntry> deductibles;
        List<VtxLevelEntry> outOfPocket;
        List<VtxLevelEntry> coPayment;
        List<VtxLevelEntry> coInsurance;
    }

    private class VtxBenefits {
        List<VtxBenefitItem> in_network;
        List<VtxBenefitItem> out_of_network;
    }

    private class VtxSubscriberDetails {
        VtxAddress address;
    }

    private class VtxClientDetails {
        String date_of_birth;
        VtxAddress address;
    }

    private class VtxCache {
        VtxInsuranceDetails insurance_details;
        VtxSubscriberDetails subscriber_details;
        VtxClientDetails client_details;
        VtxBenefits benefits;
    }

    private class VtxResponse {
        String response_status_code;
        String response_status;
        VtxCache cache;
    }
}