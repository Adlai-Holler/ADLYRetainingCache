
#import <XCTest/XCTest.h>
#import "ADLYRetainingCache.h"
#import <UIKit/UIApplication.h>
@interface ADLYRetainingCacheTests : XCTestCase

@end

@implementation ADLYRetainingCacheTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

static int const WordListLength = 50;
static dispatch_semaphore_t semaphore;
static NSArray *addObjectsWordList;
- (void)_addObjectsToCache:(ADLYRetainingCache *)cache {
    for (int i = 0; i < 1E5; i++) {
        int r = arc4random_uniform(WordListLength - 1);
        [cache setObject:addObjectsWordList[r] forKey:addObjectsWordList[r + 1]];
    }
    dispatch_semaphore_signal(semaphore);
}

static NSArray *removeObjectsWordList;
- (void)_removeObjectsFromCache:(ADLYRetainingCache *)cache {
    for (int i = 0; i < 1E5; i++) {
        int r = arc4random_uniform(WordListLength - 1);
        [cache removeObjectForKey:removeObjectsWordList[r]];
    }
    dispatch_semaphore_signal(semaphore);
}

static NSArray *retainObjectsWordList;
- (void)_retainObjectsInCache:(ADLYRetainingCache *)cache {
    for (int i = 0; i < 1E5; i++) {
        int r0 = arc4random_uniform(WordListLength);
        int r1 = arc4random_uniform(WordListLength);
        [cache retainKey:retainObjectsWordList[r0] withRetentionKey:retainObjectsWordList[r1]];
    }
    dispatch_semaphore_signal(semaphore);
}

static NSArray *releaseObjectsWordList;
- (void)_releaseObjectsInCache:(ADLYRetainingCache *)cache {
    for (int i = 0; i < 1E5; i++) {
        int r0 = arc4random_uniform(WordListLength);
        int r1 = arc4random_uniform(WordListLength);
        if (r0 / (double)WordListLength > 0.8) {
            [cache forceReleaseKey:retainObjectsWordList[r0]];
        } else {
            [cache releaseKey:retainObjectsWordList[r0] withRetentionKey:retainObjectsWordList[r1]];
        }
    }
    dispatch_semaphore_signal(semaphore);
}

- (void)testThatMultithreadedAccessDoesntCrash {
    ADLYRetainingCache *c = [[ADLYRetainingCache alloc] init];
    NSMutableArray *wordSet = [[NSMutableArray alloc] initWithCapacity:WordListLength];
    for (int i = 0; i < WordListLength; i++) {
        [wordSet addObject:[@(i) description]];
    }

    addObjectsWordList = [wordSet copy];
    retainObjectsWordList = [wordSet copy];
    releaseObjectsWordList = [wordSet copy];
    removeObjectsWordList = [wordSet copy];
    semaphore = dispatch_semaphore_create(0);
    [NSThread detachNewThreadSelector:@selector(_addObjectsToCache:) toTarget:self withObject:c];
    [NSThread detachNewThreadSelector:@selector(_retainObjectsInCache:) toTarget:self withObject:c];
    [NSThread detachNewThreadSelector:@selector(_releaseObjectsInCache:) toTarget:self withObject:c];
    [NSThread detachNewThreadSelector:@selector(_removeObjectsFromCache:) toTarget:self withObject:c];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}
- (void)testThatRetainingTheSameKeyTwiceHasNoEffect {
    ADLYRetainingCache *c = [[ADLYRetainingCache alloc] init];
    id key = @"Hello";
    id object = @"World";
    [c setObject:object forKey:key];
    [c retainKey:key withRetentionKey:@"Retention"];
    [c retainKey:key withRetentionKey:@"Retention"];
    XCTAssertNotNil([c objectForKey:key], @"");
    [c releaseKey:key withRetentionKey:@"Retention"];
    XCTAssertNotNil([c objectForKey:key], @"");
    [c _simulateEvictionOfObjectForKey:key];
    XCTAssertNil([c objectForKey:key], @"");
}

- (void)testThatReleasingAnUnretainedKeyIsSafe {
    ADLYRetainingCache *c = [[ADLYRetainingCache alloc] init];
    id key = @"Hello";
    id object = @"World";
    [c setObject:object forKey:key];
    [c releaseKey:key withRetentionKey:@"Nonexistent"];
}

- (void)testThatReleasingThenEvictingCausesEviction {
    ADLYRetainingCache *c = [[ADLYRetainingCache alloc] init];
    id key = @"Hello";
    id object = @"World";
    [c setObject:object forKey:key];
    [c retainKey:key withRetentionKey:@"RetainKey0"];
    [c _simulateEvictionOfObjectForKey:key];
    XCTAssertNotNil([c objectForKey:key], @"");
    [c releaseKey:key withRetentionKey:@"RetainKey0"];
    XCTAssertNotNil([c objectForKey:key], @"");
    [c _simulateEvictionOfObjectForKey:key];
    XCTAssertNil([c objectForKey:key], @"");
}

- (void)testThatARetainPreventsAnEviction
{
    ADLYRetainingCache *c = [[ADLYRetainingCache alloc] init];
    [c setObject:@"World" forKey:@"Hello"];
    [c retainKey:@"Hello" withRetentionKey:@"RetainKey0"];
    [c _simulateEvictionOfObjectForKey:@"Hello"];
    XCTAssertNotNil([c objectForKey:@"Hello"], @"");
}

@end
