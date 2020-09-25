#!/bin/bash

#SBATCH --time=12:00:00
#SBATCH --output=IlluminaQC-%N-%j.output
#SBATCH --error=IlluminaQC-%N-%j.error
#SBATCH --partition=demultiplexing
#SBATCH --cpus-per-task=40

cd $SLURM_SUBMIT_DIR

version="1.2.0"

# results location
res_dir_root=/Output/results

# load modules & conda envs
module purge
module load anaconda
source activate IlluminaQC-v1.2.0

# catch errors early
set -euo pipefail

# collect interop data
summary=$(interop_summary --level=3 --csv=1 "$sourceDir")

# extract fields
yieldGb=$(echo "$summary" | grep ^Total | cut -d, -f2)
q30Pct=$(echo "$summary" | grep ^Total | cut -d, -f7)
avgDensity=$(echo "$summary" | grep -A999 "^Level" | grep ^[[:space:]]*[0-9] | awk -F',| ' '{print $1"\t"$4}' | sort | uniq | awk -F'\t' '{total += $2; count++} END {print total/count}')
avgPf=$(echo "$summary" | grep -A999 "^Level" |grep ^[[:space:]]*[0-9] | awk -F',| ' '{print $1"\t"$7}' | sort | uniq | awk -F'\t' '{total += $2; count++} END {print total/count}')
totalReads=$(echo "$summary" | grep -A999 "^Level" | grep ^[[:space:]]*[0-9] | awk -F',| ' '{print $1"\t"$19}' | sort | uniq | awk -F'\t' '{total += $2} END {print total}')

# print metrics (headers)
if [ ! -e Metrics.txt ]; then
    echo -e "Run\tTotalGb\tQ30\tAvgDensity\tAvgPF\tTotalMReads" > Metrics.txt
fi

# print metrics (values)
echo -e "$(basename $sourceDir)\t$yieldGb\t$q30Pct\t$avgDensity\t$avgPf\t$totalReads" >> Metrics.txt

# BCL2FASTQ
bcl2fastq -l WARNING -R "$sourceDir" -o .

#copy files to keep to long-term storage
mkdir Data
cp "$sourceDir"/SampleSheet.csv .
cp "$sourceDir"/?unParameters.xml RunParameters.xml
cp "$sourceDir"/RunInfo.xml .
cp -R "$sourceDir"/InterOp .

# Make variable files
java -jar /data/diagnostics/apps/MakeVariableFiles/MakeVariableFiles-2.1.0.jar \
  SampleSheet.csv \
  RunParameters.xml

# move fastq & variable files into project folders
for variableFile in $(ls *.variables); do

	# reset variables
	unset sampleId seqId worklistId pipelineVersion pipelineName panel

	# load variables into local scope
	. "$variableFile"

	# make sample folder
	mkdir Data/"$sampleId"
	mv "$variableFile" Data/"$sampleId"
	mv "$sampleId"_S*.fastq.gz Data/"$sampleId"
	
	# create analysis folders
	if [[ ! -z ${pipelineVersion-} && ! -z ${pipelineName-} && ! -z ${panel-} && ! -z ${worklistId-} ]]
	then

		# make project folders
		res_dir=/$res_dir_root/"$seqId"/"$worklistId"/"$panel"/"$sampleId"
                mkdir -p $res_dir

		#soft link files
		ln -s $PWD/Data/"$sampleId"/"$variableFile" $res_dir
		for i in $(ls Data/"$sampleId"/"$sampleId"_S*.fastq.gz); do
			ln -s $PWD/"$i" $res_dir
		done

		# copy scripts
		cp /data/diagnostics/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/*sh $res_dir

                bash -c "cd $res_dir && sbatch -J "$panel"-"$sampleId" 1_*.sh"
	fi
done
