#!/bin/bash

set -euo pipefail

# Cron job to find dragen results and perform any post processing required.

dragen_results_dir=/Output/results/

# loop through each folder and find runs which have finished the dragen side of stuff


for path in $(find $dragen_results_dir -maxdepth 3 -mindepth 3 -type f -name "dragen_complete.txt" -exec dirname '{}' \;); do

  # for each of those runs find the post processing pipeline we need
  echo $path

  if [ ! -f "$path"/post_processing_started.txt ] && [ -f "$path"/post_processing_required.txt ]; then

     touch "$path"/post_processing_started.txt
 
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

     echo $post_processing_pipeline
     echo $post_processing_pipeline_version


     mkdir -p "$path"/post_processing

     cd "$path"/post_processing

     set +u
     source activate $post_processing_pipeline
     set -u
  
     # copy pipeline scripts
     cp /data/diagnostics/pipelines/"$post_processing_pipeline"/"$post_processing_pipeline"-"$post_processing_pipeline_version"/config/"$panel"/"$panel"_wren.config .
     
     cp -r /data/diagnostics/pipelines/"$post_processing_pipeline"/"$post_processing_pipeline"-"$post_processing_pipeline_version"/config .

     cp /data/diagnostics/pipelines/"$post_processing_pipeline"/"$post_processing_pipeline"-"$post_processing_pipeline_version"/"$post_processing_pipeline".nf .

     cp -r /data/diagnostics/pipelines/"$post_processing_pipeline"/"$post_processing_pipeline"-"$post_processing_pipeline_version"/bin .

    
     mkdir logs

     # run nextflow
     nextflow -C \
     "$panel"_wren.config \
     run \
     "$post_processing_pipeline".nf \
     --bams ../\*/\*\{.bam,.bam.bai\} \
     --vcf ../"$runid"\{.vcf.gz,.vcf.gz.tbi\} \
     --variables ../\*/\*.variables \
     --sv_vcf ../"$runid".sv\{.vcf.gz,.vcf.gz.tbi\} \
     --cnv_vcf ../"$runid".cnv\{.vcf.gz,.vcf.gz.tbi\} \
     --bams_crams ../\*/\*\{.cram,.cram.crai\} \
     --mosaic_vcf ../\*/Mosaic_Calling/\*.hard-filtered.vcf.gz \
     --publish_dir results \
     --sequencing_run "$runid" \
     -with-dag "$runid".png \
     -with-report "$runid".html \
     -work-dir work &> pipeline.log 

     # mv logs
     for i in $(find work/ -name "*.out" -type f ); do mv $i logs/$( echo $i | sed 's/work//' | sed 's/\///g' ) ;done

     for i in $(find work/ -name "*.err" -type f ); do mv $i logs/$( echo $i | sed 's/work//' | sed 's/\///g' ) ;done

     # delete work dir
     rm -r work     

     fi

done






