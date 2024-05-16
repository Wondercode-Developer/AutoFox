@isTest
private class LeadRestControllerTest {

    @isTest
    static void testGetLeadById() {
        // Create a test Lead
        Lead testLead = new Lead(FirstName = 'Test', LastName = 'Lead', Company = 'Test Company', Email = 'test@example.com');
        insert testLead;
    
        // Set up RestContext.request with required parameters
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/Lead/' + testLead.Id;
        request.addParameter('fieldSet', 'getLeadsDefault'); // Adding the field set parameter
        RestContext.request = request;
    
        // Call the GET endpoint
        Lead result = LeadRestController.getLeadById();
    
        // Verify the result
        System.assertEquals(testLead.Id, result.Id);
        System.assertEquals(testLead.Company, result.Company);
        System.assertEquals(testLead.Email, result.Email);
    }
    
    @isTest
    static void testGetLeadByIdWithoutFieldset() {
        // Create a test Lead
        Lead testLead = new Lead(FirstName = 'Test', LastName = 'Lead', Company = 'Test Company', Email = 'test@example.com');
        insert testLead;
    
        // Set up RestContext.request with required parameters
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/Lead/' + testLead.Id;
        RestContext.request = request;
    
        // Call the GET endpoint
        Lead result = LeadRestController.getLeadById();
    
        // Verify the result
        System.assertEquals(testLead.Id, result.Id);
        System.assertEquals(testLead.Email, result.Email);
    }
    
    @isTest
    static void testGetLeadByIdNegative() {
        // Create a test Lead
        Lead testLead = new Lead(FirstName = 'Test', LastName = 'Lead', Company = 'Test Company', Email = 'test@example.com');
        insert testLead;
    
        // Set up RestContext.request with required parameters
        RestRequest request = new RestRequest();
        request.requestUri = '/services/apexrest/Lead/' +'testLead.Id' ;
        RestContext.request = request;
    
        // Call the GET endpoint
        Lead result = LeadRestController.getLeadById();
    
        // Verify the result
        System.assertEquals(null, result);
    }

    @isTest
    static void testCreateLead() {
        // Prepare JSON payload for creating a new Lead
        String leadJson = '{"FirstName": "Test", "LastName": "Lead", "Company": "Test Company", "Email": "test@example.com"}';

        // Call the POST endpoint
        RestRequest postRequest = new RestRequest();
        postRequest.requestBody = Blob.valueOf(leadJson);
        RestContext.request = postRequest;

        Test.startTest();
        String result = LeadRestController.createLead(leadJson);
        Test.stopTest();

        // Verify the result
        System.assert(result.contains('Lead created successfully'));

        // Verify the Lead creation
        Lead insertedLead = [SELECT Id, FirstName, LastName, Company, Email FROM Lead WHERE Email = 'test@example.com'];
        System.assertEquals('Test', insertedLead.FirstName);
        System.assertEquals('Lead', insertedLead.LastName);
        System.assertEquals('Test Company', insertedLead.Company);
    }

    @isTest
    static void testUpdateLeadPositive() {
        // Create a test Lead
        Lead testLead = new Lead(FirstName = 'Test', LastName = 'Lead', Company = 'Test Company', Email = 'test@example.com');
        insert testLead;

        // Prepare JSON payload for updating the Lead
        String leadJson = '{"Id": "' + testLead.Id + '", "FirstName": "Updated Test", "LastName": "Updated Lead", "Company": "Updated Company"}';

        // Call the PUT endpoint
        RestRequest putRequest = new RestRequest();
        putRequest.requestBody = Blob.valueOf(leadJson);
        RestContext.request = putRequest;

        Test.startTest();
        String result = LeadRestController.updateLead(leadJson);
        Test.stopTest();

        // Verify the result
        System.assert(result.contains('Lead updated successfully'));

        // Verify the Lead update
        Lead updatedLead = [SELECT Id, FirstName, LastName, Company FROM Lead WHERE Id = :testLead.Id];
        System.assertEquals('Updated Test', updatedLead.FirstName);
        System.assertEquals('Updated Lead', updatedLead.LastName);
        System.assertEquals('Updated Company', updatedLead.Company);
    }
    
