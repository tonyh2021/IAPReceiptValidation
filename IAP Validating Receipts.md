##IAP Validating Receipts

###Validating Receipts With the App Store

Apple文档：[https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateRemotely.html#//apple_ref/doc/uid/TP40010573-CH104-SW1](https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ValidateRemotely.html#//apple_ref/doc/uid/TP40010573-CH104-SW1)  
Read the Receipt Data  
>To retrieve the receipt data, use the appStoreReceiptURL method of NSBundle to locate the app’s receipt, and then read the entire file. If the appStoreReceiptURL method is not available, you can fall back to the value of a transaction's transactionReceipt property for backward compatibility. Then send this data to your server—as with all interactions with your server, the details are your responsibility.  
>从Transaction的TransactionReceipt属性中得到接收的数据，并以base64编码。

```
// Load the receipt from the app bundle.
NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
if (!receipt) { /* No local receipt -- handle the error. */ }
 
/* ... Send the receipt data to your server ... */
```

Send the Receipt Data to the App Store
>On your server, create a JSON object with the following keys:  
>创建JSON对象，字典格式，键名为“receiptdata”，值为上一次编码的数据：

```
{
    "receipt-data" : "(The base64 encoded receipt data.)"
    "password" : "(Only used for receipts that contain auto-renewable subscriptions. Your app’s shared secret (a hexadecimal string).)"
}
```
>Submit this JSON object as the payload of an HTTP POST request. In the test environment, use https://sandbox.itunes.apple.com/verifyReceipt as the URL. In production, use https://buy.itunes.apple.com/verifyReceipt as the URL.  
>发送POST请求。

```
NSData *receipt; // Sent to the server by the device
 
// Create the JSON object that describes the request
NSError *error;
NSDictionary *requestContents = @{
    @"receipt-data": [receipt base64EncodedStringWithOptions:0]
};
NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents
                                                      options:0
                                                        error:&error];
 
if (!requestData) { /* ... Handle error ... */ }
 
// Create a POST request with the receipt data.
NSURL *storeURL = [NSURL URLWithString:@"https://buy.itunes.apple.com/verifyReceipt"];
NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
[storeRequest setHTTPMethod:@"POST"];
[storeRequest setHTTPBody:requestData];
 
// Make a connection to the iTunes Store on a background queue.
NSOperationQueue *queue = [[NSOperationQueue alloc] init];
[NSURLConnection sendAsynchronousRequest:storeRequest queue:queue
        completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
    if (connectionError) {
        /* ... Handle error ... */
    } else {
        NSError *error;
        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (!jsonResponse) { /* ... Handle error ...*/ }
        /* ... Send a response back to the device ... */
    }
}];
```

Parse the Response
>The response’s payload is a JSON object that contains the following keys and values:  
>返回值也是一个JSON格式对象，包括两个键值对。如果status的值为0，说明receipt有效，否则就是无效的。  

```
{

    "status" : (0), //Either 0 if the receipt is valid, or one of the error codes listed in Table 2-1.
For iOS 6 style transaction receipts, the status code reflects the status of the specific transaction’s receipt.
For iOS 7 style app receipts, the status code is reflects the status of the app receipt as a whole. For example, if you send a valid app receipt that contains an expired subscription, the response is 0 because the receipt as a whole is valid.

    "receipt" : { (receipt here) }, //A JSON representation of the receipt that was sent for verification. For information about keys found in a receipt, see Receipt Fields.
    
	//其他为iOS6版本的参数：Only returned for iOS 6 style transaction receipts for auto-renewable subscriptions.
}

```

Status Codes and Description：  
>- 21000:The App Store could not read the JSON object you provided.    
>- 21002:The data in the receipt-data property was malformed or missing.  
>- 21003:The receipt could not be authenticated.  
>- 21004:The shared secret you provided does not match the shared secret on file for your account.Only returned for iOS 6 style transaction receipts for auto-renewable subscriptions.  
>- 21005:The receipt server is not currently available.  
>- 21006:This receipt is valid but the subscription has expired. When this status code is returned to your server, the receipt data is also decoded and returned as part of the response.Only returned for iOS 6 style transaction receipts for auto-renewable subscriptions.  
>- 21007:This receipt is from the test environment, but it was sent to the production environment for verification. Send it to the test environment instead.
>- 21008:This receipt is from the production environment, but it was sent to the test environment for verification. Send it to the production environment instead.  

###为了方便java后端的同学，也把java代码贴上

```java
public int verifyReceipt( byte[] receipt) {
	int status = -1;

	//This is the URL of the REST webservice in iTunes App Store
	URL url = new URL("https://buy.itunes.apple.com/verifyReceipt");

	//make connection, use post mode
	HttpsURLConnection connection = (HttpsURLConnection) url.openConnection();
	connection.setRequestMethod("POST");
	connection.setDoOutput(true);
	connection.setAllowUserInteraction(false);

	//Encode the binary receipt data into Base 64
	//Here I'm using org.apache.commons.codec.binary.Base64 as an encoder, since commons-codec is already in Grails classpath
	Base64 encoder = new Base64();
	String encodedReceipt = new String(encoder.encode(receipt));

	//Create a JSON query object
	//Here I'm using Grails' org.codehaus.groovy.grails.web.json.JSONObject
	Map map = new HashMap();
	map.put("receipt-data", encodedReceipt);
	JSONObject jsonObject = new JSONObject(map);

	//Write the JSON query object to the connection output stream
	PrintStream ps = new PrintStream(connection.getOutputStream());
	ps.print(jsonObject.toString());
	ps.close();

	//Call the service
	BufferedReader br = new BufferedReader(new InputStreamReader(connection.getInputStream()));
	//Extract response
	String str;
	StringBuffer sb = new StringBuffer();
	while ((str = br.readLine()) != null) {
		sb.append(str);
		sb.append("/n");
	}
	br.close();
	String response = sb.toString();

	//Deserialize response
	JSONObject result = new JSONObject(response);
	status = result.getInt("status");
	if (status == 0) {
		//provide content
	} else {
		//signal error, throw an exception, do your stuff honey!
	}
	
	return status ;
}
```

###其他对于验证的文章：
[iPhone In App Purchase购买完成时验证transactionReceipt](http://www.cnblogs.com/eagley/archive/2011/06/15/2081577.html)  

[验证用户付费收据！拒绝IAP CRACKER！拒绝IAP FREE！让IPHONE越狱用户无从下手！](http://www.himigame.com/iphone-cocos2d/673.html)  

###PS：
Apple的IAP文档：[https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/StoreKitGuide/Introduction.html](https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/StoreKitGuide/Introduction.html)