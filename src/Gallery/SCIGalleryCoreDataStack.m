#import "SCIGalleryCoreDataStack.h"
#import "SCIGalleryPaths.h"

@interface SCIGalleryCoreDataStack ()
@property (nonatomic, strong, readwrite) NSPersistentContainer *persistentContainer;
@end

static NSString * const kSCIGalleryEntityName = @"SCIGalleryFile";

@implementation SCIGalleryCoreDataStack

+ (instancetype)shared {
    static SCIGalleryCoreDataStack *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SCIGalleryCoreDataStack alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupPersistentContainer];
    }
    return self;
}

- (NSManagedObjectModel *)buildModel {
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] init];

    NSEntityDescription *entity = [[NSEntityDescription alloc] init];
    entity.name = kSCIGalleryEntityName;
    entity.managedObjectClassName = @"SCIGalleryFile";

    NSAttributeDescription *identifier = [[NSAttributeDescription alloc] init];
    identifier.name = @"identifier";
    identifier.attributeType = NSStringAttributeType;
    identifier.optional = NO;

    NSAttributeDescription *relativePath = [[NSAttributeDescription alloc] init];
    relativePath.name = @"relativePath";
    relativePath.attributeType = NSStringAttributeType;
    relativePath.optional = NO;

    NSAttributeDescription *mediaType = [[NSAttributeDescription alloc] init];
    mediaType.name = @"mediaType";
    mediaType.attributeType = NSInteger16AttributeType;
    mediaType.optional = NO;
    mediaType.defaultValue = @0;

    NSAttributeDescription *source = [[NSAttributeDescription alloc] init];
    source.name = @"source";
    source.attributeType = NSInteger16AttributeType;
    source.optional = NO;
    source.defaultValue = @0;

    NSAttributeDescription *dateAdded = [[NSAttributeDescription alloc] init];
    dateAdded.name = @"dateAdded";
    dateAdded.attributeType = NSDateAttributeType;
    dateAdded.optional = NO;

    NSAttributeDescription *fileSize = [[NSAttributeDescription alloc] init];
    fileSize.name = @"fileSize";
    fileSize.attributeType = NSInteger64AttributeType;
    fileSize.optional = NO;
    fileSize.defaultValue = @0;

    NSAttributeDescription *isFavorite = [[NSAttributeDescription alloc] init];
    isFavorite.name = @"isFavorite";
    isFavorite.attributeType = NSBooleanAttributeType;
    isFavorite.optional = NO;
    isFavorite.defaultValue = @NO;

    NSAttributeDescription *folderPath = [[NSAttributeDescription alloc] init];
    folderPath.name = @"folderPath";
    folderPath.attributeType = NSStringAttributeType;
    folderPath.optional = YES;

    NSAttributeDescription *customName = [[NSAttributeDescription alloc] init];
    customName.name = @"customName";
    customName.attributeType = NSStringAttributeType;
    customName.optional = YES;

    NSAttributeDescription *sourceUsername = [[NSAttributeDescription alloc] init];
    sourceUsername.name = @"sourceUsername";
    sourceUsername.attributeType = NSStringAttributeType;
    sourceUsername.optional = YES;

    NSAttributeDescription *sourceUserPK = [[NSAttributeDescription alloc] init];
    sourceUserPK.name = @"sourceUserPK";
    sourceUserPK.attributeType = NSStringAttributeType;
    sourceUserPK.optional = YES;

    NSAttributeDescription *sourceProfileURLString = [[NSAttributeDescription alloc] init];
    sourceProfileURLString.name = @"sourceProfileURLString";
    sourceProfileURLString.attributeType = NSStringAttributeType;
    sourceProfileURLString.optional = YES;

    NSAttributeDescription *sourceMediaPK = [[NSAttributeDescription alloc] init];
    sourceMediaPK.name = @"sourceMediaPK";
    sourceMediaPK.attributeType = NSStringAttributeType;
    sourceMediaPK.optional = YES;

    NSAttributeDescription *sourceMediaCode = [[NSAttributeDescription alloc] init];
    sourceMediaCode.name = @"sourceMediaCode";
    sourceMediaCode.attributeType = NSStringAttributeType;
    sourceMediaCode.optional = YES;

    NSAttributeDescription *sourceMediaURLString = [[NSAttributeDescription alloc] init];
    sourceMediaURLString.name = @"sourceMediaURLString";
    sourceMediaURLString.attributeType = NSStringAttributeType;
    sourceMediaURLString.optional = YES;

    NSAttributeDescription *pixelWidth = [[NSAttributeDescription alloc] init];
    pixelWidth.name = @"pixelWidth";
    pixelWidth.attributeType = NSInteger32AttributeType;
    pixelWidth.optional = NO;
    pixelWidth.defaultValue = @0;

    NSAttributeDescription *pixelHeight = [[NSAttributeDescription alloc] init];
    pixelHeight.name = @"pixelHeight";
    pixelHeight.attributeType = NSInteger32AttributeType;
    pixelHeight.optional = NO;
    pixelHeight.defaultValue = @0;

    NSAttributeDescription *durationSeconds = [[NSAttributeDescription alloc] init];
    durationSeconds.name = @"durationSeconds";
    durationSeconds.attributeType = NSDoubleAttributeType;
    durationSeconds.optional = NO;
    durationSeconds.defaultValue = @0.0;

    entity.properties = @[
        identifier, relativePath, mediaType, source, dateAdded, fileSize, isFavorite, folderPath, customName,
        sourceUsername, sourceUserPK, sourceProfileURLString, sourceMediaPK, sourceMediaCode, sourceMediaURLString,
        pixelWidth, pixelHeight, durationSeconds
    ];
    model.entities = @[entity];

    return model;
}

