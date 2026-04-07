@isTest
public class InsuranceVerificationTest {
    @isTest
    static void testGetRecordWithExistingData() {
        Account provider = new Account(Name = 'Test Insurance', Payor_Id__c = 'PAYID123', Type = 'Insurance Provider');
        insert provider;

        Lead testLead = new Lead(FirstName = 'Alice', LastName = 'Smith', Company = 'Test Co', Patient_DOB__c = '01/01/1990');
        insert testLead;

        Insurance_Information__c insuranceInfo = new Insurance_Information__c(
            Lead__c = testLead.Id,
            Insurance_Provider__c = provider.Id,
            Insurance_Policy__c = 'POL123',
            Plan_Name__c = 'Platinum Plus',
            Employer__c = 'ACME Inc',
            Address__c = '123 Main St',
            City__c = 'Austin',
            State__c = 'Texas',
            Zip_Code__c = '73301'
            );
        insert insuranceInfo;

        Insurance_Verification__c verification = new Insurance_Verification__c(
            Related_Insurance_Information__c = insuranceInfo.Id,
            Lead__c = testLead.Id,
            Plan_Status__c = 'Active',
            Out_of_Network_Benefits__c = 'Yes',
            Effective_Date__c = Date.newInstance(2024, 1, 15)
            );
        insert verification;

        Test.startTest();
        InsuranceVerification.InsuranceWrapper result = InsuranceVerification.getRecord(testLead.Id);
        Test.stopTest();

        Assert.areEqual(testLead.Id, result.leadId);
        Assert.areEqual('Alice', result.firstName);
        Assert.areEqual('Smith', result.lastName);
        Assert.areNotEqual(null, result.verification);
        Assert.areEqual('Success', result.verification.status);
        Assert.areEqual(true, result.verification.policyActive);
        Assert.areEqual('Platinum Plus', result.verification.planName);
        Assert.areEqual('ACME Inc', result.verification.employer);
        Assert.areEqual('123 Main St', result.verification.policyAddress);
        Assert.areEqual('Austin', result.verification.policyCity);
        Assert.areEqual('Texas', result.verification.policyState);
        Assert.areEqual('73301', result.verification.policyZip);
        Assert.areEqual(true, result.verification.outOfNetwork);
        Assert.areEqual('1/15/2024', result.verification.activeDate);
    }

    @isTest
    static void testGetRecordWithOppData() {
        Account provider = new Account(Name = 'Test Insurance', Payor_Id__c = 'PAYID123', Type = 'Insurance Provider');
        insert provider;

        Opportunity testOpp = new Opportunity(
            Patient_First_Name__c = 'Alice',
            Patient_Last_Name__c = 'Smith',
            CloseDate = Date.today(),
            Name = 'Alice Smith',
            StageName = 'In Process',
            Client_DOB__c = '01/01/1990'
            );
        insert testOpp;

        Insurance_Information__c insuranceInfo = new Insurance_Information__c(
            Opportunity__c = testOpp.Id,
            Insurance_Provider__c = provider.Id,
            Insurance_Policy__c = 'POL123',
            Plan_Name__c = 'Platinum Plus',
            Employer__c = 'ACME Inc',
            Address__c = '123 Main St',
            City__c = 'Austin',
            State__c = 'Texas',
            Zip_Code__c = '73301'
            );
        insert insuranceInfo;

        Insurance_Verification__c verification = new Insurance_Verification__c(
            Related_Insurance_Information__c = insuranceInfo.Id,
            Opportunity__c = testOpp.Id,
            Plan_Status__c = 'Active',
            Out_of_Network_Benefits__c = 'Yes',
            Effective_Date__c = Date.newInstance(2024, 1, 15)
            );
        insert verification;

        Test.startTest();
        InsuranceVerification.InsuranceWrapper result = InsuranceVerification.getRecord(testOpp.Id);
        Test.stopTest();

        Assert.areEqual(testOpp.Id, result.leadId);
        Assert.areEqual('Alice', result.firstName);
        Assert.areEqual('Smith', result.lastName);
        Assert.areNotEqual(null, result.verification);
        Assert.areEqual('Success', result.verification.status);
        Assert.areEqual(true, result.verification.policyActive);
        Assert.areEqual('Platinum Plus', result.verification.planName);
        Assert.areEqual('ACME Inc', result.verification.employer);
        Assert.areEqual('123 Main St', result.verification.policyAddress);
        Assert.areEqual('Austin', result.verification.policyCity);
        Assert.areEqual('Texas', result.verification.policyState);
        Assert.areEqual('73301', result.verification.policyZip);
        Assert.areEqual(true, result.verification.outOfNetwork);
        Assert.areEqual('1/15/2024', result.verification.activeDate);
    }

