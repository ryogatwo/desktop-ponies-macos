#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>
#import <ImageIO/ImageIO.h>
@interface ScreenSaverView (DPTests)
- (void)chooseBehavior:(id)actor;
- (void)repopulate;
- (void)clearCast:(id)sender;
- (void)maneSixCast:(id)sender;
- (void)refreshPicker;
- (void)saveOptions:(id)sender;
- (void)cancelOptions:(id)sender;
- (void)setQuantity:(NSInteger)quantity forPony:(NSString *)identifier;
- (NSInteger)draftTotal;
- (void)controlTextDidEndEditing:(NSNotification *)notification;

@end
int main(int argc,const char **argv) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSBundle *bundle=[NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]]; NSError *error=nil;
    if (![bundle loadAndReturnError:&error]) { NSLog(@"%@",error); return 1; }
    NSArray *catalog=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:[bundle.resourcePath stringByAppendingPathComponent:@"ponies.json"]] options:0 error:&error];
    NSMutableSet *paths=[NSMutableSet set]; for (NSDictionary *pony in catalog) for (NSDictionary *b in pony[@"behaviors"]) { [paths addObject:b[@"left"]]; [paths addObject:b[@"right"]]; }
    for (NSString *p in paths) { CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:[bundle.resourcePath stringByAppendingPathComponent:p]],NULL); if (!source || !CGImageSourceGetCount(source)) { NSLog(@"Bad asset %@",p); return 2; } CGImageRef cg=CGImageSourceCreateImageAtIndex(source,0,NULL); if (!cg) return 3; CGImageRelease(cg); CFRelease(source); }
    NSString *testDomain=[@"org.desktopponies.mac.tests." stringByAppendingString:NSUUID.UUID.UUIDString];
    ScreenSaverDefaults *testSettings=[ScreenSaverDefaults defaultsForModuleWithName:testDomain];
    [testSettings registerDefaults:@{@"count":@12,@"scale":@2,@"cast":@0,@"background":@0}];
    for (NSNumber *preview in @[@NO,@YES]) {
        ScreenSaverView *view=[[[bundle principalClass] alloc] initWithFrame:NSMakeRect(0,0,preview.boolValue?320:1440,preview.boolValue?200:900) isPreview:preview.boolValue];
        [view setValue:testSettings forKey:@"settings"]; [view repopulate];
        if ([[view valueForKey:@"actors"] count]!=6) return 4;
        // Force behavior transitions without spending wall-clock time in a screensaver session.
        for (int i=0;i<1000;i++) { for (id actor in [view valueForKey:@"actors"]) [actor setValue:@0 forKey:@"remaining"]; [view animateOneFrame]; }
        id actor=[[view valueForKey:@"actors"] firstObject];
        for (NSDictionary *pony in catalog) { [actor setValue:pony forKey:@"pony"]; for (int j=0;j<3;j++) { [view chooseBehavior:actor]; if (![actor valueForKey:@"right"] || ![actor valueForKey:@"left"]) return 6; } }
        [view repopulate]; [view animateOneFrame];
        NSBitmapImageRep *rep=[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:1440 pixelsHigh:900 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        [NSGraphicsContext saveGraphicsState]; [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]]; [view drawRect:view.bounds]; [NSGraphicsContext restoreGraphicsState];
        if (!preview.boolValue && argc>2) [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES];
        [view setFrameSize:NSMakeSize(180,100)]; [view animateOneFrame];
        if (!view.hasConfigureSheet || !view.configureSheet) return 5;
    }
    ScreenSaverView *picker=[[[bundle principalClass] alloc] initWithFrame:NSMakeRect(0,0,1440,900) isPreview:NO];
    [picker setValue:testSettings forKey:@"settings"]; [picker repopulate];
    NSWindow *sheet=picker.configureSheet;
    [picker clearCast:nil];
    if ([picker draftTotal]!=0 || [[picker valueForKey:@"applyButton"] isEnabled]) return 10;
    [picker setQuantity:2 forPony:@"Twilight Sparkle"];
    NSSearchField *search=[picker valueForKey:@"searchField"]; search.stringValue=@"Rarity"; [picker refreshPicker];
    for (NSDictionary *p in [picker valueForKey:@"filteredCatalog"]) if ([p[@"id"] rangeOfString:@"rarity" options:NSCaseInsensitiveSearch].location==NSNotFound) return 11;
    [picker setQuantity:3 forPony:@"Rarity"];
    if ([picker draftTotal]!=5) return 12;
    NSButton *only=[picker valueForKey:@"onlyAdded"]; only.state=NSControlStateValueOn; search.stringValue=@""; [picker refreshPicker];
    if ([[picker valueForKey:@"filteredCatalog"] count]!=2) return 13;
    // Commit an actual editable table field through its delegate.
    NSTableView *table=[picker valueForKey:@"pickerTable"];
    id<NSTableViewDelegate> delegate=(id)picker;
    NSView *cell=[delegate tableView:table viewForTableColumn:table.tableColumns.lastObject row:0];
    NSTextField *quantity=nil; for (NSView *subview in cell.subviews) if ([subview isKindOfClass:NSTextField.class]) quantity=(id)subview;
    quantity.integerValue=4; [picker controlTextDidEndEditing:[NSNotification notificationWithName:NSControlTextDidEndEditingNotification object:quantity]];
    if ([picker draftTotal]!=6) return 14;
    // Presets disable every character-editing control, including newly created cells.
    NSPopUpButton *modePopup=[picker valueForKey:@"castPopup"];
    NSDictionary *keptCounts=[[picker valueForKey:@"draftCounts"] copy];
    for (NSNumber *mode in @[@0,@1,@2,@0,@2]) {
        BOOL custom=mode.integerValue==2;
        [modePopup selectItemAtIndex:mode.integerValue]; [picker refreshPicker];
        for (NSString *key in @[@"pickerTable",@"searchField",@"onlyAdded",@"maneSixButton",@"clearCastButton"])
            if ([[picker valueForKey:key] isEnabled]!=custom) return 30;
        if ((table.alphaValue==1.0)!=custom) return 31;
        NSControl *check=(id)[delegate tableView:table viewForTableColumn:table.tableColumns.firstObject row:0];
        NSView *copies=[delegate tableView:table viewForTableColumn:table.tableColumns.lastObject row:0];
        if (check.enabled!=custom) return 32;
        for (NSControl *control in copies.subviews) if (control.enabled!=custom) return 33;
        if (![[picker valueForKey:@"draftCounts"] isEqual:keptCounts]) return 34;
        if (!custom) {
            quantity.integerValue=19;
            [picker controlTextDidEndEditing:[NSNotification notificationWithName:NSControlTextDidEndEditingNotification object:quantity]];
            if (modePopup.indexOfSelectedItem!=mode.integerValue || ![[picker valueForKey:@"draftCounts"] isEqual:keptCounts]) return 35;
        }
    }
    [picker saveOptions:nil];
    ScreenSaverView *restored=[[[bundle principalClass] alloc] initWithFrame:NSMakeRect(0,0,1440,900) isPreview:NO];
    [restored setValue:testSettings forKey:@"settings"]; [restored repopulate];
    NSMutableDictionary *actual=[NSMutableDictionary dictionary]; for (id actor in [restored valueForKey:@"actors"]) { NSString *pid=[actor valueForKeyPath:@"pony.id"]; actual[pid]=@([actual[pid] integerValue]+1); }
    if (![actual isEqual:@{@"Rarity":@4,@"Twilight Sparkle":@2}]) return 15;
    sheet=picker.configureSheet; [picker clearCast:nil]; [picker cancelOptions:nil]; sheet=picker.configureSheet;
    if ([picker draftTotal]!=6) return 16;
    [picker setQuantity:40 forPony:@"Twilight Sparkle"];
    if ([picker draftTotal]!=40) return 17;
    [picker setQuantity:1 forPony:@"Applejack"];
    if ([picker draftTotal]!=40 || [[picker valueForKey:@"draftCounts"] objectForKey:@"Applejack"]) return 18;
    [picker saveOptions:nil]; [restored repopulate]; if ([[restored valueForKey:@"actors"] count]!=40) return 19;
    [testSettings setInteger:0 forKey:@"cast"]; [restored repopulate]; if ([[restored valueForKey:@"actors"] count]!=6) return 20;
    [testSettings setInteger:1 forKey:@"cast"]; [testSettings setInteger:12 forKey:@"count"]; [restored repopulate]; if ([[restored valueForKey:@"actors"] count]!=12) return 21;
    // Selecting Mane Six replaces a stale preset count with exactly one per character.
    sheet=picker.configureSheet;
    NSPopUpButton *preset=[picker valueForKey:@"castPopup"];
    NSSlider *countSlider=[picker valueForKey:@"countSlider"];
    [preset selectItemAtIndex:1]; countSlider.integerValue=36; [picker refreshPicker];
    if (!countSlider.enabled) return 24;
    NSDictionary *customBefore=[[picker valueForKey:@"draftCounts"] copy];
    [preset selectItemAtIndex:0]; [picker refreshPicker];
    if (countSlider.integerValue!=6 || countSlider.enabled) return 25;
    [picker saveOptions:nil];
    if ([testSettings integerForKey:@"count"]!=6 || ![[testSettings dictionaryForKey:@"customCounts"] isEqual:customBefore]) return 26;
    [restored repopulate];
    NSMutableSet *maneIDs=[NSMutableSet set];
    for (id actor in [restored valueForKey:@"actors"]) [maneIDs addObject:[actor valueForKeyPath:@"pony.id"]];
    if ([[restored valueForKey:@"actors"] count]!=6 || ![maneIDs isEqual:[NSSet setWithArray:@[@"Twilight Sparkle",@"Applejack",@"Rainbow Dash",@"Rarity",@"Fluttershy",@"Pinkie Pie"]]]) return 27;
    sheet=picker.configureSheet; if (countSlider.integerValue!=6 || countSlider.enabled) return 28;
    [preset selectItemAtIndex:1]; countSlider.integerValue=36; [picker refreshPicker]; [picker saveOptions:nil];
    [restored repopulate]; if ([[restored valueForKey:@"actors"] count]!=36) return 29;
    sheet=picker.configureSheet; [picker clearCast:nil]; [picker maneSixCast:nil];
    if ([picker draftTotal]!=6) return 22;
    [picker setQuantity:2 forPony:@"Applejack"]; [picker maneSixCast:nil]; if ([picker draftTotal]!=7) return 23;
    [picker setQuantity:2 forPony:@"Princess Luna"];
    only=[picker valueForKey:@"onlyAdded"]; only.state=NSControlStateValueOn; [picker refreshPicker];
    [sheet.contentView layoutSubtreeIfNeeded];
    if (argc>3) {
        NSBitmapImageRep *rep=[sheet.contentView bitmapImageRepForCachingDisplayInRect:sheet.contentView.bounds];
        [sheet.contentView cacheDisplayInRect:sheet.contentView.bounds toBitmapImageRep:rep];
        [[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:[NSString stringWithUTF8String:argv[3]] atomically:YES];
    }
    [testSettings removePersistentDomainForName:testDomain]; [testSettings synchronize];
    NSLog(@"PASS: picker search, hidden selections, editable copy counts, exact custom cast reload, cancel, empty-cast guard, 40-pony cap, presets, and thumbnail rendering.");
    NSLog(@"PASS: %lu characters, %lu assets, 2000 behavior transitions, full-screen and small previews, resize, options.",(unsigned long)catalog.count,(unsigned long)paths.count);
} return 0; }
