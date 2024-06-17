#!/bin/bash

set -euo pipefail

# need to load bcftools
# may be required to get module load to work - try
source ~/.bashrc
source /etc/profile.d/modules.sh
module load bcftools

# Cron job to find dragen swgs results and perform any post processing required.

dragen_results_dir=/Output/results/validations/Somatic_WGS

# loop through each folder and find runs which have finished the dragen side of stuff

for path in $(find $dragen_results_dir -maxdepth 3 -mindepth 3 -type f -name "swgs_dragen_complete.txt" -exec dirname '{}' \;); do

   # for each of those runs find the post processing pipeline we need
   echo $path

   if [ ! -f "$path"/swgs_post_processing_started.txt ] && [ -f "$path"/swgs_post_processing_required.txt ]; then

      touch "$path"/swgs_post_processing_started.txt
 
      run_id=$(basename $(dirname "$path"))
      panel=$(basename "$path")
      echo $run_id
      echo $panel

      # load the variables file which says which pipeline we need
      if [ ! -f "$path"/"$panel".variables ]; then
         echo "variables does not exist"
         exit 0
      fi

      . "$path"/"$panel".variables

      echo $post_processing_pipeline
      echo $post_processing_pipeline_version

      # make post_processing directory
      mkdir -p "$path"/post_processing

      cd "$path"/post_processing

      # activate conda environment
      set +u
      source activate $post_processing_pipeline
      set -u
  
      # copy pipeline scripts
      cp /data/diagnostics/pipelines/"$post_processing_pipeline"/"$post_processing_pipeline"-"$post_processing_pipeline_version"/config/"$panel"/"$panel"_wren.config .
      cp -r /data/diagnostics/pipelines/"$post_processing_pipeline"/"$post_processing_pipeline"-"$post_processing_pipeline_version"/config .
      cp /data/diagnostics/pipelines/"$post_processing_pipeline"/"$post_processing_pipeline"-"$post_processing_pipeline_version"/"$post_processing_pipeline".nf .
      cp -r /data/diagnostics/pipelines/"$post_processing_pipeline"/"$post_processing_pipeline"-"$post_processing_pipeline_version"/bin .

      # make logs directory
      mkdir logs

      # run nextflow
      nextflow -C \
         SWGS_wren.config \
         run \
         dragenswgs_post_processing.nf \
         --run_id ${run_id} \
         --germline_sample_id ${germline_sample_id} \
         --tumour_sample_id ${tumour_sample_id} \
         --ntc_sample_id ${ntc_sample_id} \
         --bam '../*/*{.bam,.bam.bai}' \
         --variables '../*/*.variables' \
         --contig_mean_cov_csv '../*/*.wgs_contig_mean_cov.csv' \
         --cnv_vcf '../*/*.cnv.vcf.gz' \
         --fragment_length_hist '../*/*.fragment_length_hist.csv' \
         --hard_filtered_vcf '../*/*.hard-filtered.vcf.gz' \
         --mapping_metrics_csv '../*/*.mapping_metrics.csv' \
         --tinc_vcf <tin_qc_vcf> \
         --publish_dir results \
         --with-dag ${run_id}.png \
         --with-report ${run_id}.html \
         --work-dir /home/transfer/nextflow_work/dragen/"$run_id"/"$panel"/work/ \
         &> pipeline.log 

      # mv logs
      for i in $(find work/ -name "*.out" -type f ); do mv $i logs/$( echo $i | sed 's/work//' | sed 's/\///g' ) ;done
      for i in $(find work/ -name "*.err" -type f ); do mv $i logs/$( echo $i | sed 's/work//' | sed 's/\///g' ) ;done

      tar -czvf logs.tar.gz logs/

      rm -r logs/

      # delete work dir
      rm -r /home/transfer/nextflow_work/dragen/"$run_id"/"$panel"/     

   fi

done
