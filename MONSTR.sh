#!/bin/bash
if [ $# -lt 5 ];then
echo "MONSTR.sh --t1 T1_IMAGE --t2 T2_IMAGE --fl FLAIR_IMAGE --pd PD_IMAGE --swi SWI_IMAGE
     --o OutputDir --atlasdir AtlasDir --natlas NumAtlas --rad SearchRadius --clean --reg --robust --ncpu NumCPU --fast

Required arguments:

T1_IMAGE      T1-w image with skull

T2_IMAGE      T2-w image with skull, need not be registered to the T1. (optional)

FL_IMAGE      FLAIR image with skull, need not be registered to the T1.  (optional)

PD_IMAGE      PD-w image with skull, need not be registered to the T1.  (optional)

SWI_IMAGE     SWI image with skull, need not be registered to the T1.  (optional)

              This also works as a single channel stripping script, i.e. at least one of
              the T1, T2, PD, FL, SWI are required.
              ** If T1 is present, first channel must be T1.
              ** If T1 is not mentioned, then the first mentioned channel is used
              ** to register atlases, and then transformation is used for next channels.

OutputDir     Output directory where the result mask will be written.

AtlasDir      Atlas directory, where atlasX_T1.nii,atlasX_T2.nii, atlasX_PD.nii, atlas_SWI.nii,
              atlasX_FL.nii, atlasX_brainmask.nii files are kept. X = 1,2,3.
              Not all modalities are required, but they should correspond with the modalities
              of the subject images. The naming convention (i.e. atlasX_YY.nii, X=1,2,3
              YY=T1,T2,PD,FL,SWI) must be strictly followed.

NumAtlas      Number of atlases to be used. Usually 4 works well. The atlas directory must
              contain these number of atlases. Default is 4.

SearchRadius  Search radius for atlas patches, usually 5-9 works well. Default is 5.

Optional Arguments:

--clean       Cleaning temporary files. If this argument is mentioned, the temporary files
              will be deleted. If not mentioned, temporary files will be retained (default).
              Temporary files are kept in a separate directory inside OutputDir

--reg         Use this flag if the T2/PD/FLAIR images are already registered to the
              T1. If not mentioned, then the T2/PD/FLAIR images WILL be registered to the T1.
              ** This option works if and only if T1 image is provided. Otherwise, all input
              ** modalities must be co-registered, and don't use this option.

--robust      Atlases are registered to the subject using a more robust approach. a), necks
              from the subject and atlases are removed, b) the background noises are removed
              from the images, c) then the atlas is registered to the subjet. It takes more
              time, and usually not necessary. In future, this will be default.

--ncpu        Number of processors to be used for parallel processing. Recommended is at least 8.
              If not mentioned, all availabe processors will be used.

--fast        If --fast option is mentioned, images will be subsampled. The brainmask will be generated
              on a low resolution image, and upsampled to the original resolution.
              Default is off, i.e. brainmask will be created on original images.

All files must be NIFTI(.nii). nii.gz files are not acceptable. The output is the brainmask
in the orientation of the T1 image.

This script requires AFNI, FSL, ANTs to be installed and added to PATH environment variables."
exit 1
fi

TEMP=`getopt -o ab:c:: --long t1:,t2:,fl:,pd:,swi:,reg,clean,robust,natlas:,atlasdir:,o:,ncpu:,rad:,fast \
     -n 'example bash' -- "$@"`

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

# For clusters without GUI, uncomment the following three lines
DISP=`echo $(( RANDOM %( 300 - 3 + 1 ) + 3 ))`
Xvfb :${DISP} -screen 0 800x600x8 &
export DISPLAY=":${DISP}"

this_dir="$0"
this_dir=`dirname ${this_dir}`
this_dir=`readlink -f ${this_dir}`

MIPAVDIR=$this_dir/mipav700
JAVA=$MIPAVDIR/jre/bin/java
PLUGINDIR=$this_dir/JIST-CRUISE-2016Mar25-12-05PM
export mipavjava="$JAVA -classpath $PLUGINDIR:$MIPAVDIR:`find $MIPAVDIR -name \*.jar | sed 's/jar/jar:/g' | tr -d '\n' | sed 's/^://'`"


