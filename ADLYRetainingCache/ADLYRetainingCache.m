#import "ADLYRetainingCache.h"

#define WILL_ACCESS_DATA [_dataLock lock]
#define DID_ACCESS_DATA [_dataLock unlock]

@interface ADLYRetainingCache()
@property (nonatomic, strong) NSMapTable *retainedPairs;
@property (nonatomic, strong) NSLock *dataLock;
@property (nonatomic, strong) NSMapTable *retentionKeys;
@end

@implementation ADLYRetainingCache

- (id)init {
    self = [super init];
    if (!self) return nil;
    _retainedPairs = [NSMapTable strongToStrongObjectsMapTable];
    _retentionKeys = [NSMapTable strongToStrongObjectsMapTable];
    _dataLock = [[NSLock alloc] init];
    return self;
}

- (id)_objectForKey:(id)key lock:(BOOL)lock {
    id s = [super objectForKey:key];
    if (!s) {
        if (lock) WILL_ACCESS_DATA;
        s = [_retainedPairs objectForKey:key];
        if (lock) DID_ACCESS_DATA;
    }
    return s;
}

- (id)objectForKey:(id)key {
    return [self _objectForKey:key lock:YES];
}

- (void)removeObjectForKey:(id)key {
    [super removeObjectForKey:key];
    if (!key) return;
    
    WILL_ACCESS_DATA;
    [_retainedPairs removeObjectForKey:key];
    [_retentionKeys removeObjectForKey:key];
    DID_ACCESS_DATA;
}

- (void)releaseAllObjects {
    WILL_ACCESS_DATA;
    for (id retainedKey in _retainedPairs) {
        id retainedObject = [_retainedPairs objectForKey:retainedKey];
        [super setObject:retainedObject forKey:retainedKey];
    }
    [_retainedPairs removeAllObjects];
    [_retentionKeys removeAllObjects];
    DID_ACCESS_DATA;
}

- (void)releaseAllObjectsWithRetentionKey:(id)retentionKey {
    NSParameterAssert(retentionKey != nil);
    WILL_ACCESS_DATA;
    for (id retainedKey in [_retainedPairs copy]) {
        [self _releaseKey:retainedKey withRetentionKey:retentionKey lock:NO];
    }
    DID_ACCESS_DATA;
}

- (void)retainKey:(id)key withRetentionKey:(id)retentionKey {
    if (!key) return;
    NSParameterAssert(retentionKey != nil);
    
    WILL_ACCESS_DATA;
    id object = [self _objectForKey:key lock:NO];
    if (object == nil) {
        DID_ACCESS_DATA;
        return;
    }

    NSMutableSet *retentions = [_retentionKeys objectForKey:key];
    if (!retentions) {
        retentions = [[NSMutableSet alloc] init];
        [_retentionKeys setObject:retentions forKey:key];
    }
    if (retentions.count == 0) {
        [_retainedPairs setObject:object forKey:key];
    }
    [retentions addObject:retentionKey];
    DID_ACCESS_DATA;
}

- (void)forceReleaseKey:(id)key {
    if (!key) return;
    WILL_ACCESS_DATA;
    [_retentionKeys removeObjectForKey:key];
    
    id object = [_retainedPairs objectForKey:key];
    DID_ACCESS_DATA;

    if (object) [super setObject:object forKey:key];
}

- (NSInteger)retainCountForKey:(id)key {
    WILL_ACCESS_DATA;
    NSInteger result = [[_retentionKeys objectForKey:key] count];
    DID_ACCESS_DATA;
    return result;
}

- (void)_releaseKey:(id)key withRetentionKey:(id)retentionKey lock:(BOOL)lock {
    if (!key) return;
    NSParameterAssert(retentionKey);
    if (lock) WILL_ACCESS_DATA;
    
    NSMutableSet *retentions = [_retentionKeys objectForKey:key];
    if (retentions.count > 0) {
        [retentions removeObject:retentionKey];
        if (0 == retentions.count) {
            [_retentionKeys removeObjectForKey:key];
            id object = [_retainedPairs objectForKey:key];
            if (object) [super setObject:object forKey:key];
            [_retainedPairs removeObjectForKey:key];
        }
    }
    if (lock) DID_ACCESS_DATA;
}

- (void)releaseKey:(id)key withRetentionKey:(id)retentionKey {
    [self _releaseKey:key withRetentionKey:retentionKey lock:YES];
}

@end

@implementation ADLYRetainingCache (Testing)

- (void)_simulateEvictionOfObjectForKey:(id)key {
    [super removeObjectForKey:key];
}

@end
