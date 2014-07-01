//
//  NLTAPI.m
//  NoLibTV
//
//  Created by Sébastien POIVRE on 19/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "NLTAPI.h"
#import "NLTShow.h"

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
        self.showsById = [NSMutableDictionary dictionary];
        self.familiesById = [NSMutableDictionary dictionary];
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
    [self callAPI:urlPart withResultBlock:block withKey:key withCacheDuration:cacheDurationSeconds withMethod:nil withBody:nil withContentType:nil];
}

- (void)callAPI:(NSString*)urlPart withResultBlock:(NLTCallResponseBlock)block withKey:(id)key withCacheDuration:(double)cacheDurationSeconds withMethod:(NSString*)method withBody:(NSData*)body withContentType:(NSString*)contentType{
    if([self.cachedResults objectForKey:urlPart]&&!method&&!body){
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
            NLTAPICallInfo* callInfo = [[NLTAPICallInfo alloc] init];
            callInfo.urlPart = urlPart;
            callInfo.responseBlock = block;
            callInfo.key = key;
            if(cacheDurationSeconds>0&&!method&&!body){
                callInfo.cacheValidityEndDate = [[NSDate date] dateByAddingTimeInterval:cacheDurationSeconds];
            }
            if([[self callInfoWithSameUrlPart:callInfo] count]>0){
                //If a call for the same urlpart is pending, postpone the call (to mutualize calls)
                [self.calls addObject:callInfo];
                return;
            }
            NSString* urlStr = urlPart;
            if([urlPart rangeOfString:NOCO_ENDPOINT].location == NSNotFound){

                if(urlPart.length > 1 && [[urlPart substringToIndex:1] compare:@"/"] != NSOrderedSame){
                    urlStr = [NSString stringWithFormat:@"%@/%@",NOCO_ENDPOINT,urlPart];
                }else{
                    urlStr = [NSString stringWithFormat:@"%@%@",NOCO_ENDPOINT,urlPart];
                }
            }
            NSMutableURLRequest* request = [[NLTOAuth sharedInstance] requestWithAccessTokenForURL:[NSURL URLWithString:urlStr]];
            if(method){
                [request setHTTPMethod:method];
            }
            if(body){
                [request setHTTPBody:body];
            }
            if(contentType){
                //Bug fix: http://iphonedevelopment.blogspot.fr/2008/06/http-put-and-nsmutableurlrequest.html?m=1
                [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
                //[request setValue:contentType forHTTPHeaderField:@"Content-Type"];
                [request setValue:contentType forHTTPHeaderField:@"Accept"];

            }
            NSURLConnection* connection = [NSURLConnection connectionWithRequest:request delegate:self];
#ifdef DEBUG_NLT_CALL
            NSLog(@"Call to %@",urlStr);
#endif
            if(connection){
                callInfo.connection = connection;
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

- (NSArray*)callInfoWithSameUrlPart:(NLTAPICallInfo*)referenceInfo{
    NSMutableArray* callInfos = [NSMutableArray array];
    for (NLTAPICallInfo* info in self.calls) {
        if(info.urlPart && [info.urlPart compare:referenceInfo.urlPart] == NSOrderedSame && info != referenceInfo){
            [callInfos addObject:info];
        }
    }
    return callInfos;
}

- (void)removeCallInfoWithSameUrlPart:(NLTAPICallInfo*)referenceInfo{
    NSMutableArray* callInfos = [NSMutableArray array];
    for (NLTAPICallInfo* info in self.calls) {
        if(info.urlPart && [info.urlPart compare:referenceInfo.urlPart] == NSOrderedSame && info != referenceInfo){
            [callInfos addObject:info];
        }
    }
    [self.calls removeObjectsInArray:callInfos];
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

- (void)cancelAllCalls{
    for (NLTAPICallInfo* info in self.calls) {
        [info.connection cancel];
    }
}

- (void)invalidateCache:(NSString*)urlPart{
    [self.cachedResults removeObjectForKey:urlPart];
    [self saveCache];
}

- (void)invalidateCacheWithPrefix:(NSString*)prefix{
    NSMutableArray* keyToRemove = [NSMutableArray array];
    for (NSString* urlPart in [self.cachedResults allKeys]) {
        if([urlPart hasPrefix:prefix]){
            [keyToRemove addObject:urlPart];
        }
    }
    [self.cachedResults removeObjectsForKeys:keyToRemove];
    [self saveCache];
}

- (void)invalidateAllCache{
    [self.cachedResults removeAllObjects];
    [self saveCache];
}

#pragma mark cache

- (void)loadCache{
    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
    NSData* cacheData = [settings objectForKey:@"NLTAPI_cachedResults"];
    NSDictionary* cache = [NSKeyedUnarchiver unarchiveObjectWithData:cacheData];

    if(cache){
        self.cachedResults = [NSMutableDictionary dictionaryWithDictionary:cache];
        NSMutableArray* outdatedResultKey = [NSMutableArray array];
        for (NSString* urlPart in [self.cachedResults allKeys]) {
            NSDate* cacheValidityEndDate = [[self.cachedResults objectForKey:urlPart] objectForKey:@"cacheValidityEndDate"];
            if([[NSDate date] compare:cacheValidityEndDate]!=NSOrderedAscending){
                //Result not valid anymore: purging
                [outdatedResultKey addObject:urlPart];
            }
            if([outdatedResultKey count]>0){
                [self.cachedResults removeObjectsForKeys:outdatedResultKey];
                [self saveCache];
            }
        }
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
        //Response to current block
        NSMutableArray* relatedCallInfoForCallback = [NSMutableArray array];
        if(info.responseBlock){
            [relatedCallInfoForCallback addObject:info];
        }
        //Response to other related pending blocks
        for (NLTAPICallInfo* otherInfo in [self callInfoWithSameUrlPart:info]) {
            if(otherInfo.responseBlock){
                [relatedCallInfoForCallback addObject:otherInfo];
            }
        }
        //We cleanup calls before using callbacks (in case the callbacks user want to make the same call, we don't want it to be prevented by the callInfoWithSameUrlPart check)
        [self.calls removeObject:info];
        [self removeCallInfoWithSameUrlPart:info];
        for (NLTAPICallInfo* relatedInfo in relatedCallInfoForCallback) {
            relatedInfo.responseBlock(answer,nil);
        }
    }else{
        if(jsonError){
            NSMutableArray* relatedCallInfoForCallback = [NSMutableArray array];
            if(info.responseBlock){
                [relatedCallInfoForCallback addObject:info];
            }
            //Response to other related pending blocks
            for (NLTAPICallInfo* otherInfo in [self callInfoWithSameUrlPart:info]) {
                if(otherInfo.responseBlock){
                    [relatedCallInfoForCallback addObject:otherInfo];
                }
            }
            for (NLTAPICallInfo* relatedInfo in relatedCallInfoForCallback) {
                relatedInfo.responseBlock(nil, jsonError);
            }
            [self.calls removeObject:info];
            [self removeCallInfoWithSameUrlPart:info];
        }else{
            NSError* error = [NSError errorWithDomain:@"NLTAPIDomain" code:500 userInfo:@{@"message":@"Unable to parse answer"}];
            NSMutableArray* relatedCallInfoForCallback = [NSMutableArray array];
            if(info.responseBlock){
                [relatedCallInfoForCallback addObject:info];
            }
            //Response to other related pending blocks
            for (NLTAPICallInfo* otherInfo in [self callInfoWithSameUrlPart:info]) {
                if(otherInfo.responseBlock){
                    [relatedCallInfoForCallback addObject:otherInfo];
                }
            }
            for (NLTAPICallInfo* relatedInfo in relatedCallInfoForCallback) {
                relatedInfo.responseBlock(nil, error);
            }
            [self.calls removeObject:info];
            [self removeCallInfoWithSameUrlPart:info];
        }
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    NLTAPICallInfo* info = [self callInfoForConnection:connection];
    if(info.responseBlock){
        info.responseBlock(nil, error);
    }
    //Response to other related pending blocks
    for (NLTAPICallInfo* otherInfo in [self callInfoWithSameUrlPart:info]) {
        if(otherInfo.responseBlock){
            otherInfo.responseBlock(nil, error);
        }
    }
    [self.calls removeObject:info];
    [self removeCallInfoWithSameUrlPart:info];
}

#pragma mark - Upper level call

- (void)showWithId:(long)showId withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    if([self.showsById objectForKey:[NSNumber numberWithInteger:showId]]){
        if(responseBlock){
            responseBlock([self.showsById objectForKey:[NSNumber numberWithInteger:showId]], nil);
        }
    }else{
        NSString* urlStr = [NSString stringWithFormat:@"shows/by_id/%li", showId];
        [[NLTAPI sharedInstance] callAPI:urlStr withResultBlock:^(NSArray* result, NSError *error) {
            if(error){
                if(responseBlock){
                    responseBlock(nil, error);
                }
            }else{
                NLTShow* requestedShow = nil;
                if([result isKindOfClass:[NSArray class]]){
                    for (NSDictionary* showInfo in result) {
                        NLTShow* show = [[NLTShow alloc] initWithDictionnary:showInfo];
                        if(show.id_show){
                            [self.showsById setObject:show forKey:[NSNumber numberWithInt:show.id_show]];
                        }
                        if(showId == show.id_show){
                            requestedShow = show;
                        }
                    }
                }
                if(responseBlock){
                    responseBlock(requestedShow, nil);
                }
            }
        } withKey:self withCacheDuration:NLT_SHOWS_CACHE_DURATION];
    }
}


- (void)familyWithId:(long)familyId withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    if([self.familiesById objectForKey:[NSNumber numberWithInteger:familyId]]){
        if(responseBlock){
            responseBlock([self.showsById objectForKey:[NSNumber numberWithInteger:familyId]], nil);
        }
    }else{
        NSString* urlStr = [NSString stringWithFormat:@"families/by_id/%li", familyId];
        [[NLTAPI sharedInstance] callAPI:urlStr withResultBlock:^(NSArray* result, NSError *error) {
            if(error){
                if(responseBlock){
                    responseBlock(nil, error);
                }
            }else{
                NLTFamily* requestedFamily = nil;
                if([result isKindOfClass:[NSArray class]]){
                    for (NSDictionary* familyInfo in result) {
                        NLTFamily* family = [[NLTFamily alloc] initWithDictionnary:familyInfo];
                        if(family.id_family){
                            [self.familiesById setObject:family forKey:[NSNumber numberWithInt:family.id_family]];
                        }
                        if(familyId == family.id_family){
                            requestedFamily = family;
                        }
                    }
                }
                if(responseBlock){
                    responseBlock(requestedFamily, nil);
                }
            }
        } withKey:self withCacheDuration:NLT_SHOWS_CACHE_DURATION];
    }
}

#pragma mark Search/recent shows

- (int)resultsByPage{
    return NLT_SHOWS_BY_PAGE;
}

- (void)showsAtPage:(int)page withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    NSString* urlStr = [NSString stringWithFormat:@"shows?page=%i&elements_per_page=%i", page, [self resultsByPage]];
    if(self.partnerKey){
        urlStr = [urlStr stringByAppendingFormat:@"&partner_key=%@", self.partnerKey];
    }
    [[NLTAPI sharedInstance] callAPI:urlStr withResultBlock:^(NSArray* result, NSError *error) {
        if(error){
            if(responseBlock){
                responseBlock(nil, error);
            }
        }else{
            NSMutableArray* shows = [NSMutableArray array];
            if([result isKindOfClass:[NSArray class]]){
                for (NSDictionary* showInfo in result) {
                    NLTShow* show = [[NLTShow alloc] initWithDictionnary:showInfo];
                    if(show.id_show){
                        [self.showsById setObject:show forKey:[NSNumber numberWithInt:show.id_show]];
                    }
                    [shows addObject:show];
                }
            }
            if(responseBlock){
                responseBlock(shows, nil);
            }
        }
    } withKey:self withCacheDuration:NLT_SHOWS_CACHE_DURATION];
}

- (void)search:(NSString*)query atPage:(int)page withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    NSString* urlStr = [NSString stringWithFormat:@"search?query=%@&page=%i&elements_per_page=%i", [query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ,page, [self resultsByPage]];
    if(self.partnerKey){
        urlStr = [urlStr stringByAppendingFormat:@"&partner_key=%@", self.partnerKey];
    }
    [[NLTAPI sharedInstance] callAPI:urlStr withResultBlock:^(NSArray* result, NSError *error) {
        if(error){
            if(responseBlock){
                responseBlock(nil, error);
            }
        }else{
            NSArray* results = [NSArray array];
            if([result isKindOfClass:[NSArray class]]){
                results = [NSArray arrayWithArray:result];
            }
            if(responseBlock){
                responseBlock(results, nil);
            }
        }
    } withKey:self withCacheDuration:NLT_SHOWS_CACHE_DURATION];
}

#pragma mark Queue list

//Raw call : usually not meaned to be called directly, so not publically exposed
- (void)queueListWithResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    NSString* urlStr = @"users/queue_list";
    [[NLTAPI sharedInstance] callAPI:urlStr withResultBlock:^(NSArray* result, NSError *error) {
        if(error){
            if(responseBlock){
                responseBlock(nil, error);
            }
        }else{
            NSDictionary* watchListQueue = nil;
            if([result isKindOfClass:[NSArray class]]){
                BOOL isWatchlistSure = FALSE;
                for (NSDictionary* queueInfo in result) {
                    if([[queueInfo objectForKey:@"playlist_title"] isKindOfClass:[NSString class]] && [(NSString*)[queueInfo objectForKey:@"playlist_title"] compare:@"File d'attente"]==NSOrderedSame){
                        watchListQueue = queueInfo;
                        isWatchlistSure = TRUE;
                    }else if(!isWatchlistSure){
                        watchListQueue = queueInfo;
                    }
                }
            }
            if(responseBlock){
                responseBlock(watchListQueue, nil);
            }
        }
    } withKey:self withCacheDuration:NLT_QUEUELIST_CACHE_DURATION];
}

- (void)queueListShowIdsWithResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    [[NLTAPI sharedInstance] queueListWithResultBlock:^(NSDictionary* queueList, NSError *error) {
        if(error){
            if(responseBlock){
                responseBlock(nil, error);
            }
        }else{
            NSMutableArray* shows = [NSMutableArray array];
            if([queueList objectForKey:@"playlist"]){
                if([[queueList objectForKey:@"playlist"] isKindOfClass:[NSString class]]){
                    NSArray* showStrs = [(NSString*)[queueList objectForKey:@"playlist"] componentsSeparatedByString:@","];
                    for (NSString* showStr in showStrs) {
                        if([showStr compare:@""]!=NSOrderedSame){
                            [shows addObject:[NSNumber numberWithInteger:[showStr integerValue]]];
                        }
                    }
                }else if([[queueList objectForKey:@"playlist"] isKindOfClass:[NSNumber class]]){
                    [shows addObject:(NSNumber*)[queueList objectForKey:@"playlist"]];
                }
            }
            if(responseBlock){
                responseBlock(shows, nil);
            }
        }
    } withKey:self];
}

- (void)isInQueueList:(NLTShow*)show withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    [self queueListShowIdsWithResultBlock:^(NSArray* result, NSError *error) {
        if(error){
            if(responseBlock){
                responseBlock(nil, error);
            }
        }else{
            BOOL present = [result containsObject:[NSNumber numberWithInteger:show.id_show]];
            if(responseBlock){
                responseBlock([NSNumber numberWithBool:present], nil);
            }
        }
    } withKey:key];
}