red=`tput setaf 5`
green=`tput setaf 2`
reset=`tput sgr0`
FSLOUTPUTTYPE=NIFTI
T1=
T2=
FL=
PD=
SWI=
NUMCPU=
NUMCPUT=`$this_dir/GetNumCores.sh`
CLEAN=false
ATLASROOT=
ISREG=false
RAD=5
NUMATLAS=
ROBUSTREG=false
FAST=false


while true ; do
    case "$1" in
        --t1) T1="$2" ;T1=`readlink -f $T1`; shift 2 ;;
        --t2) T2="$2" ;T2=`readlink -f $T2`; shift 2 ;;
        --fl) FL="$2" ;FL=`readlink -f $FL`; shift 2 ;;
        --pd) PD="$2" ;PD=`readlink -f $PD`; shift 2 ;;
        --swi) SWI="$2" ;SWI=`readlink -f $SWI`; shift 2 ;;
        --reg) ISREG=true ; shift ;;
        --clean) CLEAN=true ; shift ;;
        --robust) ROBUSTREG=true ; shift ;;
        --natlas) NUMATLAS="$2" ; shift 2 ;;
        --ncpu) NUMCPU="$2" ; shift 2 ;;
        --atlasdir) ATLASROOT="$2" ;ATLASROOT=`readlink -f $ATLASROOT`; shift 2 ;;
        --rad) RAD="$2" ; shift 2 ;;
        --fast) FAST=true ; shift ;;
        --o) OUTPUTDIR="$2" ;OUTPUTDIR=`readlink -f $OUTPUTDIR`; shift 2 ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 1 ;;
    esac
done


AP=`which antsRegistration`
AP=`readlink -f $AP`
if [ -f "$AP" ];then
    AP=`dirname $AP`
    echo "${green}I found ANTs installation at $AP $reset"
else
    echo "${red}I did not find ANTs in your path. Please install ANTs and add the bin directory to your PATH. $reset"
    exit 1
fi

# If fast option is specified, T2/PD/FLAIR is again registered to the low res 1.5mm iso T1,
# although there may have been pre-registration
# Simply a hack, better option will be to check "reg" flag and avoid this
if [ "$FAST" == "true" ];then
    ISREG=false
fi

START=$(date +%s)

if [ x"$NUMATLAS" == "x" ];then
    NUMATLAS=4
    echo "Default number of atlases: ${green}$NUMATLAS $reset"
else
    echo "Number of atlases: ${green}$NUMATLAS $reset"
fi

if [ x"$NUMCPU" == "x" ];then
    NUMCPU=$NUMCPUT
    echo "${red}Number of processors is not mentioned. Using all available $NUMCPU processors. $reset"
else
    echo "Number of processors to be used : ${green}$NUMCPU $reset (total available $NUMCPUT)"
fi
ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=$NUMCPU

if [ x"$ATLASROOT" == "x" ];then
    echo "${red}Atlas directory is  not mentioned. Exiting. $reset"
    exit 1
else
  echo "Atlas directory : ${green}$ATLASROOT$reset"
fi

if [ "x" != x"$T1" ];then
    echo "T1 :${green} $T1$reset"
else
    ISREG=true
    echo "${red}***********************************************************************************${reset}"
    echo "${red}WARNING: T1 image is not provided. I am assuming all modalities are co-registered. $reset "
    echo "${red}WARNING: If the other modalities (e.g. T2/PD/FL are no co-registered, please register them first. $reset"
    echo "${red}***********************************************************************************${reset}"
fi

if [ "x" != x"$T2" ];then
  echo "T2 :${green} $T2$reset"
  A=`ls $ATLASROOT/atlas1_T2.nii`
  if [ ! -f "$A" ];then
    echo "${red}ERROR: Subject has T2, but the atlas directory does not contain T2 images. Exiting.$reset"
    exit
  fi
fi
if [ "x" != x"$PD" ];then
  echo "PD :${green} $PD$reset"
  A=`ls $ATLASROOT/atlas1_PD.nii`
  if [ ! -f "$A" ];then
    echo "${red}ERROR: Subject has PD, but the atlas directory does not contain PD images. Exiting.$reset"
    exit
  fi
