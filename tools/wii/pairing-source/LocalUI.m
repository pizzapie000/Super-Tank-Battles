// Local app entry for the GPL-2.0-or-later WiimotePairPlus controller.
// Upstream provenance is recorded in UPSTREAM.txt.
#import "ViewController.h"

@interface LocalController : ViewController
@end
@implementation LocalController
- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 600, 330)];
}
@end

@interface LocalDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSWindow *window;
@end
@implementation LocalDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 600, 330) styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"WiimotePair — Wii Remote connection";
    self.window.releasedWhenClosed = NO;
    self.window.contentViewController = [[LocalController alloc] init];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *item = [[NSMenuItem alloc] init];
    [menu addItem:item];
    item.submenu = [[NSMenu alloc] initWithTitle:@"WiimotePair"];
    [item.submenu addItemWithTitle:@"Quit WiimotePair" action:@selector(terminate:) keyEquivalent:@"q"];
    NSApp.mainMenu = menu;
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--ui-test"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            NSCAssert(self.window.contentViewController.view.subviews.count >= 5, @"Pairing interface did not load");
            puts("WiimotePair interface checks: PASS");
            [NSApp terminate:nil];
        });
    }
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }
@end

int main(int argc, const char **argv) {
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "--api-check") == 0) {
            Class coordinator = NSClassFromString(@"IOBluetoothCoreBluetoothCoordinator");
            BOOL available = coordinator != Nil &&
                [coordinator respondsToSelector:NSSelectorFromString(@"sharedInstance")] &&
                [coordinator instancesRespondToSelector:NSSelectorFromString(@"pairPeer:forType:withKey:")] &&
                [IOBluetoothDevicePair instancesRespondToSelector:NSSelectorFromString(@"setUserDefinedPincode:")] &&
                [IOBluetoothDevicePair instancesRespondToSelector:NSSelectorFromString(@"currentPairingType")] &&
                [IOBluetoothDevice instancesRespondToSelector:NSSelectorFromString(@"classicPeer")];
            puts(available ? "WiimotePair API checks: PASS" : "WiimotePair API checks: unsupported macOS Bluetooth API");
            return available ? 0 : 1;
        }
        NSApplication *app = [NSApplication sharedApplication];
        LocalDelegate *delegate = [[LocalDelegate alloc] init];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
    }
    return 0;
}
