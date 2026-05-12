// Sideload compatibility shim for IG. Upstream: github.com/asdfzxcvbn/zxPluginsInject.
// Local deviation: NSUserDefaults init redirect is appex-only so main-app reads
// hit cfprefsd's natural sandbox-local path (else IG's NUX dismiss flags never
// read back and every popup re-fires); main-app writes to group.* suites are
// fanned out to the shared group container so the notification appex still sees
// what main app wrote (auth, session, multi-account, rich-preview metadata).

#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <objc/message.h>

#import "../fishhook/fishhook.h"

@interface LSBundleProxy: NSObject
@property(nonatomic, assign, readonly) NSDictionary *entitlements;
@property(nonatomic, assign, readonly) NSDictionary *groupContainerURLs;
+ (instancetype)bundleProxyForCurrentProcess;
@end

@interface NSUserDefaults (Sideload)
- (id)_initWithSuiteName:(NSString *)suiteName container:(NSURL *)container;
@end

static NSString *accessGroupId;

static BOOL createDirectoryIfNotExists(NSString *path) {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:path]) return YES;

	NSError *error = nil;
	[fileManager createDirectoryAtPath:path
		   withIntermediateDirectories:YES
							attributes:nil
								 error:&error];
	return error == nil;
}

static NSURL *getAppGroupPathIfExists(void) {
	static NSURL *cachedAppGroupPath = nil;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		LSBundleProxy *bundleProxy = [objc_getClass("LSBundleProxy") bundleProxyForCurrentProcess];
		if (!bundleProxy) return;

		NSDictionary *entitlements = bundleProxy.entitlements;
		if (![entitlements isKindOfClass:[NSDictionary class]]) return;

		NSArray *appGroups = entitlements[@"com.apple.security.application-groups"];
		if (![appGroups isKindOfClass:[NSArray class]] || appGroups.count == 0) return;

		NSDictionary *appGroupsPaths = bundleProxy.groupContainerURLs;
		if (![appGroupsPaths isKindOfClass:[NSDictionary class]]) return;

		NSURL *ourAppGroupURL = appGroupsPaths[[appGroups firstObject]];
		if ([ourAppGroupURL isKindOfClass:[NSURL class]]) cachedAppGroupPath = ourAppGroupURL;
	});

	return cachedAppGroupPath;
}

static BOOL sciIsAppExtensionProcess(void) {
	static BOOL cached = NO;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		cached = ([[NSBundle mainBundle] infoDictionary][@"NSExtension"] != nil);
	});
	return cached;
}

// Cross-process fan-out. Tagged with an associated object so the fan-out's
// own setObject:/removeObject: doesn't recurse back through our hook.
static const void *kSCIFanoutTagKey = &kSCIFanoutTagKey;

static NSURL *sciSharedContainerURLForSuite(NSString *suiteName) {
	NSURL *appGroup = getAppGroupPathIfExists();
	if (!appGroup || !suiteName.length) return nil;
	NSURL *containerURL = [appGroup URLByAppendingPathComponent:suiteName isDirectory:YES];
	NSURL *prefsDir = [[containerURL URLByAppendingPathComponent:@"Library"] URLByAppendingPathComponent:@"Preferences"];
	createDirectoryIfNotExists(prefsDir.path);
	return containerURL;
}

static NSUserDefaults *sciFanoutDefaultsForSuite(NSString *suiteName) {
	static NSMutableDictionary<NSString *, NSUserDefaults *> *cache;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ cache = [NSMutableDictionary new]; });

	@synchronized(cache) {
		NSUserDefaults *cached = cache[suiteName];
		if (cached) return cached;

		NSURL *containerURL = sciSharedContainerURLForSuite(suiteName);
		if (!containerURL) return nil;

		NSUserDefaults *fanout = [[NSUserDefaults alloc] _initWithSuiteName:suiteName container:containerURL];
		if (!fanout) return nil;

		objc_setAssociatedObject(fanout, kSCIFanoutTagKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		cache[suiteName] = fanout;
		return fanout;
	}
}

static NSString *sciSuiteNameForDefaults(NSUserDefaults *defaults) {
	if (![defaults respondsToSelector:@selector(_identifier)]) return nil;
	return ((NSString *(*)(id, SEL))objc_msgSend)(defaults, @selector(_identifier));
}

static BOOL sciShouldFanout(NSUserDefaults *defaults) {
	if (sciIsAppExtensionProcess()) return NO;
	if (objc_getAssociatedObject(defaults, kSCIFanoutTagKey)) return NO;
	NSString *suite = sciSuiteNameForDefaults(defaults);
	return [suite hasPrefix:@"group"];
}

// === keychain access-group rebind ==========================================

static OSStatus (*origSecItemAdd)(CFDictionaryRef, CFTypeRef *);
static OSStatus (*origSecItemCopyMatching)(CFDictionaryRef, CFTypeRef *);
static OSStatus (*origSecItemUpdate)(CFDictionaryRef, CFDictionaryRef);
static OSStatus (*origSecItemDelete)(CFDictionaryRef);

static CFDictionaryRef sciFixedQuery(CFDictionaryRef query) {
	if (!query || !accessGroupId.length) return NULL;
	CFMutableDictionaryRef dict = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, query);
	if (dict) CFDictionarySetValue(dict, kSecAttrAccessGroup, (__bridge const void *)accessGroupId);
	return dict;
}

