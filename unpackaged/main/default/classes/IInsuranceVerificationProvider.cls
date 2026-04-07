public interface IInsuranceVerificationProvider {
    ProviderResult verify(String memberId, String firstName, String lastName, String dob, String payerId, String payerName);
    System.Queueable buildFollowUpJob(Id recordId, ProviderResult pr);
}