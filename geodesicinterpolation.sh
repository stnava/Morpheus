#!/bin/bash
NUMPARAMS=$#
dim=2

if [ $NUMPARAMS -lt 2  ]
then
echo " USAGE ::  "
echo "  sh   geodesicinterpolation.sh image1  image2  N-interpolation-points   "
echo " You may need to tune the ANTS parameters coded within this script for your application "
exit
fi

# should we use the generative model to find landmarks then
#  drive individual mappings by the LMs?

TEMPLATE=$1
TARGET=$2
NUMSTEPS=10
STEP=1
OUTNAME=ANTSMORPH
if [ $NUMPARAMS -gt 2  ]
then
NUMSTEPS=$3
fi
if [ $NUMPARAMS -gt 3  ]
then
OUTNAME=$4
fi

MASK=0
if [ $NUMPARAMS -gt 5 ]
then
MASK=$5
fi

echo " Morphing in total $NUMSTEPS time-points by $STEP steps -- end-points are original images "


    for (( n = 0 ; n <= ${NUMSTEPS}; n=n+${STEP} ))
    do
BLENDINGA=$(echo "scale=2; ${n}/${NUMSTEPS}"  | bc )
BLENDINGB=$(echo "scale=2;  1-$BLENDINGA"  | bc )
BLENDNAME=$(echo "scale=2;  100*$BLENDINGA"  | bc )
echo " Blending values:   $BLENDINGA and $BLENDINGB"
  done

    BBA=`basename $TEMPLATE`
    BBB=`basename $TARGET `
    BASEA=${BBA%.*}
    BASEB=${BBB%.*}
    BASEA="${BASEA%.*}"
    BASEB="${BASEB%.*}"

ANTSPATH=${ANTSPATH}/
FIXEDIMAGE=$TEMPLATE
MOVINGIMAGE=$TARGET
if [[ ! -s ${OUTNAME}FwdCompositeWarp.nii.gz ]] ; then 
${ANTSPATH}/antsRegistration --dimensionality $dim \
                             --output [$OUTNAME,${OUTNAME}Warped.nii.gz] \
                             --interpolation Linear \
                             --winsorize-image-intensities [0.005,0.995] \
                             --initial-moving-transform [$FIXEDIMAGE,$MOVINGIMAGE,1] \
                             --transform Rigid[0.1] \
                             --metric MI[$FIXEDIMAGE,$MOVINGIMAGE,1,32,Regular,0.25] \
                             --convergence 1000x500x250x100 \
                             --shrink-factors 8x4x2x1 \
                             --smoothing-sigmas 3x2x1x0 \
                             --transform Affine[0.1] \
                             --metric MI[$FIXEDIMAGE,$MOVINGIMAGE,1,32,Regular,0.25] \
                             --convergence 1000x500x250x100 \
                             --shrink-factors 8x4x2x1 \
                             --smoothing-sigmas 3x2x1x0 \
                             --transform BSplineSyN[0.1,${SPLINEDISTANCE},0,3] \
                             --metric CC[$FIXEDIMAGE,$MOVINGIMAGE,1,4] \
                             --convergence 100x100x100x50 \
                             --masks $MASK \
                             --shrink-factors 6x4x2x1 \
                             --smoothing-sigmas 3x2x1x0
fi
antsApplyTransforms -d $dim -r $TEMPLATE -t ${OUTNAME}1Warp.nii.gz           -t ${OUTNAME}0GenericAffine.mat   -o [${OUTNAME}FwdCompositeWarp.nii.gz,1]
antsApplyTransforms -d $dim -r $TEMPLATE -t [${OUTNAME}0GenericAffine.mat,1] -t ${OUTNAME}1InverseWarp.nii.gz  -o [${OUTNAME}InvCompositeWarp.nii.gz,1]


for (( n = 0 ; n <= ${NUMSTEPS}; n=n+${STEP} ))
  do
    BLENDINGA=$(echo "scale=2; ${n}/${NUMSTEPS}"  | bc )
    BLENDINGB=$(echo "scale=2;  1-$BLENDINGA"  | bc )
    BLENDNAME=$(echo "scale=2;  100*$BLENDINGA"  | bc )
    echo " Blending values:   $BLENDINGA and $BLENDINGB"
    ${ANTSPATH}MultiplyImages $dim ${OUTNAME}InvCompositeWarp.nii.gz  $BLENDINGA SM${OUTNAME}InverseWarp.nii.gz 
    ${ANTSPATH}MultiplyImages $dim ${OUTNAME}FwdCompositeWarp.nii.gz  $BLENDINGB SM${OUTNAME}Warp.nii.gz 

    ${ANTSPATH}antsApplyTransforms -d $dim -i $TARGET   -o temp.nii.gz  -t SM${OUTNAME}Warp.nii.gz -r $TEMPLATE -n linear 
    ${ANTSPATH}ImageMath $dim temp.nii.gz Normalize temp.nii.gz 1
    ${ANTSPATH}ImageMath $dim temp.nii.gz m temp.nii.gz 1.   #$BLENDINGA
    ${ANTSPATH}antsApplyTransforms -d $dim -i $TEMPLATE -o temp2.nii.gz  -t SM${OUTNAME}InverseWarp.nii.gz -r $TEMPLATE -n linear
    ${ANTSPATH}ImageMath $dim temp2.nii.gz Normalize temp2.nii.gz  1
    ${ANTSPATH}ImageMath $dim temp2.nii.gz m temp2.nii.gz 0  #$BLENDINGB
  echo "  ImageMath $dim ${BASEA}${BASEB}${BLENDNAME}morph.nii.gz + temp2.nii.gz temp.nii.gz  "
  ${ANTSPATH}ImageMath $dim ${BASEA}${BASEB}${BLENDNAME}morph.nii.gz + temp2.nii.gz temp.nii.gz
  ${ANTSPATH}ConvertToJpg  ${BASEA}${BASEB}${BLENDNAME}morph.nii.gz ${BASEA}${BASEB}${BLENDNAME}morph.jpg
  rm  -f  ${BASEA}${BASEB}${BLENDNAME}morph.nii.gz

   done

rm -f  ${OUTNAME}*  SM${OUTNAME}*

exit