fi
if [ "x" != x"$FL" ];then
  echo "FL :${green} $FL$reset"
  A=`ls $ATLASROOT/atlas1_FL.nii`
  if [ ! -f "$A" ];then
    echo "${red}ERROR: Subject has FLAIR, but the atlas directory does not contain FLAIR images. Exiting.$reset"
    exit
  fi
fi
if [ "x" != x"$SWI" ];then
  echo "SWI :${green} $SWI $reset"
  A=`ls $ATLASROOT/atlas1_SWI.nii`
  if [ ! -f "$A" ];then
    echo "${red}ERROR: Subject has SWI, but the atlas directory does not contain SWI images. Exiting.$reset"
    exit
  fi
fi

echo "Output directory : ${green}$OUTPUTDIR $reset"

if [ "x" == x"$OUTPUTDIR" ];then
  echo "${red}ERROR: Output directory not mentioned. Exiting.$reset"
  exit 1
fi

if [ "$CLEAN" == "true" ];then
  echo "${red}Temporary files will be deleted.$reset"
else
    echo "${green}Temporary files will be kept.$reset"
fi

if [ "$ISREG" == "false" ];then
  echo "${green}Images are not co-registered. T2/PD/FLAIR will be rigidly registered to the T1. $reset"
else
    echo "${red}Images are assumed to be registered. T2/PD/FLAIR will not be registered again to the T1. $reset"
fi


if [ "x" != x"$T1" ];then
    ID=`basename $T1`
elif [ "x" != x"$T2" ];then
    ID=`basename $T2`
elif [ "x" != x"$PD" ];then
    ID=`basename $PD`
elif [ "x" != x"$SWI" ];then
    ID=`basename $SWI`
else
    ID=`basename $FL`

fi
#ID=${ID%.*}
ID=`remove_ext $ID`
A=$OUTPUTDIR/"$ID"_MultiModalStripMask.nii
B=$OUTPUTDIR/"$ID"_MultiModalStripMask.nii.gz
if [ -f "$A" ] || [ -f "$B" ];then
  echo "${red}------------------------------------------------------------------"
  echo "ERROR: The following file(s) already exits. I will not overwrite."
  echo "If you want to rerun, please delete this file and start over."
  echo $A
  echo $B
  echo "------------------------------------------------------------------$reset"
  exit 1
fi

NUMMODAL=0

# Creating a temporary directory in the output directory
# workingdir=`mktemp -d`
TMPDIR=
workingdir=`mktemp -d -p $OUTPUTDIR "$ID".XXXX`
chmod a+rx $workingdir
echo "Working directory : ${green}$workingdir$reset"
echo "cd $workingdir"
cd $workingdir


if [ "x" != x"$T1" ];then
    fslchfiletype NIFTI $T1 ./t1.nii
    ORIT1=`3dinfo -orient t1.nii`
    if [ "$ORIT1" != "RAI" ];then
      3dresample -orient RAI -inset t1.nii -prefix temp.nii
      mv -vf temp.nii t1.nii
    fi
    NUMMODAL=$((NUMMODAL+1))
    if [ "$FAST" == "true" ];then
        3dresample -dxyz 1.5 1.5 1.5 -inset t1.nii -prefix t1_sub.nii
        mv -vf t1_sub.nii t1.nii
    fi
fi


if [ "x" != x"$T2" ];then
  fslchfiletype NIFTI $T2 ./t2.nii
  ORI=`3dinfo -orient t2.nii`
  if [ "$ORI" != "RAI" ];then
    3dresample -orient RAI -inset t2.nii -prefix temp.nii
    mv -vf temp.nii t2.nii
  fi
  NUMMODAL=$((NUMMODAL+1))
    if [ "$FAST" == "true" ] && [ ! -f "$T1" ];then
        3dresample -dxyz 1.5 1.5 1.5 -inset t2.nii -prefix t2_sub.nii
        mv -vf t2_sub.nii t2.nii
    fi
fi

