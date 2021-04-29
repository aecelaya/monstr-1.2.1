#!/bin/bash
exe_name=$0
exe_dir=`dirname "$0"`
if [ $# -lt "3" ]; then
  echo "----------------------------------------------------------------------------------------------"
  echo "Usage:"
  echo "./run_image_dilate.sh inputvolumename outputvolumename dilation_radius"
  echo "Input and outvolume name should be NIFTI"
  echo "----------------------------------------------------------------------------------------------"
  exit 1
fi
  INPUT=$1 
  OUTPUT=$2
  RAD=$3
  
  export MCRROOT=/opt/matlabmcr-2015b/v90
  LD_LIBRARY_PATH=.:${MCRROOT}/runtime/glnxa64  ;
  LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/bin/glnxa64 ;
  LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/sys/os/glnxa64;
  LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${MCRROOT}/sys/opengl/lib/glnxa64;

  export LD_LIBRARY_PATH;

  echo "${exe_dir}"/image_dilate $INPUT $OUTPUT $RAD
  "${exe_dir}"/image_dilate $INPUT $OUTPUT $RAD


