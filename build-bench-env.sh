procs=24
curdir=`pwd`
cd ..
devdir=`pwd`
cd $curdir

if test -f ./build-bench-env.sh; then
  echo "start; building with $procs concurrency under: $devdir"
else
  echo "error: must run from the toplevel mimalloc-bench directory!"
  exit 1
fi

function phase {
  cd "$curdir"
  echo
  echo
  echo "--------------------------------------------"
  echo $1
  echo "--------------------------------------------"
  echo
}

phase "install packages"

echo "updating package database... (sudo apt update)"
sudo apt update

function aptinstall {
  echo ""
  echo "> sudo apt install $1"
  echo ""
  sudo apt install $1
}

aptinstall "g++ clang unzip dos2unix linuxinfo bc"
aptinstall "cmake python ninja-build autoconf"
aptinstall "libgoogle-perftools-dev libjemalloc-dev libgmp-dev libtbb-dev"


phase "patch shbench"

pushd "bench/shbench"
if test -f sh6bench-new.c; then
  echo "do nothing: bench/shbench/sh6bench-new.c already exists"
else
  wget http://www.microquill.com/smartheap/shbench/bench.zip
  unzip -o bench.zip
  dos2unix sh6bench.patch
  dos2unix sh6bench.c
  patch -p1 -o sh6bench-new.c sh6bench.c sh6bench.patch
fi
if test -f sh8bench-new.c; then
  echo "do nothing: bench/shbench/sh8bench-new.c already exists"
else
  wget http://www.microquill.com/smartheap/SH8BENCH.zip
  unzip -o SH8BENCH.zip
  dos2unix sh8bench.patch
  dos2unix SH8BENCH.C
  patch -p1 -o sh8bench-new.c SH8BENCH.C sh8bench.patch
fi
popd

phase "get Intel PDF manual"

pdfdoc="325462-sdm-vol-1-2abcd-3abcd.pdf"
pushd "$devdir"
if test -f "$pdfdoc"; then
  echo "do nothing: $devdir/$pdfdoc already exists"
else
  wget https://software.intel.com/sites/default/files/managed/39/c5/325462-sdm-vol-1-2abcd-3abcd.pdf
fi
popd

phase "build hoard 3.13"

pushd $devdir
if test -d Hoard; then
  echo "$devdir/Hoard already exists; no need to git clone"
else
  git clone https://github.com/emeryberger/Hoard.git
fi
cd Hoard
git checkout 3.13
cd src
make
sudo make install
popd


phase "build jemalloc 5.2.0"

pushd $devdir
if test -d jemalloc; then
  echo "$devdir/jemalloc already exists; no need to git clone"
else
  git clone https://github.com/jemalloc/jemalloc.git
fi
cd jemalloc
if test -f config.status; then
  echo "$devdir/jemalloc is already configured; no need to reconfigure"
else
  git checkout 5.2.0
  ./autogen.sh
fi
make -j $procs
popd

phase "build rpmalloc 1.3.1"

pushd $devdir
if test -d rpmalloc; then
  echo "$devdir/rpmalloc already exists; no need to git clone"
else
  git clone https://github.com/rampantpixels/rpmalloc.git
fi
cd rpmalloc
if test -f build.ninja; then
  echo "$devdir/rpmalloc is already configured; no need to reconfigure"
else
  git checkout 1.3.1
  python configure.py
fi
ninja
popd

phase "build snmalloc, commit 0b64536b"

pushd $devdir
if test -d snmalloc; then
  echo "$devdir/snmalloc already exists; no need to git clone"
else
  git clone https://github.com/Microsoft/snmalloc.git
fi
cd snmalloc
if test -f release/build.ninja; then
  echo "$devdir/snmalloc is already configured; no need to reconfigure"
else
  git checkout 0b64536b
  mkdir -p release
  cd release
  env CXX=clang++ cmake -G Ninja .. -DCMAKE_BUILD_TYPE=Release
  cd ..
fi
cd release
ninja
popd


phase "build SuperMalloc (commit 709663fb)"

pushd $devdir
if test -d SuperMalloc; then
  echo "$devdir/SuperMalloc already exists; no need to git clone"
else
  git clone https://github.com/kuszmaul/SuperMalloc.git
fi
cd SuperMalloc
git checkout 709663fb
cd release
make
popd


phase "build lean v3.4.1"

pushd $devdir
if test -d lean; then
  echo "$devdir/lean already exists; no need to git clone"
else
  git clone https://github.com/leanprover/lean
fi
cd lean
git checkout v3.4.1
mkdir -p out/release
cd out/release
env CC=gcc CXX=g++ cmake ../../src -DCUSTOM_ALLOCATORS=OFF
make -j $procs
popd

phase "build redis 5.0.3"

pushd "$devdir"
if test -d "redis-5.0.3"; then
  echo "$devdir/redis-5.0.3 already exists; no need to download it"
else
  wget "http://download.redis.io/releases/redis-5.0.3.tar.gz"
  tar xzf "redis-5.0.3.tar.gz"
fi

cd "redis-5.0.3/src"
make USE_JEMALLOC=no MALLOC=libc

popd

phase "build mimalloc variants"

pushd "$devdir"
if test -d "mimalloc"; then
  echo "$devdir/mimalloc already exists; no need to download it"
else
  git clone https://github.com/daanx/mimalloc
fi
cd mimalloc
git checkout dev

echo ""
echo "- build mimalloc release"

mkdir -p out/release
cd out/release
cmake ../..
make
cd ../..

echo ""
echo "- build mimalloc debug"

mkdir -p out/debug
cd out/debug
cmake ../..
make
cd ../..

echo ""
echo "- build mimalloc secure"

mkdir -p out/secure
cd out/secure
cmake ../..
make
cd ../..

phase "build benchmarks"

mkdir -p out/bench
cd out/bench
cmake ../../bench
make
cd ../..

curdir=`pwd`
phase "done in $curdir"

echo "run the cfrac benchmarks as:"
echo "> cd out/bench"
echo "> ../../bench/bench.sh alla cfrac"
echo
echo "to see all options use:"
echo "> ../../bench/bench.sh help"
echo