#import <Cocoa/Cocoa.h>
#import <ScreenSaver/ScreenSaver.h>
@interface PreviewDelegate : NSObject <NSApplicationDelegate>
@property NSWindow *window;
@property ScreenSaverView *view;
@property NSTimer *timer;
@end
@implementation PreviewDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)note {
    NSString *path=[NSBundle.mainBundle.bundlePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"Desktop Ponies 1.7.saver"];
    NSBundle *bundle=[NSBundle bundleWithPath:path]; NSError *error=nil;
    if (![bundle loadAndReturnError:&error]) { NSLog(@"%@",error); [NSApp terminate:nil]; return; }
    self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,1100,700) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"Desktop Ponies — Preview (⌘, for options)";
    self.view=[[bundle principalClass] alloc]; self.view=[self.view initWithFrame:self.window.contentView.bounds isPreview:NO]; self.view.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable; [self.window.contentView addSubview:self.view];
    NSMenu *menu=[NSMenu new], *appMenu=[NSMenu new]; NSMenuItem *root=[NSMenuItem new]; root.submenu=appMenu; [menu addItem:root];
    NSMenuItem *options=[[NSMenuItem alloc] initWithTitle:@"Options…" action:@selector(options:) keyEquivalent:@","]; options.target=self; [appMenu addItem:options]; [appMenu addItem:[NSMenuItem separatorItem]]; [appMenu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"]; NSApp.mainMenu=menu;
    [self.window center]; [self.window makeKeyAndOrderFront:nil]; [NSApp activateIgnoringOtherApps:YES];
    self.timer=[NSTimer timerWithTimeInterval:1.0/30 repeats:YES block:^(NSTimer *timer) { [self.view animateOneFrame]; }]; [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}
- (void)options:(id)sender { [self.window beginSheet:self.view.configureSheet completionHandler:nil]; }
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)app { return YES; }
@end
int main(int argc,const char **argv) { @autoreleasepool { [NSApplication sharedApplication]; NSApp.activationPolicy=NSApplicationActivationPolicyRegular; PreviewDelegate *delegate=[PreviewDelegate new]; NSApp.delegate=delegate; [NSApp run]; } return 0; }
