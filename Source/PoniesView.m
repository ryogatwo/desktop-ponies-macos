#import <ScreenSaver/ScreenSaver.h>
#import <ImageIO/ImageIO.h>

static double RandomUnit(void) { return arc4random_uniform(1000000)/1000000.0; }
@interface DP16Animation : NSObject
@property NSArray<NSImage *> *frames;
@property NSArray<NSNumber *> *ends;
@property double duration;
@property NSSize size;
- (instancetype)initWithPath:(NSString *)path;
- (NSImage *)frameAt:(double)time once:(BOOL)once;
@end
@implementation DP16Animation
- (instancetype)initWithPath:(NSString *)path {
    if (!(self=[super init])) return nil;
    CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path],NULL);
    if (!source) return nil;
    NSMutableArray *frames=[NSMutableArray array], *ends=[NSMutableArray array];
    for (size_t i=0;i<CGImageSourceGetCount(source);i++) {
        CGImageRef cg=CGImageSourceCreateImageAtIndex(source,i,NULL); if (!cg) continue;
        NSSize size=NSMakeSize(CGImageGetWidth(cg),CGImageGetHeight(cg));
        [frames addObject:[[NSImage alloc] initWithCGImage:cg size:size]]; self.size=size; CGImageRelease(cg);
        NSDictionary *props=CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source,i,NULL));
        NSDictionary *gif=props[(__bridge NSString *)kCGImagePropertyGIFDictionary];
        NSNumber *delay=gif[(__bridge NSString *)kCGImagePropertyGIFUnclampedDelayTime] ?: gif[(__bridge NSString *)kCGImagePropertyGIFDelayTime];
        self.duration += MAX(.02,delay ? delay.doubleValue : .1); [ends addObject:@(self.duration)];
    }
    CFRelease(source); if (!frames.count) return nil; self.frames=frames; self.ends=ends; return self;
}
- (NSImage *)frameAt:(double)t once:(BOOL)once {
    t=once ? MIN(t,self.duration-.0001) : fmod(t,self.duration);
    for (NSUInteger i=0;i<self.ends.count;i++) if (t<self.ends[i].doubleValue) return self.frames[i];
    return self.frames.lastObject;
}
@end
// Anchors in pony.ini are measured from the image's top-left corner.
static NSPoint DPImageCenter(DP16Animation *animation, NSArray *center) {
    double x=[center[0] doubleValue], y=[center[1] doubleValue];
    if (x==0 && y==0) return NSMakePoint(animation.size.width/2,animation.size.height/2);
    return NSMakePoint(x,y);
}

@interface DP16Actor : NSObject
@property NSDictionary *pony, *behavior;
@property DP16Animation *right, *left;
@property double x,y,vx,vy,remaining,elapsed,edgeDwell;
@property BOOL facingRight;
@end
@implementation DP16Actor @end

@interface DP16OptionsContentView : NSView
@end
@implementation DP16OptionsContentView
- (void)drawRect:(NSRect)dirty { [NSColor.windowBackgroundColor setFill]; NSRectFill(self.bounds); [super drawRect:dirty]; }
@end

@interface DP16PickerButton : NSButton
@property NSString *ponyID;
@end
@implementation DP16PickerButton @end
@interface DP16PickerStepper : NSStepper
@property NSString *ponyID;
@end
@implementation DP16PickerStepper @end
@interface DP16QuantityField : NSTextField
@property NSString *ponyID;
@end
@implementation DP16QuantityField @end

