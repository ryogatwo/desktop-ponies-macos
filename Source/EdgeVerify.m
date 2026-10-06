#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>

static void Put(id object, NSString *key, double value) { [object setValue:@(value) forKey:key]; }
static double Get(id object, NSString *key) { return [[object valueForKey:key] doubleValue]; }
// Use the real animation loop, with a fixed 50 ms step and no behavior change.
static void Tick(ScreenSaverView *view) { Put(view,@"lastTick",NSProcessInfo.processInfo.systemUptime-.05); [view animateOneFrame]; }
static id Actor(NSSize rightSize, NSSize leftSize, NSArray *rightCenter, NSArray *leftCenter) {
    id actor=[NSClassFromString(@"DP16Actor") new];
    id right=[NSClassFromString(@"DP16Animation") new], left=[NSClassFromString(@"DP16Animation") new];
    [right setValue:[NSValue valueWithSize:rightSize] forKey:@"size"]; [left setValue:[NSValue valueWithSize:leftSize] forKey:@"size"];
    [actor setValue:right forKey:@"right"]; [actor setValue:left forKey:@"left"];
    [actor setValue:@{@"rc":rightCenter,@"lc":leftCenter} forKey:@"behavior"]; Put(actor,@"remaining",10000); return actor;
}
static BOOL RunCase(ScreenSaverView *view, NSString *label, double x, double y, double vx, double vy, BOOL facing, NSUInteger expectedFlips) {
    id actor=Actor(NSMakeSize(100,60),NSMakeSize(120,80),@[@50,@30],@[@60,@40]);
    Put(actor,@"x",x); Put(actor,@"y",y); Put(actor,@"vx",vx); Put(actor,@"vy",vy); [actor setValue:@(facing) forKey:@"facingRight"];
    [view setValue:[NSMutableArray arrayWithObject:actor] forKey:@"actors"];
    NSUInteger flips=0; BOOL previous=facing, escaped=NO;
    for (int i=0;i<60;i++) {
        Tick(view); BOOL now=[[actor valueForKey:@"facingRight"] boolValue]; if (now!=previous) flips++; previous=now;
        if (Get(actor,@"x")<120-.01 || Get(actor,@"x")>180+.01 || Get(actor,@"y")<80-.01 || Get(actor,@"y")>220+.01) { escaped=YES; }
    }
    if (flips!=expectedFlips) { NSLog(@"FAIL %@: %lu direction changes; expected %lu",label,(unsigned long)flips,(unsigned long)expectedFlips); return NO; }
    if (escaped) { NSLog(@"FAIL %@: sprite escapes safe area",label); return NO; }
    return YES;
}
int main(int argc, const char **argv) { @autoreleasepool {
    [NSApplication sharedApplication]; NSBundle *bundle=[NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]];
    NSError *error=nil; if (![bundle loadAndReturnError:&error]) { NSLog(@"%@",error); return 1; }
    ScreenSaverView *view=[[[bundle principalClass] alloc] initWithFrame:NSMakeRect(0,0,300,300) isPreview:NO];
    NSString *domain=[@"org.desktopponies.edges." stringByAppendingString:NSUUID.UUID.UUIDString];
    ScreenSaverDefaults *settings=[ScreenSaverDefaults defaultsForModuleWithName:domain]; [settings registerDefaults:@{@"scale":@2}]; [view setValue:settings forKey:@"settings"]; [view performSelector:@selector(repopulate)];
    if (!RunCase(view,@"right wall",199,150,5,0,YES,1)) return 2;
    if (!RunCase(view,@"left wall",101,150,-5,0,NO,1)) return 3;
    if (!RunCase(view,@"already leaving right wall",199,150,-5,0,NO,0)) return 4;
    if (!RunCase(view,@"already leaving left wall",101,150,5,0,YES,0)) return 5;
    if (!RunCase(view,@"top-right corner",199,239,5,5,YES,1)) return 6;
    if (!RunCase(view,@"bottom-left corner",101,61,-5,-5,NO,1)) return 7;
    if (!RunCase(view,@"stationary pose expands",199,239,0,0,NO,0)) return 8;
    // A sprite larger than the view must stay stable instead of turning each frame.
    [view setFrameSize:NSMakeSize(80,70)];
    id actor=Actor(NSMakeSize(100,60),NSMakeSize(120,80),@[@50,@30],@[@60,@40]);
    Put(actor,@"x",0); Put(actor,@"y",0); Put(actor,@"vx",100); Put(actor,@"vy",100); [actor setValue:@YES forKey:@"facingRight"];
    [view setValue:[NSMutableArray arrayWithObject:actor] forKey:@"actors"]; Tick(view);
    double x=Get(actor,@"x"),y=Get(actor,@"y");
    for (int i=0;i<60;i++) { Tick(view); if (Get(actor,@"x")!=x || Get(actor,@"y")!=y || ![[actor valueForKey:@"facingRight"] boolValue]) return 9; }
    [settings removePersistentDomainForName:domain]; [settings synchronize];
    NSLog(@"PASS: asymmetric left/right poses, both walls, inward motion, corners, stationary poses, and oversized sprites remain stable.");
} return 0; }
