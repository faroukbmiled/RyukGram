#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCIGalleryCoreDataStack : NSObject

+ (instancetype)shared;

@property (nonatomic, strong, readonly) NSPersistentContainer *persistentContainer;
@property (nonatomic, strong, readonly) NSManagedObjectContext *viewContext;

- (void)saveContext;
- (void)unloadPersistentStores;
- (void)reloadPersistentContainer;

@end

NS_ASSUME_NONNULL_END
