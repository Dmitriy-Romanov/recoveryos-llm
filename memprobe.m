// GPU wired-memory probe: prints Metal recommendedMaxWorkingSetSize ("available").
// Portable: links only Metal + libobjc + libSystem (all present in recoveryOS).
#include <Foundation/Foundation.h>
#include <Metal/Metal.h>
#include <stdio.h>

int main(void) {
    id<MTLDevice> d = MTLCreateSystemDefaultDevice();
    if (!d) { fprintf(stderr, "no Metal device\n"); return 1; }
    printf("available_GiB: %.2f\n", (double)d.recommendedMaxWorkingSetSize / 1073741824.0);
    printf("this_process_GiB: %.2f\n", (double)d.currentAllocatedSize / 1073741824.0);
    return 0;
}