     @isTest
    static void testUpdateLeadNegativeWithoutId () {
        // Create a test Lead
        Lead testLead = new Lead(FirstName = 'Test', LastName = 'Lead', Company = 'Test Company', Email = 'test@example.com');
        insert testLead;

        // Prepare JSON payload for updating the Lead
        String leadJson = '{"FirstName": "Updated Test", "LastName": "Updated Lead", "Company": "Updated Company"}';

        // Call the PUT endpoint
        RestRequest putRequest = new RestRequest();
        putRequest.requestBody = Blob.valueOf(leadJson);
        RestContext.request = putRequest;

        Test.startTest();
        String result = LeadRestController.updateLead(leadJson);
        Test.stopTest();

        // Verify the result
        System.assert(result.contains('Lead Id is required for update.'));
    }
    @isTest
    static void testUpdateLeadNegativeWithWrongId () {
        // Create a test Lead
        Lead testLead = new Lead(FirstName = 'Test', LastName = 'Lead', Company = 'Test Company', Email = 'test@example.com');
        insert testLead;

        // Prepare JSON payload for updating the Lead
        String leadJson = '{"Id": "testLead.Id","FirstName": "Updated Test", "LastName": "Updated Lead", "Company": "Updated Company"}';

        // Call the PUT endpoint
        RestRequest putRequest = new RestRequest();
        putRequest.requestBody = Blob.valueOf(leadJson);
        RestContext.request = putRequest;

        Test.startTest();
        String result = LeadRestController.updateLead(leadJson);
        Test.stopTest();

        // Verify the result
        System.assert(result.contains('not found.'));
    }
    
    @isTest
    static void testUpdateLeadNegativeException () {
        // Create a test Lead
        Lead testLead = new Lead(FirstName = 'Test', LastName = 'Lead', Company = 'Test Company', Email = 'test@example.com');
        insert testLead;

        // Prepare JSON payload for updating the Lead
        String leadJson = '{"Id": "' + testLead.Id + '","FirstName": "Updated Test", "LastName": "Updated Lead", "Company": ""}';

        // Call the PUT endpoint
        RestRequest putRequest = new RestRequest();
        putRequest.requestBody = Blob.valueOf(leadJson);
        RestContext.request = putRequest;

        Test.startTest();
        String result = LeadRestController.updateLead(leadJson);
        Test.stopTest();

        // Verify the result
        System.assert(result.contains('Error'));
    }
    
    @isTest
    static void testLeadDeserialization() {
        // Prepare JSON payload for Lead
        String leadJson = '{"FirstName": "Test", "LastName": "Lead", "Company": "Test Company", "Email": "test@example.com", "TestPeriodEndDate__c": "2024-05-21"}';
    
        // Deserialize JSON string to Lead object
        Lead testLead = (Lead) JSON.deserialize(leadJson, Lead.class);
    
        // Verify the deserialized Lead object
        System.assertEquals('Test', testLead.FirstName);
        System.assertEquals('Lead', testLead.LastName);
        System.assertEquals('Test Company', testLead.Company);
        System.assertEquals('test@example.com', testLead.Email);
        System.assertEquals(Date.valueOf('2024-05-21'), testLead.TestPeriodEndDate__c, 'TestPeriodEndDate__c should match');
    }

    /* @isTest
   	static void testDuplicateLead() {
        // Create a test Lead
        Lead testLead = new Lead(FirstName = 'Test', LastName = 'Lead', Company = 'Test Company', Email = 'test@example.com');
        insert testLead;

        // Prepare JSON payload for creating a duplicate Lead
        String duplicateLeadJson = '{"FirstName": "Test", "LastName": "Lead", "Company": "Test Company", "Email": "test@example.com"}';

        // Call the POST endpoint to create a duplicate Lead
        RestRequest postRequest = new RestRequest();
        postRequest.requestBody = Blob.valueOf(duplicateLeadJson);
        RestContext.request = postRequest;

        Test.startTest();
        String result = LeadRestController.createLead(duplicateLeadJson);
        Test.stopTest();

        // Verify the result
        System.assert(result.contains('Error creating Lead'));
        System.assert(result.contains('duplicate value found'));

        // Verify no duplicate Lead is created
        List<Lead> leads = [SELECT Id FROM Lead WHERE Email = 'test@example.com'];
        System.assertEquals(1, leads.size());
    }*/
}