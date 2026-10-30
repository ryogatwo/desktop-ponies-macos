#import <Cocoa/Cocoa.h>
static NSString * const SaverName=@"Desktop Ponies 1.7.saver";
static BOOL InstallSaver(NSString *source, NSString *directory, NSError **error) {
    NSFileManager *fm=NSFileManager.defaultManager;
    if (![fm createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    NSString *destination=[directory stringByAppendingPathComponent:SaverName];
    NSString *staging=[directory stringByAppendingPathComponent:[@".DesktopPonies-stage-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    NSString *backup=[directory stringByAppendingPathComponent:[@".DesktopPonies-backup-" stringByAppendingString:NSUUID.UUID.UUIDString]];
    if (![fm copyItemAtPath:source toPath:staging error:error]) { [fm removeItemAtPath:staging error:NULL]; return NO; }
    BOOL existing=[fm fileExistsAtPath:destination];
    if (existing && ![fm moveItemAtPath:destination toPath:backup error:error]) { [fm removeItemAtPath:staging error:NULL]; return NO; }
    if (![fm moveItemAtPath:staging toPath:destination error:error]) {
        if (existing) [fm moveItemAtPath:backup toPath:destination error:NULL];
        [fm removeItemAtPath:staging error:NULL]; return NO;
    }
    if (existing) [fm removeItemAtPath:backup error:NULL];
    return YES;
}
@interface InstallerDelegate : NSObject <NSApplicationDelegate>
@property NSWindow *window;
@property NSButton *installButton;
@property NSTextField *status;
@end
@implementation InstallerDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,580,350) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"Install Desktop Ponies 1.7";
    NSTextField *heading=[NSTextField labelWithString:@"Desktop Ponies 1.7"];
    heading.font=[NSFont boldSystemFontOfSize:25]; heading.frame=NSMakeRect(30,282,520,40); [self.window.contentView addSubview:heading];
    NSTextField *description=[NSTextField wrappingLabelWithString:@"Install animated ponies as your Mac’s screensaver.\n\n309 characters · searchable cast picker · exact Mane Six preset\n\nInstalls for your account in Library/Screen Savers. Your saved pony choices, size, and background settings are preserved."];
    description.font=[NSFont systemFontOfSize:14]; description.frame=NSMakeRect(30,115,520,165); [self.window.contentView addSubview:description];
    self.status=[NSTextField wrappingLabelWithString:@"Artwork: Desktop Ponies contributors · CC BY-NC-SA 3.0\nNoncommercial use."];
    self.status.font=[NSFont systemFontOfSize:11]; self.status.frame=NSMakeRect(30,55,520,55); [self.window.contentView addSubview:self.status];
    self.installButton=[NSButton buttonWithTitle:@"Install Screensaver" target:self action:@selector(install:)];
    self.installButton.frame=NSMakeRect(355,18,195,32); self.installButton.keyEquivalent=@"\r"; [self.window.contentView addSubview:self.installButton];
    NSButton *quit=[NSButton buttonWithTitle:@"Close" target:NSApp action:@selector(terminate:)];quit.frame=NSMakeRect(250,18,95,32);[self.window.contentView addSubview:quit];
    [self.window center];[self.window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }
- (void)install:(id)sender {
    NSError *error=nil;
    NSString *source=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:SaverName];
    NSString *directory=[NSHomeDirectory() stringByAppendingPathComponent:@"Library/Screen Savers"];
    self.installButton.enabled=NO;
    if (!InstallSaver(source,directory,&error)) {
        self.installButton.enabled=YES;
        NSAlert *alert=[NSAlert new];alert.messageText=@"The screensaver could not be installed";alert.informativeText=error.localizedDescription?:@"Please try again.";[alert runModal];return;
    }
    self.status.stringValue=@"Installed successfully. In Screen Saver settings, select Desktop Ponies 1.7, then open Options to choose your ponies.";
    self.installButton.title=@"Open Screen Saver Settings";self.installButton.action=@selector(openSettings:);self.installButton.enabled=YES;
}
- (void)openSettings:(id)sender { [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.ScreenSaver-Settings.extension"]]; }
@end
int main(int argc,const char **argv) { @autoreleasepool {
    if (argc==4 && !strcmp(argv[1],"--test-install")) {
        NSError *error=nil;
        if (!InstallSaver([NSString stringWithUTF8String:argv[2]],[NSString stringWithUTF8String:argv[3]],&error)) { NSLog(@"%@",error);return 1; }
        return 0;
    }
    [NSApplication sharedApplication];NSApp.activationPolicy=NSApplicationActivationPolicyRegular;
    InstallerDelegate *delegate=[InstallerDelegate new];NSApp.delegate=delegate;[NSApp run];
}return 0;}
