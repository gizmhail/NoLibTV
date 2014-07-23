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
        self.familiesByKey = [NSMutableDictionary dictionary];
        self.partnersByKey = [NSMutableDictionary dictionary];
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
                self.networkActivityCount++;
                if(self.handleNetworkActivityIndicator&&![[UIApplication sharedApplication] isNetworkActivityIndicatorVisible]){
                    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:TRUE];
                }
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
    self.networkActivityCount--;
    if(self.handleNetworkActivityIndicator&&[[UIApplication sharedApplication] isNetworkActivityIndicatorVisible]){
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:FALSE];
    }
    NLTAPICallInfo* info = [self callInfoForConnection:connection];
    NSError* jsonError = nil;
    NSDictionary* answer = nil;
    if(info.data){
        answer = [NSJSONSerialization JSONObjectWithData:info.data options:NSJSONReadingAllowFragments error:&jsonError];
    }
    if(!jsonError&&answer){
        if(info.cacheValidityEndDate){
            [self.cachedResults setObject:@{@"answer":answer,@"cacheValidityEndDate":info.cacheValidityEndDate,@"cachingDate":[NSDate date]} forKey:info.urlPart];
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
            NSError* error = [NSError errorWithDomain:@"NLTAPIDomain" code:501 userInfo:@{@"message":@"Unable to parse answer"}];
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
    self.networkActivityCount--;
    if(self.handleNetworkActivityIndicator&&[[UIApplication sharedApplication] isNetworkActivityIndicatorVisible]){
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:FALSE];
    }

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
    [self showWithId:showId withResultBlock:responseBlock withKey:key noCache:FALSE];
}

- (void)showWithId:(long)showId withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key noCache:(BOOL)noCache{
#warning TODO ensure that showsById is updated with latest results (store in show the call date, and compare,...)

    long cache = NLT_SHOWS_CACHE_DURATION;
    if(noCache){
        cache = 0;
    }
    if(!noCache&& [self.showsById objectForKey:[NSNumber numberWithInteger:showId]]){
        if(responseBlock){
            responseBlock([self.showsById objectForKey:[NSNumber numberWithInteger:showId]], nil);
        }
    }else{
        NSString* urlStr = [NSString stringWithFormat:@"shows/by_id/%li", showId];
        [[NLTAPI sharedInstance] callAPI:urlStr withResultBlock:^(NSArray* result, NSError *error) {
            NSDate* cachingDate = [[self.cachedResults objectForKey:urlStr] objectForKey:@"cachingDate"];
            if(!cachingDate){
                cachingDate = [NSDate date];
            }
            if(error){
                if(responseBlock){
                    responseBlock(nil, error);
                }
            }else{
                NLTShow* requestedShow = nil;
                if([result isKindOfClass:[NSArray class]]){
                    for (NSDictionary* showInfo in result) {
                        NLTShow* show = [[NLTShow alloc] initWithDictionnary:showInfo];
                        show.cachingDate = cachingDate;
                        if(show.id_show){
                            NLTShow* previousShow = [self.showsById objectForKey:[NSNumber numberWithInt:show.id_show]];
                            if(!previousShow || [[previousShow cachingDate] compare:cachingDate]!=NSOrderedDescending){
                                [self.showsById setObject:show forKey:[NSNumber numberWithInt:show.id_show]];
                            }else if(previousShow){
                                show = previousShow;
                            }
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
        } withKey:key withCacheDuration:cache];
    }
}

- (void)familyWithFamilyKey:(NSString*)familyKey withPartnerKey:(NSString*)partnerKey withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    NSString* familyMergedKey = [NSString stringWithFormat:@"%@/%@",partnerKey,familyKey];
    [self familyWithFamilyMergedKey:familyMergedKey withResultBlock:responseBlock withKey:key];
}

- (void)familyWithFamilyMergedKey:(NSString*)familyMergedKey withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    if([self.familiesByKey objectForKey:familyMergedKey]){
        if(responseBlock){
            responseBlock([self.familiesByKey objectForKey:familyMergedKey], nil);
        }
    }else{
        NSString* urlStr = [NSString stringWithFormat:@"families/by_key/%@", familyMergedKey];
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
                        if(family.family_key && family.partner_key){
                            NSString* resultFamilyMergedKey = [NSString stringWithFormat:@"%@/%@",family.partner_key,family.family_key];
                            [self.familiesByKey setObject:family forKey:resultFamilyMergedKey];
                            if([resultFamilyMergedKey compare:familyMergedKey]==NSOrderedSame){
                                requestedFamily = family;
                            }
                        }
                    }
                }
                if(responseBlock){
                    responseBlock(requestedFamily, nil);
                }
            }
        } withKey:key withCacheDuration:NLT_SHOWS_CACHE_DURATION];
    }
}

