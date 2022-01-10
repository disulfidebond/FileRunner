# simple watcher script
while true ; do
  TSTRING=$(date +"%m%d_%H%M")
  source scanDir_fastq.automated.sh
  STARTVAR=$?
  if [ $STARTVAR -eq 0 ] ; then
    INITIAL_TSTRING=$(echo "$TSTRING")
    echo "created runFile.data.csv at $TSTRING" > runLog.hc.${INITIAL_TSTRING}.log
    bash createAndRun_AP_HC.sh 'hg19.fa' 'runFile.data.csv'
    while true ; do
      echo 'waiting for analysis to complete'
      if [ -f hc_run_completed ] ; then
        TSTRING=$(date +"%m%d_%H%M")
        echo "completed run at $TSTRING" >> runLog.hc.${INITIAL_TSTRING}.log
        sleep 10
        rm hc_run_completed
        break
      fi
      sleep 24h
    done
  else 
    echo 'no fastq files found'
  fi
  sleep 4h
done
