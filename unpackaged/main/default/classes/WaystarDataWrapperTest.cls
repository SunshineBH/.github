@isTest
public class WaystarDataWrapperTest {

    @isTest
    static void testToPipeDelimitedString() {
        WaystarDataWrapper wrapper = new WaystarDataWrapper();
        wrapper.inquiringProviderName = 'Dr. Smith';
        wrapper.payerName = 'ABC Health';
        wrapper.subscriberMemberId = '123456';
        wrapper.patientFirstName = 'John';
        wrapper.patientLastName = 'Doe';
        wrapper.patientDOB = '01/01/1990';
        wrapper.patientRelationship = 'Self';
        wrapper.otherProviderName = 'Clinic X';
        wrapper.dateOfServiceOrRange = '04/01/2024';
        wrapper.providerInquiryRef = 'REF123';
        wrapper.payerId = 'PAYER01';
        wrapper.accountBreakoutValue = 'AB123';
        wrapper.inquiringProviderFirstName = 'Jane';
        wrapper.inquiringProviderMiddleName = 'A';
        wrapper.inquiringProviderTaxId = '999999999';
        wrapper.inquiringProviderPayerNumber = 'PAY123';

        String pipeString = wrapper.toPipeDelimitedString();
        System.assertNotEquals(null, pipeString);
        System.assert (pipeString.contains('Dr. Smith|ABC Health|123456|John|Doe|01/01/1990'));
    }

}