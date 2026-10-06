#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>
@interface ScreenSaverView (RainbowTests)
- (id)image:(NSString *)path;
@end
static void Put(id actor,NSString *key,double value) { [actor setValue:@(value) forKey:key]; }
static double Get(id actor,NSString *key) { return [[actor valueForKey:key] doubleValue]; }
static NSPoint Center(id animation,NSArray *center) { NSSize size=[[animation valueForKey:@"size"] sizeValue]; NSPoint p=NSMakePoint([center[0] doubleValue],[center[1] doubleValue]); return NSEqualPoints(p,NSZeroPoint)?NSMakePoint(size.width/2,size.height/2):p; }
static NSRect Bounds(id actor,NSSize viewport,double scale) {
 id right=[actor valueForKey:@"right"],left=[actor valueForKey:@"left"]; NSDictionary *b=[actor valueForKey:@"behavior"];
 NSSize r=[[right valueForKey:@"size"] sizeValue],l=[[left valueForKey:@"size"] sizeValue]; NSPoint rc=Center(right,b[@"rc"]),lc=Center(left,b[@"lc"]);
 double xmin=MAX(rc.x,lc.x)*scale,xmax=viewport.width-MAX(r.width-rc.x,l.width-lc.x)*scale;
 double ymin=MAX(r.height-rc.y,l.height-lc.y)*scale,ymax=viewport.height-MAX(rc.y,lc.y)*scale;
 return NSMakeRect(xmin,ymin,xmax-xmin,ymax-ymin);
}
static void Tick(ScreenSaverView *view) { Put(view,@"lastTick",NSProcessInfo.processInfo.systemUptime-1.0/30); [view animateOneFrame]; }
int main(int argc,char **argv) { @autoreleasepool {
 [NSApplication sharedApplication]; NSBundle *bundle=[NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]]; if (![bundle load]) return 1;
 NSString *domain=[@"org.desktopponies.rainbowtests." stringByAppendingString:NSUUID.UUID.UUIDString]; ScreenSaverDefaults *settings=[ScreenSaverDefaults defaultsForModuleWithName:domain]; [settings registerDefaults:@{@"scale":@2}];
 NSSize viewport=NSMakeSize(1440,900); ScreenSaverView *view=[[[bundle principalClass] alloc] initWithFrame:NSMakeRect(0,0,viewport.width,viewport.height) isPreview:NO]; [view setValue:settings forKey:@"settings"]; [view performSelector:@selector(repopulate)];
 NSDictionary *pony=nil; for (NSDictionary *p in [view valueForKey:@"catalog"]) if ([p[@"id"] isEqual:@"Rainbow Dash"]) pony=p;
 if (!pony) return 2;
 // A resting pose or wrong-axis hover must not leave Rainbow stranded at any wall.
 for (NSDictionary *behavior in pony[@"behaviors"]) {
     NSString *mode=behavior[@"mode"]; BOOL idle=[behavior[@"speed"] doubleValue]==0;
     if (!idle && ![mode isEqual:@"vertical_only"] && ![mode isEqual:@"horizontal_only"]) continue;
     for (NSInteger side=0;side<4;side++) {
         if (!idle && [mode isEqual:@"vertical_only"] && side>=2) continue;
         if (!idle && [mode isEqual:@"horizontal_only"] && side<2) continue;
         id actor=NSClassFromString(@"DPActor") ? [NSClassFromString(@"DPActor") new] : [NSClassFromString(@"DP16Actor") new];
         [actor setValue:pony forKey:@"pony"]; [actor setValue:behavior forKey:@"behavior"]; [actor setValue:[view image:behavior[@"right"]] forKey:@"right"]; [actor setValue:[view image:behavior[@"left"]] forKey:@"left"];
         Put(actor,@"remaining",1000); [actor setValue:@YES forKey:@"facingRight"];
         NSRect bounds=Bounds(actor,viewport,2); double x=viewport.width/2,y=viewport.height/2;
         if (side==0) x=NSMinX(bounds); if (side==1) x=NSMaxX(bounds); if (side==2) y=NSMinY(bounds); if (side==3) y=NSMaxY(bounds);
         Put(actor,@"x",x); Put(actor,@"y",y); if (!idle) Put(actor,side<2?@"vy":@"vx",20);
         [view setValue:[NSMutableArray arrayWithObject:actor] forKey:@"actors"];
         for (int frame=0;frame<45;frame++) Tick(view);
         double inward=side==0?Get(actor,@"x")-x:side==1?x-Get(actor,@"x"):side==2?Get(actor,@"y")-y:y-Get(actor,@"y");
         if (inward<20) { NSLog(@"FAIL Rainbow %@ stays at wall %ld (inward %.2f)",behavior[@"name"],(long)side,inward); return 3; }
     }
 }
 // Fastest real animation must keep a single facing through each inward run.
 NSDictionary *zoom=nil; for (NSDictionary *b in pony[@"behaviors"]) if ([b[@"name"] isEqual:@"flyzoom"]) zoom=b;
 for (NSNumber *scale in @[@1,@2,@3]) for (NSNumber *width in @[@800,@1440,@2560]) {
     [settings setDouble:scale.doubleValue forKey:@"scale"]; viewport=NSMakeSize(width.doubleValue,900); [view setFrameSize:viewport]; [view performSelector:@selector(repopulate)];
     id actor=NSClassFromString(@"DPActor") ? [NSClassFromString(@"DPActor") new] : [NSClassFromString(@"DP16Actor") new];
     [actor setValue:pony forKey:@"pony"]; [actor setValue:zoom forKey:@"behavior"]; [actor setValue:[view image:zoom[@"right"]] forKey:@"right"]; [actor setValue:[view image:zoom[@"left"]] forKey:@"left"]; Put(actor,@"remaining",1000);
     NSRect bounds=Bounds(actor,viewport,scale.doubleValue); Put(actor,@"x",NSMaxX(bounds)-.1); Put(actor,@"y",450); Put(actor,@"vx",2000.0/3); [actor setValue:@YES forKey:@"facingRight"]; [view setValue:[NSMutableArray arrayWithObject:actor] forKey:@"actors"];
     BOOL facing=YES; int lastFlip=-1000; double travel=NSWidth(bounds); double crossingTime=travel/(scale.doubleValue*2000.0/3);
     for (int frame=0;frame<450;frame++) {
         Tick(view); BOOL now=[[actor valueForKey:@"facingRight"] boolValue];
         if (now!=facing) { if (frame-lastFlip<MAX(2,(int)floor(crossingTime*30)-1)) { NSLog(@"FAIL fast Rainbow flickers at width %@ scale %@",width,scale); return 4; } lastFlip=frame; facing=now; }
         double x=Get(actor,@"x"); if (x<NSMinX(bounds)-.01 || x>NSMaxX(bounds)+.01) return 5;
     }
 }
 [settings removePersistentDomainForName:domain]; [settings synchronize];
 NSLog(@"PASS: Rainbow Dash's real idle/hover behaviors leave all walls, and flyzoom stays stable through 4050 full-screen frames at 3 scales and 3 display widths.");
} return 0; }