- (void)familyWithId:(long)familyId withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    if([self.familiesById objectForKey:[NSNumber numberWithInteger:familyId]]){
        if(responseBlock){
            responseBlock([self.familiesById objectForKey:[NSNumber numberWithInteger:familyId]], nil);
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
                        if(family.family_key && family.partner_key){
                            NSString* resultFamilyMergedKey = [NSString stringWithFormat:@"%@/%@",family.partner_key,family.family_key];
                            [self.familiesByKey setObject:family forKey:resultFamilyMergedKey];
                        }
                    }
                }
                if(responseBlock){
                    responseBlock(requestedFamily, nil);
                }
            }
        } withKey:key withCacheDuration:NLT_SHOWS_CACHE_DURATION];
    }
}

#pragma mark Search/recent shows

- (int)resultsByPage{
    return NLT_SHOWS_BY_PAGE;
}

- (void)showsAtPage:(int)page withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    [self showsAtPage:page withResultBlock:responseBlock withFamilyKey:nil withKey:key];
}

- (void)showsAtPage:(int)page withResultBlock:(NLTCallResponseBlock)responseBlock withFamilyKey:(NSString*)familyKey withKey:(id)key{
    NSString* baseCall = @"shows";
    if(self.subscribedOnly){
        baseCall = @"shows/subscribed";
    }
    NSString* urlStr = [NSString stringWithFormat:@"%@?page=%i&elements_per_page=%i", baseCall, page, [self resultsByPage]];
    if(self.partnerKey){
        urlStr = [urlStr stringByAppendingFormat:@"&partner_key=%@", self.partnerKey];
    }
    if(familyKey){
        urlStr = [urlStr stringByAppendingFormat:@"&family_key=%@", familyKey];
    }
    [[NLTAPI sharedInstance] callAPI:urlStr withResultBlock:^(NSArray* result, NSError *error) {
        NSDate* cachingDate = [[self.cachedResults objectForKey:urlStr] objectForKey:@"cachingDate"];
        if(!cachingDate){
            cachingDate = [NSDate date];
        }
        if(error && error.domain == NSCocoaErrorDomain && error.code == 3840 && self.subscribedOnly){
#warning TODO Remove this hack if the API return something when the result is empty (cf http://bugtracker.noco.tv/view.php?id=192)
            result = @[];
            error = nil;
        }
        if([result isKindOfClass:[NSDictionary class]]&&[(NSDictionary*)result objectForKey:@"error"]){
            error = [NSError errorWithDomain:@"NLTAPIDomain" code:502 userInfo:(NSDictionary*)result];
        }
        if(error){
            if(responseBlock){
                responseBlock(nil, error);
            }
        }else{
            NSMutableArray* shows = [NSMutableArray array];
            if([result isKindOfClass:[NSArray class]]){
                for (NSDictionary* showInfo in result) {
                    NLTShow* show = [[NLTShow alloc] initWithDictionnary:showInfo];
                    show.cachingDate = cachingDate;
                    if(show.id_show){
                        NLTShow* previousShow = [self.showsById objectForKey:[NSNumber numberWithInt:show.id_show]];
                        if(!previousShow || [[previousShow cachingDate] compare:cachingDate]!=NSOrderedDescending){
                            [self.showsById setObject:show forKey:[NSNumber numberWithInt:show.id_show]];
                        }else if(previousShow){
                            show = previousShow;
                        }
                    }
                    [shows addObject:show];
                }
            }
            if(responseBlock){
                responseBlock(shows, nil);
            }
        }
    } withKey:key withCacheDuration:NLT_SHOWS_CACHE_DURATION];
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
    } withKey:key withCacheDuration:NLT_SHOWS_CACHE_DURATION];
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
    } withKey:key withCacheDuration:NLT_QUEUELIST_CACHE_DURATION];
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
                NSError* error = [NSError errorWithDomain:@"NLTAPIDomain" code:503 userInfo:@{@"message":@"Already in queue list"}];
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
                NSError* error = [NSError errorWithDomain:@"NLTAPIDomain" code:504 userInfo:@{@"message":@"Not in queue list"}];
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

