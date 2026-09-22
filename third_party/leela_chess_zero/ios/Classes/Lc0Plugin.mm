#import "Lc0Plugin.h"
#include "../FlutterLc0/ffi.h"

@implementation Lc0Plugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  if (registrar == NULL) {
    // avoid dead code stripping
    lc0_init();
    lc0_main();
    lc0_stdin_write(NULL);
    lc0_stdout_read();
  }
}
@end

