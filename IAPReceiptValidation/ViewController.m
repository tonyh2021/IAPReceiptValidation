//
//  ViewController.m
//  IAPReceiptValidation
//
//  Created by 晓童 韩 on 16/1/27.
//  Copyright © 2016年 晓童 韩. All rights reserved.
//

#import "ViewController.h"



@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)validate:(UIButton *)button {
    // Load the receipt from the app bundle.
    /*
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
    if (!receipt) { 
        //No local receipt -- handle the error.
        NSLog(@"receipt错误！");
        return;
    }
     
    // ... Send the receipt data to your server ...
    
    // Create the JSON object that describes the request
    
    NSDictionary *requestContents = @{
                                      @"receipt-data": [receipt base64EncodedStringWithOptions:0]
                                      };
    */
    //在这里我直接用我们项目中的receipt字符串啦，上面的代码当然就省掉咯
    NSString *receiptDataPath = [[NSBundle mainBundle] pathForResource:@"receipt" ofType:@"data"];
    NSString *receiptStr = [NSString stringWithContentsOfFile:receiptDataPath encoding:NSUTF8StringEncoding error:nil];
    NSDictionary *requestContents = @{
                                      @"receipt-data": receiptStr
                                      };
    NSError *error;
    NSData *requestData = [NSJSONSerialization dataWithJSONObject:requestContents
                                                          options:0
                                                            error:&error];
    
    if (!requestData) { /* ... Handle error ... */
        NSLog(@"requestData错误！");
        return;
    }
    
    NSString *verifyReceiptURL = nil;
#ifdef DEBUG
    verifyReceiptURL = @"https://sandbox.itunes.apple.com/verifyReceipt";
#else
    verifyReceiptURL = @"https://buy.itunes.apple.com/verifyReceipt";
#endif

    
    // Create a POST request with the receipt data.
    NSURL *storeURL = [NSURL URLWithString:verifyReceiptURL];
    NSMutableURLRequest *storeRequest = [NSMutableURLRequest requestWithURL:storeURL];
    [storeRequest setHTTPMethod:@"POST"];
    [storeRequest setHTTPBody:requestData];
    
    // Make a connection to the iTunes Store on a background queue.
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    [NSURLConnection sendAsynchronousRequest:storeRequest queue:queue
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if (connectionError) {
                                   /* ... Handle error ... */
                                   NSLog(@"connectionError:%@", connectionError.localizedDescription);
                               } else {
                                   NSError *error;
                                   NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                                   if (!jsonResponse) { /* ... Handle error ...*/
                                       NSLog(@"jsonResponse错误！");
                                   }
                                   /* ... Send a response back to the device ... */
                                   NSLog(@"%@", jsonResponse);
//                                   NSString *strResponse = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//                                   NSLog(@"%@", strResponse);
                                   if ([[jsonResponse objectForKey:@"status"] intValue] == 0) {
                                       NSLog(@"验证成功！");
                                   }
                               }
                           }];
}

@end
