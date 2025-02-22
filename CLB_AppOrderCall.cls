/********************************************************************************************
* NAME         :  CLB_AppOrderCall
* DESCRIPTION  :  Callout from AppOrder Case to Work Order system
*
* @AUTHOR DIVYA JC
* @DATE 3/18/2020
*
*
* MODIFICATION LOG:
* DEVELOPER                         DATE                               DESCRIPTION
* -----------------------------------------------------------------------------------------                
* DIVYA JC                        3/18/2020                            First version created
* DIVYA JC                        5/21/2020                            Updated External WorkOrder record with GPC record type
* DIVYA JC                        5/26/2020                            Added Issue_Location_Placement__c field in request.
* DIVYA JC                        6/01/2020                            Added GISFailure validation check
* SANDEEP REDDY                   6/10/2020                            Added Total_No_Of_WO_Created__c field in the SOQL
* DIVYA JC					      6/22/2020							   Removed type from response
* DIVYA JC						 11/06/2020							   Surface Types enhancement
********************************************************************************************/
public with sharing class CLB_AppOrderCall {
    public static final String sGPCRecorTypeName='GPC';//Constant to check for Case RecordType 'GPC'
    public static final String sCaseTypeGraffiti='Graffiti';//Constant to check for Case Type 'Graffiti'
    public static CLB_CalloutUtility.Result res;
    /******************************************************************************************** 
* Method Name    : appOrderHttpPost 
* Description    : Post case details to External AppOrder system  
* Return Type    : Object 
* Parameter      : String
********************************************************************************************/
    @AuraEnabled
    public static Object appOrderHttpPost(String sCaseId){
        //Object to store the result
        ReturnCaseResult caseResult;
        try{
            //Fetch case record details where id is sCaseId
            // Case caseRecord=[Select Id,recordtype.DeveloperName,Status,Total_No_Of_WO_Created__c,Type,CompleteAddress__c,Geolocation__c,Description,ContactPhone,ContactEmail,Contact.Name from case where id=:sCaseId];
            String caseSoql = 'Select ';
            for(Schema.FieldSetMember objFieldMember: SObjectType.Case.FieldSets.CLB_Case_FieldSet.getFields()){
                caseSoql += objFieldMember.getFieldPath()+',';
            }
            caseSoql += 'Geolocation__c,Contact.Name,User__r.Name,User__r.Email,User__r.Phone from Case WHERE Id =\''+sCaseId+'\'';
            
            List<Case> lstCase = Database.query(caseSoql);
            if(lstCase.size()>0){
                Case caseRecord = lstCase[0];
                res=(CLB_CalloutUtility.Result)CLB_CalloutUtility.validateCase(caseRecord);
                if(res!=null){
                    caseResult=new ReturnCaseResult(caseRecord,res);
                    return JSON.serialize(caseResult);
                }
                //If Total_No_Of_WO_Created__c>0 system does not trigger creation of record in AppOrder
                List<Case_Work_Order_Junction__c> existingExtWO=new List<Case_Work_Order_Junction__c>();
                if(caseRecord.id!=NULL){
                    existingExtWO= [Select Id from Case_Work_Order_Junction__c where Case__c=:caseRecord.id AND External_Work_Order__r.Ext_Work_Order_Status__c = 'Open'];
                    if(existingExtWO.size()>0){
                        res = new CLB_CalloutUtility.Result(false,false,false,'A work order has already been created for this Case in App Order, you cannot create multiple work orders for same request');//user is presented with error message
                        caseResult=new ReturnCaseResult(caseRecord,res);
                        return JSON.serialize(caseResult);
                    }
                }
                //If Case Type not equal to Graffiti, system does not trigger creation of record in AppOrder
                if(caseRecord.Type != sCaseTypeGraffiti){
                    res = new CLB_CalloutUtility.Result(false,false,false,'The Case Type selected is not eligible to be sent to GPC. Please update the Case Type to an appropriate value and try again');//user is presented with error message
                    caseResult=new ReturnCaseResult(caseRecord,res);
                    return JSON.serialize(caseResult);
                }
                
                Map<String,Object> departmentIdCaseMap=CLB_CaseRoutingHandler.findCaseDepartment(caseRecord);
                if(departmentIdCaseMap.containsKey('Case')){
                    caseRecord=(Case)departmentIdCaseMap.get('Case');
                    if(caseRecord!=NULL){
                        update caseRecord;
                    }
                }
                /*departmentIdCaseMap.remove('Department');
departmentIdCaseMap.put('GISFailure',true);*/
                
                if(departmentIdCaseMap.containsKey('Department')){
                    if((String)departmentIdCaseMap.get('Department')!=caseRecord.Department__c){
                        res = new CLB_CalloutUtility.Result(false,false,true,'This case ideally should be worked upon by a different department. Do you still wish to continue?');//user is presented with error message
                        caseResult=new ReturnCaseResult(caseRecord,res);
                        return JSON.serialize(caseResult);
                    } 
                    res = new CLB_CalloutUtility.Result(true,false,false,'');
                    caseResult=new ReturnCaseResult(caseRecord,res);
                    return JSON.serialize(caseResult);
                }else if(departmentIdCaseMap.containsKey('GISFailure') && departmentIdCaseMap.get('GISFailure')==true){//6/01/2020  
                    res = new CLB_CalloutUtility.Result(false,false,true,'GIS is not working at the moment, please reach out to your system admin in regard to this issue. If desired you can still continue');//user is presented with error message
                    caseResult=new ReturnCaseResult(caseRecord,res);
                    return JSON.serialize(caseResult);
                }else{
                    res = new CLB_CalloutUtility.Result(false,false,false,'Case information is not eligible to be sent to GPC. Please update the location of where the Graffiti is located or update the actual address');//user is presented with error message
                    caseResult=new ReturnCaseResult(caseRecord,res);
                    return JSON.serialize(caseResult);
                }
                
            }
            return NULL;
        }catch(Exception ex){
            system.debug(ex.getLineNumber()+'-------'+ex.getMessage());
            X11_Utility.logError(ex,'CLB_AppOrderCall','appOrderHttpPost');
            res = new CLB_CalloutUtility.Result(false,false,false,'Please try again or contact your System Administrator if the problem persists.');
            caseResult.res=res;
            return JSON.serialize(caseResult);
        }
    }
    /******************************************************************************************** 
* Method Name    : httpCalloutToAppOrder 
* Description    : Post case details to External AppOrder system  
* Return Type    : Object 
* Parameter      : String
********************************************************************************************/
    
    @AuraEnabled
    public static Object httpCalloutToAppOrder(String jsonString){
        try{
            Case caseRecord = (Case)JSON.deserialize(jsonString, Case.class);
            if(caseRecord.id!=NULL){
                //Fetch all the attachments to fetch the image URLs
                //AppOrder Image Issue commented 120 and 125-128: Deepak
				List<Attachment> attachments=[Select Id, ParentId, Name from Attachment Where ParentId=:caseRecord.id];
                String sImageURL ='/servlet/servlet.FileDownload?file=';
                String sFullFileURL = System.Label.Community_URL+sImageURL;
                List<AppOrderImages> lstImages = new List<AppOrderImages>();
                for(Attachment attch:attachments){
                    AppOrderImages objImage = new AppOrderImages(sFullFileURL+attch.id);
                    lstImages.add(objImage);
                }
                Location loc = caseRecord.Geolocation__c;
                String latitude=NULL;
                String longitude=NULL;
                if(loc!=Null){
                    latitude=String.valueOf(loc.getLatitude()); 
                    longitude=String.valueOf(loc.getLongitude());
                }
                String contactName='';
                String contactPhone='';
                String contactEmail='';
                if(caseRecord.ContactId!=NULL){
                    contactName=caseRecord.Contact.Name;
                    contactPhone=caseRecord.ContactPhone;
                    contactEmail=caseRecord.ContactEmail;
                }else if(caseRecord.User__c!=NULL){  //05/28/2020
                    contactName=caseRecord.User__r.Name;
                    contactPhone=caseRecord.User__r.Phone;
                    contactEmail=caseRecord.User__r.Email;
                }
                String sUrgent='false';
                if(caseRecord.Priority=='High'){
                    sUrgent='true';
                }
                String description='';
                if(!String.isBlank(caseRecord.Description)){
                    description=caseRecord.Description;
                }
                
                CaseWrapper caseWrapperRecord=new CaseWrapper(caseRecord.id,caseRecord.CompleteAddress__c,latitude,longitude,description,lstImages,contactName,contactPhone,contactEmail,caseRecord.Issue_Location_Placement__c,caseRecord.CaseNumber,sUrgent); //  5/26/2020
                String sEndPointURL = 'callout:CLB_AppOrder_Callout_Request/rest/workOrder';
                String sRequestJSON=JSON.serialize(caseWrapperRecord);
                Map<String,Object> httpMapFields =new Map<String,Object>();
                httpMapFields.put('cName','CLB_AppOrderCall');
                httpMapFields.put('mName','appOrderHttpPost');
                httpMapFields.put('methodType','POST');
                httpMapFields.put('endPointCallout',sEndPointURL);
                httpMapFields.put('contentType','application/json');
                httpMapFields.put('body',sRequestJSON);
                //HTTP callout to AppOrder
                CLB_CalloutUtility.IntegrationWrapper respWrapper = CLB_CalloutUtility.getHttpResponse(httpMapFields);
                HttpResponse response = respWrapper.response; 
                if(response!=null && response.getStatusCode()==200){
                    OutputWrapper wrapper = (OutputWrapper) JSON.deserializeStrict(response.getBody(), OutputWrapper.class);
                    //Update Case record status to In Progress if the response status is successful
                    caseRecord.Status='In Progress';
                    caseRecord.Integration_Error_Code__c='';
                    caseRecord.Integration_Error_Description__c='';
                    if(caseRecord!=NULL){
                        update caseRecord;
                    }
                    //Insert new External Work Order record if the response status is successful
                    External_Work_Order__c extWO=new External_Work_Order__c();
                    Id devRecordTypeId = Schema.SObjectType.External_Work_Order__c.getRecordTypeInfosByName().get('GPC').getRecordTypeId();// 5/21/2020
                    //extWO.Case__c=caseRecord.id;
                    extWO.Ext_Work_Order_Id__c=wrapper.workOrderId;
                    extWO.Name=wrapper.workOrderId;
                    extWO.Ext_Work_Order_Status__c='Open';  // 5/28/2020
                    extWO.Ext_Work_Order_URL__c=wrapper.link;
                    extWO.RecordTypeId=devRecordTypeId;    // 5/21/2020
                    if(extWO!=NULL){
                        Database.SaveResult workOrderInsertResult = Database.insert(extWO);
                        if(workOrderInsertResult.isSuccess()){
                            Case_Work_Order_Junction__c csWorkOrderJunction = new Case_Work_Order_Junction__c(Case__c = caseRecord.id, External_Work_Order__c = workOrderInsertResult.getId());
                            if(csWorkOrderJunction!=NULL){
                                insert csWorkOrderJunction;
                            }
                        }
                    }
                    //Creating Logs for integration
                    respWrapper.errorLog.Case__c=caseRecord.id;
                    respWrapper.errorLog.Integration_Status__c='Success';
                    if(respWrapper.errorLog!=NULL){
                        insert respWrapper.errorLog;
                    }
                    res = new CLB_CalloutUtility.Result(true,true,false, 'Case has successfully been sent to GPC');
                    
                }else if(response!=null){
                    caseRecord.Integration_Error_Code__c=String.valueOf(response.getStatusCode());
                    caseRecord.Integration_Error_Description__c=response.getStatus();
                    if(caseRecord!=NULL){
                        update caseRecord;
                    }
                    //Creating Logs for integration
                    respWrapper.errorLog.Case__c=caseRecord.id;
                    respWrapper.errorLog.Integration_Status__c='Failure';
                    if(respWrapper.errorLog!=NULL){
                        insert respWrapper.errorLog;
                    }
                    res = new CLB_CalloutUtility.Result(false,false,false, 'The Case could not be sent to GPC. Please try again or contact your System Administrator if the problem persists. Error code '+response.getStatusCode());
                }
                else{
                    caseRecord.Integration_Error_Description__c=respWrapper.errorLog.ResponseJSON__c;
                    if(caseRecord!=NULL){
                        update caseRecord;
                    }
                    //Creating Logs for integration
                    respWrapper.errorLog.Case__c=caseRecord.id;
                    respWrapper.errorLog.Integration_Status__c='Failure';
                    if(respWrapper.errorLog!=NULL){
                        insert respWrapper.errorLog;
                    }
                    res = new CLB_CalloutUtility.Result(false,false,false, 'The Case could not be sent to GPC. Please try again or contact your System Administrator if the problem persists.');
                }
            }
            return JSON.serialize(res);
        }catch(Exception ex){
            system.debug(ex.getLineNumber()+'-------'+ex.getMessage());
            X11_Utility.logError(ex,'CLB_AppOrderCall','httpCalloutToAppOrder');
            res = new CLB_CalloutUtility.Result(false,false,false,'Please try again or contact your System Administrator if the problem persists.');
            return JSON.serialize(res);
        }
        
    } 
    
    /******************************************************************************************** 
* Method Name    : closeCaseStatus 
* Description    : To close the related case when the work orders are closed  
* Return Type    : None 
* Parameter      : List<String>
********************************************************************************************/
    @InvocableMethod
    public static void closeCaseStatus(List<String> workOrderId){
        try{
            if(!workOrderId.isEmpty()){
                //START---Modified by Divya JC on 11/06/2020
                Case_Work_Order_Junction__c objCaseWorkOrder = [Select Case__c,Case__r.contactid,Case__r.Contact.email,Case__r.Surface_Type__c,Case__r.Status,External_Work_Order__r.Ext_Work_Order_Failure_Notes__c from Case_Work_Order_Junction__c WHERE External_Work_Order__c =:workOrderId Limit 1];
                List<Case> csLstUpdate = new List<Case>();
                List<String> surfaceType=new List<String>();
                surfaceType=System.Label.CLB_Surface_Type.split(';');
                if(objCaseWorkOrder.Case__c!=NULL){
                Case cse =new Case(Id = objCaseWorkOrder.Case__c);
                if(!String.isBlank(objCaseWorkOrder.External_Work_Order__r.Ext_Work_Order_Failure_Notes__c)){
                    cse.Surface_Type__c=objCaseWorkOrder.External_Work_Order__r.Ext_Work_Order_Failure_Notes__c;
                }
                if(objCaseWorkOrder.Case__r.Status != 'Closed' && !surfaceType.contains(objCaseWorkOrder.External_Work_Order__r.Ext_Work_Order_Failure_Notes__c)){
                    Date todaysDate = Date.today();
                    cse.Status = 'Closed';
                    cse.Closure_Reason__c = 'Issue closed on '+ todaysDate.month() +'/'+todaysDate.day()+'/'+todaysDate.year();
                }else if(objCaseWorkOrder.Case__r.Status != 'Closed' && surfaceType.contains(objCaseWorkOrder.External_Work_Order__r.Ext_Work_Order_Failure_Notes__c) && objCaseWorkOrder.Case__r.contactid!=NULL){
                    CLB_EmailUtils.sendSingleEmail('CLB_SurfaceCode_Template', objCaseWorkOrder.Case__r.contactid, objCaseWorkOrder.Case__r.Contact.email, 'CLB', objCaseWorkOrder.Case__c, new List<String>()); //Updated by Divya JC - 10/19/2020- Method to Send Email                      
                }
                //END---Modified by Divya JC on 11/06/2020
                update cse;
                }
            }
        }catch(Exception e){
            X11_Utility.logError(e,'CLB_AppOrderCall','closeCaseStatus');
        }
    }
    
    //Inner Wrapper Class to store the iput data to be sent to External AppOrder System
    Class CaseWrapper{
        String id;
        String referenceId;
        String address;
        String latitude;
        String longitude;
        String description;
        List<AppOrderImages> images = new List<AppOrderImages>();
        String name;
        String phone;
        String email;
        String userName;
        String type;
        String urgent;
        String password; 
        String describeLocation; //  5/26/2020
        String cityReferenceNumber; //05/28/2020
        CaseWrapper(String caseID,String address,String latitude,String longitude,String description,List<AppOrderImages> images,String contactName,String contactPhone,String contactEmail,String describeLocation,String cityReferenceNumber,String urgent){   //  5/26/2020, 05/28/2020
            this.id='1';
            userName='{!$Credential.UserName}';
            password='{!$Credential.Password}'; 
            referenceId=caseID;
            //this.type='';
            urgent='false';//    6/22/2020
            this.address=address;
            this.latitude=latitude;
            this.longitude=longitude;
            this.description=description;
            this.images = images;
            this.name=contactName;
            if(!String.isBlank(contactName)){
                if(this.name.length() >125){
                    this.name=this.name.substring(0,125);
                }
            }
            this.phone=contactPhone;
            if(!String.isBlank(contactPhone)){
                if(this.phone.length() >255){
                    this.phone=this.phone.substring(0,255);
                }
            }
            this.email=contactEmail;
            if(!String.isBlank(contactEmail)){
                if(this.email.length() >255){
                    this.email=this.email.substring(0,255);
                }
            }
            this.describeLocation=describeLocation;  //  5/26/2020
            this.cityReferenceNumber=cityReferenceNumber; //05/28/2020
            this.urgent=urgent;//05/28/2020
        }
        
    }
    //Inner Wrapper Class to store the image URLs
    public class AppOrderImages{
        String image;//'https://clbdev-clbprodsite.cs66.force.com/servlet/servlet.FileDownload?file=00P0v000004jtDmEAI';
        AppOrderImages(String image){
            this.image=image;
        }
    }
    //Inner Wrapper Class to fetch the WorkOrderID after successful response from the AppOrder
    public class OutputWrapper {
        public String workOrderId {get; set;}
        public String message {get; set;}
        public String id {get; set;}
        public String link {get; set;}
    }
    public class ReturnCaseResult {
        public CLB_CalloutUtility.Result res {get; set;}
        public Case caseRecord {get; set;}
        ReturnCaseResult(Case caseRecord,CLB_CalloutUtility.Result res){
            this.res=res;
            this.caseRecord=caseRecord;
        }
    }
}