public with sharing class AutofoxIntegration {

    @AuraEnabled
    public static MessageBody checkMissingFields(Id recordId){
        MessageBody retVal = new MessageBody();
        
        if(String.isBlank(recordId)){
            return retVal;
        }

        try {
            Map<String, String> missingFields = new Map<String, String>();
            String email;
            String objectType = recordId.getSObjectType().getDescribe().getName();

            if (objectType == 'Lead') {
                Lead lead = [SELECT Email, FirstName, LastName, Company, Address, Language__c, Country FROM Lead WHERE Id = :recordId]; 
                checkMissingField(lead.Email, 'Email', missingFields);
                checkMissingField(lead.FirstName, 'First Name', missingFields);
                checkMissingField(lead.LastName, 'Last Name', missingFields);
                checkMissingField(lead.Company, 'Company Name', missingFields);
                checkMissingField(formatAddress(lead.Address), 'Address', missingFields);
                checkMissingField(lead.Language__c, 'Language', missingFields);
                checkMissingField(lead.Country, 'Country', missingFields);
                email = lead.Email;
            } else if (objectType == 'Opportunity') {
                Opportunity opp = [SELECT  Account.Name, Account.BillingAddress, Account.BillingCountry, LKP_Contact__r.Language__c, LKP_Contact__r.Email, LKP_Contact__r.FirstName, LKP_Contact__r.LastName FROM Opportunity WHERE Id = :recordId]; //todo: fields
                checkMissingField(opp.LKP_Contact__r.Email, 'Email', missingFields);
                checkMissingField(opp.LKP_Contact__r.FirstName, 'First Name', missingFields);
                checkMissingField(opp.LKP_Contact__r.LastName, 'Last Name', missingFields);
                checkMissingField(opp.Account.Name, 'Company Name', missingFields);
                checkMissingField(formatAddress(opp.Account.BillingAddress), 'Billing Address', missingFields);
                checkMissingField(opp.LKP_Contact__r.Language__c, 'Language', missingFields);
                checkMissingField(opp.Account.BillingCountry, 'Country', missingFields);
                email = opp.LKP_Contact__r.Email;
            }

            if(!missingFields.isEmpty()){
                retVal.message = System.Label.AutofoxIntegration_Warning_MissingFields	+ ': ' + String.join(new List<String>(missingFields.values()), ', ');
                retVal.messageType = 'MissingInformation';
                return retVal;
            }
    
            retVal.message =  System.Label.AutofoxIntegration_Warning_beforeSendingAccessTokenMessage_Part1	+ ' ' + email + ' . ' + System.Label.AutofoxIntegration_Warning_beforeSendingAccessTokenMessage_Part2;
            retVal.messageType = 'ValidationMessage';
            return retVal;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void checkMissingField(String fieldValue, String fieldName, Map<String, String> missingFields) {  
        if (String.isBlank(fieldValue)) {
            missingFields.put(fieldName, fieldName);
        }
    }

    @AuraEnabled
    public static MessageBody generateAccessToken(Id recordId) {
        MessageBody retVal = new MessageBody();

        // Fetch record details
        RecordDetail recordDetail = fetchRecordDetails(recordId);
        
        // Call Autofox endpoint
        HttpResponse response = callCreateUserAPI(recordDetail.requestBody);
        if (response.getStatusCode() == 200) {
            // Parse the response            
            Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            Integer status = (Integer) responseData.get('status');
            Map<String, Object> data = (Map<String, Object>) responseData.get('data');
            String accessToken = (String) data.get('login_token');
            
            // Update record with the access token
            updateRecord(recordDetail.record, accessToken);
            
            // Send email to the customer
            sendEmailToCustomer(recordDetail.requestBody, accessToken, recordId);

            retVal.message = System.Label.AutofoxIntegration_Notify_CodeGenerated;

            retVal.messageType = 'CodeGenerated';
            return retVal;

        } else {
            retVal.message = System.Label.AutofoxIntegration_Notify_CodeCannotGenerated + ': ' + parseResponseToGetErrorMessage(response.getBody());
            retVal.messageType = 'CodeCanNotGenerated';
            return retVal;
        }
    }

    private static RecordDetail fetchRecordDetails(Id recordId) {
        RecordDetail recordDetail = new RecordDetail();

        String objectType = recordId.getSObjectType().getDescribe().getName();
        recordDetail.objectType = objectType;

        RequestBody body = new RequestBody();
        if (objectType == 'Lead') {
            Lead record = [SELECT Email, FirstName, LastName, Company, Address, Language__c, Country FROM Lead WHERE Id = :recordId]; 

            body.email = record.Email;
            body.first_name = record.FirstName;
            body.last_name = record.LastName;
            body.company_name = record.Company;
            body.company_address = formatAddress(record.Address);  
            body.language = record.Language__c;
            body.country_id = UtilityMethod.getCountryCode(record.Country); 

            recordDetail.record = record;
            recordDetail.requestBody = body;

        } else if (objectType == 'Opportunity') {
            Opportunity record = [SELECT  Account.Name, Account.BillingAddress, Account.BillingCountry, LKP_Contact__r.Language__c, LKP_Contact__r.Email, LKP_Contact__r.FirstName, LKP_Contact__r.LastName FROM Opportunity WHERE Id = :recordId]; //todo: fields
            
            body.email = record.LKP_Contact__r.Email;
            body.first_name = record.LKP_Contact__r.FirstName;
            body.last_name = record.LKP_Contact__r.LastName;
            body.company_name = record.Account.Name;
            body.company_address = formatAddress(record.Account.BillingAddress);
            body.language = record.LKP_Contact__r.Language__c;
            body.country_id = UtilityMethod.getCountryCode(record.Account.BillingCountry);

            recordDetail.record = record;
            recordDetail.requestBody = body;
        } else {
            throw new IllegalArgumentException('Unsupported object type');
        }
        return recordDetail;
    }

    private static HttpResponse callCreateUserAPI(RequestBody requestBody) {
        String url = 'https://api.autofox.ai/admin/create-user-pipedrive';
        String token = 'H0PKG4WT9GGRV3';
        String csrfToken = 'Ic03OqHNOJpdWfbDmCGk1CQeNGXQwxq28cXcOvpCQsUTxVV7t5n79Xfomekbohhy';

        String boundary = '---------------------------' + Datetime.now().getTime();
        String body = '';

        Map<String, String> formDataMap = new Map<String, String>{
            'email' => requestBody.email,
            'first_name' => requestBody.first_name,
            'last_name' => requestBody.last_name,
            'company_name' => requestBody.company_name,
            'company_address' => requestBody.company_address,
            'language' => requestBody.language,
            'country_id' => requestBody.country_id
        };

        for (String key : formDataMap.keySet()) {
            String fieldValue = formDataMap.get(key);
            body += '--' + boundary + '\r\n';
            body += 'Content-Disposition: form-data; name="' + key + '"\r\n\r\n';
            body += fieldValue + '\r\n';
        }
        body += '--' + boundary + '--\r\n';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + token);
        req.setHeader('X-CSRFToken', csrfToken);
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setBodyAsBlob(Blob.valueOf(body));
        Http http = new Http();
        HttpResponse response = http.send(req);

        return response;
    }

    private static void sendEmailToCustomer(RequestBody requestBody, String accessToken, ID recordId) {

        EmailTemplate emailTemplate = [SELECT Id, Name, HtmlValue FROM EmailTemplate WHERE DeveloperName = 'Autofox_AccessToken'];

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTemplateId(emailTemplate.Id); 
        String htmlBody = emailTemplate.HtmlValue;
        htmlBody = htmlBody.replace('{!firstName}', requestBody.first_name);
        htmlBody = htmlBody.replace('{!accessToken}', accessToken);
        email.setHtmlBody(htmlBody);
        email.setToAddresses(new String[] {requestBody.email});
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });

      //  createEmailMessageLog(recordId, requestBody.email, 'Autofox access token is sent');
    }

    private static void updateRecord(SObject record, String accessToken) {
        record.put('AutofoxAppToken__c', accessToken);
        update record;
    }

    private static String formatAddress(Address address) {
        String formattedAddress = '';
        if (address != null) {
            if (!String.isBlank(address.street)) formattedAddress += address.street + ', ';
            if (!String.isBlank(address.city)) formattedAddress += address.city + ', ';
            if (!String.isBlank(address.state)) formattedAddress += address.state + ', ';
            if (!String.isBlank(address.postalCode)) formattedAddress += address.postalCode + ', ';
            if (!String.isBlank(address.country)) formattedAddress += address.country;
            // Remove trailing comma and space if present
            formattedAddress = formattedAddress.endsWith(', ') ? formattedAddress.left(formattedAddress.length() - 2) : formattedAddress;
        }
        return formattedAddress;
    }

    public static String parseResponseToGetErrorMessage(String jsonResponse) {
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(jsonResponse);
        Integer status = (Integer) responseMap.get('status');
        if (status == 0) {
            List<Object> errors = (List<Object>) responseMap.get('errors');
            if (!errors.isEmpty()) {
                Map<String, Object> validation = (Map<String, Object>) ((Map<String, Object>) errors[0]).get('validation');
                if (validation != null && validation.containsKey('email')) {
                    List<Object> emailErrors = (List<Object>) validation.get('email');
                    if (!emailErrors.isEmpty()) {
                        String errorMessage = (String) emailErrors[0];
                        return errorMessage;
                    }
                }
            }
        }
        return null;
    }

    private static void createEmailMessageLog(Id recordId, String recipientEmail, String subject) {
        // EmailMessage kaydı oluşturma
        EmailMessage emailMessage = new EmailMessage();
        emailMessage.RelatedToId = recordId; // İlgili kaydın ID'si (Örneğin, Account, Opportunity)
        emailMessage.Subject = subject;
        emailMessage.ToAddress = recipientEmail;
      //  emailMessage.TextBody = body;
        emailMessage.Status = '3'; // 3 = Sent
        emailMessage.FromName = UserInfo.getName();
        emailMessage.FromAddress = UserInfo.getUserEmail();
        
        // EmailMessage kaydını ekleme
        insert emailMessage;
    }

    private class RequestBody {
        public String email { get; set; }
        public String first_name { get; set; }
        public String last_name { get; set; }
        public String company_name { get; set; }
        public String company_address { get; set; }
        public String language { get; set; } //Available values : DE, EN, IT, FR, TR, PT, RO, ES, CA
        public String country_id { get; set; }
    }

    private class RecordDetail {
        public RequestBody requestBody { get; set; }
        public String objectType { get; set; }
        public Sobject record { get; set; }
    }

    public class MessageBody {
        @AuraEnabled
        public String messageType;
        @AuraEnabled
        public String message;
    }
}