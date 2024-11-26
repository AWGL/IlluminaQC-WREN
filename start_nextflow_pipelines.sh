#!/bin/bash


# Cron job to find dragen results and start a nextflow pipeline for the samples.

#results_dir=/Output/results/

# loop through each folder and find runs which have finished the dragen side of stuff



# may be required to get module load to work - try
source ~/.bashrc
source /etc/profile.d/modules.sh
module load singularity

set -euo pipefail

results_dir=/Output/results/

for path in $(find $results_dir -maxdepth 3 -mindepth 3 -type f -name "nextflow_pipeline_required.txt" -exec dirname '{}' \;); do

  # for each of those runs find the post processing pipeline we need
  echo $path

  if [ ! -f "$path"/nextflow_pipeline_started.txt ] && [ -f "$path"/nextflow_pipeline_required.txt ]; then

     touch "$path"/nextflow_pipeline_started.txt

     runid=$(basename $(dirname "$path"))
     panel=$(basename "$path")
     echo $runid
     echo $panel

     # load the variables file which says which pipeline we need

     if [ ! -f "$path"/"$panel".variables ]; then
        echo "variables does not exist"
        exit 0
     fi


     . "$path"/"$panel".variables

     echo $nextflow_pipeline
     echo $nextflow_pipeline_version

     mkdir -p "$path"/post_processing

     cd "$path"/post_processing

     set +u
     source activate $nextflow_pipeline
     set -u

     # copy pipeline scripts
     cp /data/diagnostics/pipelines/"$nextflow_pipeline"/"$nextflow_pipeline"-"$nextflow_pipeline_version"/config/"$panel"/"$panel"_wren.config .

     cp -r /data/diagnostics/pipelines/"$nextflow_pipeline"/"$nextflow_pipeline"-"$nextflow_pipeline_version"/config .

     cp /data/diagnostics/pipelines/"$nextflow_pipeline"/"$nextflow_pipeline"-"$nextflow_pipeline_version"/"$nextflow_pipeline".nf .

     cp -r /data/diagnostics/pipelines/"$nextflow_pipeline"/"$nextflow_pipeline"-"$nextflow_pipeline_version"/bin .

    
     mkdir logs 

     # run nextflow
     nextflow -C \
     "$panel"_wren.config \
     run \
     "$nextflow_pipeline".nf \
     --fastqs ../\*/\*\.fastq.gz \
     --variables ../\*/\*.variables \
     --publish_dir results \
     --sequencing_run "$runid" \
     -with-report "$runid".html \
     -with-dag "$runid".png \
     -work-dir /home/transfer/nextflow_work/non_dragen/"$runid"/"$panel"/work/ &> logs/pipeline.log

     # mv logs 
     for i in $(find work/ -name "*.out" -type f ); do mv $i logs/$( echo $i | sed 's/work//' | sed 's/\///g' ) ;done

     for i in $(find work/ -name "*.err" -type f ); do mv $i logs/$( echo $i | sed 's/work//' | sed 's/\///g' ) ;done

     tar -czvf logs.tar.gz logs/
     rm -r logs/

     # delete work dir
     rm -r /home/transfer/nextflow_work/non_dragen/"$runid"/"$panel"/work/

     fi

done

