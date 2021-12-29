# FileRunner
FileRunner is a barebones implementation that allows sequencing files to be automatically processed through variant calling pipelines. There are two versions, an automated version that will start processing sequencing files as soon as they are copied to a directory, and a semiautomated version that allows a user to start and monitor processing pipelines. The former is at a beta state, the former is at an alpha state. Bugs, fixes, and updates are described in the Issues.

# Automated Version Usage and Description
Usage for the automated version is fairly straightforward. Open Terminal, change to the Mutect2, Haplotype_Caller, or AlignOnly directory, and then type `./fastq_scanner.sh`

Once every 30 minutes, the `fastq_scanner.sh` script will call `scanDir_fastq.automated.sh`, which will scan the directory for sequence files ending in `fq.gz`, `fq`, `fastq`, or `fastq.gz`. If it detects any of these files, then it will pause before scanning again. If it does detect any of these files, then it will generate a file manifest, and trigger the corresponding runfile `createAndRun` bash script. 

The Mutect2, Haplotype_Caller, and AlignOnly directories have tailored runfiles for each of the specified analyses. Here, 'preprocessing' refers to updating read groups in the alignment files, then marking duplicates, then running Base Quality Score Recalibration (BQSR):
- `createAndRun_AP.sh` generates execution scripts that run alignment and preprocessing.
- `createAndRun_AP_Mu2TO.sh` generates execution scripts that run alignment, preprocessing, and then the tumor-only mode of Mutect2
- `createAndRun_AP_HC.sh` generates execution scripts that run alignment, preprocessing, and then haplotype caller

All of the above workflows will run in parallel, but use minimal resources, and is designed to be run in the background. For example, the `bwa` execution script that is run uses the default of `-t1` for only a single thread, and picard uses the `-Xmx4g` argument. 

While running, the workflow will copy fastq.gz files, BWA alignment files (which end in `.sorted.bam`), preprocessed BAM files (which end in `bqsr.bam`), and output variant caller format VCF files (which end in `.vcf`) to a directory with a timestamp. For example, if you start FileRunner in the Mutect2 directory at `/data/workspace/Mutect2/` on December 29,2021, then these files will appear in the directory `/data/workspace/Mutect2_run1130_12292021`.

Currently, the behavior is to not delete intermediate files, such as the marked-duplicate BAM files that end in `mkDup.bam`, although these files can be deleted once the workflow has finished running.

If the workflow halts prematurely in an error, then it will remain 'frozen' at that stage, although the read and any output files will be copied to the aforementioned output directory. This behavior is caused by the run file copying fastq read files to the directory (thereby causing the `fastq_scanner.sh` not to (re-)start the analysis, and the runfiles always generating a completed run flag, which then resets the `fastq_scanner.sh` scanner script to scanning for copied read files.

It is strongly recommended to use `screen` when starting the workflow. Each step generates logfiles that can be scanned for completion and errors, and the output from the the `fastq_scanner.sh` script mainly provides updates to STDOUT that indicate it is running.

It is also **strongly** recommended not to modify any files in the Mutect2, Haplotype_Caller, and AlignOnly directories while an analysis is running, and to copy all fastq sequence files to the desired driectory at one time. Copying one set of fastq files, and then a second set of fastq files before the workflow has finished, is not supported yet and will have unpredictable results.

# Semi-automated Version Usage and Description
The initial setup of the Semi-automated version is similar to the automated one: copy the input files to the directory of choice (for example, copy the fastq read files to the Mutect2 directory if you want to run Mutect2 analyses in tunor-only mode). However, from there, do not run `fastq_scanner.sh`. Instead, open `workflow_runner.R` in RStudio, and follow the usage instructions in the file. Briefly, this R Script will create runfiles that you will start and monitor from within RStudio using the 'Jobs' tab, and can be either a single workflow with all steps, or individual workflows for each step.

Similar to the fully automated version, the workflow will use minimal resources and is designed to be run in the background.

### As of 12/29/2021, the semi-automated version of FileRunner is still undergoing work and is in an 'alpha' state. Use at your own risk.