- (void)setupPersistentContainer {
    NSManagedObjectModel *model = [self buildModel];
    self.persistentContainer = [[NSPersistentContainer alloc] initWithName:@"SCIGalleryModel" managedObjectModel:model];

    NSString *storePath = [[SCIGalleryPaths galleryDirectory] stringByAppendingPathComponent:@"gallery.sqlite"];
    NSURL *storeURL = [NSURL fileURLWithPath:storePath];
    NSPersistentStoreDescription *storeDesc = [[NSPersistentStoreDescription alloc] initWithURL:storeURL];
    storeDesc.shouldMigrateStoreAutomatically = YES;
    storeDesc.shouldInferMappingModelAutomatically = YES;
    self.persistentContainer.persistentStoreDescriptions = @[storeDesc];

    [self.persistentContainer loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *desc, NSError *error) {
        if (error) {
            NSLog(@"[SCInsta Gallery] Failed to load Core Data store: %@", error);
        }
    }];

    self.persistentContainer.viewContext.automaticallyMergesChangesFromParent = YES;
}

- (NSManagedObjectContext *)viewContext {
    return self.persistentContainer.viewContext;
}

- (void)saveContext {
    NSManagedObjectContext *ctx = self.viewContext;
    if (![ctx hasChanges]) return;

    NSError *error;
    if (![ctx save:&error]) {
        NSLog(@"[SCInsta Gallery] Failed to save context: %@", error);
    }
}

- (void)unloadPersistentStores {
    NSPersistentStoreCoordinator *coordinator = self.persistentContainer.persistentStoreCoordinator;
    for (NSPersistentStore *store in [coordinator.persistentStores copy]) {
        NSError *removeError = nil;
        [coordinator removePersistentStore:store error:&removeError];
        if (removeError) {
            NSLog(@"[SCInsta Gallery] Failed unloading persistent store: %@", removeError);
        }
    }
}

- (void)reloadPersistentContainer {
    [self unloadPersistentStores];
    [self setupPersistentContainer];
}

@end
