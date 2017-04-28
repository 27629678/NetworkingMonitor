//
//  NEURLConnectionProxy.m
//  Demo
//
//  Created by sddz_yuxiaohua on 2017/4/26.
//  Copyright © 2017年 XY Co., Ltd. All rights reserved.
//

#import "NEURLConnectionProxy.h"

static NSUInteger allInputOutputNetworkTrafficAmount = 0;

@interface NEURLConnectionClient : NSObject <NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLRequest *request;

@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, assign) NSUInteger sendDataLength;
@property (nonatomic, assign) NSUInteger receiveDataLength;
@property (nonatomic, strong) NSError *error;

/// default unit is Kb
+ (NSString *)networkTrafficAmount;

@end

@implementation NEURLConnectionClient

+ (NSString *)networkTrafficAmount
{
    // GB
    CGFloat ONE_GB = 1024 * 1024 * 1024 * 1.0f;
    if (allInputOutputNetworkTrafficAmount > ONE_GB) {
        return [NSString stringWithFormat:@"%.2f TB(s).",
                (allInputOutputNetworkTrafficAmount / ONE_GB)];
    }
    
    // MB
    CGFloat ONE_MB = 1024 * 1024 * 1.0f;
    if (allInputOutputNetworkTrafficAmount > (1024 * 1024)) {
        return [NSString stringWithFormat:@"%.2f MB(s).",
                (allInputOutputNetworkTrafficAmount / ONE_MB)];
    }
    
    // KB
    CGFloat ONE_KB = 1024 * 1.0f;
    if (allInputOutputNetworkTrafficAmount > ONE_KB) {
        return [NSString stringWithFormat:@"%.2f KB(s).",
                (allInputOutputNetworkTrafficAmount / ONE_KB)];
    }
    
    return [NSString stringWithFormat:@"%@ byte(s).", @(allInputOutputNetworkTrafficAmount)];
}

- (nullable NSURLRequest *)connection:(NSURLConnection *)connection
                      willSendRequest:(NSURLRequest *)request
                     redirectResponse:(nullable NSURLResponse *)response;
{
    self.request = request;
    self.duration = [NSDate timeIntervalSinceReferenceDate];
    NSData *header = [NSJSONSerialization dataWithJSONObject:request.allHTTPHeaderFields options:0 error:nil];
    self.sendDataLength += header.length;
    
    if (request.HTTPBody) {
        self.sendDataLength += request.HTTPBody.length;
    }
    
    return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.receiveDataLength += response.description.length;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    self.receiveDataLength += data.length;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.error = error;
}

- (void)connection:(NSURLConnection *)connection
   didSendBodyData:(NSInteger)bytesWritten
 totalBytesWritten:(NSInteger)totalBytesWritten
totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    self.sendDataLength += bytesWritten;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    self.duration = [NSDate timeIntervalSinceReferenceDate] - self.duration;
    
    NSLog(@"Monitor Message: {"
          @"\n\tInstance: %p"
          @"\n\tUrl:%@"
          @"\n\tSend Data: %@ bytes"
          @"\n\tReceive Data: %@ bytes"
          @"\n\tError:%@"
          @"\n\tDuration: %@ }",
          self,
          self.request.URL,
          @(self.sendDataLength),
          @(self.receiveDataLength),
          self.error,
          [self durationRepresentaion]);
    NSLog(@"All Traffic Amount: %@", [NEURLConnectionClient networkTrafficAmount]);
    NSCAssert(!self.error, @"");
    
    allInputOutputNetworkTrafficAmount += (self.sendDataLength + self.receiveDataLength);
}

#pragma mark - private

- (NSString *)durationRepresentaion
{
    if (self.duration > 1) {
        return [NSString stringWithFormat:@"%.3f S", self.duration];
    }
    
    return [NSString stringWithFormat:@"%.3f MS", self.duration * 1000];
}

@end    // NEURLConnectionClient

@interface NEURLConnectionProxy () <NSURLConnectionDelegate, NSURLConnectionDataDelegate, NSURLConnectionDownloadDelegate>

@property (nonatomic, weak) id delegate;

@property (nonatomic, strong) NEURLConnectionClient *client;

@end

@implementation NEURLConnectionProxy

- (void)proxyUsingDelegate:(id)delegate
{
    self.delegate = delegate;
    
    self.client = [NEURLConnectionClient new];
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    return [self.delegate respondsToSelector:aSelector] || [self.client respondsToSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    if ([self.client respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:self.client];
    }
    
    if ([self.delegate respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:self.delegate];
    }
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
    if ([self.delegate respondsToSelector:sel]) {
        return [self.delegate methodSignatureForSelector:sel];
    }
    
    return [NSMethodSignature signatureWithObjCTypes:"@^v^c"];
}

@end    // NEURLConnectionProxy