if [ "x" != x"$PD" ];then
  fslchfiletype NIFTI $PD pd.nii
  ORI=`3dinfo -orient pd.nii`
  if [ "$ORI" != "RAI" ];then
    3dresample -orient RAI -inset pd.nii -prefix temp.nii
    mv -vf temp.nii pd.nii
  fi
  NUMMODAL=$((NUMMODAL+1))
  if [ "$FAST" == "true" ] && [ ! -f "$T1" ] && [ ! -f "$T2" ];then
        3dresample -dxyz 1.5 1.5 1.5 -inset pd.nii -prefix pd_sub.nii
        mv -vf pd_sub.nii pd.nii
  fi
fi

if [ "x" != x"$FL" ];then
  fslchfiletype NIFTI $FL fl.nii
  ORI=`3dinfo -orient fl.nii`
  if [ "$ORI" != "RAI" ];then
    3dresample -orient RAI -inset fl.nii -prefix temp.nii
    mv -vf temp.nii fl.nii
  fi
  NUMMODAL=$((NUMMODAL+1))
  if [ "$FAST" == "true" ] && [ ! -f "$T1" ] && [ ! -f "$T2" ] && [ ! -f "$PD" ];then
        3dresample -dxyz 1.5 1.5 1.5 -inset fl.nii -prefix fl_sub.nii
        mv -vf fl_sub.nii fl.nii
  fi
fi

if [ "x" != x"$SWI" ];then
  fslchfiletype NIFTI $SWI sw.nii
  ORI=`3dinfo -orient sw.nii`
  if [ "$ORI" != "RAI" ];then
    3dresample -orient RAI -inset sw.nii -prefix temp.nii
    mv -vf temp.nii sw.nii
  fi
  NUMMODAL=$((NUMMODAL+1))
  if [ "$FAST" == "true" ] && [ ! -f "$T1" ] && [ ! -f "$T2" ] && [ ! -f "$PD" ] && [ ! -f "$FL" ];then
        3dresample -dxyz 1.5 1.5 1.5 -inset sw.nii -prefix sw_sub.nii
        mv -vf sw_sub.nii sw.nii
  fi
fi


echo "Number of image modalities : ${green}$NUMMODAL $reset"

if [ "x" != x"$T1" ];then
    echo N4BiasFieldCorrection -d 3 -i t1.nii -o t1.nii -s 3 -c [ 50x50x50x50,0.00001] -b [ 150]
    N4BiasFieldCorrection -d 3 -i t1.nii -o t1.nii -s 3 -c [ 50x50x50x50,0.00001] -b [ 150] &>/dev/null
fi

if [ "x" != x"$T2" ];then
  echo N4BiasFieldCorrection -d 3 -i t2.nii -o t2.nii -s 3 -c [ 50x50x50x50,0.00001] -b [ 150]
  N4BiasFieldCorrection -d 3 -i t2.nii -o t2.nii -s 3 -c [ 50x50x50x50,0.00001] -b [ 150] &>/dev/null
  if [ "$ISREG" == "false" ];then
    echo antsaffine.sh t1.nii t2.nii t2_reg.nii $NUMCPU
    $this_dir/antsaffine.sh t1.nii t2.nii t2_reg.nii  $NUMCPU
    mv -vf t2_reg.nii t2.nii
  fi
fi
if [ "x" != x"$PD" ];then
    echo N4BiasFieldCorrection -d 3 -i pd.nii -o pd.nii -s 3 -c [ 50x50x50x50,0.00001] -b [ 150]
    $AP/N4BiasFieldCorrection -d 3 -i pd.nii -o pd.nii -s 3 -c [ 50x50x50x50,0.00001] -b [ 150] &>/dev/null
  if [ "$ISREG" == "false" ];then
    echo antsaffine.sh t1.nii pd.nii pd_reg.nii $NUMCPU
    $this_dir/antsaffine.sh t1.nii pd.nii pd_reg.nii $NUMCPU
    mv -vf pd_reg.nii pd.nii
  fi
fi

if [ "x" != x"$FL" ];then
  echo N4BiasFieldCorrection -d 3 -i fl.nii -o fl.nii -s 3 -c [ 50x50x50x50,0.00001] -b [ 150]
  $AP/N4BiasFieldCorrection -d 3 -i fl.nii -o fl.nii -s 3 -c [ 50x50x50x50,0.00001] -b [ 150] &>/dev/null
  if [ "$ISREG" == "false" ];then
    echo antsaffine.sh t1.nii fl.nii fl_reg.nii $NUMCPU
    $this_dir/antsaffine.sh t1.nii fl.nii fl_reg.nii $NUMCPU
    mv -vf fl_reg.nii fl.nii
  fi
