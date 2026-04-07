public without sharing class InsuranceVerification {
    @AuraEnabled(cacheable = true)
    public static InsuranceWrapper getRecord(Id recordId) {
        InsuranceWrapper result = new InsuranceWrapper();
        try {
            if(recordId == null) {
                throw new VerificationException('Missing Record Id');
            }

            Insurance_Information__c insuranceInfo;
            SObjectType type = recordId.getSObjectType();
            if (type == Lead.SObjectType) {
                Lead lead = [SELECT Id, FirstName, LastName, Patient_DOB__c,
                             (SELECT Id, Subscriber_DOB__c, Insurance_Policy__c, Insurance_Provider__c, Address__c, City__c,
                              State__c, Zip_Code__c, CreatedDate, Employer__c, Plan_Name__c,
                              (SELECT Id, Plan_Status__c, Out_of_Network_Benefits__c, Effective_Date__c FROM Insurance_Verification__r ORDER BY CreatedDate DESC LIMIT 1)
                              FROM Insurance_Information__r ORDER BY CreatedDate DESC LIMIT 1)
                             FROM Lead
                             WHERE Id = : recordId
                                        LIMIT 1
                ];

                result.leadId = lead.Id;
                result.firstName = lead.FirstName;
                result.lastName = lead.LastName;
                result.dob = getDate(lead.Patient_DOB__c);

                if(lead.Insurance_Information__r.isEmpty()==false) {
                    insuranceInfo = lead.Insurance_Information__r[0];
                }
            } else {
                Opportunity lead = [SELECT Id, Patient_First_Name__c, Patient_Last_Name__c, Client_DOB__c,
                                    (SELECT Id, Subscriber_DOB__c, Insurance_Policy__c, Insurance_Provider__c, Address__c, City__c,
                                     State__c, Zip_Code__c, CreatedDate, Employer__c, Plan_Name__c,
                                     (SELECT Id, Plan_Status__c, Out_of_Network_Benefits__c, Effective_Date__c FROM Insurance_Verification__r ORDER BY CreatedDate DESC LIMIT 1)
                                     FROM Insurance_Information__r ORDER BY CreatedDate DESC LIMIT 1)
                                    FROM Opportunity
                                    WHERE Id = : recordId
                                               LIMIT 1
                ];

                result.leadId = lead.Id;
                result.firstName = lead.Patient_First_Name__c;
                result.lastName = lead.Patient_Last_Name__c;
                result.dob = getDate(lead.Client_DOB__c);

                if(lead.Insurance_Information__r.isEmpty()==false) {
                    insuranceInfo = lead.Insurance_Information__r[0];
                }
            }

            if(insuranceInfo != null) {
                result.verification = new InsuranceVerificationResultWrapper();
                result.verification.lastVerification = insuranceInfo.CreatedDate;
                result.verification.status = 'Success';
                result.verification.planName = insuranceInfo.Plan_Name__c;
                result.verification.employer = insuranceInfo.Employer__c;
                result.verification.policyAddress = insuranceInfo.Address__c;
                result.verification.policyCity = insuranceInfo.City__c;
                result.verification.policyState = insuranceInfo.State__c;
                result.verification.policyZip = insuranceInfo.Zip_Code__c;
                result.memberId = insuranceInfo.Insurance_Policy__c;
                result.provider = insuranceInfo.Insurance_Provider__c;

                if(insuranceInfo.Insurance_Verification__r.isEmpty()==false) {
                    result.verification.policyActive = insuranceInfo.Insurance_Verification__r[0].Plan_Status__c=='Active';
                    result.verification.outOfNetwork = insuranceInfo.Insurance_Verification__r[0].Out_of_Network_Benefits__c=='Yes';
                    Date effective = insuranceInfo.Insurance_Verification__r[0].Effective_Date__c;
                    if(insuranceInfo.Insurance_Verification__r[0].Effective_Date__c!=null) {
                        if(insuranceInfo.Insurance_Verification__r[0].Effective_Date__c>Date.today()) {
                            result.verification.policyActive = false;
                        }
                        result.verification.activeDate = effective.month() + '/' + effective.day() + '/' + effective.year();
                    }
                }
            }
        } catch (Exception ex) {
            ErrorLogger.ErrorInfo log = new ErrorLogger().logError(ex, 'Insurance Verifiction', recordId);
            result.verification = new InsuranceVerificationResultWrapper();
            result.verification.status = 'Failure';
            result.verification.errorMessage = ex.getMessage() + ' ' + Label.Fatal_Error.replaceAll('\\{errorid\\}', log.id());
        }
        return result;
    }

    @AuraEnabled
    public static InsuranceVerificationResultWrapper verifyInsurance(Id recordId, String detail) {
        System.debug('Entering InsuranceVerification.verifyInsurance: ' + detail);
        InsuranceVerificationResultWrapper result = new InsuranceVerificationResultWrapper();
        result.isDebugMode = FeatureManagement.checkPermission('LWCDebugMode');
        Savepoint sp;

        try {
            if(recordId == null) {
                throw new VerificationException('Missing Record Id');
            }

            InsuranceWrapper input = (InsuranceWrapper) JSON.deserializeStrict(detail, InsuranceWrapper.class);

            List<Account> insuranceProvider = [SELECT Id, Name, Payor_Id__c, Phone, Verify_Service__c
                                               FROM Account
                                               WHERE Id = : input.provider
                                                          LIMIT 1];

            if(insuranceProvider.isEmpty() || insuranceProvider[0].Payor_Id__c == null) {
                throw new VerificationException('Payor ID is missing.');
            }

            String dob = input.dob.month() + '/' + input.dob.day() + '/' + input.dob.year();
            result.debugLog += ' Verify Service: ' + insuranceProvider[0].Verify_Service__c;
            IInsuranceVerificationProvider provider = ProviderFactory(insuranceProvider[0].Verify_Service__c);
            ProviderResult pr = provider.verify(input.memberId, input.firstName, input.lastName, dob, insuranceProvider[0].Payor_Id__c, insuranceProvider[0].Name);
            result.debugLog += ' vobId: ' + pr.vobId;

            sp = Database.setSavepoint();

            if (!pr.success) {
                result.status = 'Failure';
                result.errorMessage = pr.errorMessage;
            } else if (pr.policyActive == false && pr.planName == null) {
                result.status = 'Success';
                result.policyActive = false;
                result.errorMessage = pr.errorMessage;
            } else {
                result.status = 'Success';
                result.policyActive = pr.policyActive;
                result.activeDate = pr.activeDate;
                result.planName = pr.planName;
                result.employer = pr.employer;
                result.policyAddress = pr.subscriberAddress;
                result.policyCity = pr.subscriberCity;
                result.policyState = pr.subscriberState;
                result.policyZip = pr.subscriberZip;
                result.outOfNetwork = pr.outOfNetwork;

                Insurance_Information__c insuranceRecord = buildInsuranceInformation(pr, recordId, insuranceProvider[0]);
                upsert insuranceRecord;

                Insurance_Verification__c verificationRecord = buildInsuranceVerification(pr, recordId, insuranceRecord.Id);
                insert verificationRecord;

                System.Queueable followUpJob = provider.buildFollowUpJob(recordId, pr);
                if (followUpJob != null) {
                    result.debugLog += ' Follow up: true';
                    System.enqueueJob(followUpJob);
                }

                enrichParentRecord(recordId, pr, insuranceProvider[0].Name);
            }
        } catch (VerificationTimeoutException ex) {
            if(sp != null) { Database.rollback(sp); }
            ErrorLogger.ErrorInfo log = new ErrorLogger().logError(ex, 'Insurance Verifiction', recordId);
            result.status = 'Failure';
            result.errorMessage = 'We didn\'t receive a response in time. Please try again shortly. If the problem continues, contact support. Error ID: ' + log.id();
        } catch (Exception ex) {
            if(sp != null) { Database.rollback(sp); }
            ErrorLogger.ErrorInfo log = new ErrorLogger().logError(ex, 'Insurance Verifiction', recordId);
            result.status = 'Failure';
            result.errorMessage = ex.getMessage() + ' ' + Label.Fatal_Error.replaceAll('\\{errorid\\}', log.id());
            if(Test.isRunningTest()) {
                throw ex;
            }
        }
        return result;
    }

    private static Insurance_Information__c buildInsuranceInformation(ProviderResult pr, Id recordId, Account providerAccount) {
        List<Insurance_Information__c> existing = [SELECT Id FROM Insurance_Information__c
                                                   WHERE (Lead__c = : recordId OR Opportunity__c = : recordId) AND
                                                   Insurance_Provider__c = : providerAccount.Id AND Insurance_Policy__c = : pr.insurancePolicy
                                                                                                                          LIMIT 1];
        Insurance_Information__c rec = existing.isEmpty() ? new Insurance_Information__c() : existing[0];
        SObjectType type = recordId.getSObjectType();
        if (type == Lead.SObjectType) {
            rec.Lead__c = recordId;
        } else {
            rec.Opportunity__c = recordId;
        }
        rec.Insurance_Provider__c = providerAccount.Id;
        rec.Insurance_Providers__c = providerAccount.Name;
        rec.Insurance_Provider_Phone_Number__c = providerAccount.Phone;
        rec.Insurance_Policy__c = pr.insurancePolicy;
        rec.Plan_Name__c = pr.planName;
        rec.Employer__c = pr.employer;
        rec.Address__c = pr.subscriberAddress;
        rec.City__c = pr.subscriberCity;
        rec.State__c = mapState(pr.subscriberState);
        rec.Zip_Code__c = pr.subscriberZip;
        return rec;
    }

    private static Insurance_Verification__c buildInsuranceVerification(ProviderResult pr, Id recordId, Id insuranceInfoId) {
        Insurance_Verification__c rec = new Insurance_Verification__c();
        rec.Related_Insurance_Information__c = insuranceInfoId;
        SObjectType type = recordId.getSObjectType();
        if (type == Lead.SObjectType) {
            rec.Lead__c = recordId;
        } else {
            rec.Opportunity__c = recordId;
        }
        rec.Plan_Status__c = pr.planStatus;
        rec.Out_of_Network_Benefits__c = pr.outOfNetworkBenefits;
        rec.Effective_Date__c = pr.effectiveDate;
        rec.DED_INNET__c = pr.dedInn;
        rec.DED_met_INNET__c = pr.dedMetInn;
        rec.OOP_INNET__c = pr.oopInn;
        rec.OOP_met_INNET__c = pr.oopMetInn;
        rec.Copay_Admit_Fee_INNET__c = pr.copayInn;
        rec.Individual_or_Family_INNET__c = pr.indOrFamInn;
        rec.DED_OB__c = pr.dedOon;
        rec.DED_met_OB__c = pr.dedMetOon;
        rec.OOP_OB__c = pr.oopOon;
        rec.OOP_met_OB__c = pr.oopMetOon;
        rec.Copay_Admit_Fee_OB__c = pr.copayOon;
        rec.Individual_or_Family_OB__c = pr.indOrFamOon;
        rec.Substance_Abuse_DED__c = pr.dedOon;
        rec.Substance_Abuse_DED_met__c = pr.dedMetOon;
        rec.Substance_Abuse_OOP__c = pr.oopOon;
        rec.Substance_Abuse_OOP_met__c = pr.oopMetOon;
        rec.Substance_Abuse_Copay_Admit_Fee__c = pr.copayOon;
        rec.Max_Daily_Copay_OON__c = pr.copayOon;
        rec.Detox_Benefits_Covered_INNET__c = pr.covgPercInn;
        rec.Residential_Benefits_Covered_INNET__c = pr.covgPercInn;
        rec.Part_Hospital_Covered_INNET__c = pr.covgPercInn;
        rec.IOP_Covered_INNET__c = pr.covgPercInn;
        rec.Detox_Benefits_Covered__c = pr.covgPercOon;
        rec.Residential_Benefits_Covered__c = pr.covgPercOon;
        rec.Part_Hospital_Covered__c = pr.covgPercOon;
        rec.IOP_Covered__c = pr.covgPercOon;
        rec.Does_the_client_have_an_INN_OOP_Max__c = pr.hasInnOopMax;
        rec.Does_the_client_have_an_OON_OOP_Max__c = pr.hasOonOopMax;
        return rec;
    }

    private static void enrichParentRecord(Id recordId, ProviderResult pr, String providerName) {
        SObjectType type = recordId.getSObjectType();
        if (type == Lead.SObjectType) {
            Boolean updated = false;
            Lead leadRecord = [SELECT Id, Patient_DOB__c, Insurance_Providors__c, Employer__c,
                               Street_Address__c, Address_2__c, City, PostalCode
                               FROM Lead
                               WHERE Id = : recordId];
            if(String.isBlank(leadRecord.Patient_DOB__c)) {
                leadRecord.Patient_DOB__c = pr.patientDob;
                updated = true;
            }
            if(String.isBlank(leadRecord.Insurance_Providors__c)) {
                leadRecord.Insurance_Providors__c = providerName;
                updated = true;
            }
            if(String.isBlank(leadRecord.Employer__c)) {
                leadRecord.Employer__c = pr.employer;
                updated = true;
            } else if(leadRecord.Employer__c == null) {
                leadRecord.Employer__c = 'Marketplace';
                updated = true;
            }
            if(String.isBlank(leadRecord.Street_Address__c)) {
                leadRecord.Street_Address__c = pr.patientAddress1;
                leadRecord.Address_2__c = pr.patientAddress2;
                leadRecord.City__c = pr.patientCity;
                leadRecord.State__c = mapState(pr.patientState);
                leadRecord.Zip_Code__c = pr.patientZip;
                updated = true;
            }
            if(updated) { update leadRecord; }
        } else if(type == Opportunity.SObjectType) {
            Boolean updated = false;
            Opportunity oppRecord = [SELECT Id, Employer__c FROM Opportunity WHERE Id = : recordId];
            if(String.isBlank(oppRecord.Employer__c)) {
                oppRecord.Employer__c = pr.employer;
                updated = true;
            } else if(oppRecord.Employer__c == null) {
                oppRecord.Employer__c = 'Marketplace';
                updated = true;
            }
            if(updated) { update oppRecord; }
        }
    }

    private static Map<String, String> stateAbbreviationMap;

    private static String mapState(String abbreviation) {
        if (String.isBlank(abbreviation)) return abbreviation;
        if (stateAbbreviationMap == null) {
            stateAbbreviationMap = new Map<String, String>();
            for (State_Abbreviation_Mapping__c s : State_Abbreviation_Mapping__c.getAll().values()) {
                if (String.isNotBlank(s.State_Code__c)) {
                    stateAbbreviationMap.put(s.State_Code__c.toUpperCase(), s.Name);
                }
            }
        }
        String mapped = stateAbbreviationMap.get(abbreviation.toUpperCase());
        return mapped != null ? mapped : abbreviation;
    }

    public static Date getDate(String dateOrRange) {
        if (String.isBlank(dateOrRange)) return null;

        String firstDateStr = dateOrRange.split('-')[0].trim();
        List<String> parts = firstDateStr.split('/');
        if (parts.size() != 3) return null;

        Integer month = Integer.valueOf(parts[0]);
        Integer day = Integer.valueOf(parts[1]);
        Integer year = Integer.valueOf(parts[2]);

        return Date.newInstance(year, month, day);
    }

    public class InsuranceWrapper {
        @AuraEnabled public String provider;
        @AuraEnabled public String memberId;
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public Date dob;
        @AuraEnabled public Id leadId;
        @AuraEnabled public InsuranceVerificationResultWrapper verification;
    }

    public class InsuranceVerificationResultWrapper {
        @AuraEnabled public String status;
        @AuraEnabled public Boolean policyActive;
        @AuraEnabled public String activeDate;
        @AuraEnabled public Boolean insuranceAccepted;
        @AuraEnabled public String planName;
        @AuraEnabled public String employer;
        @AuraEnabled public String policyAddress;
        @AuraEnabled public String policyCity;
        @AuraEnabled public String policyState;
        @AuraEnabled public String policyZip;
        @AuraEnabled public DateTime lastVerification;
        @AuraEnabled public Boolean outOfNetwork;
        @AuraEnabled public String errorMessage;
        @AuraEnabled public String debugLog = 'DEBUG';
        @AuraEnabled public Boolean isDebugMode;
    }

    @TestVisible private static IInsuranceVerificationProvider mockProvider;

    public static IInsuranceVerificationProvider ProviderFactory(String providerName) {
        if (mockProvider != null) return mockProvider;
        if (providerName == 'VerifyTX') return new VerifyTXVerificationProvider();
        return new WaystarVerificationProvider();
    }

    public class VerificationException extends Exception {}
    public class VerificationTimeoutException extends Exception {}
}