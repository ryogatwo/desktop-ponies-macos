#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>
@interface ScreenSaverView (CastTest)
- (void)repopulate;
- (void)beginBehavior:(NSDictionary *)behavior actor:(id)actor;
@end
int main(int argc,char **argv) { @autoreleasepool {
 [NSApplication sharedApplication]; NSBundle *bundle=[NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]]; if (![bundle load]) return 1;
 NSString *domain=[@"org.desktopponies.casttests." stringByAppendingString:NSUUID.UUID.UUIDString]; ScreenSaverDefaults *settings=[ScreenSaverDefaults defaultsForModuleWithName:domain]; [settings registerDefaults:@{@"scale":@2,@"cast":@2,@"background":@0,@"count":@12}];
 ScreenSaverView *view=[[[bundle principalClass] alloc] initWithFrame:NSMakeRect(0,0,1440,900) isPreview:NO]; [view setValue:settings forKey:@"settings"];
 NSBitmapImageRep *rep=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:1440 pixelsHigh:900 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
 [NSGraphicsContext saveGraphicsState]; [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
 NSUInteger characters=0,behaviors=0,frames=0;
 for (NSDictionary *pony in [view valueForKey:@"catalog"]) { @autoreleasepool {
     [settings setObject:@{pony[@"id"]:@1} forKey:@"customCounts"]; [view repopulate]; NSArray *actors=[view valueForKey:@"actors"]; if (actors.count!=1 || ![[actors[0] valueForKeyPath:@"pony.id"] isEqual:pony[@"id"]]) return 2;
     id actor=actors[0];
     for (NSDictionary *behavior in pony[@"behaviors"]) {
         [view beginBehavior:behavior actor:actor];
         if (![actor valueForKey:@"left"] || ![actor valueForKey:@"right"]) return 3;
         for (NSString *side in @[@"right",@"left"]) {
             id animation=[actor valueForKey:side]; NSArray *ends=[animation valueForKey:@"ends"];
             [actor setValue:@([side isEqual:@"right"]) forKey:@"facingRight"];
             double previous=0;
             for (NSNumber *end in ends) { [actor setValue:@((previous+end.doubleValue)/2) forKey:@"elapsed"]; [view drawRect:view.bounds]; previous=end.doubleValue; frames++; }
         }
         behaviors++;
     }
     characters++;
 }}
 [settings setInteger:1 forKey:@"cast"]; [settings setInteger:40 forKey:@"count"];
 for (int run=0;run<50;run++) { @autoreleasepool { [view repopulate]; if ([[view valueForKey:@"actors"] count]!=40) return 4; for (int frame=0;frame<30;frame++) { [view setValue:@(NSProcessInfo.processInfo.systemUptime-1.0/30) forKey:@"lastTick"]; [view animateOneFrame]; [view drawRect:view.bounds]; } } }
 [NSGraphicsContext restoreGraphicsState]; [settings removePersistentDomainForName:domain]; [settings synchronize];
 NSLog(@"PASS: %lu custom characters, %lu behaviors, %lu rendered GIF frames, and 50 random casts of 40 characters.",(unsigned long)characters,(unsigned long)behaviors,(unsigned long)frames);
} return 0; }