fi

if [ "x" != x"$SWI" ];then
  echo N4BiasFieldCorrection -d 3 -i sw.nii -o sw.nii -s 3 -c [ 50x50x50x50,0.00001] -b [ 150]
  $AP/N4BiasFieldCorrection -d 3 -i sw.nii -o sw.nii -s 3 -c [ 50x50x50x50,0.00001]  -b [ 150] &>/dev/null
  if [ "$ISREG" == "false" ];then
    echo antsaffine.sh t1.nii sw.nii sw_reg.nii $NUMCPU
    $this_dir/antsaffine.sh t1.nii sw.nii sw_reg.nii $NUMCPU
    mv -vf sw_reg.nii sw.nii
  fi
fi

subs=
if [ "x" != x"$T1" ];then
    subs=t1.nii
elif [ "x" != x"$T2" ];then
    subs=t2.nii
elif [ "x" != x"$PD" ];then
    subs=pd.nii
elif [ "x" != x"$FL" ];then
    subs=fl.nii
elif [ "x" != x"$SWI" ];then
    subs=sw.nii
fi

if [ "$ROBUSTREG" == "true" ];then
    robustfov -i $subs -r temp.nii -m temp.mat -b 160
    flirt -in temp.nii -ref $subs -applyxfm -init temp.mat -out tmpsubject.nii
    rm -f temp.nii temp.mat
fi

