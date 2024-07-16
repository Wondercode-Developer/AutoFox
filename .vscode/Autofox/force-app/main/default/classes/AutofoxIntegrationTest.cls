@isTest
private class AutofoxIntegrationTest {
    
    @testSetup
    static void setupTestData() {
        // Prepare test data for Lead
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Email = 'test@example.com',
            Company = 'Test Company',
            Language__c = 'EN',
            Country = 'US'
        );
        insert testLead;

        // Prepare test data for Opportunity
        Account testAccount = new Account(
            Name = 'Test Account',
            BillingStreet = '456 Test St',
            BillingCity = 'Test City',
            BillingState = 'Test State',
            BillingPostalCode = '54321',
            BillingCountry = 'Test Country'
        );
        insert testAccount;

        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'test@example.com',
            Language__c = 'EN',
            AccountId = testAccount.Id
        );
        insert testContact;

        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            LKP_Contact__c = testContact.Id,
            CloseDate = System.today(),
            StageName = 'Closed Won'
        );
        insert testOpportunity;
    }

    @isTest
    static void testGenerateAccessTokenWithLead() {
        // Fetch the test lead
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];

        // Set up mock HTTP response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Call the method under test
        Test.startTest();
        AutofoxIntegration.MessageBody result = AutofoxIntegration.generateAccessToken(testLead.Id);
        Test.stopTest();

        // Verify the result
        System.assertEquals('CodeGenerated', result.messageType);

        // Verify that the lead was updated with the access token
        testLead = [SELECT AutofoxAppToken__c FROM Lead WHERE Id = :testLead.Id];
        System.assertNotEquals(null, testLead.AutofoxAppToken__c);
    }

    @isTest
    static void testGenerateAccessTokenWithOpportunity() {
        // Fetch the test opportunity
        Opportunity testOpportunity = [SELECT Id FROM Opportunity LIMIT 1];

        // Set up mock HTTP response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Call the method under test
        Test.startTest();
        AutofoxIntegration.MessageBody result = AutofoxIntegration.generateAccessToken(testOpportunity.Id);
        Test.stopTest();

        // Verify the result
        System.assertEquals('CodeGenerated', result.messageType);

        // Verify that the opportunity was updated with the access token
        testOpportunity = [SELECT AutofoxAppToken__c FROM Opportunity WHERE Id = :testOpportunity.Id];
        System.assertNotEquals(null, testOpportunity.AutofoxAppToken__c);
    }

    @isTest
    static void testCheckMissingFieldsWithLead() {
        // Fetch the test lead
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];

        // Call the method under test
        Test.startTest();
        AutofoxIntegration.MessageBody result = AutofoxIntegration.checkMissingFields(testLead.Id);
        Test.stopTest();

        // Verify the result
        System.assert(result.messageType == 'ValidationMessage' || result.messageType == 'MissingInformation', 'Message type should be either ValidationMessage or MissingInformation');
    }

    @isTest
    static void testCheckMissingFieldsWithOpportunity() {
        // Fetch the test opportunity
        Opportunity testOpportunity = [SELECT Id FROM Opportunity LIMIT 1];

        // Call the method under test
        Test.startTest();
        AutofoxIntegration.MessageBody result = AutofoxIntegration.checkMissingFields(testOpportunity.Id);
        Test.stopTest();

        // Verify the result
        System.assert(result.messageType == 'ValidationMessage' || result.messageType == 'MissingInformation', 'Message type should be either ValidationMessage or MissingInformation');
    }

    // Mock HTTP response generator
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            // Create a mock HTTP response
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"status": 1, "data": {"id": 14944, "login_token": "5MUIHQJJD0V3NB"}}');
            return res;
        }
    }
}