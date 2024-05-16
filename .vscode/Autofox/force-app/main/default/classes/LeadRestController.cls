/**
 * LeadRestController:
 * This RESTful web service provides endpoints to interact with Lead records in Salesforce.
 * It supports retrieving Lead records by Id, creating new Lead records, and updating existing Lead records.
 * Additionally, it includes custom deserialization logic to handle Date and DateTime fields during data input.
 */

@RestResource(urlMapping='/Lead/*')
global with sharing class LeadRestController {

    /**
     * LeadDeserializer:
     * This inner class handles the deserialization of JSON input for Lead records.
     * It dynamically converts string representations of Date and DateTime fields into their respective Salesforce data types.
     */
    public class LeadDeserializer {

        /**
         * deserialize:
         * This method deserializes the input JSON string to a Map<String, Object> representing Lead data.
         * It dynamically converts string representations of Date and DateTime fields to Date or DateTime objects.
         */
        public Lead deserialize(String input) {
            // Deserialize the JSON string to a Map<String, Object>
            Map<String, Object> leadMap = (Map<String, Object>) JSON.deserializeUntyped(input);

            // Dynamically query all Date and DateTime fields in the Lead object
            List<String> dateFields = new List<String>();
            Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
            for (String fieldName : leadFields.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = leadFields.get(fieldName).getDescribe();
                if (fieldDescribe.getType() == Schema.DisplayType.Date || fieldDescribe.getType() == Schema.DisplayType.DateTime) {
                    dateFields.add(fieldName);
                }
            }

            // Convert Date and DateTime strings to DateTime objects
            for (String field : dateFields) {
                if (leadMap.containsKey(field) && leadMap.get(field) instanceof String) {
                    // Check if the field is of type Date or DateTime
                    if (leadFields.get(field).getDescribe().getType() == Schema.DisplayType.Date) {
                        leadMap.put(field, Date.valueOf((String) leadMap.get(field)));
                    } else if (leadFields.get(field).getDescribe().getType() == Schema.DisplayType.DateTime) {
                        leadMap.put(field, DateTime.valueOf((String) leadMap.get(field)));
                    }
                }
            }

            // Deserialize the Map to a Lead object
            return (Lead) JSON.deserialize(JSON.serialize(leadMap), Lead.class);
        }
    }

    // GET request to retrieve a Lead record by Id
    @HttpGet
    global static Lead getLeadById() {
        RestRequest request = RestContext.request;
        String leadId = request.requestURI.substring(request.requestURI.lastIndexOf('/') + 1);
        
        // Get the field set name from the URL
        String fieldSetName = request.params.get('fieldSet');

        
        // Retrieve the Lead with specified fields
        List<String> selectedFields = new List<String>();
        if (fieldSetName != null && Schema.SObjectType.Lead.FieldSets.getMap().containsKey(fieldSetName)) {
        	for(Schema.FieldSetMember fsm : Schema.SObjectType.Lead.FieldSets.getMap().get(fieldSetName).getFields()) {
                selectedFields.add(fsm.getFieldPath());
            }
        } else {
            // If field set is not specified or not found, retrieve default fields
            selectedFields.add('Id');
            selectedFields.add('FirstName');
            selectedFields.add('LastName');
            selectedFields.add('Email');
        }
        
        // Construct dynamic SOQL query
        String query = 'SELECT ' + String.join(selectedFields, ',') + ' FROM Lead WHERE Id = :leadId';
        
        // Execute query
        List<Lead> leads = Database.query(query);
        
       	// Return the first Lead (if found)
        if (!leads.isEmpty()) {
            return leads[0];
        } else {
        // If Lead with specified Id is not found, return null
        	return null;
        }
    }
    // POST request to create a new Lead
    @HttpPost
    global static String createLead(String leadJson) {
        // Deserialize the JSON input using the LeadDeserializer
        Lead newLead = new LeadDeserializer().deserialize(leadJson);

        // Attempt to insert the Lead
        Database.SaveResult saveResult = Database.insert(newLead, false);

        // Check if the Lead was inserted successfully
        if (saveResult.isSuccess()) {
            return 'Lead created successfully with Id: ' + saveResult.getId();
        } else {
            // Check if the error is due to a duplicate rule violation
            for (Database.Error error : saveResult.getErrors()) {
                if (error.getStatusCode() == StatusCode.DUPLICATE_VALUE) {
                    // If a duplicate rule violation occurred, return the error message
                    return error.getMessage();
                }
            }
            // If it's another type of error, return a generic error message
            return 'Error creating Lead: ' + saveResult.getErrors()[0].getMessage();
        }
    }

    // PUT request to update an existing Lead
    @HttpPut
    global static String updateLead(String leadJson) {
        Lead leadToUpdate;
        
         try {
            // Deserialize JSON string to Lead object
            LeadDeserializer deserializer = new LeadDeserializer();
            Map<String, Object> leadMap = (Map<String, Object>) JSON.deserializeUntyped(leadJson);
            leadToUpdate = (Lead) deserializer.deserialize(JSON.serialize(leadMap));
    
            // Check if Lead Id is present
            if (String.isBlank(leadToUpdate.Id)) {
                return 'Lead Id is required for update.';
            }
    
             List<Lead> existingLeads = [SELECT Id FROM Lead WHERE Id = :leadToUpdate.Id LIMIT 1];

			if (!existingLeads.isEmpty()) {                
                // Update the Lead record directly with the values from leadMap
                update leadToUpdate;
                return 'Lead updated successfully';
            } else {
                return 'Lead with Id ' + leadToUpdate.Id + ' not found.';
            }
        } catch(Exception ex) {
            return 'Error updating Lead: ' + ex.getMessage();
        }
    }
}