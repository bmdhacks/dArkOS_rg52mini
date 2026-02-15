#!/bin/bash

for IMAGE in *.img
do
  # Remove stale archives so a rebuild always produces a fresh archive
  rm -f ${IMAGE}.7z ${IMAGE}.7z.*
  7z a -v1950m ${IMAGE}.7z ${IMAGE}
  #xz --keep -z -9 -T0 -M 80% ${IMAGE}
done
