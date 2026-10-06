#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>
static NSDictionary *Counts(ScreenSaverView *view) {
    NSMutableDictionary *counts=[NSMutableDictionary dictionary];
    for (id actor in [view valueForKey:@"actors"]) { NSString *name=[actor valueForKeyPath:@"pony.id"]; counts[name]=@([counts[name] integerValue]+1); }
    return counts;
}
int main(int argc,char **argv) { @autoreleasepool {
    if (argc>2 && !strcmp(argv[1],"--write")) {
        ScreenSaverDefaults *prefs=[ScreenSaverDefaults defaultsForModuleWithName:[NSString stringWithUTF8String:argv[2]]];
        BOOL live=argc>3;
        [prefs setInteger:2 forKey:@"cast"];
        [prefs setObject:live?@{@"Trixie":@4}:@{@"Princess Luna":@3,@"Adagio Dazzle":@2} forKey:@"customCounts"];
        [prefs setObject:NSUUID.UUID.UUIDString forKey:@"settingsRevision"];
        if (![prefs synchronize]) { NSLog(@"Cannot persist test preferences; run this test outside a workspace sandbox."); return 5; } return 0;
    }
    [NSApplication sharedApplication];
    NSBundle *bundle=[NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]]; if (![bundle load]) return 1;
    NSString *domain=[@"org.desktopponies.settings-test." stringByAppendingString:NSUUID.UUID.UUIDString];
    ScreenSaverDefaults *prefs=[ScreenSaverDefaults defaultsForModuleWithName:domain];
    [prefs registerDefaults:@{@"cast":@0,@"count":@12,@"scale":@2,@"background":@0}];
    ScreenSaverView *view=[[[bundle principalClass] alloc] initWithFrame:NSMakeRect(0,0,1440,900) isPreview:NO];
    [view setValue:prefs forKey:@"settings"]; [view performSelector:@selector(repopulate)];
    [view startAnimation]; [view stopAnimation];
    NSString *executable=NSProcessInfo.processInfo.arguments[0];
    NSTask *writer=[NSTask new]; writer.executableURL=[NSURL fileURLWithPath:executable]; writer.arguments=@[@"--write",domain]; [writer launch]; [writer waitUntilExit];
    [view startAnimation];
    if (![Counts(view) isEqual:@{@"Princess Luna":@3,@"Adagio Dazzle":@2}]) { NSLog(@"FAIL: retained fullscreen view ignores settings written by another process: %@",Counts(view)); return 2; }
    writer=[NSTask new]; writer.executableURL=[NSURL fileURLWithPath:executable]; writer.arguments=@[@"--write",domain,@"live"]; [writer launch]; [writer waitUntilExit];
    [view setValue:@0 forKey:@"lastSettingsCheck"]; [view animateOneFrame];
    if (![Counts(view) isEqual:@{@"Trixie":@4}]) { NSLog(@"FAIL: running fullscreen view ignores live updates: %@",Counts(view)); return 3; }
    NSArray *actors=[view valueForKey:@"actors"];
    [view setValue:@0 forKey:@"lastSettingsCheck"]; [view animateOneFrame];
    if (actors!=[view valueForKey:@"actors"]) return 4;
    [view stopAnimation]; [prefs removePersistentDomainForName:domain]; [prefs synchronize];
    NSLog(@"PASS: existing fullscreen view reloads cast changes from another process on restart and while running; unchanged preferences do not respawn actors.");
} return 0; }