- (void)addToQueueList:(NLTShow*)show withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    //We invalidate the cache as this method need fresh data and will lead to changed data
    [self invalidateCache:@"users/queue_list"];
    [self queueListShowIdsWithResultBlock:^(NSArray* result, NSError *error) {
        [self invalidateCache:@"users/queue_list"];
        if(error){
            if(responseBlock){
                responseBlock(nil, error);
            }
        }else{
            BOOL present = [result containsObject:[NSNumber numberWithInteger:show.id_show]];
            if(!present){
                //Add to queue list
                NSString* showIdStr = [NSString stringWithFormat:@"%i",show.id_show];
                NSMutableArray* shows = [NSMutableArray array];
                for (NSNumber* watchListShowId in result) {
                    [shows addObject:[NSString stringWithFormat:@"%@", watchListShowId]];
                }
                [shows addObject:showIdStr];

                NSString* newQueueListStr = [shows componentsJoinedByString:@","];
                newQueueListStr = [NSString stringWithFormat:@"[%@]",newQueueListStr];
                NSString* urlStr = @"users/queue_list";
                [self callAPI:urlStr withResultBlock:responseBlock withKey:key withCacheDuration:0 withMethod:@"PUT" withBody:[newQueueListStr dataUsingEncoding:NSUTF8StringEncoding] withContentType:@"application/json"];
            }else{
                //Already in queueList
                NSError* error = [NSError errorWithDomain:@"NLTAPIDomain" code:500 userInfo:@{@"message":@"Already in queue list"}];
                if(responseBlock){
                    responseBlock(nil, error);
                }
            }
        }
    } withKey:key];
}

