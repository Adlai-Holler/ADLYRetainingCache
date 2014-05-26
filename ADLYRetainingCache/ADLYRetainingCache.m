#import "ADLYRetainingCache.h"

#define WILL_ACCESS_RETAINED_PAIRS [_retainedPairsLock lock]
#define DID_ACCESS_RETAINED_PAIRS [_retainedPairsLock unlock]

#define WILL_ACCESS_RETENTION_KEYS [_retentionKeysLock lock]
#define DID_ACCESS_RETENTION_KEYS [_retentionKeysLock unlock]

@interface ADLYRetainingCache()
@property (nonatomic, strong) NSMapTable *retainedPairs;
@property (nonatomic, strong) NSLock *retainedPairsLock;
@property (nonatomic, strong) NSMapTable *retentionKeys;
/** This lock also guards the mutable set values in retentionKeys */
@property (nonatomic, strong) NSLock *retentionKeysLock;
@end

@implementation ADLYRetainingCache

- (id)init {
    self = [super init];
    if (!self) return nil;
    _retainedPairs = [NSMapTable strongToStrongObjectsMapTable];
    _retainedPairsLock = [[NSLock alloc] init];
    _retentionKeys = [NSMapTable strongToStrongObjectsMapTable];
    _retentionKeysLock = [[NSLock alloc] init];
    return self;
}

- (id)objectForKey:(id)key {
    id s = [super objectForKey:key];
    if (!s) {
        WILL_ACCESS_RETAINED_PAIRS;
        s = [_retainedPairs objectForKey:key];
        DID_ACCESS_RETAINED_PAIRS;
    }
    return s;
}

- (void)removeObjectForKey:(id)key {
    [super removeObjectForKey:key];
    if (!key) return;
    
    WILL_ACCESS_RETAINED_PAIRS;
    [_retainedPairs removeObjectForKey:key];
    DID_ACCESS_RETAINED_PAIRS;
    
    WILL_ACCESS_RETENTION_KEYS;
    [_retentionKeys removeObjectForKey:key];
    DID_ACCESS_RETENTION_KEYS;
}

- (void)retainKey:(id)key withRetentionKey:(id)retentionKey {
    if (!key) return;
    NSParameterAssert(retentionKey != nil);
    id object = [self objectForKey:key];
    if (object == nil) return;
    
    WILL_ACCESS_RETENTION_KEYS;
    NSMutableSet *retentions = [_retentionKeys objectForKey:key];
    if (!retentions) {
        retentions = [NSMutableSet setWithObject:retentionKey];
        [_retentionKeys setObject:retentions forKey:key];
    } else {
        [retentions addObject:retentionKey];
    }
    BOOL isFirstRetain = (retentions.count == 1);
    DID_ACCESS_RETENTION_KEYS;
    
    if (isFirstRetain) {
        WILL_ACCESS_RETAINED_PAIRS;
        [_retainedPairs setObject:object forKey:key];
        DID_ACCESS_RETAINED_PAIRS;
    }
}

- (void)forceReleaseKey:(id)key {
    if (!key) return;
    WILL_ACCESS_RETENTION_KEYS;
    [_retentionKeys removeObjectForKey:key];
    DID_ACCESS_RETENTION_KEYS;
    
    WILL_ACCESS_RETAINED_PAIRS;
    id object = [_retainedPairs objectForKey:key];
    DID_ACCESS_RETAINED_PAIRS;

    if (object) [super setObject:object forKey:key];
}

- (NSInteger)retainCountForKey:(id)key {
    WILL_ACCESS_RETENTION_KEYS;
    NSInteger result = [[_retentionKeys objectForKey:key] count];
    DID_ACCESS_RETENTION_KEYS;
    return result;
}

- (void)releaseKey:(id)key withRetentionKey:(id)retentionKey {
    if (!key) return;
    NSParameterAssert(retentionKey);
    id object = [self objectForKey:key];
    
    WILL_ACCESS_RETENTION_KEYS;
    NSMutableSet *retentions = [_retentionKeys objectForKey:key];
    [retentions removeObject:retentionKey];
    BOOL lastRelease = (0 == retentions.count);
    if (lastRelease) {
        [_retentionKeys removeObjectForKey:key];
    }
    DID_ACCESS_RETENTION_KEYS;
    
    if (lastRelease) {
        if (object) [super setObject:object forKey:key];
        WILL_ACCESS_RETAINED_PAIRS;
        [_retainedPairs removeObjectForKey:key];
        DID_ACCESS_RETAINED_PAIRS;
    }
}

@end

@implementation ADLYRetainingCache (Testing)

- (void)_simulateEvictionOfObjectForKey:(id)key {
    [super removeObjectForKey:key];
}

@end
