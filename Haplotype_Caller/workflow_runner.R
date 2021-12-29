# scan the directory for fastq files
system('bash scanDir_fastq.automated.sh')
# start workflow to run from start to finish
system('bash createAndRun_AP_HC.sh')
