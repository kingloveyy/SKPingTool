//
//  SKPingServices.m
//  SKPingDemo
//
//  Created by King on 15/5/13.
//  Copyright (c) 2015年 King. All rights reserved.
//

#import "SKPingServices.h"

@implementation SKPingItem

/**
 *  重写description，输出log
 *
 */
- (NSString *)description {
    if (self.status == SKPingStatusDidStart) {
        return [NSString stringWithFormat:@"PING %@ (%@): %ld data bytes",self.originalAddress, self.IPAddress, (long)self.dateBytesLength];
    }
    if (self.status == SKPingStatusDidTimeout) {
        return [NSString stringWithFormat:@"Request timeout for icmp_seq %ld", (long)self.ICMPSequence];
    }
    if (self.status == SKPingStatusDidReceivePacket) {
        return [NSString stringWithFormat:@"%ld bytes from %@: icmp_seq=%ld ttl=%ld time=%.3f ms", (long)self.dateBytesLength, self.IPAddress, (long)self.ICMPSequence, (long)self.timeToLive, self.timeMilliseconds];
    }
    return super.description;
}

+ (NSString *)statisticsWithPingItems:(NSArray *)pingItems {
    
    NSString *address = [pingItems.firstObject originalAddress];
    NSMutableString *description = [NSMutableString stringWithCapacity:50];
    [description appendFormat:@"--- %@ ping statistics ---\n", address];
    __block NSInteger receivedCount = 0;
    [pingItems enumerateObjectsUsingBlock:^(SKPingItem *obj, NSUInteger idx, BOOL *stop) {
        if (obj.status == SKPingStatusDidReceivePacket) {
            receivedCount ++;
        }
    }];
    NSInteger allCount = pingItems.count;
    CGFloat lossPercent = (CGFloat)(allCount - receivedCount) / MAX(1.0, allCount) * 100;
    [description appendFormat:@"%ld packets transmitted, %ld packet received, %.1f%% packet loss\n", (long)allCount, (long)receivedCount, lossPercent];
    return [description stringByReplacingOccurrencesOfString:@".0%" withString:@"%"];
}
@end

@interface SKPingServices () <SimplePingDelegate> {
    BOOL _hasStarted;
    BOOL _isTimeout;
    NSInteger   _repingTimes;
    NSInteger   _icmpSequence;
    NSMutableArray *_pingItems;
}

@property(nonatomic, copy)   NSString   *address;
@property(nonatomic, strong) SimplePing *simplePing;

@property(nonatomic, strong)void(^callbackHandler)(SKPingItem *item, NSArray *pingItems);

@end

@implementation SKPingServices

+ (SKPingServices *)startPingAddress:(NSString *)address
                      callbackHandler:(void(^)(SKPingItem *item, NSArray *pingItems))handler {
    SKPingServices *services = [[SKPingServices alloc] initWithAddress:address];
    services.callbackHandler = handler;
    [services startPing];
    return services;
}

- (instancetype)initWithAddress:(NSString *)address {
    self = [super init];
    if (self) {
        self.timeoutMilliseconds = 500;
        self.address = address;
        self.simplePing = [SimplePing simplePingWithHostName:address];
        self.simplePing.delegate = self;
        self.maximumPingTimes = 100;
        _icmpSequence = 1;
        _pingItems = [NSMutableArray arrayWithCapacity:10];
    }
    return self;
}

- (void)startPing {
    _icmpSequence = 1;
    _repingTimes = 0;
    _hasStarted = NO;
    [_pingItems removeAllObjects];
    [self.simplePing start];
}

- (void)reping {
    [self.simplePing stop];
    [self.simplePing start];
}

- (void)_timeoutActionFired {
    SKPingItem *pingItem = [[SKPingItem alloc] init];
    pingItem.ICMPSequence = _icmpSequence;
    pingItem.originalAddress = self.address;
    pingItem.status = SKPingStatusDidTimeout;
    [self _handlePingItem:pingItem];
}

- (void)_handlePingItem:(SKPingItem *)pingItem {
    if (pingItem.status == SKPingStatusDidReceivePacket || pingItem.status == SKPingStatusDidTimeout) {
        [_pingItems addObject:pingItem];
    }
    if (_repingTimes < self.maximumPingTimes - 1) {
        if (self.callbackHandler) {
            self.callbackHandler(pingItem, [_pingItems copy]);
        }
        _repingTimes ++;
        _icmpSequence ++;
        NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(reping) userInfo:nil repeats:NO];
        [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    } else {
        if (self.callbackHandler) {
            self.callbackHandler(pingItem, [_pingItems copy]);
        }
        [self cancel];
    }
}

- (void)cancel {
    [self.simplePing stop];
    SKPingItem *pingItem = [[SKPingItem alloc] init];
    pingItem.status = SKPingStatusFinished;
    if (self.callbackHandler) {
        self.callbackHandler(pingItem, [_pingItems copy]);
    }
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(_timeoutActionFired) object:nil];
}

- (void)simplePing:(SimplePing *)pinger didStartWithAddress:(NSData *)address {
    [pinger sendPingWithData:nil];
    [self performSelector:@selector(_timeoutActionFired) withObject:nil afterDelay:self.timeoutMilliseconds / 1000.0];
}


- (void)simplePing:(SimplePing *)pinger didSendPacket:(NSData *)packet ICMPHeader:(ICMPHeader *)_ICMPHeader {
    
    SKPingItem *pingItem = [[SKPingItem alloc] init];
    pingItem.IPAddress = pinger.IPAddress;
    pingItem.originalAddress = self.address;
    pingItem.dateBytesLength = packet.length - sizeof(ICMPHeader);
    pingItem.status = SKPingStatusDidStart;
    if (self.callbackHandler && !_hasStarted) {
        self.callbackHandler(pingItem, nil);
        _hasStarted = YES;
    }
}

- (void)simplePing:(SimplePing *)pinger didReceivePingResponsePacket:(NSData *)packet timeElasped:(NSTimeInterval)timeElasped {
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(_timeoutActionFired) object:nil];
    const struct IPHeader * ipPtr = NULL;
    size_t                  ipHeaderLength = 0;
    if (packet.length >= (sizeof(IPHeader) + sizeof(ICMPHeader))) {
        ipPtr = (const IPHeader *) [packet bytes];
        ipHeaderLength = (ipPtr->versionAndHeaderLength & 0x0F) * sizeof(uint32_t);
    }
    NSInteger timeToLive = 0, dataBytesSize = 0;
    if (ipPtr != NULL) {
        dataBytesSize = packet.length - ipHeaderLength;
        timeToLive = ipPtr->timeToLive;
    }
    SKPingItem *pingItem = [[SKPingItem alloc] init];
    pingItem.IPAddress = pinger.IPAddress;
    pingItem.dateBytesLength = dataBytesSize;
    pingItem.timeToLive = timeToLive;
    pingItem.timeMilliseconds = timeElasped * 1000;
    pingItem.ICMPSequence = _icmpSequence;
    pingItem.originalAddress = self.address;
    pingItem.status = SKPingStatusDidReceivePacket;
    [self _handlePingItem:pingItem];
}
@end