- (void)removeFromQueueList:(NLTShow*)show withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    [self invalidateCache:@"users/queue_list"];
    [self queueListShowIdsWithResultBlock:^(NSArray* result, NSError *error) {
        [self invalidateCache:@"users/queue_list"];
        if(error){
            if(responseBlock){
                responseBlock(nil, error);
            }
        }else{
            BOOL present = [result containsObject:[NSNumber numberWithInteger:show.id_show]];
            if(present){
                //Remove from queue list
                NSMutableArray* shows = [NSMutableArray array];
                for (NSNumber* watchListShowId in result) {
                    if([watchListShowId integerValue]!=show.id_show){
                        [shows addObject:[NSString stringWithFormat:@"%@", watchListShowId]];
                    }
                }
                NSString* urlStr = @"users/queue_list";
                if([shows count]>0){
                    NSString* newQueueListStr = [shows componentsJoinedByString:@","];
                    newQueueListStr = [NSString stringWithFormat:@"[%@]",newQueueListStr];
                    [self callAPI:urlStr withResultBlock:responseBlock withKey:key withCacheDuration:0 withMethod:@"PUT" withBody:[newQueueListStr dataUsingEncoding:NSUTF8StringEncoding] withContentType:@"application/json"];
                }else{
                    [self callAPI:urlStr withResultBlock:responseBlock withKey:key withCacheDuration:0 withMethod:@"DELETE" withBody:nil withContentType:@"application/json"];
                }
            }else{
                //Already in queueList
                NSError* error = [NSError errorWithDomain:@"NLTAPIDomain" code:500 userInfo:@{@"message":@"Not in queue list"}];
                if(responseBlock){
                    responseBlock(nil, error);
                }
            }
        }
    } withKey:key];
}


