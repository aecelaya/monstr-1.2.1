#!/bin/bash

if [ $# -lt "6" ]; then
echo "=======================================================================================
./run_create_brainmask.sh NumModalities NumAtlas Modalities WindowSize Patchsize NumCPU OutputDir Volumes

NUMMODALITY   Number of image modalities used for stripping, e.g. if T1, T2
              and  FLAIR images used, NUMMODALITY = 3
NUMATLAS      Number of atlas images. A good number is 2-10. Each atlas image
              must have (T+1) images, T = NUMMODALITY
Modalities    A comma-separated string containing the modalities, 
              Options are T1, T2, PD or FL.
              Example: T1,T1,PD if 3 modalities are used, first two are T1 
              and last one is PD. The atlases must correspond to the 
              modalities as well. E.g. if T1,T1,PD are used, then each 
              of the atlases must also follow the T1,T1,PD order. See below for atlases
WINDOWSIZE    Local search window size for each patch. Enter as a scalar string.
              Typically 5 or 7. 5 means 5x5x5  window will be used. 
PATCHSIZE     Patch size, usually 3x3x1 or 3x3x3. Must be odd number.
              5 takes long time with very little improvement.
NumCPU        Number of parallel processing cores.
OUTPUTDIR     Output directory, where the output mask volume will be written.
Volumes       List of filenames. It should be of the following pattern. Assume
              T1, T2 and FLAIR images used for stripping.
 
              1) First T filesnames should be of T subject modalities, i.e.
              number of subject images is T = NUMMODALITY = 3 
 
              2) Next (T+1)*N = 4N filenames should be of N ( = NumAtlas) atlases
              in the following order,
              First N volumes should be all atlas  T1 images,
              Next N volumes should be all atlas T2 images,
              Next N volumes should be all atlas FLAIR images,
              Last N volumes should be all atlas brainmasks (binary 0-1 volumes)

All volumes must be NIFTI. Atlas images MUST be registered to the subject space.
I recommend ANTS with coarse alignment (~2 min per atlas) to register all the atlas 
T1, T2, FLAIR, brainmasks to the subject space.
======================================================================================="
exit 1
fi
NumModalities=$1
NumAtlas=$2
MODAL=$3
WindowSize=$4
Patchsize=$5
NumCPU=$6
OutputDir=$7


MCR_CACHE_ROOT=`mktemp -d`
exe_name=$0
exe_dir=`dirname "$0"`

export MCRROOT=/opt/matlabmcr-2015b/v90
LD_LIBRARY_PATH=.:${MCRROOT}/runtime/glnxa64 ;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/bin/glnxa64 ;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/sys/os/glnxa64;
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/sys/opengl/lib/glnxa64;

export LD_LIBRARY_PATH;

shift 1
args=
while [ $# -gt 1 ]; do
     token=$7
     args="${args} ${token}" 
     shift
done
echo ${exe_dir}/run_create_brainmask $NumModalities $NumAtlas $MODAL $WindowSize $Patchsize $NumCPU $OutputDir $args
${exe_dir}/run_create_brainmask $NumModalities $NumAtlas $MODAL $WindowSize $Patchsize $NumCPU $OutputDir $args
rm -rf $MCR_CACHE_ROOT


