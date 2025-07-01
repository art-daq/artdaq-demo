#!/bin/bash

spack load lcov || exit 1
export USE_GCOV=1

cp srcs/CMakePresets.json{,.bak}
sed -i 's/RelWithDebInfo/Debug/g' srcs/CMakePresets.json
spack mpd build -G Ninja --clean -j$CETPKG_J

lcov -d . --zerocounters
lcov -c --ignore-errors mismatch --keep-going -i -d . -o artdaq.base

spack mpd test

lcov -d . --ignore-errors mismatch --keep-going --capture --output-file artdaq.info
lcov -a artdaq.base -a artdaq.info --output-file artdaq.total
lcov --remove artdaq.total '/cvmfs/*' 'boost/*' '*/spack/opt/spack/*' '*/spack/var/spack/*' '/usr/include/curl/*' --output-file artdaq.info.cleaned
genhtml -o coverage artdaq.info.cleaned

mv srcs/CMakePresets.json{.bak,}