@interface DesktopPoniesView16 : ScreenSaverView <NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate, NSSearchFieldDelegate>
@property NSArray *catalog;
@property NSMutableArray<DP16Actor *> *actors;
@property NSCache *images;
@property ScreenSaverDefaults *settings;
@property NSString *resourceRoot;
@property double lastTick, lastSettingsCheck;
@property NSDictionary *loadedSettings;
@property NSWindow *sheet;
@property NSSlider *countSlider,*sizeSlider;
@property NSPopUpButton *castPopup,*backgroundPopup;
@property NSMutableDictionary<NSString *, NSNumber *> *draftCounts;
@property NSArray *filteredCatalog;
@property NSTableView *pickerTable;
@property NSSearchField *searchField;
@property NSButton *onlyAdded, *applyButton;
@property NSTextField *summaryLabel, *randomLabel, *emptyLabel;
@property NSCache *thumbnails;
- (void)repopulate;
@end
@implementation DesktopPoniesView16
- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)preview {
    if (!(self=[super initWithFrame:frame isPreview:preview])) return nil;
    self.animationTimeInterval=1.0/30.0;
    self.resourceRoot=[NSBundle bundleForClass:self.class].resourcePath;
    NSData *data=[NSData dataWithContentsOfFile:[self.resourceRoot stringByAppendingPathComponent:@"ponies.json"]];
    self.catalog=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : @[];
    self.catalog=[self.catalog sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) { return [a[@"id"] localizedStandardCompare:b[@"id"]]; }];
    self.images=[NSCache new]; self.images.countLimit=64;
    self.settings=[ScreenSaverDefaults defaultsForModuleWithName:@"org.desktopponies.mac.saver"];
    [self.settings registerDefaults:@{@"count":@6,@"scale":@2,@"cast":@0,@"background":@0}];
    [self repopulate]; return self;
}
- (BOOL)isOpaque { return YES; }
- (double)spriteScale {
    return MAX(.2,MIN(3.0,[self.settings doubleForKey:@"scale"])) * (self.isPreview ? MAX(.15,MIN(1.0,NSWidth(self.bounds)/1440.0)) : 1.0);
}
- (DP16Animation *)image:(NSString *)relative {
    DP16Animation *a=[self.images objectForKey:relative];
    if (!a) { a=[[DP16Animation alloc] initWithPath:[self.resourceRoot stringByAppendingPathComponent:relative]]; if (a) [self.images setObject:a forKey:relative]; }
    return a;
}
- (void)chooseBehavior:(DP16Actor *)p {
    NSArray *bs=p.pony[@"behaviors"]; double total=0; for (NSDictionary *b in bs) total+=[b[@"weight"] doubleValue];
    double pick=RandomUnit()*total; NSDictionary *chosen=bs.lastObject;
    for (NSDictionary *b in bs) { pick-=[b[@"weight"] doubleValue]; if (pick<=0) { chosen=b; break; } }
    [self beginBehavior:chosen actor:p];
}
- (void)beginBehavior:(NSDictionary *)chosen actor:(DP16Actor *)p {
    p.behavior=chosen; p.right=[self image:chosen[@"right"]]; p.left=[self image:chosen[@"left"]];
    p.elapsed=0; p.remaining=[chosen[@"min"] doubleValue]+RandomUnit()*MAX(0,[chosen[@"max"] doubleValue]-[chosen[@"min"] doubleValue]);
    p.facingRight=RandomUnit()>.5;
    NSString *mode=chosen[@"mode"]; double angle=0;
    if ([mode isEqual:@"vertical_only"]) angle=M_PI_2;
    else if ([mode isEqual:@"horizontal_vertical"]) angle=RandomUnit()>.5?M_PI_2:0;
    else if ([mode containsString:@"diagonal"] || [mode isEqual:@"all"]) angle=(.0833+RandomUnit()*.3333)*M_PI;
    if ([mode isEqual:@"diagonal_horizontal"] && RandomUnit()>.5) angle=0;
    if ([mode isEqual:@"diagonal_vertical"] && RandomUnit()>.5) angle=M_PI_2;
    double speed=[chosen[@"speed"] doubleValue]*100.0/3.0;
    if ([mode isEqual:@"none"] || [mode isEqual:@"mouseover"] || [mode isEqual:@"sleep"]) speed=0;
    p.vx=cos(angle)*speed*(p.facingRight?1:-1); p.vy=sin(angle)*speed*(RandomUnit()>.5?1:-1);
    if (fabs(p.vx)<1e-8) p.vx=0;
    if (fabs(p.vy)<1e-8) p.vy=0;
}
- (void)releaseActor:(DP16Actor *)p directionX:(NSInteger)dx directionY:(NSInteger)dy {
    NSMutableArray *candidates=[NSMutableArray array]; double total=0;
    for (NSDictionary *b in p.pony[@"behaviors"]) {
        NSString *mode=b[@"mode"];
        BOOL diagonal=[mode containsString:@"diagonal"] || [mode isEqual:@"all"];
        BOOL horizontal=diagonal || [mode isEqual:@"horizontal_only"] || [mode isEqual:@"horizontal_vertical"];
        BOOL vertical=diagonal || [mode isEqual:@"vertical_only"] || [mode isEqual:@"horizontal_vertical"];
        if ([b[@"speed"] doubleValue]<=0 || (dx && !horizontal) || (dy && !vertical) || (dx && dy && !diagonal)) continue;
        [candidates addObject:b]; total+=[b[@"weight"] doubleValue];
    }
    if (!candidates.count) return;
    NSMutableArray *brisk=[NSMutableArray array];
    for (NSDictionary *b in candidates) if ([b[@"speed"] doubleValue]>=1) [brisk addObject:b];
    if (brisk.count) { candidates=brisk; total=0; for (NSDictionary *b in candidates) total+=[b[@"weight"] doubleValue]; }
    double pick=RandomUnit()*total; NSDictionary *chosen=candidates.lastObject;
    for (NSDictionary *b in candidates) { pick-=[b[@"weight"] doubleValue]; if (pick<=0) { chosen=b; break; } }
    [self beginBehavior:chosen actor:p];
    double speed=[chosen[@"speed"] doubleValue]*100.0/3.0;
    // Mixed movement modes may randomly choose the wrong axis. Pick an inward
    // vector supported by the selected behavior instead of leaving it on the wall.
    if (dx && dy) { p.vx=dx*speed/M_SQRT2; p.vy=dy*speed/M_SQRT2; }
    else if (dx) { p.vx=dx*speed; p.vy=0; }
    else if (dy) { p.vx=0; p.vy=dy*speed; }
    if (p.vx) p.facingRight=p.vx>0;
    p.edgeDwell=0;
}

