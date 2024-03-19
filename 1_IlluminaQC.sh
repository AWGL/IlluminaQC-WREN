#!/bin/bash

#SBATCH --time=12:00:00
#SBATCH --output=IlluminaQC-%N-%j.output
#SBATCH --error=IlluminaQC-%N-%j.error
#SBATCH --partition=demultiplexing
#SBATCH --cpus-per-task=40

# Useage: <as transfer user> mkdir /data/output/fastq/<seqId> && cd /data/output/fastq/<seqId> &&
#   sbatch -J IlluminaQC-<seqId> --export=sourceDir=/data/archive/<instrumentType>/<seqId> /data/diagnostics/pipelines/IlluminaQC/IlluminaQC-<version>/1_IlluminaQC.sh

cd $SLURM_SUBMIT_DIR

version="1.2.0"

# results location for validations
val_dir_base=/Output/validations/

# set results dir
if [ -z ${validation-} ] || [ $validation == 'FALSE' ]; then
	res_dir_base=/Output/results
else
	res_dir_base=$val_dir_base
fi
unset validation

# load modules & conda envs
module purge
module load anaconda bcl2fastq
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

# Copy files to keep to long-term storage
mkdir Data
cp "$sourceDir"/SampleSheet.csv .
cp "$sourceDir"/?unParameters.xml RunParameters.xml
cp "$sourceDir"/RunInfo.xml .
cp -R "$sourceDir"/InterOp .

# Sometimes the SampleSheet isn't being fixed the first time round - fix again
mv SampleSheet.csv SampleSheet_orig.csv
# Convert from Windows file back to csv
sed "s/\r//g" SampleSheet_orig.csv > SampleSheet.csv
# Add commas to blank lines
sed -i "s/^[[:blank:]]*$/,,,,,,,,/" SampleSheet.csv
cat SampleSheet.csv | sed 's/Name$ge/pipelineName=germline_enrichment_nextflow;pipelineVersion=master/' | sed 's/Name$SA/pipelineName=SomaticAmplicon;pipelineVersion=master/' | sed 's/NGHS101X/NGHS-101X/' | sed 's/NGHS102X/NGHS-102X/' | sed 's/ref\$/referral=/' | sed 's/%/;/g' | sed 's/\$/=/g' > SampleSheet_fixed.csv
mv SampleSheet_fixed.csv SampleSheet.csv

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

		# set different output path for validations if given
		if [ -z ${validation-} ] || [ $validation == 'FALSE' ]; then
			res_dir=/$res_dir_base/"$seqId"/"$panel"/"$sampleId"
		else 
			res_dir=/$val_dir_base/"$seqId"/"$panel"/"$sampleId"
		fi
		unset validation

		# make project folders
                mkdir -p $res_dir

		#soft link files
		cp $PWD/Data/"$sampleId"/"$variableFile" $res_dir
		for i in $(ls Data/"$sampleId"/"$sampleId"_S*.fastq.gz); do
			ln -s $PWD/"$i" $res_dir
		done

		# copy scripts
		cp /data/diagnostics/pipelines/"$pipelineName"/"$pipelineName"-"$pipelineVersion"/*sh $res_dir

                bash -c "cd $res_dir && sbatch -J "$panel"-"$sampleId" 1_*.sh"
	fi
done

# Copy the fixed SampleSheet to quality temp
cd $SLURM_SUBMIT_DIR
cp SampleSheet.csv /data_heath/archive/quality_temp/miseq/${seqId}/
