# simple watcher script
while true ; do
  TSTRING=$(date +"%m%d_%H%M")
  source scanDir_fastq.automated.sh
  if [ -f runFile.data.csv ] ; then
    INITIAL_TSTRING=$(echo "$TSTRING")
    echo "created runFile.data.csv at $TSTRING" > runLog.mu2to.${INITIAL_TSTRING}.log
    bash createAndRun_AP_Mu2TO.sh 'hg19.fa' 'runFile.data.csv'
    while true ; do
      echo 'waiting for analysis to complete'
      if [ -f mu2to_run_completed ] ; then
        TSTRING=$(date +"%m%d_%H%M")
        echo "completed run at $TSTRING" >> runLog.mu2to.${INITIAL_TSTRING}.log
        sleep 10
        rm mu2to_run_completed
        break
      fi
      sleep 24h
    done
  else 
    echo 'no fastq files found'
  fi
  sleep 4h
done
