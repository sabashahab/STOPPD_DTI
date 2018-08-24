#!/bin/bash
source /etc/profile.d/modules.sh
source /etc/profile.d/quarantine.sh
module load slicer/0,nightly
module load FSL/5.0.7 
module load DTIPrep/1.2.4
module load UKFTractography/2015-02-05


if [ -z "$3" ]; then
cat <<EOF
Runs DTIPrep and UKFTractography on a DWI image
Usage:
  $0 <dwi> <DTIPrep-protocol.xml> <outputdir> <seeds>
EOF
  exit 1
fi 



inputimage=$1           # input NRRD DWI image
dtiprep_protocol=$2     # xml spec for DTIPrep
outputfolder=$3         # output folder for all outputs
 



# Change the commented out section below depending on whether you are using nrrd or nhdr.
stem=$(basename $inputimage .nrrd)
#stem=$(basename $inputimage .nhdr)

threads=8

#DTI PREP
# Run image through DTIPrep to clean up the image
if [ ! -e $outputfolder/${stem}_QCed.nrrd ]; then
  DTIPrep \
    --DWINrrdFile $inputimage \
    --xmlProtocol $dtiprep_protocol \
    --outputFolder $outputfolder \
    --numberOfThreads $threads \
    --check 
else 
  echo "DTIPrep was already run on this subject!"
fi

#Diffusion Weighted Volume Masking 

if [ ! -e $outputfolder/${stem}_MASK.nrrd ]; then
  DiffusionWeightedVolumeMasking \
    --removeislands \
    ${outputfolder}/${stem}_QCed.nrrd \
    ${outputfolder}/${stem}_SCALAR.nrrd \
    ${outputfolder}/${stem}_MASK.nrrd
else 
  echo "DiffusionWeightedVolumeMasking was already run on this subject!"
fi

#DWI to DTI Estimation

if [ ! -e $outputfolder/${stem}_DTI.nrrd ]; then
  DWIToDTIEstimation \
    --enumeration WLS \
    --shiftNeg \
    -m $outputfolder/${stem}_MASK.nrrd \
    $outputfolder/${stem}_QCed.nrrd \
    $outputfolder/${stem}_DTI.nrrd \
    $outputfolder/${stem}_SCALAR.nrrd
else 
  echo "DWIToDTIEstimate was already run on this subject!"
fi

Tractography label map seeding

if [ ! -e $outputfolder/${stem}_SlicerTractography.vtk ]; then
TractographyLabelMapSeeding \
	${outputfolder}/${stem}_DTI.nrrd \
	${outputfolder}/${stem}_SlicerTractography.vtk \
	--useindexspace \
	--stoppingvalue 0.10
else 
  echo "TractographyLabelMapSeeding was already run on this subject!"
fi