for u in $(seq 1 $NUMATLAS)
do

  ATLAST1=$ATLASROOT/atlas"$u"_T1.nii
  ATLAST2=$ATLASROOT/atlas"$u"_T2.nii
  ATLASPD=$ATLASROOT/atlas"$u"_PD.nii
  ATLASFL=$ATLASROOT/atlas"$u"_FL.nii
  ATLASSWI=$ATLASROOT/atlas"$u"_SWI.nii
  ATLASMASK=$ATLASROOT/atlas"$u"_brainmask.nii

  REGT1=atlas"$u"_T1_ANTS.nii
  REGT2=atlas"$u"_T2_ANTS.nii
  REGPD=atlas"$u"_PD_ANTS.nii
  REGFL=atlas"$u"_FL_ANTS.nii
  REGSWI=atlas"$u"_SWI_ANTS.nii
  REGMASK=atlas"$u"_brainmask_ANTS.nii

  if [ "x" != x"$T1" ];then
      #ID=${REGT1%.*}
      ID=`remove_ext $REGT1`
      if [ "$ROBUSTREG" == "false" ];then
          echo AntsExample.sh t1.nii $ATLAST1 fastfortesting $REGT1 $NUMCPU
          $this_dir/AntsExample.sh t1.nii $ATLAST1 fastfortesting $REGT1 $NUMCPU
      else
          robustfov -i $ATLAST1 -r temp.nii -m temp.mat -b 160 &>/dev/null
          flirt -in temp.nii -ref $ATLAST1 -applyxfm -init temp.mat -out tmpatlas.nii
          rm -f temp.nii temp.mat
          $this_dir/AntsExample.sh tmpsubject.nii tmpatlas.nii fastfortesting $REGT1 $NUMCPU
          rm -f tmpatlas.nii
      fi

  elif [ "x" != x"$T2" ];then
      #ID=${REGT2%.*}
      ID=`remove_ext $REGT2`
      if [ "$ROBUSTREG" == "false" ];then
        echo AntsExample.sh t2.nii $ATLAST2 fastfortesting $REGT2 $NUMCPU
        $this_dir/AntsExample.sh t2.nii $ATLAST2 fastfortesting $REGT2 $NUMCPU
      else
          robustfov -i $ATLAST2 -r temp.nii -m temp.mat -b 160  &>/dev/null
          flirt -in temp.nii -ref $ATLAST2 -applyxfm -init temp.mat -out tmpatlas.nii
          rm -f temp.nii temp.mat
          $this_dir/AntsExample.sh tmpsubject.nii tmpatlas.nii fastfortesting $REGT2 $NUMCPU
          rm -f tmpatlas.nii
       fi

  elif [ "x" != x"$PD" ];then
      #ID=${REGPD%.*}
      ID=`remove_ext $REGPD`
      if [ "$ROBUSTREG" == "false" ];then
        echo AntsExample.sh pd.nii $ATLASPD fastfortesting $REGPD
        $this_dir/AntsExample.sh pd.nii $ATLASPD fastfortesting $REGPD
      else
        robustfov -i $ATLASPD -r temp.nii -m temp.mat -b 160 &>/dev/null
        flirt -in temp.nii -ref $ATLASPD -applyxfm -init temp.mat -out tmpatlas.nii
        rm -f temp.nii temp.mat
        $this_dir/AntsExample.sh tmpsubject.nii tmpatlas.nii fastfortesting $REGPD $NUMCPU
        rm -f tmpatlas.nii
      fi
  elif [ "x" != x"$FL" ];then
      #ID=${REGFL%.*}
      ID=`remove_ext $REGFL`
      if [ "$ROBUSTREG" == "false" ];then
        echo AntsExample.sh fl.nii $ATLASFL fastfortesting $REGFL $NUMCPU
        $this_dir/AntsExample.sh fl.nii $ATLASFL fastfortesting $REGFL $NUMCPU
      else
        robustfov -i $ATLASFL -r temp.nii -m temp.mat -b 160 &>/dev/null
        flirt -in temp.nii -ref $ATLASFL -applyxfm -init temp.mat -out tmpatlas.nii
        rm -f temp.nii temp.mat
        $this_dir/AntsExample.sh tmpsubject.nii tmpatlas.nii fastfortesting $REGFL $NUMCPU
        rm -f tmpatlas.nii
      fi
  else
      #ID=${REGSWI%.*}
      ID=`remove_ext $REGSWI`
      if [ "$ROBUSTREG" == "false" ];then
        echo AntsExample.sh sw.nii $ATLASSWI fastfortesting $REGSWI $NUMCPU
        $this_dir/AntsExample.sh sw.nii $ATLASSWI fastfortesting $REGSWI $NUMCPU
      else
        robustfov -i $ATLASSWI -r temp.nii -m temp.mat -b 160 &>/dev/null
        flirt -in temp.nii -ref $ATLASSWI -applyxfm -init temp.mat -out tmpatlas.nii
        rm -f temp.nii temp.mat
        $this_dir/AntsExample.sh tmpsubject.nii tmpatlas.nii fastfortesting $REGSWI $NUMCPU
        rm -f tmpatlas.nii
      fi
  fi

  if [ "x" != x"$T2" ];then
     antsApplyTransforms -d 3 -i $ATLAST2 -r $subs -o $REGT2 -n BSpline -f 0 -v 1 -t "$ID"1Warp.nii.gz -t "$ID"0GenericAffine.mat
  fi
  if [ "x" != x"$PD" ];then
     antsApplyTransforms -d 3 -i $ATLASPD -r $subs -o $REGPD -n BSpline -f 0 -v 1 -t "$ID"1Warp.nii.gz -t "$ID"0GenericAffine.mat
  fi
  if [ "x" != x"$FL" ];then
     antsApplyTransforms -d 3 -i $ATLASFL -r $subs -o $REGFL -n BSpline -f 0 -v 1 -t "$ID"1Warp.nii.gz -t "$ID"0GenericAffine.mat
  fi
  if [ "x" != x"$SWI" ];then
     antsApplyTransforms -d 3 -i $ATLASSWI -r $subs -o $REGSWI -n BSpline -f 0 -v 1 -t "$ID"1Warp.nii.gz -t "$ID"0GenericAffine.mat
  fi


  antsApplyTransforms -d 3 -i $ATLASMASK -r $subs -o $REGMASK -n NearestNeighbor -f 0 -v 1 -t "$ID"1Warp.nii.gz -t "$ID"0GenericAffine.mat

  rm -f *.gz *.mat
done

subs=
modal=
if [ "x" != x"$T1" ];then
    subs=t1.nii
    modal=T1,
    atlas=`ls *T1_ANTS.nii`
