public class WaystarDataWrapper {
    // Required Fields
    public String inquiringProviderName;           // Field 1
    public String payerName;                       // Field 2
    public String subscriberMemberId;              // Field 3
    public String patientFirstName;                // Field 4
    public String patientLastName;                 // Field 5
    public String patientDOB;                      // Field 6 (MM/DD/YYYY)

    // Optional Fields
    public String patientRelationship;             // Field 7
    public String otherProviderName;               // Field 8
    public String dateOfServiceOrRange;            // Field 9
    public String serviceType = '30';              // Field 10 (default to "30")
    public String providerInquiryRef;              // Field 11
    public String payerId;                         // Field 12
    public String accountBreakoutValue;            // Field 13
    public String fileFormatVersion = '1';         // Field 14 (default to version 1)
    public String inquiringProviderEntityId = '1P';     // Field 15 (default to "1P")
    public String inquiringProviderFirstName;      // Field 16
    public String inquiringProviderMiddleName;     // Field 17
    public String inquiringProviderTaxId;          // Field 18
    public String inquiringProviderPayerNumber;     // Field 19
    public String inquiringProviderNPI = 'HPI-1609352186';            // Field 20 (e.g., HPI-1609352186, NPI for Mountain Springs Recovery)

    // Pipe-delimited export for Data param
    public String toPipeDelimitedString() {
        List<String> values = new List<String> {
            inquiringProviderName,
            payerName,
            subscriberMemberId,
            patientFirstName,
            patientLastName,
            patientDOB,
            patientRelationship,
            otherProviderName,
            dateOfServiceOrRange,
            serviceType,
            providerInquiryRef,
            payerId,
            accountBreakoutValue,
            fileFormatVersion,
            inquiringProviderEntityId,
            inquiringProviderFirstName,
            inquiringProviderMiddleName,
            inquiringProviderTaxId,
            inquiringProviderPayerNumber,
            inquiringProviderNPI
        };

        // Ensure nulls become empty strings to preserve field positions
        for (Integer i = 0; i < values.size(); i++) {
            if (values[i] == null) {
                values[i] = '';
            }
            // values[i] = EncodingUtil.urlEncode( values[i], 'UTF-8');
        }
        return String.join(values, '|');
    }

}