    @isTest
    static void testGetRecordMissingId() {
        InsuranceVerification.InsuranceWrapper result = InsuranceVerification.getRecord(null);
        Assert.isTrue(result.verification.errorMessage.contains('Missing Record Id System Error. Please submit a support ticket with details.'));
    }

    @isTest
    static void testVerifyInsurance_Success() {
        Account payer = new Account(Name = 'Test Payer', Payor_Id__c = '12345', Type = 'Insurance Provider');
        insert payer;

        Lead testLead = new Lead(FirstName = 'Test', LastName = 'Patient', Company = 'TestCo');
        insert testLead;

        ProviderResult mockResult = new ProviderResult();
        mockResult.success = true;
        mockResult.policyActive = true;
        mockResult.planName = '30';
        mockResult.employer = 'TechCorp';
        mockResult.planStatus = 'Active';
        mockResult.outOfNetwork = true;
        mockResult.outOfNetworkBenefits = 'Yes';
        mockResult.subscriberAddress = '456 Elm St';
        mockResult.subscriberCity = 'Springfield';
        mockResult.subscriberState = 'Illinois';
        mockResult.subscriberZip = '62704';
        mockResult.insurancePolicy = '123456';
        InsuranceVerification.mockProvider = new MockProvider(mockResult);

        InsuranceVerification.InsuranceWrapper wrapper = new InsuranceVerification.InsuranceWrapper();
        wrapper.provider = payer.Id;
        wrapper.memberId = '123456';
        wrapper.firstName = 'John';
        wrapper.lastName = 'Doe';
        wrapper.dob = Date.newInstance(1980, 1, 1);
        wrapper.leadId = testLead.Id;

        Test.startTest();
        InsuranceVerification.InsuranceVerificationResultWrapper result = InsuranceVerification.verifyInsurance(testLead.Id, JSON.serialize(wrapper));
        Test.stopTest();

        Assert.areEqual('Success', result.status);
        Assert.isTrue(result.policyActive, 'Expected policy to be active');
        Assert.areEqual('30', result.planName);
        Assert.areEqual('TechCorp', result.employer);
        Assert.areEqual('456 Elm St', result.policyAddress);
        Assert.areEqual(true, result.outOfNetwork);
    }

    @isTest
    static void testVerifyInsurance_Failcode() {
        Account payer = new Account(Name = 'Test Payer', Payor_Id__c = '12345', Type = 'Insurance Provider');
        insert payer;

        Lead testLead = new Lead(FirstName = 'Test', LastName = 'Patient', Company = 'TestCo');
        insert testLead;

        ProviderResult mockResult = new ProviderResult();
        mockResult.success = false;
        mockResult.errorMessage = 'System error. Please contact support.';
        InsuranceVerification.mockProvider = new MockProvider(mockResult);

        InsuranceVerification.InsuranceWrapper wrapper = new InsuranceVerification.InsuranceWrapper();
        wrapper.provider = payer.Id;
        wrapper.memberId = '123456';
        wrapper.firstName = 'John';
        wrapper.lastName = 'Doe';
        wrapper.dob = Date.newInstance(1980, 1, 1);
        wrapper.leadId = testLead.Id;

        Test.startTest();
        InsuranceVerification.InsuranceVerificationResultWrapper result = InsuranceVerification.verifyInsurance(testLead.Id, JSON.serialize(wrapper));
        Test.stopTest();

        Assert.areEqual('Failure', result.status);
    }