fi
if [ "x" != x"$T2" ];then
  subs="$subs t2.nii"
  modal="${modal}T2,"
  atlas="$atlas *T2_ANTS.nii"
fi
if [ "x" != x"$PD" ];then
  subs="$subs pd.nii"
  modal="${modal}PD,"
  atlas="$atlas *PD_ANTS.nii"
fi
if [ "x" != x"$FL" ];then
  subs="$subs fl.nii"
  modal="${modal}FL,"
  atlas="$atlas *FL_ANTS.nii"
fi
if [ "x" != x"$SWI" ];then
  subs="$subs sw.nii"
  modal="${modal}FL,"
  atlas="$atlas *SWI_ANTS.nii"
fi

L=${#modal}
modal=${modal:0:L-1}


${this_dir}/run_create_brainmask.sh $NUMMODAL $NUMATLAS $modal $RAD 3x3x3 $NUMCPU ./ $subs $atlas *brainmask_ANTS.nii

subs=
if [ "x" != x"$T1" ];then
    subs=t1
elif [ "x" != x"$T2" ];then
  subs=t2
elif [ "x" != x"$PD" ];then
   subs=pd
elif [ "x" != x"$FL" ];then
  subs=fl
elif [ "x" != x"$SWI" ];then
  subs=sw
fi

echo "${green}$mipavjava edu.jhu.ece.iacl.jist.cli.run edu.jhu.ece.iacl.plugins.segmentation.skull_strip.MedicAlgorithmSmoothBrainMask -inBrain "$subs"_MultiModalStripMask.nii -inOriginal $subs.nii -outSmooth $PWD/"$subs"_MultiModalStripMask_smooth.nii${reset}"

$mipavjava edu.jhu.ece.iacl.jist.cli.run edu.jhu.ece.iacl.plugins.segmentation.skull_strip.MedicAlgorithmSmoothBrainMask -inBrain "$subs"_MultiModalStripMask.nii -inOriginal $subs.nii -inMax 0.3 -outSmooth $PWD/"$subs"_MultiModalStripMask_smooth.nii

if [ "x" != x"$T1" ];then
    ID=`basename $T1`
    #ID=${ID%.*}
    ID=`remove_ext $ID`
elif [ "x" != x"$T2" ];then
    ID=`basename $T2`
    #ID=${ID%.*}
    ID=`remove_ext $ID`
elif [ "x" != x"$PD" ];then
    ID=`basename $PD`
    #ID=${ID%.*}
    ID=`remove_ext $ID`
elif [ "x" != x"$FL" ];then
    ID=`basename $FL`
    #ID=${ID%.*}
    ID=`remove_ext $ID`
else
    ID=`basename $SWI`
    #ID=${ID%.*}
    ID=`remove_ext $ID`
fi


echo "${green}fslmaths "$subs"_MultiModalStripMask_smooth.nii "$subs"_MultiModalStripMask_smooth.nii -odt char $reset"
fslmaths "$subs"_MultiModalStripMask_smooth.nii "$subs"_MultiModalStripMask_smooth.nii -odt char

$this_dir/run_image_dilate.sh "$subs"_MultiModalStripMask_smooth.nii "$subs"_MultiModalStripMask_smooth.nii 1
if [ x"$ORIT1" == "x" ];then
    ORIT1=$ORI
fi

if [ "$FAST" == "true" ];then
    3dresample -orient $ORIT1 -inset "$subs"_MultiModalStripMask_smooth.nii -prefix mask_original_orientation.nii
    #DIM=`3dinfo -ni $T1`x`3dinfo -nj $T1`x`3dinfo -nk $T1`

    if [ -f "$T1" ];then
        DIM=`PrintHeader $T1 2` # Works better than AFNI, AFNI has all sorts of warning messages sometimes, which
                                # might screw up the 3dinfo output.
                                # @TODO: Move away from AFNI
        ResampleImage 3 mask_original_orientation.nii mask_original_space.nii $DIM 1 1
        fslcpgeom $T1 mask_original_space.nii -d
        #3dresample -master $T1 -inset mask_original_orientation.nii -prefix mask_original_space.nii -rmode NN
        $mipavjava edu.jhu.ece.iacl.jist.cli.run edu.jhu.ece.iacl.plugins.segmentation.skull_strip.MedicAlgorithmSmoothBrainMask -inBrain mask_original_space.nii -inOriginal $T1 -inMax 0.3 -outSmooth $PWD/"$subs"_MultiModalStripMask_smooth.nii
    elif [ -f "$T2" ];then
        DIM=`PrintHeader $T2 2`
        ResampleImage 3 mask_original_orientation.nii mask_original_space.nii $DIM 1 1
        fslcpgeom $T2 mask_original_space.nii -d
        #3dresample -master $T2 -inset mask_original_orientation.nii -prefix mask_original_space.nii -rmode NN
        $mipavjava edu.jhu.ece.iacl.jist.cli.run edu.jhu.ece.iacl.plugins.segmentation.skull_strip.MedicAlgorithmSmoothBrainMask -inBrain mask_original_space.nii -inOriginal $T2 -inMax 0.3 -outSmooth $PWD/"$subs"_MultiModalStripMask_smooth.nii
    elif [ -f "$PD" ];then
        DIM=`PrintHeader $PD 2`
        ResampleImage 3 mask_original_orientation.nii mask_original_space.nii $DIM 1 1
        fslcpgeom $PD mask_original_space.nii -d
        #3dresample -master $PD -inset mask_original_orientation.nii -prefix mask_original_space.nii -rmode NN
        $mipavjava edu.jhu.ece.iacl.jist.cli.run edu.jhu.ece.iacl.plugins.segmentation.skull_strip.MedicAlgorithmSmoothBrainMask -inBrain mask_original_space.nii -inOriginal $PD -inMax 0.3 -outSmooth $PWD/"$subs"_MultiModalStripMask_smooth.nii
    elif [ -f "$FL" ];then
        DIM=`PrintHeader $FL 2`
        ResampleImage 3 mask_original_orientation.nii mask_original_space.nii $DIM 1 1
        fslcpgeom $FL mask_original_space.nii -d
        #3dresample -master $FL -inset mask_original_orientation.nii -prefix mask_original_space.nii -rmode NN
        $mipavjava edu.jhu.ece.iacl.jist.cli.run edu.jhu.ece.iacl.plugins.segmentation.skull_strip.MedicAlgorithmSmoothBrainMask -inBrain mask_original_space.nii -inOriginal $FL -inMax 0.3 -outSmooth $PWD/"$subs"_MultiModalStripMask_smooth.nii
    else
        DIM=`PrintHeader $SWI 2`
        ResampleImage 3 mask_original_orientation.nii mask_original_space.nii $DIM 1 1
        fslcpgeom $SWI mask_original_space.nii -d
        #3dresample -master $SWI -inset mask_original_orientation.nii -prefix mask_original_space.nii -rmode NN
        $mipavjava edu.jhu.ece.iacl.jist.cli.run edu.jhu.ece.iacl.plugins.segmentation.skull_strip.MedicAlgorithmSmoothBrainMask -inBrain mask_original_space.nii -inOriginal $SWI -inMax 0.3 -outSmooth $PWD/"$subs"_MultiModalStripMask_smooth.nii
    fi

    $this_dir/run_image_dilate.sh "$subs"_MultiModalStripMask_smooth.nii "$subs"_MultiModalStripMask_smooth.nii 1
fi

3dresample -orient $ORIT1 -inset "$subs"_MultiModalStripMask_smooth.nii -prefix $OUTPUTDIR/"$ID"_MultiModalStripMask.nii


if [ "$CLEAN" == "true" ];then
    cd $OUTPUTDIR
    rm -vrf $workingdir
else
    gzip -vf $workingdir/*.nii
    echo "${green}Working directory was $workingdir$reset"
    cd $OUTPUTDIR
fi


END=$(date +%s)
DIFF=$(( $END - $START ))
((sec=DIFF%60, DIFF/=60, min=DIFF%60, hrs=DIFF/60))
if [ $hrs == "0" ];then
    echo "${green}MONSTR skull-stripping took $min MIN $sec SEC$reset"
else
    echo "${green}MONSTR skull-stripping took $hrs HRS $min MIN $sec SEC$reset"
fi

pkill Xvfb






