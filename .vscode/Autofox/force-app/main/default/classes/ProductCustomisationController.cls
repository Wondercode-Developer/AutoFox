public with sharing class ProductCustomisationController {
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getFilesForAccount(Id quoteLineItemId) {
        // Fetch the Account related to the QuoteLineItem
        Id accountId = [
            SELECT Quote.AccountId FROM QuoteLineItem WHERE Id = :quoteLineItemId LIMIT 1
        ].Quote.AccountId;

        // Fetch ContentDocumentLinks attached to the Account
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId 
            FROM ContentDocumentLink 
            WHERE LinkedEntityId = :accountId
        ];

        if (links.isEmpty()) {
            return new List<Map<String, String>>();
        }

        // Extract ContentDocument IDs from the ContentDocumentLinks
        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            contentDocumentIds.add(link.ContentDocumentId);
        }

        // Fetch ContentDocuments using the extracted IDs
        List<ContentDocument> documents = [
            SELECT Id, Title, LatestPublishedVersionId 
            FROM ContentDocument 
            WHERE Id IN :contentDocumentIds
        ];

        // Prepare the data to return as a list of maps
        List<Map<String, String>> fileData = new List<Map<String, String>>();
        for (ContentDocument doc : documents) {
            Map<String, String> fileMap = new Map<String, String>();
            fileMap.put('Id', doc.Id);
            fileMap.put('Title', doc.Title);
            fileMap.put('ContentDownloadUrl', '/sfc/servlet.shepherd/version/download/' + doc.LatestPublishedVersionId);
            fileData.add(fileMap);
        }
        return fileData;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getLogoPositions() {
        Schema.DescribeFieldResult fieldResult = ProductCustomisation__c.logoPosition__c.getDescribe();
        List<Schema.PicklistEntry> picklistEntries = fieldResult.getPicklistValues();

        List<Map<String, String>> options = new List<Map<String, String>>();
        for (Schema.PicklistEntry entry : picklistEntries) {
            Map<String, String> option = new Map<String, String>();
            option.put('label', entry.getLabel());
            option.put('value', entry.getValue());
            options.add(option);
        }
        return options;
    }
}