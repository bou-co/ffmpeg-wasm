#!/bin/bash

rm -rf build build64
rm -rf modules
git submodule sync --recursive
git submodule update --init --recursive --remote