#pragma mark Progress

- (void)setResumePlay:(long)timeInMS forShow:(NLTShow*)show withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    NSString* urlStr = [NSString stringWithFormat:@"shows/%i/progress", show.id_show];
    float progress = 0;
    if(show.duration_ms > 0){
        progress = timeInMS/(float)show.duration_ms;
    }
    NSString* progressInfo = [NSString stringWithFormat:@"{\"progress\":{\"total\":%f},\"resume_play\": %li}", progress, timeInMS];
    [self callAPI:urlStr withResultBlock:responseBlock withKey:key withCacheDuration:0 withMethod:@"PUT" withBody:[progressInfo dataUsingEncoding:NSUTF8StringEncoding] withContentType:@"application/json"];
}

- (void)getResumePlayForShow:(NLTShow*)show withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    NSString* urlStr = [NSString stringWithFormat:@"shows/%i/progress", show.id_show];
    [self callAPI:urlStr withResultBlock:^(id result, NSError *error) {
        if(error){
            if(responseBlock){
                responseBlock(nil , error);
            }
        }else{
            long progress= 0;
            if([result isKindOfClass:[NSArray class]]){
                for (NSDictionary*showInfo in result) {
                    if([[showInfo objectForKey:@"id_show"] integerValue]==show.id_show){
                        progress = [[showInfo objectForKey:@"resume_play"] integerValue];
                    }
                }
            }
            if(responseBlock){
                responseBlock([NSNumber numberWithLong:progress], nil);
            }
        }
    } withKey:key withCacheDuration:0];
}

#pragma mark User account

- (void)userAccountInfoWithResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    [[NLTAPI sharedInstance] callAPI:@"users/init" withResultBlock:^(id result, NSError *error) {
        if([result isKindOfClass:[NSDictionary class]]&&[(NSDictionary*)result objectForKey:@"error"]){
            error = [NSError errorWithDomain:@"NLTAPIDomain" code:505 userInfo:(NSDictionary*)result];
        }
        if(!error){
            if(responseBlock){
                responseBlock(result, error);
            }
        }else{
            if(responseBlock){
                responseBlock(nil, error);
            }
        }
    } withKey:key withCacheDuration:NLT_USER_CACHE_DURATION];
}

#pragma mark Partners

- (void)partnersWithResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    [[NLTAPI sharedInstance] callAPI:@"partners" withResultBlock:^(id result, NSError *error) {
        if([result isKindOfClass:[NSDictionary class]]&&[(NSDictionary*)result objectForKey:@"error"]){
            error = [NSError errorWithDomain:@"NLTAPIDomain" code:506 userInfo:(NSDictionary*)result];
        }
        if(!error){
            if([result isKindOfClass:[NSArray class]]){
                for (NSDictionary* partnerKeyInfo in result) {
                    if([partnerKeyInfo objectForKey:@"partner_key"]){
                        [self.partnersByKey setObject:partnerKeyInfo forKey:[partnerKeyInfo objectForKey:@"partner_key"]];
                    }
                }
            }
            if(responseBlock){
                responseBlock(result, error);
            }
        }else{
            if(responseBlock){
                responseBlock(nil, error);
            }
        }
    } withKey:key withCacheDuration:NLT_PARTNERS_CACHE_DURATION];
}

