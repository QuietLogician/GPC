/********************************************************************************************
* NAME         :  CLB_CalloutUtility
* DESCRIPTION	:  Utility Class for Application Callouts.
*
* @AUTHOR Deepak, Uppala Sai
* @DATE 03/10/2020
*
*
* MODIFICATION LOG:
* DEVELOPER                         DATE                               DESCRIPTION
* -----------------------------------------------------------------------------------------                
* Deepak, Uppala Sai       	03/10/2020            				First version created
* Divya JC                  05/05/2020                          Added validateCase method for validating case before callout
* Divya JC 					05/28/2020							Removed Total_No_Of_WO_Created__c>0 condition from validateCase Method
********************************************************************************************/

public class CLB_CalloutUtility {
    public static final String sCaseStatusClosed='Closed';//Constant to check for Case Status 'Closed'
    public static final String sCaseStatusDuplicate='Duplicate';
    public static final String sCaseStatusClosedReferred='Closed Referred';//Constant to check for Case Status 'Closed'
    public static final String sCaseStatusCancelled='Cancelled';
    
    /********************************************************************************************
METHOD NAME    : getHttpResponse
DESCRIPTION    : Generic Method used to make callout. 
RETURN TYPE    : HttpResponse
PARAMETER      : Single Parameter which is of Type Map<String,Object>
1. Key: 'methodType' --> 'GET/POST/PUT/DELETE',
2. Key: 'endPointCallout' --> Either Named Creaditial API Name or EndPoint URL
3. Key: 'Content-Type' --> Type of Content('application/JSON')
4. Key: 'body' --> Body Data.
EXCEPTION E: EXCEPTION RAISED IN THE APPLICATION 
********************************************************************************************/
    
    public static IntegrationWrapper getHttpResponse(Map<String,Object> httpMapFields){
        Httprequest request = new HttpRequest();
        request.setMethod(String.valueOf(httpMapFields.get('methodType')));
        request.setHeader('Content-Type', String.valueOf(httpMapFields.get('contentType')));
        if(httpMapFields.containsKey('authorization')){
            request.setHeader('Authorization', String.valueOf(httpMapFields.get('authorization')));
        }
        if(String.valueOf(httpMapFields.get('methodType')) == 'GET'){
            request.setEndpoint(String.valueOf(httpMapFields.get('endPointCallout')) + String.valueOf(httpMapFields.get('body')));
        }else{
            request.setEndpoint(String.valueOf(httpMapFields.get('endPointCallout')));//'callout:CLB_Callout_Request'
            request.setBody(String.valueOf(httpMapFields.get('body')));
        }
        request.setTimeout(120000);
        Http http = new Http();
        HttpResponse response;
        try{
            response = http.send(request);
            System.debug('::-> response'+response.getStatusCode());
            //System.debug('::-> response'+response.getBody());
            IntegrationWrapper integrationWrapper = new IntegrationWrapper();
            integrationWrapper.response = response;
            integrationWrapper.errorLog = createIntegrationLog(String.valueOf(httpMapFields.get('cName')),String.valueOf(httpMapFields.get('mName')),String.valueOf(request.getEndpoint()),String.valueOf(response.getStatusCode()),JSON.serialize(request.getBody()),JSON.serialize(response.getBody()));
            system.debug(integrationWrapper);
            return integrationWrapper;
        }catch(Exception e){
            System.debug(e.getMessage());
            IntegrationWrapper integrationWrapper = new IntegrationWrapper();
            integrationWrapper.response = null;
            integrationWrapper.errorLog = createIntegrationLog(String.valueOf(httpMapFields.get('cName')),String.valueOf(httpMapFields.get('mName')),String.valueOf(request.getEndpoint()),'',JSON.serialize(request.getBody()),e.getTypeName()+':'+e.getMessage());
            return integrationWrapper;
        }
    }
    
    public class IntegrationWrapper{
        public HttpResponse response;
        public X11_Error_Log__c errorLog;
    }
    
    /********************************************************************************************
METHOD NAME    : createIntegrationLog
DESCRIPTION    : This method create the Generic Log record based on the input parameters
RETURN TYPE    : X11_Error_Log__c
PARAMETER      : String, String, String, String, String, String, String
Author         : Deepak, Uppala Sai
*********************************************************************************************/
    public static X11_Error_Log__c createIntegrationLog(String cName, String mName, String cEndPointURL, String cStatusCode, String cReqJSON, String cRespJSON){
        X11_Error_Log__c integrationLogObj = new X11_Error_Log__c();
        Id devRecordTypeId = Schema.SObjectType.X11_Error_Log__c.getRecordTypeInfosByName().get('Integration Log').getRecordTypeId();
        integrationLogObj.recordTypeID=devRecordTypeId;
        integrationLogObj.X11_ClassName__c = !String.isEmpty(cName) ? cName : '';
        integrationLogObj.X11_MethodName__c = !String.isEmpty(mName) ? mName : '';
        integrationLogObj.End_Point_URL__c = !String.isEmpty(cEndPointURL) ? cEndPointURL.length() > 255 ? cEndPointURL.substring(0, 255) : cEndPointURL : '';
        integrationLogObj.HTTP_Status_Code__c = !String.isEmpty(cStatusCode) ? cStatusCode : '';
        if(!String.isEmpty(cReqJSON)){
            if(cReqJSON.length() > 131070){
                integrationLogObj.RequestJSON__c = cReqJSON.substring(0, 131070); 
            }else{
                integrationLogObj.RequestJSON__c = cReqJSON;
            }
        }
        
        if(!String.isEmpty(cRespJSON)){
            if(cRespJSON.length() > 131070){
                integrationLogObj.ResponseJSON__c = cRespJSON.substring(0, 131070); 
                integrationLogObj.Additional_Information__c = cRespJSON.length() > 262140 ? cRespJSON.substring(131070, 262140) : cRespJSON.substring(131070,cRespJSON.length()) ;
            }else{
                //System.debug(cRespJSON);
                integrationLogObj.ResponseJSON__c = cRespJSON;
            }
        }
        return integrationLogObj;
    }
    /********************************************************************************************
    METHOD NAME    : validateCase
    DESCRIPTION    : This method to validate case for callout
    RETURN TYPE    : Object
    PARAMETER      : Case
    Author         : Divya JC
    *********************************************************************************************/
    public static Object validateCase(Case caseRecord){  
        Result res;
        if(!CLB_UserUtils.isRecordAccessible(UserInfo.getUserId(), caseRecord.id)){
            res = new Result(false,false,false,'Insufficient access rights on record');//User is presented with error message
            return res;
        }
        //If case is closed, system does not trigger creation of record in AppOrder
        if(caseRecord.Status == sCaseStatusClosed || caseRecord.Status == sCaseStatusClosedReferred || caseRecord.Status == sCaseStatusCancelled){
            res = new Result(false,false,false,'The Case has already been Closed');//User is presented with error message
            return res;
        }
        if(caseRecord.Status == sCaseStatusDuplicate){
            res = new Result(false,false,false,'This Case is marked as a Duplicate, please make all updates on the associated Parent case');//User is presented with error message
            return res;
        }
        
        return null;
    }
    public class Result{
        public boolean isSuccess;
        public boolean isRefresh;
        public boolean isConfirmation;
        public String message;
        public Result(boolean isSuccess,boolean isRefresh, boolean isConfirmation, String message){
            this.isSuccess = isSuccess;
            this.isRefresh = isRefresh;
            this.isConfirmation = isConfirmation;
            this.message = message;
        }
    }
}