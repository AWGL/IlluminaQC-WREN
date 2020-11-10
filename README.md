# IlluminaQC

Quality control workflow for Illumina sequencing data

From v2.0.0 the scripts have been refactored to use SLURM scheduling on WREN. 

Launch from `/data/output/fastq/<seqId>` directory:
```
sbatch --export=sourceDir=<path-to-seq-dir> <path-to-IlluminaQC-directory>/1_IlluminaQC.sh
```

### Validation Runs

Validation runs will be saved under `/data/output/validations/` if lanched:
```
sbatch --export=sourceDir=<path-to-seq-dir>,validation=TRUE <path-to-IlluminaQC-directory>/1_IlluminaQC.sh
```

alternativly individuel samples can be desiganted as validation samples within the samplsheet (ad `validation=TRUE` to description field)