- (void)repopulate {
    self.actors=[NSMutableArray array];
    NSSet *mane=[NSSet setWithArray:@[@"Twilight Sparkle",@"Applejack",@"Rainbow Dash",@"Rarity",@"Fluttershy",@"Pinkie Pie"]];
    NSMutableArray *pool=[NSMutableArray array];
    for (NSDictionary *p in self.catalog) if ([self.settings integerForKey:@"cast"]==1 || [mane containsObject:p[@"id"]]) [pool addObject:p];
    if (!pool.count) [pool addObjectsFromArray:self.catalog];
    NSMutableArray *cast=[NSMutableArray array];
    if ([self.settings integerForKey:@"cast"]==2) {
        NSDictionary *counts=[self.settings dictionaryForKey:@"customCounts"];
        for (NSDictionary *pony in self.catalog) {
            NSInteger copies=MAX(0,MIN(40,[counts[pony[@"id"]] integerValue]));
            for (NSInteger j=0;j<copies && cast.count<40;j++) [cast addObject:pony];
        }
    } else {
        NSInteger count=[self.settings integerForKey:@"cast"]==0 ? (NSInteger)pool.count : MAX(1,MIN(40,[self.settings integerForKey:@"count"]));
        for (NSInteger i=0;i<count && pool.count;i++) {
            NSDictionary *pony=pool[(NSUInteger)i<pool.count ? i : arc4random_uniform((uint32_t)pool.count)];
            if ([self.settings integerForKey:@"cast"]==1) pony=pool[arc4random_uniform((uint32_t)pool.count)];
            [cast addObject:pony];
        }
    }
    for (NSDictionary *pony in cast) {
        DP16Actor *p=[DP16Actor new]; p.pony=pony;
        p.x=NSWidth(self.bounds)*(.1+RandomUnit()*.8); p.y=NSHeight(self.bounds)*(.1+RandomUnit()*.8); [self chooseBehavior:p]; [self.actors addObject:p];
    }
    self.loadedSettings=[self settingsSnapshot];
    self.lastTick=0; [self setNeedsDisplay:YES];
}
- (NSDictionary *)settingsSnapshot {
    return @{@"cast":@([self.settings integerForKey:@"cast"]),
             @"count":@([self.settings integerForKey:@"count"]),
             @"scale":@([self.settings doubleForKey:@"scale"]),
             @"background":@([self.settings integerForKey:@"background"]),
             @"customCounts":[self.settings dictionaryForKey:@"customCounts"] ?: @{},
             @"revision":[self.settings stringForKey:@"settingsRevision"] ?: @""};
}
- (void)reloadSettings:(BOOL)force {
    [self.settings synchronize];
    NSDictionary *snapshot=[self settingsSnapshot];
    if (force || ![snapshot isEqual:self.loadedSettings]) [self repopulate];
    self.lastSettingsCheck=NSProcessInfo.processInfo.systemUptime;
}
- (void)startAnimation { [self reloadSettings:YES]; [super startAnimation]; self.lastTick=0; }
- (void)stopAnimation { [super stopAnimation]; self.lastTick=0; }
- (void)animateOneFrame {
    double now=NSProcessInfo.processInfo.systemUptime;
    if (now-self.lastSettingsCheck>=1) [self reloadSettings:NO];
    double dt=self.lastTick ? MIN(.1,MAX(0,now-self.lastTick)) : self.animationTimeInterval; self.lastTick=now;
    double scale=[self spriteScale];
    for (DP16Actor *p in self.actors) {
        p.elapsed+=dt; p.remaining-=dt; if (p.remaining<=0) [self chooseBehavior:p];
        p.x+=p.vx*dt*scale; p.y+=p.vy*dt*scale;
        // Use the union of both facing poses so turning does not move the wall.
        NSPoint right=DPImageCenter(p.right,p.behavior[@"rc"]);
        NSPoint left=DPImageCenter(p.left,p.behavior[@"lc"]);
        double xmin=MAX(right.x,left.x)*scale;
        double xmax=NSWidth(self.bounds)-MAX(p.right.size.width-right.x,p.left.size.width-left.x)*scale;
        double ymin=MAX(p.right.size.height-right.y,p.left.size.height-left.y)*scale;
        double ymax=NSHeight(self.bounds)-MAX(right.y,left.y)*scale;
        if (xmax<=xmin) { p.x=(xmin+xmax)/2; p.vx=0; }
        else {
            if (p.x<xmin) { p.x=xmin; if (p.vx<0) p.vx=-p.vx; }
            else if (p.x>xmax) { p.x=xmax; if (p.vx>0) p.vx=-p.vx; }
            if (p.vx) p.facingRight=p.vx>0;
        }
        if (ymax<=ymin) { p.y=(ymin+ymax)/2; p.vy=0; }
        else if (p.y<ymin) { p.y=ymin; if (p.vy<0) p.vy=-p.vy; }
        else if (p.y>ymax) { p.y=ymax; if (p.vy>0) p.vy=-p.vy; }
        // A new idle or hover behavior can leave a pony stranded on a wall.
        // Let it turn naturally, then choose a moving behavior if it stays there.
        double margin=8*scale;
        NSInteger escapeX=0, escapeY=0;
        if (xmax-xmin>2*margin) {
            if (p.x<=xmin+margin && p.vx<=0) escapeX=1;
            else if (p.x>=xmax-margin && p.vx>=0) escapeX=-1;
        }
        if (ymax-ymin>2*margin) {
            if (p.y<=ymin+margin && p.vy<=0) escapeY=1;
            else if (p.y>=ymax-margin && p.vy>=0) escapeY=-1;
        }
        p.edgeDwell=(escapeX || escapeY) ? p.edgeDwell+dt : 0;
        if (p.edgeDwell>=.8) [self releaseActor:p directionX:escapeX directionY:escapeY];
    }
    [self setNeedsDisplay:YES];
}
- (void)drawRect:(NSRect)dirty {
    NSInteger bg=[self.settings integerForKey:@"background"];
    if (bg==0) { [[NSColor blackColor] setFill]; NSRectFill(self.bounds); }
    else {
        NSColor *top=bg==1?[NSColor colorWithSRGBRed:.13 green:.10 blue:.25 alpha:1]:[NSColor colorWithSRGBRed:.39 green:.69 blue:.83 alpha:1];
        NSColor *bottom=bg==1?[NSColor colorWithSRGBRed:.025 green:.04 blue:.09 alpha:1]:[NSColor colorWithSRGBRed:.78 green:.90 blue:.86 alpha:1];
        [[[NSGradient alloc] initWithStartingColor:bottom endingColor:top] drawInRect:self.bounds angle:90];
    }
    [NSGraphicsContext currentContext].imageInterpolation=NSImageInterpolationNone;
    double scale=[self spriteScale];
    NSArray *sorted=[self.actors sortedArrayUsingComparator:^NSComparisonResult(DP16Actor *a, DP16Actor *b) { return a.y>b.y?NSOrderedAscending:(a.y<b.y?NSOrderedDescending:NSOrderedSame); }];
    for (DP16Actor *p in sorted) {
        DP16Animation *a=p.facingRight?p.right:p.left; if (!a) continue;
        NSPoint center=DPImageCenter(a,p.behavior[p.facingRight?@"rc":@"lc"]);
        NSRect rect=NSMakeRect(p.x-center.x*scale,p.y-(a.size.height-center.y)*scale,a.size.width*scale,a.size.height*scale);
        [[a frameAt:p.elapsed once:[p.behavior[@"once"] boolValue]] drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:NO hints:nil];
    }
    if (!self.actors.count) [([self.settings integerForKey:@"cast"]==2 ? @"Add a pony in Screen Saver Options." : @"Pony assets could not be loaded.") drawAtPoint:NSMakePoint(20,20) withAttributes:@{NSForegroundColorAttributeName:NSColor.whiteColor}];
}
- (BOOL)hasConfigureSheet { return YES; }
- (NSInteger)draftTotal {
    NSInteger total=0; for (NSNumber *n in self.draftCounts.allValues) total+=n.integerValue; return total;
}
- (void)refreshPicker {
    NSString *query=self.searchField.stringValue;
    self.filteredCatalog=[self.catalog filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *p, NSDictionary *bindings) {
        BOOL matches=!query.length || [p[@"id"] rangeOfString:query options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location!=NSNotFound || [p[@"name"] rangeOfString:query options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location!=NSNotFound;
        return matches && (self.onlyAdded.state!=NSControlStateValueOn || [self.draftCounts[p[@"id"]] integerValue]>0);
    }]];
    [self.pickerTable reloadData];
    BOOL custom=self.castPopup.indexOfSelectedItem==2;
    BOOL mane=self.castPopup.indexOfSelectedItem==0;
    if (mane) self.countSlider.doubleValue=6;
    self.countSlider.enabled=self.castPopup.indexOfSelectedItem==1;
    NSInteger total=[self draftTotal];
    self.summaryLabel.stringValue=[NSString stringWithFormat:@"%ld ponies · %lu characters in your cast · maximum 40",(long)total,(unsigned long)self.draftCounts.count];
    self.randomLabel.stringValue=mane?@"6 ponies · one of each Mane Six character":custom?@"Using exact copies from your cast below":[NSString stringWithFormat:@"%ld ponies chosen from this preset",(long)llround(self.countSlider.doubleValue)];
    self.applyButton.enabled=!custom || total>0;
    self.emptyLabel.hidden=self.filteredCatalog.count>0;
    self.emptyLabel.stringValue=query.length?@"No characters match your search.":@"Your cast is empty. Turn off Only added to browse.";
}
- (NSImage *)thumbnail:(NSDictionary *)pony {
    NSString *identifier=pony[@"id"]; NSImage *image=[self.thumbnails objectForKey:identifier]; if (image) return image;
    NSDictionary *behavior=[pony[@"behaviors"] firstObject];
    for (NSDictionary *b in pony[@"behaviors"]) if ([b[@"speed"] doubleValue]==0) { behavior=b; break; }
    NSString *path=[self.resourceRoot stringByAppendingPathComponent:behavior[@"right"]];
    CGImageSourceRef source=CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path],NULL);
    if (source) { CGImageRef cg=CGImageSourceCreateImageAtIndex(source,0,NULL); if (cg) { image=[[NSImage alloc] initWithCGImage:cg size:NSZeroSize]; CGImageRelease(cg); } CFRelease(source); }
    if (image) [self.thumbnails setObject:image forKey:identifier]; return image;
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return self.filteredCatalog.count; }
- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)column row:(NSInteger)row {
    NSDictionary *pony=self.filteredCatalog[row]; NSString *identifier=pony[@"id"]; NSInteger quantity=[self.draftCounts[identifier] integerValue];
    if ([column.identifier isEqual:@"add"]) {
        DP16PickerButton *check=[[DP16PickerButton alloc] initWithFrame:NSMakeRect(0,0,60,48)]; check.title=@""; check.buttonType=NSButtonTypeSwitch; check.state=quantity>0?NSControlStateValueOn:NSControlStateValueOff; check.ponyID=identifier; check.target=self; check.action=@selector(togglePony:); [check setAccessibilityLabel:[@"Add " stringByAppendingString:identifier]]; return check;
    }
    if ([column.identifier isEqual:@"pony"]) {
        NSTableCellView *cell=[[NSTableCellView alloc] initWithFrame:NSMakeRect(0,0,column.width,48)];
        NSImageView *image=[[NSImageView alloc] initWithFrame:NSMakeRect(0,2,62,44)]; image.image=[self thumbnail:pony]; image.imageScaling=NSImageScaleProportionallyUpOrDown; cell.imageView=image; [cell addSubview:image];
        NSTextField *name=[NSTextField labelWithString:identifier]; name.frame=NSMakeRect(76,14,column.width-82,22); name.font=[NSFont systemFontOfSize:13]; name.lineBreakMode=NSLineBreakByTruncatingTail; name.toolTip=identifier; cell.textField=name; [cell addSubview:name]; return cell;
    }
    NSView *cell=[[NSView alloc] initWithFrame:NSMakeRect(0,0,column.width,48)];
    DP16QuantityField *field=[[DP16QuantityField alloc] initWithFrame:NSMakeRect(8,12,44,24)]; field.ponyID=identifier; field.integerValue=quantity; field.alignment=NSTextAlignmentCenter; field.delegate=self;
    NSNumberFormatter *formatter=[NSNumberFormatter new]; formatter.numberStyle=NSNumberFormatterDecimalStyle; formatter.allowsFloats=NO; formatter.minimum=@0; formatter.maximum=@40; field.formatter=formatter; [field setAccessibilityLabel:[@"Copies of " stringByAppendingString:identifier]]; [cell addSubview:field];
    DP16PickerStepper *stepper=[[DP16PickerStepper alloc] initWithFrame:NSMakeRect(58,10,20,28)]; stepper.ponyID=identifier; stepper.minValue=0; stepper.maxValue=40; stepper.integerValue=quantity; stepper.valueWraps=NO; stepper.target=self; stepper.action=@selector(stepQuantity:); [stepper setAccessibilityLabel:[@"Copies of " stringByAppendingString:identifier]]; [cell addSubview:stepper]; return cell;
}
- (void)setQuantity:(NSInteger)quantity forPony:(NSString *)identifier {
    // Count limits apply across the entire cast, including characters hidden by search.
    NSInteger existing=[self.draftCounts[identifier] integerValue];
    NSInteger allowed=MAX(0,40-([self draftTotal]-existing));
    NSInteger clamped=MAX(0,MIN(allowed,quantity));
    if (clamped) self.draftCounts[identifier]=@(clamped); else [self.draftCounts removeObjectForKey:identifier];
    [self.castPopup selectItemAtIndex:2]; [self refreshPicker];
    if (quantity>allowed) self.summaryLabel.stringValue=@"Cast limit reached: 40 ponies. Remove a copy before adding more.";
}
- (void)togglePony:(DP16PickerButton *)sender { [self.sheet makeFirstResponder:nil]; [self setQuantity:sender.state==NSControlStateValueOn?1:0 forPony:sender.ponyID]; }
- (void)stepQuantity:(DP16PickerStepper *)sender { [self.sheet makeFirstResponder:nil]; [self setQuantity:sender.integerValue forPony:sender.ponyID]; }
- (void)controlTextDidEndEditing:(NSNotification *)notification {
    if ([notification.object isKindOfClass:DP16QuantityField.class]) { DP16QuantityField *field=notification.object; [self setQuantity:field.integerValue forPony:field.ponyID]; }
}
- (void)controlTextDidChange:(NSNotification *)notification { if (notification.object==self.searchField) [self refreshPicker]; }
- (void)pickerFilterChanged:(id)sender { [self.sheet makeFirstResponder:nil]; [self refreshPicker]; }
- (void)clearCast:(id)sender { [self.sheet makeFirstResponder:nil]; [self.draftCounts removeAllObjects]; [self.castPopup selectItemAtIndex:2]; [self refreshPicker]; }
- (void)maneSixCast:(id)sender {
    [self.sheet makeFirstResponder:nil]; BOOL limit=NO;
    for (NSString *identifier in @[@"Twilight Sparkle",@"Applejack",@"Rainbow Dash",@"Rarity",@"Fluttershy",@"Pinkie Pie"]) {
        if ([self.draftCounts[identifier] integerValue]>0) continue;
        if ([self draftTotal]>=40) { limit=YES; continue; }
        self.draftCounts[identifier]=@1;
    }
    [self.castPopup selectItemAtIndex:2]; [self refreshPicker];
    if (limit) self.summaryLabel.stringValue=@"Cast limit reached: remove copies to add the rest of the Mane Six.";
}
- (NSTextField *)label:(NSString *)text frame:(NSRect)frame {
    NSTextField *label=[NSTextField labelWithString:text]; label.frame=frame; [self.sheet.contentView addSubview:label]; return label;
}
- (NSWindow *)configureSheet {
    [self.settings synchronize];
    if (!self.sheet) {
        self.sheet=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,760,650) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO]; self.sheet.title=@"Desktop Ponies 1.6 — Build your cast"; self.sheet.contentView=[[DP16OptionsContentView alloc] initWithFrame:NSMakeRect(0,0,760,650)];
        [self label:@"Choose a preset or add your own ponies" frame:NSMakeRect(24,605,710,24)].font=[NSFont boldSystemFontOfSize:17];
        self.castPopup=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(24,563,230,28) pullsDown:NO]; [self.castPopup addItemsWithTitles:@[@"Mane Six preset",@"Random from all characters",@"My custom cast"]]; self.castPopup.target=self; self.castPopup.action=@selector(pickerFilterChanged:);
        self.countSlider=[NSSlider sliderWithValue:6 minValue:1 maxValue:40 target:self action:@selector(pickerFilterChanged:)]; self.countSlider.frame=NSMakeRect(275,565,180,24); self.countSlider.numberOfTickMarks=40; self.countSlider.allowsTickMarkValuesOnly=YES;
        self.randomLabel=[self label:@"" frame:NSMakeRect(470,561,266,32)]; self.randomLabel.font=[NSFont systemFontOfSize:11]; self.randomLabel.maximumNumberOfLines=2;
        self.searchField=[[NSSearchField alloc] initWithFrame:NSMakeRect(24,515,450,28)]; self.searchField.placeholderString=[NSString stringWithFormat:@"Search %lu characters…",(unsigned long)self.catalog.count]; self.searchField.delegate=self; [self.searchField setAccessibilityLabel:@"Search characters"];
        self.onlyAdded=[NSButton checkboxWithTitle:@"Only added" target:self action:@selector(pickerFilterChanged:)]; self.onlyAdded.frame=NSMakeRect(490,518,115,24);
        NSButton *mane=[NSButton buttonWithTitle:@"Add Mane Six" target:self action:@selector(maneSixCast:)]; mane.frame=NSMakeRect(610,514,126,30); mane.toolTip=@"Add any missing Mane Six characters while keeping your existing cast.";
        NSScrollView *scroll=[[NSScrollView alloc] initWithFrame:NSMakeRect(24,164,712,340)]; scroll.borderType=NSBezelBorder; scroll.hasVerticalScroller=YES; scroll.autohidesScrollers=YES;
        self.pickerTable=[[NSTableView alloc] initWithFrame:scroll.bounds]; self.pickerTable.rowHeight=48; self.pickerTable.intercellSpacing=NSMakeSize(0,0); self.pickerTable.usesAlternatingRowBackgroundColors=YES; self.pickerTable.allowsColumnReordering=NO; self.pickerTable.selectionHighlightStyle=NSTableViewSelectionHighlightStyleNone; self.pickerTable.dataSource=self; self.pickerTable.delegate=self;
        NSArray *ids=@[@"add",@"pony",@"copies"], *titles=@[@"Add",@"Character",@"Copies"], *widths=@[@60,@540,@94];
        for (NSUInteger i=0;i<ids.count;i++) { NSTableColumn *c=[[NSTableColumn alloc] initWithIdentifier:ids[i]]; c.title=titles[i]; c.width=[widths[i] doubleValue]; c.resizingMask=NSTableColumnNoResizing; [self.pickerTable addTableColumn:c]; }
        scroll.documentView=self.pickerTable; [self.sheet.contentView addSubview:scroll];
        self.emptyLabel=[self label:@"" frame:NSMakeRect(85,300,590,30)]; self.emptyLabel.alignment=NSTextAlignmentCenter; self.emptyLabel.textColor=NSColor.secondaryLabelColor;
        self.summaryLabel=[self label:@"" frame:NSMakeRect(24,131,568,24)]; self.summaryLabel.font=[NSFont systemFontOfSize:12];
        NSButton *clear=[NSButton buttonWithTitle:@"Clear cast" target:self action:@selector(clearCast:)]; clear.frame=NSMakeRect(624,129,112,28);
        [self label:@"Sprite size" frame:NSMakeRect(24,89,76,24)]; self.sizeSlider=[NSSlider sliderWithValue:2 minValue:.5 maxValue:3 target:nil action:nil]; self.sizeSlider.frame=NSMakeRect(103,90,190,24);
        [self label:@"Background" frame:NSMakeRect(333,89,90,24)]; self.backgroundPopup=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(425,86,170,28) pullsDown:NO]; [self.backgroundPopup addItemsWithTitles:@[@"Black",@"Twilight",@"Daylight"]];
        NSTextField *credit=[self label:@"Artwork: Desktop Ponies contributors · CC BY-NC-SA 3.0" frame:NSMakeRect(24,24,480,20)]; credit.font=[NSFont systemFontOfSize:10]; credit.textColor=NSColor.secondaryLabelColor;
        NSButton *cancel=[NSButton buttonWithTitle:@"Cancel" target:self action:@selector(cancelOptions:)]; cancel.frame=NSMakeRect(534,19,92,32); cancel.keyEquivalent=@"\033";
        self.applyButton=[NSButton buttonWithTitle:@"Apply" target:self action:@selector(saveOptions:)]; self.applyButton.frame=NSMakeRect(636,19,100,32); self.applyButton.keyEquivalent=@"\r";
        for (NSView *v in @[self.castPopup,self.countSlider,self.searchField,self.onlyAdded,mane,clear,self.sizeSlider,self.backgroundPopup,cancel,self.applyButton]) [self.sheet.contentView addSubview:v];
        self.thumbnails=[NSCache new]; self.thumbnails.countLimit=320;
    }
    // Each presentation starts from saved values; Cancel discards the previous draft.
    self.draftCounts=[NSMutableDictionary dictionary]; NSDictionary *saved=[self.settings dictionaryForKey:@"customCounts"];
    for (NSDictionary *p in self.catalog) { NSInteger n=MAX(0,MIN(40,[saved[p[@"id"]] integerValue])); n=MIN(n,40-[self draftTotal]); if (n) self.draftCounts[p[@"id"]]=@(n); }
    if (!saved) for (DP16Actor *a in self.actors) self.draftCounts[a.pony[@"id"]]=@([self.draftCounts[a.pony[@"id"]] integerValue]+1);
    [self.castPopup selectItemAtIndex:MAX(0,MIN(2,[self.settings integerForKey:@"cast"]))];
    self.countSlider.doubleValue=MAX(1,MIN(40,[self.settings integerForKey:@"count"])); self.sizeSlider.doubleValue=[self.settings doubleForKey:@"scale"];
    [self.backgroundPopup selectItemAtIndex:MAX(0,MIN(2,[self.settings integerForKey:@"background"]))]; self.searchField.stringValue=@""; self.onlyAdded.state=NSControlStateValueOff; [self refreshPicker]; return self.sheet;
}
- (void)cancelOptions:(id)sender { [self.sheet.sheetParent endSheet:self.sheet]; [self.sheet orderOut:nil]; }
- (void)saveOptions:(id)sender {
    if (![self.sheet makeFirstResponder:nil]) return;
    if (self.castPopup.indexOfSelectedItem==2 && ![self draftTotal]) return;
    [self.settings setObject:[self.draftCounts copy] forKey:@"customCounts"];
    [self.settings setInteger:(NSInteger)round(self.countSlider.doubleValue) forKey:@"count"]; [self.settings setDouble:self.sizeSlider.doubleValue forKey:@"scale"]; [self.settings setInteger:self.castPopup.indexOfSelectedItem forKey:@"cast"]; [self.settings setInteger:self.backgroundPopup.indexOfSelectedItem forKey:@"background"]; [self.settings setObject:NSUUID.UUID.UUIDString forKey:@"settingsRevision"]; [self.settings synchronize];
    [self repopulate]; [self.sheet.sheetParent endSheet:self.sheet]; [self.sheet orderOut:nil];
}
@end
