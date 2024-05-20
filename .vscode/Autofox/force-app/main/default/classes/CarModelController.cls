/**
 * CarModelController:
 * 
 */
public with sharing class CarModelController {
    
    /**
     * @description Retrieves a list of car model records from the CarModel__c object.
     * @return List<CarModel__c> A list of CarModel__c records including Id, Order__c, Image_URL__c, View__c, Automatic_Processing__c, and Manual_Processing__c fields.
     * @throws Any exception encountered during the query execution will be propagated to the caller.
     */
    @AuraEnabled(cacheable=true)
    public static List<CarModelWrapper> getCarModelRecords() {
        List<CarModelWrapper> carModelWrappers = new List<CarModelWrapper>();

        // Query CarModel records
        List<CarModel__c> carModels = [
            SELECT Id, Name__c, Name 
            FROM CarModel__c
        ];

        // Collect CarModel Ids for the second query
        Set<Id> carModelIds = new Set<Id>();
        for (CarModel__c carModel : carModels) {
            carModelIds.add(carModel.Id);
        }

        // Query the latest ContentDocumentLink for each CarModel
        Map<Id, ContentDocumentLink> latestFilesMap = new Map<Id, ContentDocumentLink>();
        for (ContentDocumentLink link : [
                SELECT ContentDocumentId, LinkedEntityId 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId IN :carModelIds 
                ORDER BY ContentDocument.CreatedDate DESC
        ]) {
            // Only store the first occurrence, which is the latest due to ORDER BY
            if (!latestFilesMap.containsKey(link.LinkedEntityId)) {
                latestFilesMap.put(link.LinkedEntityId, link);
            }
        }

        // Create wrapper instances
        for (CarModel__c carModel : carModels) {
            String ansichtenUrl = '';
            if (latestFilesMap.containsKey(carModel.Id)) {
                ansichtenUrl = '/sfc/servlet.shepherd/document/download/' + latestFilesMap.get(carModel.Id).ContentDocumentId;
            }

            CarModelWrapper wrapper = new CarModelWrapper(
                carModel.Id,
                carModel.Name,
                null,
                false,
                false,
                ansichtenUrl
            );

            carModelWrappers.add(wrapper);
        }

        return carModelWrappers;
    }

    public class CarModelWrapper {
        @AuraEnabled
        public Id carModelId { get; set; }
        @AuraEnabled
        public String name { get; set; }
        @AuraEnabled
        public Integer order { get; set; }
        @AuraEnabled
        public Boolean automaticProcessing { get; set; }
        @AuraEnabled
        public Boolean manualProcessing { get; set; }
        @AuraEnabled
        public String ansichtenUrl { get; set; }
    
        public CarModelWrapper(Id carModelId, String name, Integer order, Boolean automaticProcessing, Boolean manualProcessing, String ansichtenUrl) {
            this.carModelId = carModelId;
            this.name = name;
            this.order = order;
            this.automaticProcessing = automaticProcessing;
            this.manualProcessing = manualProcessing;
            this.ansichtenUrl = ansichtenUrl;
        }
    }
}