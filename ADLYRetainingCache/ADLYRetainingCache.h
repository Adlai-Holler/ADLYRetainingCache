#import <Foundation/Foundation.h>

/** An NSCache subclass that can be forced to retain pairs with "retention keys". The retain count for a given pair is the number of unique retention keys used to retain it. In this way it is a kind of NSCache-NSMutableDictionary hybrid – like NSCache, it is thread-safe and it does not copy its keys, like NSMutableDictionary the programmer can manually prevent objects from being evicted.
 When an objects retain count drops to 0, it will not necessarily be evicted immediately. Use the NSCacheDelegate method -cache:willEvictObject: to determine when an object is evicted.
 
 Instances of this class are safe to access from multiple threads. */
@interface ADLYRetainingCache : NSCache

/** The object at `key`, if present, will not be evicted until the last retention key is released, or forceReleaseKey: is called. */
- (void)retainKey:(id)key withRetentionKey:(id)retentionKey;

- (void)releaseKey:(id)key withRetentionKey:(id)retentionKey;

/** Removes all retention keys for key */
- (void)forceReleaseKey:(id)key;

- (NSInteger)retainCountForKey:(id)key;

@end

@interface ADLYRetainingCache (Testing)

- (void)_simulateEvictionOfObjectForKey:(id)key;

@end