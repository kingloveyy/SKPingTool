//
//  ViewController.m
//  SKPingServices
//
//  Created by King on 15/5/14.
//  Copyright (c) 2015年 King. All rights reserved.
//

#import "ViewController.h"
#import "SKPingServices.h"

@interface ViewController ()
@property (nonatomic, strong) SKPingServices *pingServices;
- (IBAction)cancel:(id)sender;
@property (weak, nonatomic) IBOutlet UITextField *hostField;

@end

@implementation ViewController

- (SKPingServices *)pingServices
{
    if (!_pingServices) {
        _pingServices = [[SKPingServices alloc] init];
        _pingServices.maximumPingTimes = 10;
    }
    return _pingServices;
}

- (IBAction)ping:(UIButton *)button {
    
    [button setTitle:@"Stop" forState:UIControlStateNormal];
    self.pingServices = [SKPingServices startPingAddress:self.hostField.text callbackHandler:^(SKPingItem *pingItem, NSArray *pingItems) {
        if (pingItem.status != SKPingStatusFinished) {
            NSLog(@"%@",pingItem.description);
        } else {
            NSLog(@"%@",[SKPingItem statisticsWithPingItems:pingItems]);
            [button setTitle:@"Ping" forState:UIControlStateNormal];
            
            self.pingServices = nil;
        }
    }];
}

- (IBAction)cancel:(id)sender {
    [self.pingServices cancel];
}

@end
