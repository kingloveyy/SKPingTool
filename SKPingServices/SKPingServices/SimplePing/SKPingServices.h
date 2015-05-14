//
//  SKPingServices.h
//  SKPingDemo
//
//  Created by King on 15/5/13.
//  Copyright (c) 2015年 King. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "SimplePing.h"

typedef NS_ENUM(NSInteger, SKPingStatus) {
    SKPingStatusDidStart,
    SKPingStatusDidReceivePacket,
    SKPingStatusDidTimeout,
    SKPingStatusFinished,
};

@interface SKPingItem : NSObject

@property(nonatomic) NSString *originalAddress;
@property(nonatomic, copy) NSString *IPAddress;

@property(nonatomic) NSUInteger dateBytesLength;
@property(nonatomic) double     timeMilliseconds;
@property(nonatomic) NSInteger  timeToLive;
@property(nonatomic) NSInteger  ICMPSequence;

@property(nonatomic) SKPingStatus status;

+ (NSString *)statisticsWithPingItems:(NSArray *)pingItems;

@end

@interface SKPingServices : NSObject

@property(nonatomic) double timeoutMilliseconds;

+ (SKPingServices *)startPingAddress:(NSString *)address
                      callbackHandler:(void(^)(SKPingItem *pingItem, NSArray *pingItems))handler;

@property(nonatomic) NSInteger  maximumPingTimes;
- (void)cancel;

@end