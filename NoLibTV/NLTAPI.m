//
//  NLTAPI.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 19/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "NLTAPI.h"
#import "NLTOAuth.h"

@interface NLTAPICallInfo : NSObject
@property (retain,nonatomic) NSString* urlPart;
@property (retain,nonatomic) NSURLConnection* connection;
@property (retain,nonatomic) NSMutableData* data;
@property (retain,nonatomic) NSDate* cacheValidityEndDate;
@property (copy,nonatomic) NLTCallResponseBlock responseBlock;
@property (assign,nonatomic) id key;
@end

@implementation NLTAPICallInfo
@end

@interface NLTAPI ()
@property (retain,nonatomic)NSMutableArray* calls;
@property (retain,nonatomic)NSMutableDictionary* cachedResults;
@end


@implementation NLTAPI

+ (instancetype)sharedInstance{
    static NLTAPI* _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(!_sharedInstance){
            _sharedInstance = [[self alloc] init];
        }
    });
    return _sharedInstance;
}

- (instancetype)init{
    if(self = [super init]){
        self.calls = [NSMutableArray array];
        self.cachedResults = [NSMutableDictionary dictionary];
        [self loadCache];
    }
    return self;
}

- (void)callAPI:(NSString*)urlPart withResultBlock:(NLTCallResponseBlock)block{
    [self callAPI:urlPart withResultBlock:block withKey:nil withCacheDuration:0];
}


- (void)callAPI:(NSString*)urlPart withResultBlock:(NLTCallResponseBlock)block withKey:(id)key{
    [self callAPI:urlPart withResultBlock:block withKey:key withCacheDuration:0];
}

- (void)callAPI:(NSString*)urlPart withResultBlock:(NLTCallResponseBlock)block withKey:(id)key withCacheDuration:(double)cacheDurationSeconds{
    if([self.cachedResults objectForKey:urlPart]){
        NSDate* cacheValidityEndDate = [[self.cachedResults objectForKey:urlPart] objectForKey:@"cacheValidityEndDate"];
        if([[NSDate date] compare:cacheValidityEndDate]==NSOrderedAscending){
            //Result is cached and still valid
            id answer = [[self.cachedResults objectForKey:urlPart] objectForKey:@"answer"];
            if(block){
                block(answer,nil);
            }
            return;
        }
    }
    [[NLTOAuth sharedInstance] authenticate:^(NSError *error) {
        if(error){
            if(block){
                block(nil,error);
            }
        }else{
            NSString* urlStr = urlPart;
            if([urlPart rangeOfString:NOCO_ENDPOINT].location == NSNotFound){

                if(urlPart.length > 1 && [[urlPart substringToIndex:1] compare:@"/"] != NSOrderedSame){
                    urlStr = [NSString stringWithFormat:@"%@/%@",NOCO_ENDPOINT,urlPart];
                }else{
                    urlStr = [NSString stringWithFormat:@"%@%@",NOCO_ENDPOINT,urlPart];
                }
            }
            NSURLRequest* request = [[NLTOAuth sharedInstance] requestWithAccessTokenForURL:[NSURL URLWithString:urlStr]];
            NSURLConnection* connection = [NSURLConnection connectionWithRequest:request delegate:self];
            if(connection){
                NLTAPICallInfo* callInfo = [[NLTAPICallInfo alloc] init];
                callInfo.urlPart = urlPart;
                callInfo.responseBlock = block;
                callInfo.key = key;
                callInfo.connection = connection;
                if(cacheDurationSeconds>0){
                    callInfo.cacheValidityEndDate = [[NSDate date] dateByAddingTimeInterval:cacheDurationSeconds];
                }
                [self.calls addObject:callInfo];
                [connection start];
            }else{
                NSError* error = [NSError errorWithDomain:@"NLTAPIDomain" code:500 userInfo:@{@"message":@"Unable to create connection"}];
                if(block){
                    block(nil,error);
                }
            }
        }
    }];
}

- (NLTAPICallInfo*)callInfoForConnection:(NSURLConnection*)connection {
    for (NLTAPICallInfo* info in self.calls) {
        if(info.connection == connection){
            return info;
        }
    }
    return nil;
}

- (void)cancelCallsWithKey:(id)key{
    for (NLTAPICallInfo* info in self.calls) {
        if(info.key == key){
            [info.connection cancel];
        }
    }
}

- (void)cancelAllCAlls{
    for (NLTAPICallInfo* info in self.calls) {
        [info.connection cancel];
    }
}

- (void)invalidateCache:(NSString*)urlPart{
    [self.cachedResults removeObjectForKey:urlPart];
    [self saveCache];
}

#pragma mark cache

- (void)loadCache{
    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
    NSData* cacheData = [settings objectForKey:@"NLTAPI_cachedResults"];
    NSDictionary* cache = [NSKeyedUnarchiver unarchiveObjectWithData:cacheData];

    if(cache){
        self.cachedResults = [NSMutableDictionary dictionaryWithDictionary:cache];
    }
}

- (void) saveCache{
    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
    NSData* cacheData = [NSKeyedArchiver archivedDataWithRootObject:self.cachedResults];
    [settings setObject:cacheData forKey:@"NLTAPI_cachedResults"];
    [settings synchronize];
}

#pragma mark NSURLConnectionDataDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    NLTAPICallInfo* info = [self callInfoForConnection:connection];
    info.data = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    NLTAPICallInfo* info = [self callInfoForConnection:connection];
    [info.data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection{
    NLTAPICallInfo* info = [self callInfoForConnection:connection];
    NSError* jsonError = nil;
    NSDictionary* answer = nil;
    if(info.data){
        answer = [NSJSONSerialization JSONObjectWithData:info.data options:NSJSONReadingAllowFragments error:&jsonError];
    }
    if(!jsonError&&answer){
        if(info.cacheValidityEndDate){
            [self.cachedResults setObject:@{@"answer":answer,@"cacheValidityEndDate":info.cacheValidityEndDate} forKey:info.urlPart];
            [self saveCache];
        }
        if(info.responseBlock){
            info.responseBlock(answer,nil);
        }
    }else{
        if(info.responseBlock){
            if(jsonError){
                info.responseBlock(nil, jsonError);
            }else{
                info.responseBlock(nil, [NSError errorWithDomain:@"NLTAPIDomain" code:500 userInfo:@{@"message":@"Unable to parse answer"}]);
            }
        }
    }
    [self.calls removeObject:info];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    NLTAPICallInfo* info = [self callInfoForConnection:connection];
    if(info.responseBlock){
        info.responseBlock(nil, error);
    }
    [self.calls removeObject:info];
}


@end
