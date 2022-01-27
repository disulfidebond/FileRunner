#!/bin/bash

FQLIST=$1 # provided by scanning
REFFILE='hg19.fa'
HGVERSION='hg19' # default, must be manually modified

if [[ -z $REFFILE ]] ; then
  echo 'Please specify the required genome reference file'
  exit 1
fi

CHECKI=$(ls . | grep 'amb$')
if [[ -z $CHECKI ]] ; then
  echo 'WARNING! BWA index files may not be present'
  echo 'Please verify that bwa index has been run before proceeding'
  sleep 5
fi

if [[ -z $FQLIST ]] ; then
  echo 'Please provide the text file with the list of fastq files'
  echo 'The required format for the file is one line per pair of fastq files'
  echo 'For example:'
  echo ''
  echo 'sample1fastq1.fastq,sample1fastq2.fastq'
  echo 'sample2fastq1.fastq,sample2fastq2.fastq'
  echo ''
  exit 1
fi

if [[ -z $HGVERSION ]] ; then
  echo 'Please specify a human genome version as either hg19 or hg38'
  exit 1
else
  if [[ $HGVERSION != 'hg19' ]] ; then
    if [[ $HGVERSION != 'hg38' ]] ; then
      echo 'Unrecognized human genome identifier.'
      echo 'Please specify a human genome version as either hg19 or hg38'
      exit 1
    fi
  fi
fi

