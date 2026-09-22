// Force inclusion of BLAS backend by explicitly referencing its symbols
// This file must be compiled and linked to ensure network_blas.cc is included

#include <memory>
#include <optional>
#include "neural/factory.h"
#include "neural/network.h"

namespace lczero {

// Declare the MakeBlasNetwork template function from network_blas.cc
template <bool use_eigen>
std::unique_ptr<Network> MakeBlasNetwork(const std::optional<WeightsFile>& w,
                                         const OptionsDict& o);

// Force instantiation of both BLAS network variants
// This creates explicit references that the linker cannot remove
namespace {

// Use a constructor attribute to run before main()
__attribute__((constructor))
static void InitBlasBackends() {
    // Just referencing the function addresses is enough to force linkage
    // We don't actually call them - we just need them to exist
    volatile void* blas_ptr = reinterpret_cast<void*>(&MakeBlasNetwork<false>);
    volatile void* eigen_ptr = reinterpret_cast<void*>(&MakeBlasNetwork<true>);
    (void)blas_ptr;
    (void)eigen_ptr;
}

}  // namespace
}  // namespace lczero

