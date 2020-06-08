#!/bin/sh
#PBS -V # export all environment variables to the batch job.
#PBS -q sq # submit to the serial queue
#PBS -l walltime=72:00:00 # Maximum wall time for the job.
#PBS -l feature=highmem # High Memory
#PBS -A Research_Project-MRC190311 # research project to submit under. 
#PBS -l procs=1 # specify number of processors.
#PBS -m e -M e.j.hannon@exeter.ac.uk # email me at job completion
#PBS -e LogFiles/ChipAlignmentPE.err # error file
#PBS -o LogFiles/ChipAlignmentPE.log # output file

## needs to be executed from the scripts folder

## Output some useful job information

echo PBS: working directory is $PBS_O_WORKDIR
echo PBS: job identifier is $PBS_JOBID
echo PBS: job name is $PBS_JOBNAME
echo PBS: current home directory is $PBS_O_HOME

## print start date and time
echo Job started on:
date -u


####### 
## NOTE: Do not store confidential information in this file use the config file
######

cd $PBS_O_WORKDIR
#cd ${SCRIPTDIR}
source ./ChipSeq/config.txt

## run fastqc
module load FastQC 
fastqc ${DATADIRPE}/*q.gz

## rn fastp
module load fastp
cd ${DATADIRPE}
mkdir -p 11_trimmed
mkdir -p 11_trimmed/fastp_reports/
R1Files=($(ls *R1*q.gz))
for f in ${R1Files[@]};	
do	
	## find both paired files
	sampleName=${f/_*}
	if [ ! -f 11_trimmed/fastp_reports/${sampleName}_fastp.json ]	
	then
		pairedFiles=($(ls ${sampleName}*.gz))
		f1=${pairedFiles[0]}
		f2=${pairedFiles[1]}
		
		outf1=${f1/.f/_trimmed.f}
		outf2=${f2/.f/_trimmed.f}
	
		fastp --cut_tail --cut_tail_mean_quality=20 --detect_adapter_for_pe --length_required=27 --thread=8 --in1=${f1} --in2=${f2} --out1=11_trimmed/${outf1} --out2=11_trimmed/${outf2} --html=11_trimmed/fastp_reports/${sampleName}_fastp.html --json=11_trimmed/fastp_reports/${sampleName}_fastp.json
	fi
done


## merge QC output
module purge ## had conflict issues if this wasn't run first
module load MultiQC/1.2-intel-2017b-Python-2.7.14
cd ${DATADIRPE}
multiqc . -f ## can add flag to ignore certain folders if needed

## run alignment

module purge ## had conflict issues if this wasn't run first
module load Bowtie2
module load SAMtools
module load picard/2.6.0-Java-1.8.0_131
#module load Java
cd ${SCRIPTDIR}/ChipSeq/
./alignmentPE.sh ## by using ./ rather than sh executes script in current session and can make use of variables alredy declared.


module purge
module load BEDTools
module load SAMtools
module load picard/2.6.0-Java-1.8.0_131
cd ${SCRIPTDIR}/ChipSeq
./calcENCODEQCMetricsPE.sh

echo Starting peak calling at:
date -u
module purge
module load MACS2
cd ${SCRIPTDIR}/ChipSeq/
./peakCallingPE.sh


## print finish date and time
echo Job finished on:
date -u