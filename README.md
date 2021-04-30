## MONSTR-1.2.1

MONSTR (Multi-cONtrast brain STRipping) is a skull-stripping tool for multi-contrast MR images. This repository contains modified scripts from the original package that allow for MONSTR to work on a Docker image.

For more information on the MONSTR tool itself, visit the package's website - https://www.nitrc.org/projects/monstr/

#### Coming soon
- Dockerfile to build MONSTR Docker image
- Link to MONSTR Docker image on Docker Hub

#### Modifications
Uncomment lines 76 - 78 in `MONSTR.sh` and export the `DISPLAY` variable.

Before:
```bash
# For clusters without GUI, uncomment the following three lines
# DISP=`echo $(( RANDOM %( 300 - 3 + 1 ) + 3 ))`
# Xvfb :${DISP} -screen 0 800x600x8 &
# DISPLAY=":${DISP}"
```
After:
```bash
# For clusters without GUI, uncomment the following three lines
DISP=`echo $(( RANDOM %( 300 - 3 + 1 ) + 3 ))`
Xvfb :${DISP} -screen 0 800x600x8 &
export DISPLAY=":${DISP}"
```

In `run_image_dilate.sh` (line 16) and `run_create_brainmask.sh` (line 55), change the `MCRROOT` variable to the installed Matlab MCR v90 directory.

Before:
```bash
LD_LIBRARY_PATH=.:${MCRROOT}/runtime/glnxa64  ;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/bin/glnxa64 ;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/sys/os/glnxa64;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/sys/opengl/lib/glnxa64;
```
After:
```bash
export MCRROOT=/opt/matlabmcr-2015b/v90
LD_LIBRARY_PATH=.:${MCRROOT}/runtime/glnxa64  ;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/bin/glnxa64 ;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/sys/os/glnxa64;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/sys/opengl/lib/glnxa64;
```
