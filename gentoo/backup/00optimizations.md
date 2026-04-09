# GCC OPTIMIZATIONS
COST="-fvect-cost-model=dynamic -fsimd-cost-model=dynamic"
DEVIRT="-fdevirtualize-speculatively -fdevirtualize-at-ltrans"
FIPA="-fipa-pta -fipa-icf"
FFAST="-fno-math-errno -fno-signed-zeros -fno-trapping-math -faggressive-loop-optimizations" 
FORTRAN="-fstack-arrays"
GRAPHITE="-floop-block -fgraphite-identity -floop-parallelize-all"
SAFE_MATH="-ffinite-loops -fsplit-wide-types-early -ftree-vectorize -fprofile-correction"
MISC="-fwrapv -fno-semantic-interposition -fno-strict-aliasing -fno-common -fno-plt"

# CLANG OPTIMIZATIONS
FFAST="-fno-math-errno -fno-signed-zeros -fno-trapping-math -faggressive-loop-optimizations"
GENERAL="-fno-signed-zeros -fno-trapping-math -faggressive-loop-optimizations"
HARDENING="-fcf-protection -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS -fstack-protector-strong -fstack-clash-protection"
POLLY="-fplugin=LLVMPolly.so -mllvm=-polly -mllvm=-polly-vectorizer=stripmine -mllvm=-polly-omp-backend=LLVM -mllvm=-polly-parallel -mllvm=-polly-num-threads=9 -mllvm=-polly-scheduling=dynamic"