    @isTest
    static void InactiveTest() {
        Lead testLead = new Lead(LastName = 'Smith', Company = 'Test Co');
        insert testLead;

        Account payer = new Account(Name = 'Test Payer', Payor_Id__c = '12345', Type = 'Insurance Provider');
        insert payer;

        ProviderResult mockResult = new ProviderResult();
        mockResult.success = true;
        mockResult.policyActive = false;
        mockResult.planName = 'BLUE CHOICE PREFERRED';
        mockResult.planStatus = 'Inactive';
        mockResult.outOfNetworkBenefits = 'No';
        mockResult.insurancePolicy = '123456';
        InsuranceVerification.mockProvider = new MockProvider(mockResult);

        InsuranceVerification.InsuranceWrapper wrapper = new InsuranceVerification.InsuranceWrapper();
        wrapper.provider = payer.Id;
        wrapper.memberId = '123456';
        wrapper.firstName = 'John';
        wrapper.lastName = 'Doe';
        wrapper.dob = Date.newInstance(1980, 1, 1);
        wrapper.leadId = testLead.Id;

        Test.startTest();
        InsuranceVerification.InsuranceVerificationResultWrapper result = InsuranceVerification.verifyInsurance(testLead.Id, JSON.serialize(wrapper));
        Test.stopTest();

        Assert.areEqual('Success', result.status);
        Assert.areEqual(false, result.policyActive);
    }

    @isTest
    static void OONTest() {
        Lead testLead = new Lead(LastName = 'Smith', Company = 'Test Co');
        insert testLead;

        Account payer = new Account(Name = 'Test Payer', Payor_Id__c = '12345', Type = 'Insurance Provider');
        insert payer;

        ProviderResult mockResult = new ProviderResult();
        mockResult.success = true;
        mockResult.policyActive = true;
        mockResult.planName = 'Anon Inc';
        mockResult.planStatus = 'Active';
        mockResult.outOfNetwork = true;
        mockResult.outOfNetworkBenefits = 'Yes';
        mockResult.insurancePolicy = '123456';
        InsuranceVerification.mockProvider = new MockProvider(mockResult);

        InsuranceVerification.InsuranceWrapper wrapper = new InsuranceVerification.InsuranceWrapper();
        wrapper.provider = payer.Id;
        wrapper.memberId = '123456';
        wrapper.firstName = 'John';
        wrapper.lastName = 'Doe';
        wrapper.dob = Date.newInstance(1980, 1, 1);
        wrapper.leadId = testLead.Id;

        Test.startTest();
        InsuranceVerification.InsuranceVerificationResultWrapper result = InsuranceVerification.verifyInsurance(testLead.Id, JSON.serialize(wrapper));
        Test.stopTest();

        Assert.areEqual('Success', result.status);
        Assert.areEqual(true, result.outOfNetwork);
    }

    @isTest
    static void MultplePlansTest() {
        Lead testLead = new Lead(LastName = 'Smith', Company = 'Test Co');
        insert testLead;

        Account payer = new Account(Name = 'Test Payer', Payor_Id__c = '12345', Type = 'Insurance Provider');
        insert payer;

        ProviderResult mockResult = new ProviderResult();
        mockResult.success = true;
        mockResult.policyActive = true;
        mockResult.planName = 'SILVER 94 TRIO HMO JAN25';
        mockResult.planStatus = 'Active';
        mockResult.outOfNetwork = false;
        mockResult.outOfNetworkBenefits = 'No';
        mockResult.insurancePolicy = '123456';
        InsuranceVerification.mockProvider = new MockProvider(mockResult);

        InsuranceVerification.InsuranceWrapper wrapper = new InsuranceVerification.InsuranceWrapper();
        wrapper.provider = payer.Id;
        wrapper.memberId = '123456';
        wrapper.firstName = 'John';
        wrapper.lastName = 'Doe';
        wrapper.dob = Date.newInstance(1980, 1, 1);
        wrapper.leadId = testLead.Id;

        Test.startTest();
        InsuranceVerification.InsuranceVerificationResultWrapper result = InsuranceVerification.verifyInsurance(testLead.Id, JSON.serialize(wrapper));
        Test.stopTest();

        Assert.areEqual('Success', result.status);
        Assert.areEqual(true, result.policyActive);
    }