FQFILES=($(<${FQLIST}))
TSTRING=$(date +"%m%d_%H%M")
V=$(echo ${#FQFILES[@]})
PSTRING='wait'
# this sets the bash script to wait until all alignments are completed
for i in $(seq 1 $V) ; do
  PSTRING=$(echo "$PSTRING %$i")
done

# it is not a good idea to run more than 12 BWA alignments at a time
if ((V > 22)) ; then
  echo ''
  echo 'WARNING! The list of fastq files you have provided may overload the genie server.'
  echo 'Please double check you are certain this is what you want'
  echo 'before starting the alignment step'
  echo ''
  echo 'Pausing for 10 seconds'
  sleep 10
fi

# Setup1: create a command script for running bwa files
rm run_started 2> /dev/null
rm mu2to_run_completed 2> /dev/null

touch run_started
mkdir ../Mu2TO_run${TSTRING}

# Setup1: create a command script for running bwa files
touch run_started
mkdir ../Mu2TO_run${TSTRING}/

# Setup2: move other .bed, .bam, and .vcf files to
mkdir ../Mu2TO_run${TSTRING}/orig_files

ARRFILES_BAM=($(ls . | grep 'bam$'))
ARRFILES_VCF=($(ls . | grep 'vcf$' | grep -v 'resources_broad'))
ARRFILES_VCFGZ=($(ls . | grep 'vcf.gz$' | grep -v 'resources_broad'))
ARRFILES_BED=($(ls . | grep 'bed$'))        


for i in "${ARRFILES_BAM[@]}" ; do
  mv ${i} ../Mu2TO_run${TSTRING}/orig_files/
done
for i in "${ARRFILES_VCF[@]}" ; do
  mv ${i} ../Mu2TO_run${TSTRING}/orig_files/
done
for i in "${ARRFILES_VCFGZ[@]}"	; do
  mv ${i} ../Mu2TO_run${TSTRING}/orig_files/
done
for i in "${ARRFILES_BED[@]}" ;	do 
  mv ${i} ../Mu2TO_run${TSTRING}/orig_files/
done

for i in "${FQFILES[@]}" ; do
  FQ1=$(echo "$i" | cut -d, -f1)
  FQ2=$(echo "$i" | cut -d, -f2)
  BAMNAME=$(echo "$FQ1" | cut -d_ -f1-3)
  BAMNAME=$(echo "${BAMNAME}.sorted.bam")
  echo "bwa mem ${REFFILE} ${FQ1} ${FQ2} 2> ${BAMNAME}.${TSTRING}.log | samtools sort -o ${BAMNAME} - &" >> bwa_align_${TSTRING}
done
echo "$PSTRING" >> bwa_align_${TSTRING}
echo "echo 'job done'" >> bwa_align_${TSTRING}
echo "touch bwa_align_${TSTRING}_finished" >> bwa_align_${TSTRING}
echo 'Finished creating  parallel executable file named:'
echo "bwa_align_${TSTRING}"


# Run Section 1: BWA
# start alignment step, then scan for completion at 30 minute intervals
bash bwa_align_${TSTRING}
while true ; do
  if [ -f bwa_align_${TSTRING}_finished ] ; then
    echo 'finished BWA alignment step'
    mv *.fq.gz ../Mu2TO_run${TSTRING}/
    mv *.fastq.gz ../Mu2TO_run${TSTRING}/
    mv *.fastq ../Mu2TO_run${TSTRING}/
    mv *.fq ../Mu2TO_run${TSTRING}/
    break
  fi
  echo 'pausing for alignment to complete...'
  sleep 1800
done

# Setup2: create a command script for merging BAM files
BAMLIST=($(ls . | grep 'sorted.bam$' | cut -d_ -f1-2 | sort -n | uniq))
V=$(echo ${#BAMLIST[@]})
PSTRING='wait'
# this sets the bash script to wait until all alignments are completed
for i in $(seq 1 $V) ; do
  PSTRING=$(echo "$PSTRING %$i")
done

for i in "${BAMLIST[@]}" ; do
  BAMRGX=$(echo "$i")
  OUTBAMNAME=$(echo "${BAMRGX}.merged.sorted.bam")
  BAMFILES=($(ls . | grep "^${BAMRGX}" | grep -v merged | grep 'sorted.bam$'))
  BAMSTRING=''
  for x in "${BAMFILES[@]}" ; do
    S=$(echo "I=${x} ")
    BAMSTRING=$(echo "${BAMSTRING}${S}")
  done
  echo "java -Xmx4g -jar /PATH/TO/PICARD/picard.jar MergeSamFiles AS=true ${BAMSTRING} O=${OUTBAMNAME} &> mergeLog.${OUTBAMNAME}.${TSTRING}.txt &" >> merge_command_${TSTRING}
done
echo "$PSTRING" >> merge_command_${TSTRING}
echo "touch merge_command_${TSTRING}_finished" >> merge_command_${TSTRING}
echo 'Finished creating merge runfile named:'
echo "merge_command_${TSTRING}"

# Run Section 2: Merge BAM files
bash merge_command_${TSTRING}
while true ; do
  if [ -f merge_command_${TSTRING}_finished ] ; then
    echo 'finished merge alignment step'
    break
  fi
  echo 'pausing for alignment to complete...'
  sleep 1800
done


# Setup3: create a command script for running preprocess steps
BAMLIST=($(ls . | grep 'merged.sorted.bam$'))

# remove existing rg files
rm *.rg.txt 2> /dev/null
# create new rg files
for i in "${BAMLIST[@]}" ; do
  SMNAME=$(echo "$i" | cut -d. -f1)
  echo "ID:${SMNAME}" >> ${SMNAME}.rg.txt
  echo "LB:LB0001" >> ${SMNAME}.rg.txt
  echo "PL:Illumina" >> ${SMNAME}.rg.txt
  echo "SM:${SMNAME}" >> ${SMNAME}.rg.txt
  echo "PU:1" >> ${SMNAME}.rg.txt
done

RGFILE='.rg.txt'

# required variables
V=$(echo ${#BAMLIST[@]})
PSTRING='wait'
for i in $(seq 1 $V) ; do
  PSTRING=$(echo "$PSTRING %$i")
done

INDEL1=''
INDEL2=''
if [[ $HGVERSION == 'hg19' ]] ; then
  INDEL1='resources_broad_hg38_v0_Homo_sapiens_assemblyhg19.crossMap.known_indels.fixed.sorted.vcf'
  INDEL2='resources_broad_hg38_v0_Mills_and_1000G_gold_standard.indels.hg19.crossMap.fixed.sorted.vcf'
else
  INDEL1='resources_broad_hg38_v0_Homo_sapiens_assembly38.known_indels.vcf'
  INDEL2='resources_broad_hg38_v0_Mills_and_1000G_gold_standard.indels.hg38.vcf'
fi

# Preprocess Step1: fix RG
declare -a FBAMLIST
for i in "${BAMLIST[@]}" ; do
  RGTEXT=$(echo "$i" | cut -d. -f1)
  RGTEXT=$(echo "${RGTEXT}${RGFILE}")
  TMPARR=($(<${RGTEXT}))
  IDSTRING=$(echo "${TMPARR[0]}" | cut -d: -f2)
  LBSTRING=$(echo "${TMPARR[1]}" | cut -d: -f2)
  PLSTRING=$(echo "${TMPARR[2]}" | cut -d: -f2)
  SMSTRING=$(echo "${TMPARR[3]}" | cut -d: -f2)
  PUSTRING=$(echo "${TMPARR[4]}" | cut -d: -f2)
  BAMFILE=$(echo "$i" | sed 's/\.bam//g')
  BAMFILE=$(echo "${BAMFILE}.fixed.bam")
  FBAMLIST+=("${BAMFILE}")
  echo "java -Xmx4g -jar /PATH/TO/PICARD/picard.jar AddOrReplaceReadGroups I=${i} O=${BAMFILE} ID=$IDSTRING LB=$LBSTRING PU=$PUSTRING PL=$PLSTRING SM=$SMSTRING 2>> step1Log_${i}.txt &" &>> step1_${TSTRING}
done
echo "$PSTRING" >> step1_${TSTRING}
echo "touch step1_${TSTRING}_finished" >> step1_${TSTRING}
echo "completed setup for task 1 and created file step1_${TSTRING}"

# Preprocess Step2: Mark Duplicates
for i in "${FBAMLIST[@]}" ; do
  BFILE=$(echo "$i" | sed 's/\.bam//g')
  OUTFILE=$(echo "${BFILE}.mkDup.bam")
  MFILE=$(echo "${BFILE}.mkDup.metrics.txt")
  INFILE=$(echo "${BFILE}.bam")
  echo "samtools index ${INFILE}" &>> step2_${TSTRING}
  echo 'sleep 2' &>> step2_${TSTRING}
  echo "java -Xmx4g -jar /PATH/TO/PICARD/picard.jar MarkDuplicates I=${INFILE} O=${OUTFILE} M=${MFILE} 2>> mkDupLog.${BFILE}.${TSTRING}.txt &" &>> step2_${TSTRING}
done

echo "$PSTRING" >> step2_${TSTRING} 
echo "touch step2_${TSTRING}_finished" >> step2_${TSTRING}
echo "completed setup for task 2 and creted file step2_${TSTRING}"

# Preprocess Step3 Setup: BQSR using GATK
for i in "${FBAMLIST[@]}" ; do
  # BFILE=$(echo "$i" | rev | cut -d. -f3- | rev)
  BFILE=$(echo "$i" | sed 's/\.bam//g')
  INFILE=$(echo "${BFILE}.mkDup.bam")
  echo "samtools index ${INFILE}" &>> step3_${TSTRING}
  # echo 'wait %1' >> step3_${TSTRING}
  echo 'sleep 2' >> step3_${TSTRING}
  BQSRFILE=$(echo "${BFILE}.mkDup.bqsr.table")
  echo "gatk BaseRecalibrator --known-sites $INDEL1 --known-sites $INDEL2 -I $INFILE -R $REFFILE -O $BQSRFILE &> ${i}.bqsr.log &" &>> step3_${TSTRING}
done
echo "$PSTRING" >> step3_${TSTRING}

for i in "${FBAMLIST[@]}" ; do
  # BFILE=$(echo "$i" | rev | cut -d. -f3- | rev)
  BFILE=$(echo "$i" | sed 's/\.bam//g')
  BQSRFILE=$(echo "${BFILE}.mkDup.bqsr.table")
  INFILE=$(echo "${BFILE}.mkDup.bam")
  OUTFILE=$(echo "${BFILE}.mkDup.bqsr.bam")
  echo "gatk ApplyBQSR --bqsr-recal-file $BQSRFILE -I $INFILE -O $OUTFILE &> ${i}.normal.applybqsr.log &" &>> step3_${TSTRING}
done
echo "$PSTRING" >> step3_${TSTRING}
echo "touch step3_${TSTRING}_finished" >> step3_${TSTRING}
echo "completed setup and created file step3_${TSTRING}"


# Run section for preprocessing

# run preprocessing steps sequentially, and scan at 30 minute intervals
bash step1_${TSTRING}
while true ; do
  if [ -f step1_${TSTRING}_finished ] ; then
    echo 'finished Preprocess Step 1: Fix RG'
    break
  fi
  echo 'pausing for Fix RG Step to complete...'
  sleep 1800
done

bash step2_${TSTRING}
while true ; do
  if [ -f step2_${TSTRING}_finished ] ; then
    echo 'finished Preprocess Step 2: Mark Duplicates'
    break
  fi
  echo 'pausing for Mark Duplicates Step to complete...'
  sleep 1800
done

bash step3_${TSTRING}
while true ; do
  if [ -f step3_${TSTRING}_finished ] ; then
    echo 'finished Preprocess Step 3: BQSR'
    mv *.sorted.bam ../Mu2TO_run${TSTRING}/
    break
  fi
  echo 'pausing for BQSR Step to complete...'
  sleep 1800
done

# Analysis Setup for Mutect2: Tumor Only
BAMLIST=($(ls . | grep 'bqsr.bam$'))
# run Mutect2
declare -a VCFLIST
for i in "${BAMLIST[@]}" ; do
  OUTNAME=$(echo "$i" | cut -d, -f1 | cut -d. -f1)
  TUMORBAM=$(echo "$i")
  OUTPUTNAME=$(echo "mutect2.unfiltered.tumorOnly.${OUTNAME}.vcf")
  VCFLIST+=("${OUTPUTNAME}")
  echo "gatk --java-options \"-Xmx16g\" Mutect2 --independent-mates true -R ${REFFILE} -I ${TUMORBAM} -O ${OUTPUTNAME} &> ${i}.mutect2.${TSTRING}.log &" &>> stepMutect2_${TSTRING}
  echo "sleep 2" >> stepMutect2_${TSTRING}
done
echo "$PSTRING" >> stepMutect2_${TSTRING}
echo "echo 'Finished Mutect2 Step of workflow, starting Filtering'" >> stepMutect2_${TSTRING}

# run Mutect2 Filtering
for i in "${VCFLIST[@]}" ; do
  OUTNAMEVCF=$(echo "$i" | cut -d. -f3-)
  OUTNAMEVCF=$(echo "mutect2.${OUTNAMEVCF}")
  if [[ $RUNMODE != 'PAIRED' ]] ; then
    echo "gatk --java-options \"-Xmx16g\" FilterMutectCalls -V ${i} -O ${OUTNAMEVCF} &> ${i}.filtermutect2.${TSTRING}.log &" &>> stepMutect2_${TSTRING}
    echo "sleep 2" >> stepMutect2_${TSTRING}
  else
    echo "gatk --java-options \"-Xmx16g\" FilterMutectCalls -V ${i} -O ${OUTNAMEVCF} &> ${i}.filtermutect2.${TSTRING}.log &" &>> stepMutect2_${TSTRING}
    echo "sleep 2" >> stepMutect2_${TSTRING}
  fi
done
echo "$PSTRING" >> stepMutect2_${TSTRING}
echo "touch stepMutect2_${TSTRING}_finished" >> stepMutect2_${TSTRING}
echo "echo 'Workflow Completed'" >> stepMutect2_${TSTRING}
echo "completed setup and created file stepMutect2_${TSTRING}
sleep 30


bash stepMutect2_${TSTRING}
while true ; do
  if [ -f stepMutect2_${TSTRING}_finished ] ; then
    echo 'finished Mutect2 Analysis'
    mkdir ../Mu2TO_run${TSTRING}/BAM_VCF
    mv *.bqsr.bam ../Mu2TO_run${TSTRING}/BAM_VCF/
    mv *.vcf ../Mu2TO_run${TSTRING}/BAM_VCF/
    mv *.idx ../Mu2TO_run${TSTRING}/BAM_VCF/
    mv *.stats ../Mu2TO_run${TSTRING}/BAM_VCF/
    break
  fi
  echo 'pausing for Mutect2 analyses to complete...'
  sleep 1800
done

mkdir ../Mu2TO_run${TSTRING}/runfiles_and_logs
mv mkDupLog.* ../Mu2TO_run${TSTRING}/runfiles_and_logs/
mv step1* ../Mu2TO_run${TSTRING}/runfiles_and_logs/
mv step2* ../Mu2TO_run${TSTRING}/runfiles_and_logs/
mv step3* ../Mu2TO_run${TSTRING}/runfiles_and_logs/
mv *.log ../Mu2TO_run${TSTRING}/runfiles_and_logs/
mv *.rg.txt ../Mu2TO_run${TSTRING}/runfiles_and_logs/
mv *.sorted.fixed.mkDup.metrics.txt ../Mu2TO_run${TSTRING}/runfiles_and_logs/
mv *.sorted.fixed.mkDup.bqsr.table ../Mu2TO_run${TSTRING}/runfiles_and_logs/
mv mergeLog* ../Mu2TO_run${TSTRING}/runfiles_and_logs/
mv merge_command* ../Mu2TO_run${TSTRING}/runfiles_and_logs/

rm *.sorted.fixed.bam*
rm *.sorted.fixed.mkDup.bam*
rm *.sorted.fixed.mkDup.bqsr.bai
echo 'cleanup completed'

touch mu2to_run_completed