static OSStatus zxSecItemAdd(CFDictionaryRef q, CFTypeRef *r) {
	CFDictionaryRef d = sciFixedQuery(q);
	OSStatus s = origSecItemAdd(d ?: q, r);
	if (d) CFRelease(d);
	return s;
}

static OSStatus zxSecItemCopyMatching(CFDictionaryRef q, CFTypeRef *r) {
	CFDictionaryRef d = sciFixedQuery(q);
	OSStatus s = origSecItemCopyMatching(d ?: q, r);
	if (d) CFRelease(d);
	return s;
}

static OSStatus zxSecItemUpdate(CFDictionaryRef q, CFDictionaryRef u) {
	CFDictionaryRef d = sciFixedQuery(q);
	OSStatus s = origSecItemUpdate(d ?: q, u);
	if (d) CFRelease(d);
	return s;
}

static OSStatus zxSecItemDelete(CFDictionaryRef q) {
	CFDictionaryRef d = sciFixedQuery(q);
	OSStatus s = origSecItemDelete(d ?: q);
	if (d) CFRelease(d);
	return s;
}

static void rebindSecFuncs(void) {
	struct rebinding rebinds[4] = {
		{"SecItemAdd", (void *)zxSecItemAdd, (void **)&origSecItemAdd},
		{"SecItemCopyMatching", (void *)zxSecItemCopyMatching, (void **)&origSecItemCopyMatching},
		{"SecItemUpdate", (void *)zxSecItemUpdate, (void **)&origSecItemUpdate},
		{"SecItemDelete", (void *)zxSecItemDelete, (void **)&origSecItemDelete}
	};
	rebind_symbols(rebinds, 4);
}

// === CloudKit disable ======================================================

%hook CKContainer
- (id)_setupWithContainerID:(id)a options:(id)b { return nil; }
- (id)_initWithContainerIdentifier:(id)a { return nil; }
%end

%hook CKEntitlements
- (id)initWithEntitlementsDict:(NSDictionary *)entitlements {
	NSMutableDictionary *m = [entitlements mutableCopy];
	[m removeObjectForKey:@"com.apple.developer.icloud-container-environment"];
	[m removeObjectForKey:@"com.apple.developer.icloud-services"];
	return %orig([m copy]);
}
%end

// === NSFileManager group container URL =====================================

%hook NSFileManager
- (NSURL *)containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier {
	if (NSURL *ourAppGroupURL = getAppGroupPathIfExists()) {
		NSURL *fakeAppGroupURL = [ourAppGroupURL URLByAppendingPathComponent:groupIdentifier isDirectory:YES];
		createDirectoryIfNotExists(fakeAppGroupURL.path);
		return fakeAppGroupURL;
	}
	return %orig(groupIdentifier);
}
%end

// === NSUserDefaults: appex redirect + main-app fan-out =====================

%hook NSUserDefaults

- (id)_initWithSuiteName:(NSString *)suiteName container:(NSURL *)container {
	// Main app stays on cfprefsd's natural path so IG's reads find what IG
	// wrote (popup dismiss flags etc). Fan-out mirrors group.* writes into
	// the entitled container the appex reads from.
	if (!sciIsAppExtensionProcess()) return %orig(suiteName, container);

	NSURL *appGroupURL = getAppGroupPathIfExists();
	if (!appGroupURL) return %orig(suiteName, container);
	if (![suiteName hasPrefix:@"group"]) return %orig(suiteName, container);

	NSURL *customContainerURL = [appGroupURL URLByAppendingPathComponent:suiteName isDirectory:YES];
	if (!customContainerURL) return %orig(suiteName, container);

	NSURL *prefsDir = [[customContainerURL URLByAppendingPathComponent:@"Library"] URLByAppendingPathComponent:@"Preferences"];
	createDirectoryIfNotExists(prefsDir.path);
	return %orig(suiteName, customContainerURL);
}

- (void)setObject:(id)value forKey:(NSString *)key {
	%orig;
	if (!sciShouldFanout(self)) return;
	NSUserDefaults *fanout = sciFanoutDefaultsForSuite(sciSuiteNameForDefaults(self));
	[fanout setObject:value forKey:key];
}

- (void)removeObjectForKey:(NSString *)key {
	%orig;
	if (!sciShouldFanout(self)) return;
	NSUserDefaults *fanout = sciFanoutDefaultsForSuite(sciSuiteNameForDefaults(self));
	[fanout removeObjectForKey:key];
}

%end

// === keychain access-group bootstrap =======================================

static void setRequiredIDs(void) {
	NSDictionary *query = @{
		(__bridge NSString *)kSecClass: (__bridge NSString *)kSecClassGenericPassword,
		(__bridge NSString *)kSecAttrAccount: @"zxPluginsInjectGenericEntry",
		(__bridge NSString *)kSecAttrService: @"",
		(__bridge id)kSecReturnAttributes: (id)kCFBooleanTrue
	};

	CFDictionaryRef result = nil;
	OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
	if (status == errSecItemNotFound) {
		status = SecItemAdd((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
	}
	if (status != errSecSuccess) return;

	accessGroupId = [(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kSecAttrAccessGroup];
	if (result) CFRelease(result);
}

__attribute__((constructor)) static void init(void) {
	setRequiredIDs();
	rebindSecFuncs();
}
