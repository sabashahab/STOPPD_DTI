#!/bin/bash
source /etc/profile.d/modules.sh
source /etc/profile.d/quarantine.sh
module load python/2.7.8-anaconda-2.1.0
module load python-extras/2.7.8
module load whitematteranalysis/latest
module load slicer/0,nightly

if [ -z "$2" ]; then
cat <<EOF

Runs the WMA pipeline on input VTK files

Usage:
$0 <inputfile> <outputdir> <atlas> <clusteredmrml>

Arguments:  
  <inputfile>      Path to TRACTS.vtk file for subject
  <outputdir>      Parent output dir
  <atlas>      	   atlas.vtp file from the atlas folder
  <clusteredmrml>  Path to the clustered mrml file
  <tractList>  	   Path to a list of tract names
EOF
  exit 1
fi 

inputfolder=$1            # TRACTS.vtk file
outputfolder=$2              # output/
atlas=$3       	          # atlas/
clusteredmrml=$4          # mrml file
tractsfile=$5		  # List of tract names
filename=`echo $1 | sed "s/.*\///" | sed "s/\..*//"`
atlasDirectory=`dirname $atlas`
declare -a listHemispheres=("tracts_commissural" "tracts_left_hemisphere" "tracts_right_hemisphere")

mkdir -p $outputfolder

if [ ! -e $outputfolder/RegisterToAtlas/$filename/output_tractography/$filename'_reg.vtk' ]; then
wm_register_to_atlas_new.py \
  $inputfolder $atlas $outputfolder/RegisterToAtlas 
else 
  echo "wm_register_to_atlas_new.py was already run on this subject!"
fi

if [ ! -e $outputfolder/ClusterFromAtlas/$filename'_reg' ]; then
wm_cluster_from_atlas.py \
  -l 20 \
  $outputfolder/RegisterToAtlas/$filename/output_tractography/$filename'_reg.vtk' \
  $atlasDirectory $outputfolder/ClusterFromAtlas
else 
  echo "wm_cluster_from_atlas_new.py was already run on this subject!"
fi

if [ ! -e $outputfolder/OutliersPerSubject/$filename'_reg_outlier_removed' ]; then
wm_cluster_remove_outliers.py \
  -cluster_outlier_std 4 \
  $outputfolder/ClusterFromAtlas/$filename'_reg' \
  $atlasDirectory \
  $outputfolder/OutliersPerSubject
else 
  echo "wm_cluster_remove_outliers.py was already run on this subject!"
fi

if [ ! -e $outputfolder/ClusterByHemisphere/$filename ]; then
wm_separate_clusters_by_hemisphere.py \
  -atlasMRML $clusteredmrml \
  $outputfolder/OutliersPerSubject/$filename'_reg_outlier_removed'/ \
  $outputfolder/ClusterByHemisphere/$filename
else 
  echo "wm_separate_clusters_by_hemisphere.py was already run on this subject!"
fi

if [ ! -e $outputfolder/AppendClusters/$filename ]; then
for hemisphere in "${listHemispheres[@]}"; do
echo $hemisphere
while read tractname; do 
wm_append_clusters.py \
  -appendedTractName $tractname \
  -tractMRML $atlasDirectory/$tractname'.mrml' \
  $outputfolder/ClusterByHemisphere/$filename/$hemisphere \
  $outputfolder/AppendClusters/$filename/$hemisphere >> /scratch/saba/log_wma.txt
done < $tractsfile
done
else
  echo "wm_separate_clusters_by_hemisphere.py was already run on this subject!"
fi

if [ ! -e $outputfolder/FiberMeasurements/$filename ]; then
for hemisphere in "${listHemispheres[@]}"; do
echo $hemisphere
mkdir -p $outputfolder/FiberMeasurements/$filename/$hemisphere/
echo $outputfolder/FiberMeasurements/$filename/$hemisphere >> /scratch/saba/testing.txt; 
FiberTractMeasurements \
  --outputfile $outputfolder/FiberMeasurements/$filename/$hemisphere/$filename'.csv' \
  --inputdirectory $outputfolder/AppendClusters/'OutliersPerSubject_'$filename/$hemisphere \
  -i Fibers_File_Folder \
  --separator Tab \
  -f Column_Hierarchy
done
else
  echo "FiberTractMeasurements was already run on this subject!"
fi