#pragma mark vido

/**
 * Available medias
 * First level of results: video language
 * Second level of results: subtitle language
 * Third level qualities
 */
- (void)availableMediaForShow:(NLTShow*)show  withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    NSString* urlStr = [NSString stringWithFormat:@"/shows/%i/medias", show.id_show];
    [[NLTAPI sharedInstance] callAPI:urlStr withResultBlock:^(id result, NSError *error) {
        if(responseBlock){
            responseBlock(result, error);
        }
    } withKey:key withCacheDuration:NLT_SHOWS_CACHE_DURATION];
}

- (void)videoUrlForShow:(NLTShow*)show withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    [self videoUrlForShow:show withPreferedQuality:self.preferedQuality withPreferedLanguage:self.preferedLanguage withPreferedSubtitleLanguage:self.preferedSubtitleLanguage withResultBlock:responseBlock withKey:key];
}

- (void)videoUrlForShow:(NLTShow*)show withPreferedQuality:(NSString*)preferedQuality withPreferedLanguage:(NSString*)preferedLanguage withPreferedSubtitleLanguage:(NSString*)preferedSubtitleLanguage withResultBlock:(NLTCallResponseBlock)responseBlock withKey:(id)key{
    //Adaptating to nil values (and special values)
    if(preferedLanguage==nil
       ||[preferedLanguage compare:@"none" options:NSCaseInsensitiveSearch]
       ||[preferedLanguage compare:@"V.O." options:NSCaseInsensitiveSearch]
       ||[preferedLanguage compare:@"V.O" options:NSCaseInsensitiveSearch]
       ||[preferedLanguage compare:@"version originale" options:NSCaseInsensitiveSearch]){
        preferedLanguage = show.original_lang;
    }
    if(preferedSubtitleLanguage == nil){
        preferedSubtitleLanguage = @"none";
    }
    if(preferedQuality == nil){
        preferedQuality = @"LQ";
    }
    
    [[NLTAPI sharedInstance] availableMediaForShow:show withResultBlock:^(id result, NSError *error) {
        if(!error&&result&&[result isKindOfClass:[NSDictionary class]]){
            BOOL infoOk = false;
            BOOL perfectMatchLang = FALSE;
            BOOL perfectMatchSub = FALSE;
            BOOL perfectMatchQuality = FALSE;
            NSString* subLang = nil;
            NSString* audioLang = nil;
            NSString* qualityKey = nil;
           //Searching for available language matching request
            NSDictionary* audioLangInfo = nil;
            for (NSString* availableAudioLang in (NSDictionary*)result) {
                NSDictionary* availableAudioLangInfo = [result objectForKey:availableAudioLang];
                if([availableAudioLang compare:preferedLanguage options:NSCaseInsensitiveSearch]==NSOrderedSame){
                    //Perfect match
                    audioLang = availableAudioLang;
                    audioLangInfo = availableAudioLangInfo;
                    perfectMatchLang = true;
                    break;
                }else{
                    //Alternative match
                    if(audioLang == nil){
                        audioLang = availableAudioLang;
                        audioLangInfo = availableAudioLangInfo;
                    }
                }
            }
            if(audioLangInfo&& [[audioLangInfo objectForKey:@"video_list"] isKindOfClass:[NSDictionary class]]){
                NSDictionary* subtitleInfoList = [audioLangInfo objectForKey:@"video_list"];
                //Searching for available subtitle language matching request
                NSDictionary* subLangInfo = nil;
                for (NSString* aivalableSubtitleLang in subtitleInfoList) {
                    NSDictionary* aivalableSubtitleLangInfo = [subtitleInfoList objectForKey:aivalableSubtitleLang];
                    if([aivalableSubtitleLang compare:preferedSubtitleLanguage options:NSCaseInsensitiveSearch]==NSOrderedSame){
                        //Perfect match
                        subLang = aivalableSubtitleLang;
                        subLangInfo = aivalableSubtitleLangInfo;
                        perfectMatchSub = true;
                        break;
                    }else{
                        //Alternative match
                        if(subLang == nil){
                            subLang = aivalableSubtitleLang;
                            subLangInfo = aivalableSubtitleLangInfo;
                        }
                    }
                }
                if(subLangInfo &&  [[subLangInfo objectForKey:@"quality_list"] isKindOfClass:[NSDictionary class]]){
                    NSDictionary* qualityList = [subLangInfo objectForKey:@"quality_list"];
                    //Searching for available quality matching request
                    NSDictionary* qualityInfo = nil;
                    for (NSString* aivalableQuality in qualityList) {
                        NSDictionary* aivalableQualityInfo = [qualityList objectForKey:qualityList];
                        if([aivalableQuality compare:preferedQuality options:NSCaseInsensitiveSearch]==NSOrderedSame){
                            //Perfect match
                            qualityKey = aivalableQuality;
                            qualityInfo = aivalableQualityInfo;
                            infoOk = TRUE;
                            perfectMatchQuality = true;
                            break;
                        }else{
                            //Alternative match
                            if(qualityKey == nil){
                                qualityKey = aivalableQuality;
                                qualityInfo = aivalableQualityInfo;
                                infoOk = TRUE;
                            }
                        }
                    }
                }
            }
            if(infoOk){
                NSString* urlStr = [NSString stringWithFormat:@"/shows/%i/video/%@/%@", show.id_show,qualityKey,audioLang];
                if(subLang&&[subLang compare:@"none" options:NSCaseInsensitiveSearch]!=NSOrderedSame){
                    urlStr = [urlStr stringByAppendingFormat:@"?sub_lang=%@",subLang];
                }
#ifdef DEBUG
                NSLog(@"Match found for video. Calling %@ (perfect match %i/%i/%i)",urlStr,perfectMatchLang,perfectMatchSub,perfectMatchQuality);
#endif
                [[NLTAPI sharedInstance] callAPI:urlStr withResultBlock:^(id result, NSError *error) {
                    if(result&&[result objectForKey:@"file"]&&[result objectForKey:@"file"]!=[NSNull null]){
                        if([(NSString*)[result objectForKey:@"file"] compare:@"not found"]!=NSOrderedSame){
                            if(responseBlock){
                                responseBlock(result,nil);
                            }
                        }else{
                            NSError* error = [NSError errorWithDomain:@"NLTAPIDomain" code:404 userInfo:@{@"message":@"Video not available"}];
                            if([result objectForKey:@"popmessage"]&&[[result objectForKey:@"popmessage"] objectForKey:@"message"]){
                                NSMutableDictionary* errorInfo = [NSMutableDictionary dictionaryWithDictionary:result];
                                [errorInfo setObject:@"message" forKey:@"Unable to find video (see popmessage key for more details)"];
                                error = [NSError errorWithDomain:@"NLTAPIDomain" code:NLTAPI_ERROR_VIDEO_UNAVAILABLE_WITH_POPMESSAGE userInfo:errorInfo];
                            }
                            if(responseBlock){
                                responseBlock(nil, error);
                            }
                        }
                    }else{
                        NSError* error = [NSError errorWithDomain:@"NLTAPIDomain" code:406 userInfo:@{@"message":@"Video not available"}];
                        if(responseBlock){
                            responseBlock(nil, error);
                        }
                    }
                } withKey:key];
            }else{
                NSLog(@"Unable to find matching quality for video");
                NSError* error = [NSError errorWithDomain:@"NLTAPIDomain" code:404 userInfo:@{@"message":@"Unable to find matching quality"}];
                if(responseBlock){
                    responseBlock(nil, error);
                }
            }
        }else{
            if(responseBlock){
                responseBlock(nil, error);
            }
        }
    } withKey: key];
}
@end