    @isTest
    static void testVerifyInsurance_NullRecordId() {
        InsuranceVerification.InsuranceWrapper wrapper = new InsuranceVerification.InsuranceWrapper();
        wrapper.provider = null;
        wrapper.memberId = '123456';
        wrapper.firstName = 'John';
        wrapper.lastName = 'Doe';
        wrapper.dob = Date.newInstance(1980, 1, 1);

        Test.startTest();
        Exception caught;
        try {
            InsuranceVerification.verifyInsurance(null, JSON.serialize(wrapper));
        } catch (InsuranceVerification.VerificationException ex) {
            caught = ex;
        }
        Test.stopTest();

        Assert.isNotNull(caught);
        Assert.isTrue(caught.getMessage().contains('Missing Record Id'));
    }

    @isTest
    static void testVerifyInsurance_MissingPayorId() {
        Account payer = new Account(Name = 'Test Payer', Type = 'Insurance Provider');
        insert payer;

        Lead testLead = new Lead(FirstName = 'Test', LastName = 'Patient', Company = 'TestCo');
        insert testLead;

        InsuranceVerification.InsuranceWrapper wrapper = new InsuranceVerification.InsuranceWrapper();
        wrapper.provider = payer.Id;
        wrapper.memberId = '123456';
        wrapper.firstName = 'John';
        wrapper.lastName = 'Doe';
        wrapper.dob = Date.newInstance(1980, 1, 1);

        Test.startTest();
        Exception caught;
        try {
            InsuranceVerification.verifyInsurance(testLead.Id, JSON.serialize(wrapper));
        } catch (InsuranceVerification.VerificationException ex) {
            caught = ex;
        }
        Test.stopTest();

        Assert.isNotNull(caught);
        Assert.isTrue(caught.getMessage().contains('Payor ID is missing'));
    }

    @isTest
    static void testVerifyInsurance_OpportunityPath() {
        Account payer = new Account(Name = 'Test Payer', Payor_Id__c = '12345', Type = 'Insurance Provider');
        insert payer;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp', StageName = 'Prospecting', CloseDate = Date.today(),
            Patient_First_Name__c = 'John', Patient_Last_Name__c = 'Doe'
        );
        insert opp;

        ProviderResult mockResult = new ProviderResult();
        mockResult.success = true;
        mockResult.policyActive = true;
        mockResult.planName = 'Gold Plan';
        mockResult.planStatus = 'Active';
        mockResult.outOfNetworkBenefits = 'No';
        mockResult.insurancePolicy = '123456';
        mockResult.employer = 'Acme';
        InsuranceVerification.mockProvider = new MockProvider(mockResult);

        InsuranceVerification.InsuranceWrapper wrapper = new InsuranceVerification.InsuranceWrapper();
        wrapper.provider = payer.Id;
        wrapper.memberId = '123456';
        wrapper.firstName = 'John';
        wrapper.lastName = 'Doe';
        wrapper.dob = Date.newInstance(1980, 1, 1);

        Test.startTest();
        InsuranceVerification.InsuranceVerificationResultWrapper result = InsuranceVerification.verifyInsurance(opp.Id, JSON.serialize(wrapper));
        Test.stopTest();

        Assert.areEqual('Success', result.status);
        Assert.areEqual(true, result.policyActive);

        List<Insurance_Information__c> infos = [SELECT Id FROM Insurance_Information__c WHERE Opportunity__c = :opp.Id];
        Assert.areEqual(1, infos.size());
    }

    @isTest
    static void testGetDate_RangeFormat() {
        Date result = InsuranceVerification.getDate('01/15/1990-12/31/1990');
        Assert.areEqual(Date.newInstance(1990, 1, 15), result);
    }

    @isTest
    static void testGetDate_BlankReturnsNull() {
        Assert.isNull(InsuranceVerification.getDate(null));
        Assert.isNull(InsuranceVerification.getDate(''));
    }

    class MockProvider implements IInsuranceVerificationProvider {
        private ProviderResult fixedResult;

        public MockProvider(ProviderResult result) {
            this.fixedResult = result;
        }

        public ProviderResult verify(String memberId, String firstName, String lastName, String dob, String payerId, String payerName) {
            return fixedResult;
        }

        public System.Queueable buildFollowUpJob(Id recordId, ProviderResult pr) {
            return null;
        }
    }
}