#pragma mark Show read status

- (void)setReadStatus:(BOOL)isRead forShow:(NLTShow*)show withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    NSString* urlStr = [NSString stringWithFormat:@"shows/%i/mark_read",show.id_show];
    //We're changing info for a show : calls cached for shows are reliable anymore
    [self invalidateCacheWithPrefix:@"shows"];
    NSString* method = @"POST";
    if(!isRead){
        method = @"DELETE";
    }
    [[NLTAPI sharedInstance] callAPI:urlStr withResultBlock:^(id result, NSError *error) {
        if(error){
            if(responseBlock){
                responseBlock(nil, error);
            }
        }else{
            if([result isKindOfClass:[NSArray class]]){
                for (NSDictionary* readInfo in result) {
                    if([readInfo objectForKey:@"id_show"]&&[readInfo objectForKey:@"id_show"]!=[NSNull null]&&[[readInfo objectForKey:@"id_show"] integerValue]==show.id_show){
                        if([readInfo objectForKey:@"mark_read"]&&[readInfo objectForKey:@"mark_read"]!=[NSNull null]){
                            show.mark_read = [[readInfo objectForKey:@"mark_read"] boolValue];
                        }
                    }
                }
            }
            if(responseBlock){
#ifdef DEBUG
                NSLog(@"Result %@",result);
#endif
                responseBlock(result, nil);
            }
        }
    } withKey:key withCacheDuration:0 withMethod:method withBody:nil withContentType:nil];
}

@end
